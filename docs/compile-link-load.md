# 从 C 源码到运行进程：完整链条与验证手册

一份“每一步都拿工具证明给自己看”的笔记。
目标程序：本仓库 `src/pc_hello_world/main.c`

```c
#include <stdio.h>

int main(void) {
    printf("Hello, World!\n");
    return 0;
}
```

本文所有“证据”都在 `docs/artifacts/` 里，是从仓库里那份 Linux `a.out` 用 `readelf` /
`objdump` 真实抓下来的。**注意**：生成 `a.out` 的开发机是 Linux x86-64（ELF）。
本文命令都是 Linux 命令；本机是 Windows，命令留到 Linux 机器上跑。
`docs/reproduce.sh` 可一键重跑整条链并重新抓取所有证据。

---

## 0. 一句话全景

```
  源码            预处理            编译            汇编             链接
 main.c  --cpp-->  main.i  --cc1-->  main.s  --as-->  main.o  --ld-->  a.out
  文本             纯文本            汇编文本          机器码            机器码
                                                     +符号表          +符号表+动态信息
                                                     (ELF ET_REL)     (ELF ET_DYN / PIE)

 运行:
 execve(a.out)
   └─ 内核读 ELF 头: e_entry=0x1060, PT_INTERP=ld.so
      ├─ 映射 ld.so + libc
      └─ 把 PC 设为 ld.so 的入口   ← 不是 0 !
           └─ ld.so 重定位, 跳到 a.out 的 _start (0x1060)
                └─ _start 调 __libc_start_main(main, ...)
                     └─ __libc_start_main 初始化 libc, 调 main
                          └─ main 调 puts/printf → write(1,...)
                               └─ main ret → exit_group(0)
```

核心结论先行，后面逐步证明：

1. `gcc` 是**驱动**，不是一个巨型编译器；它依次调用 `cpp → cc1 → as → ld`。
2. “编译”严格只指 `cc1` 那一步（C→汇编）。你脑子里的“变机器码”是**汇编**那一步。
3. `.o` **也是 ELF**。ELF 是容器格式，不是“可执行文件”的同义词。
4. 进程的 PC **从不从 0 开始**。内核读 ELF 头里的入口点 `e_entry`。裸机开机才从 reset vector 起。
5. `syscall` 陷入**内核**，不是某个叫 “system” 的东西。而且程序启动早期很多 syscall 是 `ld.so`/`libc` 发的，不是你的 `main`。

---

## 1. 工具链里到底有哪些程序

`gcc` 全称 GNU Compiler Collection，但命令 `gcc` 本身是个**驱动程序（driver）**：
它解析参数、按顺序调用真正干活的小程序，自己不翻译代码。

| 阶段 | 干活的可执行文件 | 干什么 | 输入 → 输出 |
|---|---|---|---|
| 预处理 | `cpp`（或 `cc1 -E`） | 展开 `#include`、宏、条件编译 | `main.c` → `main.i` |
| 编译 | `cc1`（C 前端） | C 语法 → 目标 ISA 汇编 | `main.i` → `main.s` |
| 汇编 | `as`（GNU assembler） | 汇编文本 → 机器码目标文件 | `main.s` → `main.o` |
| 链接 | `ld`（经 `collect2`） | 符号解析、重定位、合并、拉入库 | `main.o` + `crt*.o` + `libc` → `a.out` |

多语言支持 = 多个前端：`cc1`(C)、`cc1plus`(C++)、`gfortran`……

**验证 gcc 确实在调这些小程序：**

```bash
gcc -### main.c 2>&1        # 打印每一步实际执行的命令(不真跑)
gcc -v main.c -o a.out 2>&1 # 真跑, 把调用的子程序都打出来
```

看输出里的 `cc1`、`as`、`collect2`(它再调 `ld`) 三段。

---

## 2. 四步流水线，每步的产物与证明

### 2.0 源文件

- 产物：`main.c`（证据：`docs/artifacts/main.c`）
- 检查：`file main.c` → ASCII text / UTF-8

### 2.1 预处理（Preprocess）

命令：

```bash
gcc -E main.c -o main.i
```

`-E` = 只跑预处理器。把 `#include <stdio.h>` 整个头文件展开，宏替换，删注释。

- 产物：`main.i` —— 仍然是**纯文本**，但可能几千行。
- 检查手法：

```bash
wc -l main.i                       # 行数暴涨 (几十行源码 → 上千行)
head -n 20 main.i                  # 看到 stdio.h 展开的内容
grep -n "Hello, World!" main.i     # 你的字符串还在
grep -n "extern int printf" main.i # 函数声明被搬进来了
file main.i                        # C source, ASCII text
```

证明点：`printf` 在 `.i` 里只是个**声明**，没有实现——实现要等链接时去 libc 找。

### 2.2 编译（Compile，狭义）

命令：

```bash
gcc -S -O0 -masm=intel main.c -o main.O0.s   # 未经优化
gcc -S -O2 -masm=intel main.c -o main.O2.s   # 优化后
```

- 产物：`main.s` —— **汇编文本**，已经是目标 ISA（x86-64）的指令，但还不是机器码。
- 中间产物在哪：本仓库 Windows 侧生成过 `src/pc_hello_world/main.O0.s` / `main.O2.s`。
  **警告**：那两份是 MinGW 生成的 **Windows/PE 目标**汇编（传参见 `rcx/rdx`、`__mingw_vfprintf`、
  `__main`），和 Linux `a.out` 不是一回事。要在 Linux 上重生成。
- 检查手法：

```bash
file main.O0.s                  # assembler source
grep -n "call" main.O0.s        # 能看到 call printf / call puts
grep -n ".string\|.ascii" main.O0.s | grep Hello   # 字符串常量
diff <(gcc -S -O0 ... ) ...     # 对比 -O0 与 -O2 差异
```

**有意思的证据**：本仓库那份 `a.out` 是优化过的，`objdump -d` 里 `main` 调的是
`puts@plt` 而不是 `printf@plt` —— 编译器把 `printf("...\n")` 优化成了 `puts("...")`
（见 `docs/artifacts/objdump-d.txt` 第 115-124 行）。这就是 `.s` 这一步能改变最终指令的直接证据。

### 2.3 汇编（Assemble）

命令：

```bash
gcc -c main.c -o main.o     # 等价于先 -S 再调 as
as main.O0.s -o main.o      # 直接调汇编器
```

- 产物：`main.o` —— **可重定位目标文件**，ELF 格式，类型 `ET_REL`。
- 关键：`.o` **就是 ELF**！不要把 ELF 等同于“可执行”。
- 检查手法：

```bash
file main.o                          # ELF 64-bit relocatable
readelf -h main.o                    # Type: REL (Relocatable file)
readelf -s main.o                    # 符号表: main 已定义, printf 是 UND(未定义)
readelf -r main.o                    # 重定位表: 引用 printf 的地方留了坑, 等链接器填
objdump -d main.o                    # 机器码, 但跳转/调用地址是占位 0
```

证明点：`.o` 里 `main` 是 `FUNC GLOBAL`, `printf` 是 `FUNC GLOBAL UND`（undefined）。
调用 `printf` 处的地址还是 0，地址值记在**重定位表**里。链接器的活就是填这个坑。

### 2.4 链接（Link）

命令：

```bash
gcc main.c -o a.out                 # 驱动自动把 crt*.o、libc、动态信息都接上
# 或者看得更清楚:
gcc -v main.c -o a.out 2>&1 | tail -20   # 看 collect2 / ld 的完整命令行
```

链接器做四件事：

1. **符号解析**：把每个 `.o` 里的 `UND` 符号（`printf`, `__libc_start_main`）去
   `libc.so.6` 等库的符号表里找定义。
2. **重定位**：把 `.o` 里占位的 0 地址换成真实地址/偏移。
3. **拉入启动代码和库**：`Scrt1.o`（提供 `_start`）、`crti.o`/`crtn.o`、
   `libc.so.6`。所以最终程序里有 `_start`，但你源码里没写。
4. **定下入口点**：ELF 头的 `e_entry` 写成 `_start` 的地址。

- 产物：`a.out` —— ELF，类型 `ET_DYN`（PIE 可执行）。
- 检查手法（这些就是本文 `docs/artifacts/` 的证据来源）：

```bash
file a.out
readelf -h a.out          # Entry point address: 0x1060 ; Type: DYN ; Machine: X86-64
readelf -l a.out          # 看 INTERP: /lib64/ld-linux-x86-64.so.2
readelf -d a.out          # NEEDED: libc.so.6
readelf -s a.out          # 现在 puts 仍是 UND, 由运行时动态链接器解决
objdump -d -M intel a.out | sed -n '/<_start>:/,/^$/p'
```

真实的 `a.out` 头部（`docs/artifacts/readelf-h.txt`）：

```
Class:    ELF64
Data:     2's complement, little endian
OS/ABI:   UNIX - System V        <- ABI 归属
Type:     DYN (Position-Independent Executable file)
Machine:  Advanced Micro Devices X86-64   <- ISA 归属
Entry point address: 0x1060
```

**架构 vs 指令集（你上一条问的）**：
- **ISA**（x86-64）决定指令编码。它在 **2.2 编译**那一步就定死了 —— 所以“编译那步已符合指令集”是对的。
- **ABI / 目标三元组**（`x86_64-pc-linux-gnu`）决定调用约定、syscall 号、ELF 格式、动态链接方式。
  ELF 头里的 `OS/ABI: System V`、`Machine: X86-64` 就是这两者的落款。

---

## 3. ELF 解剖：一个可执行文件的四张表

用 `readelf` 拆 `a.out`。对应证据文件见括号。

### 3.1 ELF Header（`readelf -h`，`artifacts/readelf-h.txt`）
魔数 `7f 45 4c 46`（"ELF"）、类别（ELF64）、端序（小端）、`e_entry`、机器类型。

### 3.2 Program Headers / 段（`readelf -l`，`artifacts/readelf-l.txt`）
**给内核/加载器看的**：哪些字节区间要以什么权限映射到内存。

```
LOAD  offset 0x0     R      代码段前的只读
LOAD  offset 0x1000  R E    代码段(可执行)
LOAD  offset 0x2000  R      只读数据(.rodata)
LOAD  offset 0x2db8  RW     数据段
INTERP -> /lib64/ld-linux-x86-64.so.2
```
`Segment to Segment mapping` 那节告诉你“哪个段包含哪些 section”。

### 3.3 Sections / 节（`readelf -S`，`artifacts/readelf-S.txt`）
**给链接器和工具看的**：`.text`(代码)、`.rodata`(只读字符串/常量)、`.data`、`.bss`、
`.symtab`(符号表)、`.dynsym`(动态符号表)、`.dynstr`、`.rela.dyn`/`.rela.plt`(重定位)、`.dynamic`。

`main` 里字符串的最终位置（`objdump -s -j .rodata`，`artifacts/objdump-rodata.txt`）：

```
 2000 01000200 48656c6c 6f2c2057 6f726c64  ....Hello, World
 2010 2100                                 !.
```
"Hello, World!\0" 在 `0x2004`，正好是 `main` 里 `lea rax,[rip+0xeac] # 2004` 指向的地方。

### 3.4 Symbol Table / 符号表（`readelf -s`，`artifacts/readelf-syms.txt` 等）
一张 **名字 → 地址/偏移 + 类型 + 绑定** 的表。你上次问的“符号表是什么”就是它。

```
_statement    Value      Type Bind   Ndx Name
    29: 0x1060     38 FUNC GLOBAL  16  _start
    31: 0x1149     30 FUNC GLOBAL  16  main
    18: 0x0         0 FUNC GLOBAL UND  __libc_start_main   <- 未定义, 运行时补
    21: 0x0         0 FUNC GLOBAL UND  puts@GLIBC_2.2.5    <- 未定义, 运行时补
```

- `Ndx = UND` 表示这个符号没在本文件定义，靠链接器（静态）或动态链接器（运行时）补。
- **两种符号表**：
  - `.symtab`：链接/调试用，可以 `strip` 掉。
  - `.dynsym`：运行时动态链接必须保留。
- 工具靠它：`readelf -s`、`nm`、`gdb`、backtrace。

### 3.5 Dynamic / 重定位（`readelf -d`、`readelf -r`）
`readelf -d a.out`（`artifacts/readelf-d.txt`）关键行：

```
NEEDED      Shared library: [libc.so.6]     <- 运行时要去加载它
FLAGS       BIND_NOW
FLAGS_1     Flags: NOW PIE                  <- PIE 可执行
```

`readelf -r a.out`（`artifacts/readelf-relocs.txt`）关键行：

```
R_X86_64_GLOB_DAT  __libc_start_main@GLIBC_2.34
R_X86_64_JUMP_SLOT puts@GLIBC_2.2.5
```

这些就是“链接期没法填、必须等运行时由 `ld.so` 填”的坑。因为 `libc.so.6` 是共享库，
它的加载地址每次运行都不同（ASLR），所以 `puts` 的真实地址只能在进程启动时才知道。

---

## 4. 运行时：程序到底从哪里开始执行

**关键结论：PC 永远不从 0 开始。** 内核读 ELF 头 `e_entry` 决定跳哪。

### 4.1 分层

| 层 | 谁提供 | 入口 |
|---|---|---|
| 可执行文件 | 你编译的 `a.out` | `e_entry = 0x1060`（`_start`） |
| 动态链接器 | 系统 `ld-linux-x86-64.so.2` | 它自己的 `_start` |
| libc | 系统 `libc.so.6` | `__libc_start_main` 之后调 `main` |

### 4.2 完整启动序列

1. shell 调 `execve("./a.out", ...)` → 陷入内核（syscall）。
2. 内核读 `a.out` 的 ELF 头：
   - 看到 `PT_INTERP` 段 → `/lib64/ld-linux-x86-64.so.2`。
   - 把 `a.out` 的 `LOAD` 段按权限映射进新地址空间（基址随机，ASLR）。
   - 再把 **`ld.so` 也映射进来**，并把 **PC 设成 `ld.so` 的入口**（不是 `a.out` 的入口！）。
3. `ld.so` 运行：
   - 读 `a.out` 的 `.dynamic`，按 `NEEDED` 去加载 `libc.so.6`（这就是 `strace-linux.txt`
     里一连串 `openat(...libc.so.6)`、`mmap(...)` 的来源）。
   - 做重定位，把 GOT 里的 `puts` 槽填成 libc 中的真实地址。
   - 跳转到 `a.out` 的 `e_entry = 0x1060`。
4. `_start`（`objdump -d` 反汇编，`artifacts/objdump-d.txt` 第 44-59 行）：

```
0000000000001060 <_start>:
  1060: endbr64
  1064: xor    ebp,ebp
  1066: mov    r9,rdx              ; rdx = _rtld_fini
  1069: pop    rsi                 ; rsi = argc
  106a: mov    rdx,rsp             ; rdx = argv
  106d: and    rsp,0xfffffffffffffff0
  1071: push   rax
  1072: push   rsp
  1073: xor    r8d,r8d             ; r8 = fini
  1076: xor    ecx,ecx             ; rcx = init
  1078: lea    rdi,[rip+0xca]      ; rdi = &main  → 0x1149
  107f: call   [rip+...]           ; call __libc_start_main
  1085: hlt                        ; 如果从这里返回就崩
```

   `_start` 的活：把 `argc`/`argv`/`envp` 摆到 ABI 规定的寄存器，把 `main` 地址放进 `rdi`，
   然后调 `__libc_start_main`。
5. `__libc_start_main`：
   - 初始化 libc（TLS、堆、stdio 等 —— 对应 strace 里的 `arch_prctl`、`brk`、`rseq`、`getrandom`）。
   - 调 `main`（通过 `_start` 传进来的函数指针）。
6. `main`（`objdump-d.txt` 第 115-124 行）：

```
0000000000001149 <main>:
  1149: endbr64
  114d: push   rbp
  114e: mov    rbp,rsp
  1151: lea    rax,[rip+0xeac]      ; "Hello, World!\n" @ 0x2004
  1158: mov    rdi,rax
  115b: call   1050 <puts@plt>       ; 优化后: printf → puts
  1160: mov    eax,0x0
  1165: pop    rbp
  1166: ret
```

7. `main` 返回 → 回到 `__libc_start_main` → 它调 `exit(0)` → `exit_group` syscall → 进程结束。

**证明入口不是 main**：

```bash
readelf -h a.out | grep Entry          # 0x1060, 而 main 在 0x1149
readelf -s a.out | grep -E "_start| main"
gdb ./a.out -batch -ex "starti" -ex "info registers rip"  # 第一停到处就是 _start/ld.so
```

`starti` 停在**第一条指令**；对动态程序通常先在 `ld.so` 里，`continue` 到 `_start` 后才见 `main`。

---

## 5. 看进程的地址空间

程序跑得太快（`a.out` 微秒级退出），直接 `cat /proc/PID/maps` 抓不到。方法：

### 方法 A：/proc/<pid>/maps（最原始、最准）
临时在 `main` 里加一个停顿再重编：

```c
// main.c 顶部 #include <stdio.h>
int main(void) {
    printf("Hello, World!\n");
    getchar();          // 卡住, 等回车
    return 0;
}
```

然后：

```bash
./a.out &            # 后台跑
PID=$!
cat /proc/$PID/maps  # 地址空间布局
cat /proc/$PID/maps > docs/artifacts/maps.txt
wait $PID
```

会看到类似（地址随 ASLR 每次不同）：

```
55...000 r--p  00000000  a.out          <- 只读段(ELF头)
55...000 r-xp  00001000  a.out          <- 代码段, 含 _start/main
55...000 r--p  00002000  a.out          <- .rodata
55...000 rw-p  00003000  a.out          <- .data/.bss
7f...000 r-xp  00000000  libc.so.6
7f...000 r--p  ...        ld-linux-x86-64.so.2
7f...000 rw-p  [stack]                  <- 栈, 高端
7f...000 r-xp  [vdso]                   <- 内核注入的"虚拟动态库", 让 syscall 更快
```

### 方法 B：pmap（美化版）
```bash
pmap $PID
pmap -x $PID      # 带 RSS/脏页统计
```

### 方法 C：gdb
```bash
gdb ./a.out -batch \
  -ex "b main" -ex "run" \
  -ex "info proc mappings" \
  -ex "info registers rip rsp"
```
`info proc mappings` 的输出格式和 `/proc/PID/maps` 一样。

### 方法 D：让 ld.so 自己说话
```bash
LD_DEBUG=libs ./a.out 2> docs/artifacts/ld-debug-libs.txt   # 打印加载哪些库、地址
LD_DEBUG=files ./a.out                                      # 打印打开的文件
LD_DEBUG=reloc ./a.out                                      # 打印重定位
```
这就是“动态链接器如何填坑”的第一手日志。

### 方法 E：从 strace 重建
`strace-linux.txt` 里所有 `mmap`/`brk`/`munmap` 的返回值，拼起来就是地址空间的一张快照
（如 `libc` 被映射到 `0x761297000000`）。

---

## 6. syscall：谁在什么时候陷入内核

`strace` 抓的是**每一次用户态→内核态的穿越**。命令：

```bash
strace ./a.out                            # 基本
strace -f ./a.out                         # 跟随子进程/线程
strace -T ./a.out                         # 每次调用耗时
strace -e trace=openat,mmap ./a.out       # 只看某几类
strace -k ./a.out                         # 带用户态 backtrace (谁调的)
strace -o docs/artifacts/strace.txt ./a.out
```

本仓库 `strace-linux.txt` 全量 37 行，按“谁发的”分三类：

| 阶段 | 谁发的 | syscall | 干什么 |
|---|---|---|---|
| 加载 | 内核+ld.so | `execve` | 启动镜像 |
| 加载 | ld.so | `brk`, `mmap`, `munmap`, `mprotect`, `access`, `openat`, `close`, `read`, `pread64`, `fstat` | 读 `/etc/ld.so.cache`、`libc.so.6`，映射段，改页权限 |
| 初始化 | libc | `arch_prctl(ARCH_SET_FS)`, `set_tid_address`, `set_robust_list`, `rseq`, `prlimit64`, `getrandom` | 设 TLS、登记线程/锁、读栈上限、拿随机数(栈 canary) |
| 程序本体 | 你的程序 | `brk`(扩堆), `write(1,"Hello, World!\n",14)` | 真正干活 |
| 退出 | libc | `exit_group(0)` | 结束进程 |

**最关键的认知**：这 20 来次 syscall 里，**你的 `main` 只贡献了 `write` 和（间接的）`exit_group`**。
剩下全是 `ld.so` 和 libc 启动。
所以“执行到 syscall 由 system 接管”要修正为：**`syscall` 指令触发 CPU 陷入内核态（ring3→ring0），
由内核的 syscall 处理程序执行，`sysret` 返回用户态。**

```bash
# 验证 write 就是 printf 的最终落地:
strace -e trace=write ./a.out
# 想看 libc 层调用(而非 syscall)用 ltrace:
ltrace -S ./a.out        # -S 同时显示 syscall
```

---

## 7. 你原复述里的错误，逐条订正

| 你的说法 | 问题 | 正确 |
|---|---|---|
| “gcc 是包含非常多编译器的集合” | 不准确 | gcc 是**一个驱动** + 多语言前端；它编排 `cpp/cc1/as/ld` |
| “gcc 把程序变成汇编或机器，这一步叫编译” | 混淆阶段 | 编译(cc1)=C→**汇编**；汇编(as)=汇编→**机器码**；两步 |
| “链接=让彼此认识对方” | 太窄 | 链接=符号解析+**重定位**+拉入 `crt1.o`/libc+定入口点 |
| “链接产物是 ELF” | 对但不全 | **`.o` 也是 ELF**（`ET_REL`）。ELF 是容器，不是“可执行” |
| “编译完成就符合指令集吗？架构还是指令集？” | 两个概念混用 | **ISA**(x86-64) 在编译期定；**ABI/三元组**(System V/x86_64-linux) 管调用约定、syscall 号、ELF |
| “程序加载进地址空间，从 PC=0 开始执行” | **错** | 内核读 `e_entry`(0x1060)，**不从 0**；PIE+动态链接时先跳 `ld.so` 入口 |
| “执行到 syscall 由 system 接管” | 模糊 | `syscall` 陷入**内核态**，由**内核**处理，`sysret` 返回 |
| “main 是起点” | 常规误解 | 真正入口是 `_start`；`main` 由 `__libc_start_main` 调用 |

---

## 8. 证据清单（docs/artifacts/）

| 文件 | 来自哪条命令 | 证明什么 |
|---|---|---|
| `main.c` | 源程序快照 | 输入 |
| `strace-linux.txt` | `strace ./a.out` | 运行时全部 syscall；启动序列；write 落地 |
| `readelf-h.txt` | `readelf -h a.out` | ISA=X86-64, ABI=System V, Type=DYN, Entry=0x1060 |
| `readelf-l.txt` | `readelf -l a.out` | 段布局；`PT_INTERP=ld-linux-x86-64.so.2` |
| `readelf-S.txt` | `readelf -S a.out` | section 列表(.text/.rodata/.symtab/.dynsym/.rela.*) |
| `readelf-syms.txt` | `readelf -s a.out` | 符号表：`_start`=0x1060、`main`=0x1149、`puts`=UND |
| `readelf-dynsyms.txt` | `readelf --dyn-syms a.out` | 动态符号表 |
| `readelf-d.txt` | `readelf -d a.out` | NEEDED libc.so.6、PIE、BIND_NOW |
| `readelf-relocs.txt` | `readelf -r a.out` | 运行时需填的重定位(`__libc_start_main`, `puts`) |
| `readelf-notes.txt` | `readelf -n a.out` | build-id、ABI-tag Linux 3.2.0、x86 IBT/SHSTK |
| `objdump-d.txt` | `objdump -d -M intel a.out` | `_start`/`main` 反汇编；`printf`→`puts` 优化 |
| `objdump-rodata.txt` | `objdump -s -j .rodata a.out` | "Hello, World!\n" 在 0x2004 |

> 这些证据来自已有的 Linux `a.out`。要自己从源码重跑并重新抓全部证据，
> 在 Linux 上执行 `docs/reproduce.sh`。

---

## 9. 在 Linux 机器上一键复现

```bash
cd docs
bash reproduce.sh
```

脚本会：跑完 `cpp→cc1→as→ld` 生成 `.i/.s/.o/a.out`，用 `readelf`/`objdump` 拆解，
用 `strace`/`LD_DEBUG` 记录运行，并用改过的带 `getchar()` 的版本抓 `/proc/PID/maps`。
见 `docs/reproduce.sh`。

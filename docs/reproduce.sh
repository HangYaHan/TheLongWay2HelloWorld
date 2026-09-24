#!/usr/bin/env bash
#
# 在 Linux x86-64 上一键复现 "从 C 源码到运行进程" 的每一步，并抓取全部证据。
# 用法:  bash docs/reproduce.sh
#
set -euo pipefail

# --- 定位路径 ---------------------------------------------------------------
DOCS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$DOCS_DIR/.." && pwd)"
SRC_DIR="$ROOT_DIR/src/pc_hello_world"
OUT="$DOCS_DIR/artifacts"
mkdir -p "$OUT"

cd "$SRC_DIR"
echo "== workdir: $SRC_DIR"
echo "== gcc: $(command -v gcc)"; gcc --version | head -1

# --- 0. 输入 -----------------------------------------------------------------
cp -f main.c "$OUT/main.c"

# --- 1. 预处理 ---------------------------------------------------------------
echo "== [1/6] preprocess"
gcc -E main.c -o main.i
cp -f main.i "$OUT/main.i"

# --- 2. 编译 -----------------------------------------------------------------
echo "== [2/6] compile (-S)"
gcc -S -O0 -masm=intel -fno-asynchronous-unwind-tables main.c -o main.O0.s
gcc -S -O2 -masm=intel -fno-asynchronous-unwind-tables main.c -o main.O2.s
cp -f main.O0.s main.O2.s "$OUT/"

# --- 3. 汇编 -----------------------------------------------------------------
echo "== [3/6] assemble (-c)"
gcc -c -O0 main.c -o main.o
cp -f main.o "$OUT/main.o"
{
  echo "### file main.o"; file main.o
  echo; echo "### readelf -h main.o (Type: REL = relocatable)"; readelf -h main.o
  echo; echo "### readelf -s main.o (main defined, printf UND)"; readelf -s main.o
  echo; echo "### readelf -r main.o (relocations left for linker)"; readelf -r main.o
} > "$OUT/object-file.txt" 2>&1

# --- 4. 链接 -----------------------------------------------------------------
echo "== [4/6] link"
gcc -O2 main.c -o a.out
cp -f a.out "$OUT/a.out"
{
  echo "### file a.out"; file a.out
  echo; echo "### readelf -h a.out"; readelf -h a.out
  echo; echo "### readelf -l a.out"; readelf -l a.out
  echo; echo "### readelf -S a.out"; readelf -S a.out
  echo; echo "### readelf -d a.out"; readelf -d a.out
  echo; echo "### readelf -s a.out"; readelf -s a.out
  echo; echo "### readelf --dyn-syms a.out"; readelf --dyn-syms a.out
  echo; echo "### readelf -r a.out"; readelf -r a.out
  echo; echo "### readelf -n a.out"; readelf -n a.out
} > "$OUT/executable.txt" 2>&1
readelf -h a.out                        > "$OUT/readelf-h.txt"
readelf -l a.out                        > "$OUT/readelf-l.txt"
readelf -S a.out                        > "$OUT/readelf-S.txt"
readelf -d a.out                        > "$OUT/readelf-d.txt"
readelf -s a.out                        > "$OUT/readelf-syms.txt"
readelf --dyn-syms a.out                > "$OUT/readelf-dynsyms.txt"
readelf -r a.out                        > "$OUT/readelf-relocs.txt"
readelf -n a.out                        > "$OUT/readelf-notes.txt"
objdump -d -M intel a.out               > "$OUT/objdump-d.txt"
objdump -s -j .rodata a.out             > "$OUT/objdump-rodata.txt"
{
  echo "### objdump -d _start"
  objdump -d -M intel a.out | sed -n '/<_start>:/,/^$/p'
  echo; echo "### objdump -d main"
  objdump -d -M intel a.out | sed -n '/<main>:/,/^$/p'
} > "$OUT/disasm-start-main.txt" 2>&1

# 也反汇编未优化的 .o, 对照 -O0 / -O2 差异
objdump -d -M intel main.o              > "$OUT/objdump-main-o.txt" 2>&1
gcc -S -O0 -masm=intel main.c -o "$OUT/main.O0.linux.s"
gcc -S -O2 -masm=intel main.c -o "$OUT/main.O2.linux.s"

# --- 5. 运行: syscall 与动态链接日志 ----------------------------------------
echo "== [5/6] run: strace / LD_DEBUG"
if command -v strace >/dev/null 2>&1; then
  strace -o "$OUT/strace.txt" ./a.out
else
  echo "  (strace 未安装, 跳过; apt install strace)"
fi

LD_DEBUG=libs ./a.out 2> "$OUT/ld-debug-libs.txt"   || true
LD_DEBUG=files ./a.out 2> "$OUT/ld-debug-files.txt" || true
LD_DEBUG=reloc ./a.out 2> "$OUT/ld-debug-reloc.txt" || true
ldd a.out > "$OUT/ldd.txt" 2>&1 || true

# --- 6. 运行: 地址空间 -------------------------------------------------------
echo "== [6/6] run: /proc/PID/maps"
cat > main_pause.c <<'EOF'
#include <stdio.h>
int main(void) {
    printf("Hello, World!\n");
    getchar();          /* 卡住, 方便抓地址空间 */
    return 0;
}
EOF
gcc -O2 main_pause.c -o a_pause
./a_pause &
PID=$!
sleep 1
cat "/proc/$PID/maps" > "$OUT/maps.txt" 2>&1 || true
if command -v pmap >/dev/null 2>&1; then
  pmap -x "$PID" > "$OUT/pmap.txt" 2>&1 || true
fi
# 送一个回车让它退出
kill "$PID" 2>/dev/null || true
wait "$PID" 2>/dev/null || true
rm -f main_pause.c a_pause

echo
echo "== done. 证据在: $OUT"
ls -1 "$OUT"

PROJECT ROADMAP
The Long Way to Hello
Goal: Build or integrate a minimal CPU/softcore on Zynq/FPGA and make it print Hello World, then extend toward interrupts, RTOS, and system understanding.
PHASE 0 — DEFINE THE MISSION

Objective:
Decide what “done” means and choose a feasible route.

Decisions to make:

Platform:
Zynq-7000 board or other FPGA board
CPU route:
Route A: Use an existing softcore first (MicroBlaze / PicoRV32 / VexRiscv)
Route B: Build your own simplified CPU first
Recommended: existing softcore first, then build your own simplified CPU
Final milestone:
Minimum:
CPU + memory + UART + bare-metal program + Hello World
Better:
plus timer interrupt + GPIO + simple monitor
Advanced:
plus FreeRTOS or a tiny scheduler
Stretch:
Linux on ARM side of Zynq, or stronger softcore with OS support
Deliverables:

One-page project definition
Chosen board, toolchain, repository structure
Final project name
Acceptance criteria:

You can clearly explain your final goal in 3 sentences
You know which route you are taking first
Risks:

Choosing an overly ambitious end goal too early
Switching routes too often
PHASE 1 — FUNDAMENTALS OF DIGITAL DESIGN AND TOOLING

Objective:
Gain enough digital design and FPGA workflow knowledge to build and debug simple hardware blocks.

Topics:

Basic digital logic
combinational logic
sequential logic
flip-flops
finite state machines
Verilog/SystemVerilog basics
modules
always blocks
blocking vs non-blocking assignment
parameterization
FPGA workflow
simulation
synthesis
implementation
bitstream generation
Debug methods
waveform reading
testbench design
on-board debug basics
Mini projects:

LED blinker
UART transmitter
UART receiver
Timer/counter
Simple GPIO peripheral
Deliverables:

Verilog source code for UART TX/RX
Testbenches for UART and timer
FPGA project that blinks LED and sends a byte over UART
Acceptance criteria:

You can explain each signal in your UART module
You can debug using waveforms instead of guessing
You can synthesize and run a small design on board
Risks:

Skipping simulation
Treating FPGA as software and not respecting timing/sequencing
PHASE 2 — COMPUTER ORGANIZATION BASICS

Objective:
Understand how a CPU executes instructions and how software maps to hardware.

Topics:

ISA basics
registers
arithmetic instructions
load/store
branch/jump
Datapath and control
ALU
register file
program counter
instruction memory
data memory
CPU styles
single-cycle
multi-cycle
pipeline basics
Exceptions and interrupts
Memory-mapped I/O
Exercises:

Hand-execute simple assembly programs
Draw datapath for add/load/store/branch
Explain how a C loop becomes instructions
Deliverables:

Notes for your chosen ISA subset
A diagram of your minimal CPU datapath
Instruction execution walkthroughs
Acceptance criteria:

You can explain exactly what happens during fetch/decode/execute
You can map a simple C program to assembly and to datapath behavior
Risks:

Memorizing textbook diagrams without understanding signal flow
Jumping into RTL before understanding the execution model
PHASE 3 — BUILD A MINIMAL SYSTEM WITH AN EXISTING SOFTCORE

Objective:
Build confidence by making a known-good CPU print Hello World on FPGA/Zynq.

Recommended options:

MicroBlaze if using Xilinx-first flow
PicoRV32 if you want transparency and simplicity
VexRiscv if you want stronger RISC-V ecosystem
System components:

CPU core
BRAM or on-chip memory
UART
Timer
Optional GPIO
Simple interconnect or memory map
Topics:

address mapping
ROM vs RAM placement
MMIO reads/writes
startup code
linker script
cross-compilation
Tasks:

Integrate CPU and memory
Integrate UART peripheral
Write startup code
Write linker script
Build a bare-metal C program
Make UART print Hello World
Deliverables:

Minimal SoC block diagram
Memory map document
startup.S
linker.ld
hello.c
FPGA bitstream / project files
Acceptance criteria:

On reset, CPU executes from expected address
UART outputs deterministic characters
Hello World appears reliably after power-up or reset
Risks:

Wrong reset vector
Wrong linker address
Stack not initialized
UART baud timing mismatch
CPU fetches garbage due to memory integration errors
PHASE 4 — UNDERSTAND THE SOFTWARE PATH FROM C TO HELLO

Objective:
Understand every layer involved in making Hello World appear.

Topics:

Compiler output
generate assembly from C
inspect object files
Linking
sections
symbol placement
memory regions
Startup
initialize stack pointer
copy data section if needed
clear bss
jump to main
UART driver
polling-based transmit
Binary loading format
ELF basics
binary image generation
Tasks:

Compile hello.c to assembly
Read generated assembly
Follow symbols in ELF
Verify memory image loaded into FPGA memory
Confirm MMIO write path to UART
Deliverables:

Annotated assembly for Hello World
ELF section map
Documentation: “How one character reaches UART”
Acceptance criteria:

You can explain the exact chain:
C source -> assembly -> machine code -> memory image -> CPU execution -> UART TX -> serial terminal
You can locate main, stack, bss, and UART base address in your build
Risks:

Treating toolchain as magic
Not understanding the relationship between ELF and actual FPGA memory image
PHASE 5 — BUILD YOUR OWN SIMPLIFIED CPU

Objective:
Create a small CPU that can execute a minimal program and eventually print Hello World.

Recommended strategy:
Start with a tiny ISA subset.
Do not begin with pipeline, cache, MMU, or complex privilege support.

Suggested instruction subset:

Arithmetic/logical
add
sub
and
or
xor
Immediate operations
Load/store
Branch/jump
Optional shift
Optional compare/set
Microarchitecture:

single-cycle first, or a very simple multi-cycle core
Hardware blocks:

PC
Instruction memory interface
Decoder
Register file
ALU
Data memory interface
Branch logic
Control unit
Development sequence:

ALU
Register file
PC update logic
Instruction decode
Execute arithmetic instructions
Add load/store
Add branch/jump
Run hand-written assembly programs
Connect MMIO UART
Print single character
Print Hello World
Deliverables:

CPU RTL
Testbench suite
ISA subset document
Execution traces for sample programs
Acceptance criteria:

CPU passes directed tests for each instruction
CPU can run a small loop correctly
CPU can write a byte to UART MMIO
Hello World is printed from your own CPU
Risks:

Making the ISA too large
Implementing too many instructions before verification
No formal or systematic test strategy
PHASE 6 — INTERRUPTS, TIMER, AND REAL EMBEDDED BEHAVIOR

Objective:
Move from “a CPU that runs code” to “a system that reacts to events”.

Topics:

Timer peripheral
Interrupt request and acknowledge
Interrupt vector or trap entry
Context saving/restoring
Return from interrupt
Polling vs interrupt-driven I/O
Tasks:

Add timer interrupt
Write interrupt handler in assembly/C
Blink or print on periodic interrupt
Add external interrupt source if available
Build a basic interrupt controller if needed
Deliverables:

Timer module
Interrupt entry/exit code
Example program using timer interrupt
Acceptance criteria:

Periodic interrupt occurs at expected interval
Main program resumes correctly after interrupt
Register corruption does not occur across interrupts
Risks:

Incomplete context save
Incorrect interrupt enable/disable logic
Re-entrancy problems
PHASE 7 — RTOS CONCEPTS AND A TINY SCHEDULER

Objective:
Connect hardware traps/timers to operating system mechanics.

Topics:

Task control block
Stack layout
Context switching
Tick interrupt
Cooperative vs preemptive scheduling
Critical sections
Queues/semaphores basics
Strategy:
Option A:

Write a tiny cooperative scheduler yourself
Option B:
Port a small RTOS such as FreeRTOS
Recommended:
Write a tiny scheduler first, then study or port FreeRTOS
Tasks:

Create two tasks with separate stacks
Implement manual context switch
Trigger switch from timer interrupt
Add simple round-robin scheduling
Add a UART output task and a blinking task
Deliverables:

Tiny scheduler source code
Task stack initialization routine
Demo with multiple tasks
Acceptance criteria:

Multiple tasks run correctly
Context switch preserves program state
Timer drives scheduling events
Risks:

Wrong stack frame format
Saving too few or too many registers
Debugging context switch without enough observability
PHASE 8 — ZYNQ ARM SIDE AND LINUX SYSTEM VIEW

Objective:
If using Zynq, learn how a production-class hard processor system runs Linux and talks to PL hardware.

Why this phase matters:
Even if your own softcore never runs Linux, understanding Linux on Zynq gives you the missing system-level picture.

Topics:

Zynq PS/PL architecture
AXI basics
U-Boot
Linux kernel boot
device tree
memory-mapped peripherals in PL
simple kernel driver or user-space mmap access
Tasks:

Build a simple PL peripheral
Expose it to ARM/Linux through AXI
Access it from Linux user space
Optionally write a basic kernel module/driver
Deliverables:

PL peripheral
device tree changes
Linux-side test program or driver
Acceptance criteria:

Linux on ARM can communicate with PL peripheral
You can explain the path from hardware register to user-space read/write
Risks:

Getting lost in Linux build complexity
Spending too much time on distro/build system issues instead of learning core concepts
PHASE 9 — POLISH, DOCUMENTATION, AND PORTFOLIO

Objective:
Turn your journey into a professional portfolio artifact.

What to document:

System architecture
ISA subset
CPU microarchitecture
Memory map
Build process
Startup flow
Debug methodology
Lessons learned
Next steps
Artifacts to prepare:

Git repository with clean structure
README with architecture diagram
Demo video:
board reset
serial terminal showing Hello World
optional interrupt/RTOS demo
Technical write-up:
“From Gates to Hello”
Short resume bullets
Resume bullet examples:

Designed and implemented a minimal CPU/SoC on FPGA with UART, timer, and memory-mapped I/O
Built bare-metal software flow including startup code, linker script, and cross-compilation
Brought up a Hello World application on custom/minimal hardware
Implemented interrupt handling and explored task switching / RTOS concepts
Acceptance criteria:

Another engineer can reproduce the project from your repository
Your README tells a coherent story from architecture to demo
Your resume bullets are concrete and measurable
Risks:

Finishing the technical part but not packaging it well
Underestimating how valuable good documentation is
RECOMMENDED MILESTONE LADDER

Milestone 1:
LED blink on FPGA

Milestone 2:
UART transmit a single byte

Milestone 3:
Minimal softcore system running

Milestone 4:
Bare-metal Hello World on existing softcore

Milestone 5:
Own simplified CPU executes arithmetic test program

Milestone 6:
Own CPU writes one byte to UART

Milestone 7:
Own CPU prints Hello World

Milestone 8:
Timer interrupt works

Milestone 9:
Basic scheduler or RTOS demo works

Milestone 10:
Zynq Linux side communicates with PL peripheral

WHAT SUCCESS LOOKS LIKE

Minimum success:

You understand the full path from C source to UART output
You can build and debug a minimal CPU-based system
You have a working Hello World on FPGA
Strong success:

You built your own simplified CPU and made it print Hello World
You implemented interrupts and basic drivers
You can explain startup, linking, MMIO, and task switching
Exceptional success:

You connect this work to RTOS or Linux
You present it as a polished systems project portfolio
You become interview-ready for low-level systems roles
SUGGESTED LEARNING ORDER OF BOOKS

Digital Design and Computer Architecture
Computer Organization and Design (RISC-V edition if possible)
Operating Systems: Three Easy Pieces
Computer Systems: A Programmer’s Perspective
Vendor documentation / ISA spec / softcore project docs as needed
MENTAL MODEL FOR THE WHOLE JOURNEY

Gate -> Register -> Datapath -> CPU -> Bus -> Peripheral -> Memory Map -> Startup -> C Runtime -> Driver -> Interrupt -> Scheduler -> OS

If you can walk through that chain and explain each transition, you have built real understanding.
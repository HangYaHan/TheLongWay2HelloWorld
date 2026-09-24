	.file	"main.c"
	.intel_syntax noprefix
	.text
	.def	printf;	.scl	3;	.type	32;	.endef
printf:
	push	rbp
	mov	rbp, rsp
	push	rbx
	sub	rsp, 56
	mov	QWORD PTR 16[rbp], rcx
	mov	QWORD PTR 24[rbp], rdx
	mov	QWORD PTR 32[rbp], r8
	mov	QWORD PTR 40[rbp], r9
	lea	rax, 24[rbp]
	mov	QWORD PTR -32[rbp], rax
	mov	rbx, QWORD PTR -32[rbp]
	mov	ecx, 1
	mov	rax, QWORD PTR __imp___acrt_iob_func[rip]
	call	rax
	mov	rcx, rax
	mov	rax, QWORD PTR 16[rbp]
	mov	r8, rbx
	mov	rdx, rax
	call	__mingw_vfprintf
	mov	DWORD PTR -20[rbp], eax
	mov	eax, DWORD PTR -20[rbp]
	mov	rbx, QWORD PTR -8[rbp]
	leave
	ret
	.section .rdata,"dr"
.LC0:
	.ascii "Hello, World!\12\0"
	.text
	.globl	main
	.def	main;	.scl	2;	.type	32;	.endef
main:
	push	rbp
	mov	rbp, rsp
	sub	rsp, 32
	call	__main
	lea	rax, .LC0[rip]
	mov	rcx, rax
	call	printf
	mov	eax, 0
	leave
	ret
	.def	__main;	.scl	2;	.type	32;	.endef
	.ident	"GCC: (MinGW-W64 x86_64-msvcrt-posix-seh, built by Brecht Sanders, r1) 15.1.0"
	.def	__mingw_vfprintf;	.scl	2;	.type	32;	.endef

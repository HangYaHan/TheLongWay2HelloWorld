	.file	"main.c"
	.intel_syntax noprefix
	.text
	.section .rdata,"dr"
.LC0:
	.ascii "Hello, World!\12\0"
	.text
	.p2align 4
	.def	printf.constprop.0;	.scl	3;	.type	32;	.endef
printf.constprop.0:
	push	rbx
	mov	ecx, 1
	sub	rsp, 48
	lea	rbx, 72[rsp]
	mov	QWORD PTR 72[rsp], rdx
	mov	QWORD PTR 80[rsp], r8
	mov	QWORD PTR 88[rsp], r9
	mov	QWORD PTR 40[rsp], rbx
	call	[QWORD PTR __imp___acrt_iob_func[rip]]
	mov	r8, rbx
	lea	rdx, .LC0[rip]
	mov	rcx, rax
	call	__mingw_vfprintf
	add	rsp, 48
	pop	rbx
	ret
	.section	.text.startup,"x"
	.p2align 4
	.globl	main
	.def	main;	.scl	2;	.type	32;	.endef
main:
	sub	rsp, 40
	call	__main
	lea	rcx, .LC0[rip]
	call	printf.constprop.0
	xor	eax, eax
	add	rsp, 40
	ret
	.def	__main;	.scl	2;	.type	32;	.endef
	.ident	"GCC: (MinGW-W64 x86_64-msvcrt-posix-seh, built by Brecht Sanders, r1) 15.1.0"
	.def	__mingw_vfprintf;	.scl	2;	.type	32;	.endef

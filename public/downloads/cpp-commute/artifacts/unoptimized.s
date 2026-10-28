	.text
	.intel_syntax noprefix
	.file	"machine_cases.cpp"
	.globl	copy_int                        # -- Begin function copy_int
	.p2align	4, 0x90
	.type	copy_int,@function
copy_int:                               # @copy_int
	.cfi_startproc
# %bb.0:
	push	rbp
	.cfi_def_cfa_offset 16
	.cfi_offset rbp, -16
	mov	rbp, rsp
	.cfi_def_cfa_register rbp
	mov	dword ptr [rbp - 4], edi
	mov	eax, dword ptr [rbp - 4]
	mov	dword ptr [rbp - 8], eax
	mov	eax, dword ptr [rbp - 8]
	add	eax, 1
	pop	rbp
	.cfi_def_cfa rsp, 8
	ret
.Lfunc_end0:
	.size	copy_int, .Lfunc_end0-copy_int
	.cfi_endproc
                                        # -- End function
	.globl	read_pointer                    # -- Begin function read_pointer
	.p2align	4, 0x90
	.type	read_pointer,@function
read_pointer:                           # @read_pointer
	.cfi_startproc
# %bb.0:
	push	rbp
	.cfi_def_cfa_offset 16
	.cfi_offset rbp, -16
	mov	rbp, rsp
	.cfi_def_cfa_register rbp
	mov	qword ptr [rbp - 8], rdi
	mov	rax, qword ptr [rbp - 8]
	mov	eax, dword ptr [rax]
	pop	rbp
	.cfi_def_cfa rsp, 8
	ret
.Lfunc_end1:
	.size	read_pointer, .Lfunc_end1-read_pointer
	.cfi_endproc
                                        # -- End function
	.globl	pointer_identity                # -- Begin function pointer_identity
	.p2align	4, 0x90
	.type	pointer_identity,@function
pointer_identity:                       # @pointer_identity
	.cfi_startproc
# %bb.0:
	push	rbp
	.cfi_def_cfa_offset 16
	.cfi_offset rbp, -16
	mov	rbp, rsp
	.cfi_def_cfa_register rbp
	mov	qword ptr [rbp - 8], rdi
	mov	rax, qword ptr [rbp - 8]
	pop	rbp
	.cfi_def_cfa rsp, 8
	ret
.Lfunc_end2:
	.size	pointer_identity, .Lfunc_end2-pointer_identity
	.cfi_endproc
                                        # -- End function
	.globl	set_reference                   # -- Begin function set_reference
	.p2align	4, 0x90
	.type	set_reference,@function
set_reference:                          # @set_reference
	.cfi_startproc
# %bb.0:
	push	rbp
	.cfi_def_cfa_offset 16
	.cfi_offset rbp, -16
	mov	rbp, rsp
	.cfi_def_cfa_register rbp
	mov	qword ptr [rbp - 8], rdi
	mov	rax, qword ptr [rbp - 8]
	mov	dword ptr [rax], 100
	pop	rbp
	.cfi_def_cfa rsp, 8
	ret
.Lfunc_end3:
	.size	set_reference, .Lfunc_end3-set_reference
	.cfi_endproc
                                        # -- End function
	.globl	read_const_reference            # -- Begin function read_const_reference
	.p2align	4, 0x90
	.type	read_const_reference,@function
read_const_reference:                   # @read_const_reference
	.cfi_startproc
# %bb.0:
	push	rbp
	.cfi_def_cfa_offset 16
	.cfi_offset rbp, -16
	mov	rbp, rsp
	.cfi_def_cfa_register rbp
	mov	qword ptr [rbp - 8], rdi
	mov	rax, qword ptr [rbp - 8]
	mov	eax, dword ptr [rax]
	pop	rbp
	.cfi_def_cfa rsp, 8
	ret
.Lfunc_end4:
	.size	read_const_reference, .Lfunc_end4-read_const_reference
	.cfi_endproc
                                        # -- End function
	.globl	gradient_by_value               # -- Begin function gradient_by_value
	.p2align	4, 0x90
	.type	gradient_by_value,@function
gradient_by_value:                      # @gradient_by_value
	.cfi_startproc
# %bb.0:
	push	rbp
	.cfi_def_cfa_offset 16
	.cfi_offset rbp, -16
	mov	rbp, rsp
	.cfi_def_cfa_register rbp
	mov	qword ptr [rbp - 8], rdi
	mov	eax, dword ptr [rbp - 8]
	pop	rbp
	.cfi_def_cfa rsp, 8
	ret
.Lfunc_end5:
	.size	gradient_by_value, .Lfunc_end5-gradient_by_value
	.cfi_endproc
                                        # -- End function
	.globl	_Z13copy_gradientRK8Gradient    # -- Begin function _Z13copy_gradientRK8Gradient
	.p2align	4, 0x90
	.type	_Z13copy_gradientRK8Gradient,@function
_Z13copy_gradientRK8Gradient:           # @_Z13copy_gradientRK8Gradient
	.cfi_startproc
# %bb.0:
	push	rbp
	.cfi_def_cfa_offset 16
	.cfi_offset rbp, -16
	mov	rbp, rsp
	.cfi_def_cfa_register rbp
	mov	qword ptr [rbp - 16], rdi
	mov	rax, qword ptr [rbp - 16]
	mov	rax, qword ptr [rax]
	mov	qword ptr [rbp - 8], rax
	mov	rax, qword ptr [rbp - 8]
	pop	rbp
	.cfi_def_cfa rsp, 8
	ret
.Lfunc_end6:
	.size	_Z13copy_gradientRK8Gradient, .Lfunc_end6-_Z13copy_gradientRK8Gradient
	.cfi_endproc
                                        # -- End function
	.globl	_Z12ref_gradientR8Gradient      # -- Begin function _Z12ref_gradientR8Gradient
	.p2align	4, 0x90
	.type	_Z12ref_gradientR8Gradient,@function
_Z12ref_gradientR8Gradient:             # @_Z12ref_gradientR8Gradient
	.cfi_startproc
# %bb.0:
	push	rbp
	.cfi_def_cfa_offset 16
	.cfi_offset rbp, -16
	mov	rbp, rsp
	.cfi_def_cfa_register rbp
	mov	qword ptr [rbp - 8], rdi
	mov	rax, qword ptr [rbp - 8]
	pop	rbp
	.cfi_def_cfa rsp, 8
	ret
.Lfunc_end7:
	.size	_Z12ref_gradientR8Gradient, .Lfunc_end7-_Z12ref_gradientR8Gradient
	.cfi_endproc
                                        # -- End function
	.globl	local_reference                 # -- Begin function local_reference
	.p2align	4, 0x90
	.type	local_reference,@function
local_reference:                        # @local_reference
	.cfi_startproc
# %bb.0:
	push	rbp
	.cfi_def_cfa_offset 16
	.cfi_offset rbp, -16
	mov	rbp, rsp
	.cfi_def_cfa_register rbp
	mov	dword ptr [rbp - 4], edi
	lea	rax, [rbp - 4]
	mov	qword ptr [rbp - 16], rax
	mov	rax, qword ptr [rbp - 16]
	mov	eax, dword ptr [rax]
	add	eax, 1
	pop	rbp
	.cfi_def_cfa rsp, 8
	ret
.Lfunc_end8:
	.size	local_reference, .Lfunc_end8-local_reference
	.cfi_endproc
                                        # -- End function
	.globl	member_reference                # -- Begin function member_reference
	.p2align	4, 0x90
	.type	member_reference,@function
member_reference:                       # @member_reference
	.cfi_startproc
# %bb.0:
	push	rbp
	.cfi_def_cfa_offset 16
	.cfi_offset rbp, -16
	mov	rbp, rsp
	.cfi_def_cfa_register rbp
	mov	dword ptr [rbp - 4], edi
	lea	rax, [rbp - 4]
	mov	qword ptr [rbp - 16], rax
	mov	rax, qword ptr [rbp - 16]
	mov	eax, dword ptr [rax]
	add	eax, 1
	pop	rbp
	.cfi_def_cfa rsp, 8
	ret
.Lfunc_end9:
	.size	member_reference, .Lfunc_end9-member_reference
	.cfi_endproc
                                        # -- End function
	.globl	dynamic_reference               # -- Begin function dynamic_reference
	.p2align	4, 0x90
	.type	dynamic_reference,@function
dynamic_reference:                      # @dynamic_reference
	.cfi_startproc
# %bb.0:
	push	rbp
	.cfi_def_cfa_offset 16
	.cfi_offset rbp, -16
	mov	rbp, rsp
	.cfi_def_cfa_register rbp
	mov	al, dil
	and	al, 1
	mov	byte ptr [rbp - 1], al
	mov	qword ptr [rbp - 16], rsi
	mov	qword ptr [rbp - 24], rdx
	lea	rax, [rbp - 32]
	mov	qword ptr [rbp - 40], rax       # 8-byte Spill
	test	byte ptr [rbp - 1], 1
	je	.LBB10_2
# %bb.1:
	mov	rax, qword ptr [rbp - 16]
	mov	qword ptr [rbp - 48], rax       # 8-byte Spill
	jmp	.LBB10_3
.LBB10_2:
	mov	rax, qword ptr [rbp - 24]
	mov	qword ptr [rbp - 48], rax       # 8-byte Spill
.LBB10_3:
	mov	rax, qword ptr [rbp - 40]       # 8-byte Reload
	mov	rcx, qword ptr [rbp - 48]       # 8-byte Reload
	mov	qword ptr [rax], rcx
	mov	rax, qword ptr [rbp - 32]
	mov	eax, dword ptr [rax]
	pop	rbp
	.cfi_def_cfa rsp, 8
	ret
.Lfunc_end10:
	.size	dynamic_reference, .Lfunc_end10-dynamic_reference
	.cfi_endproc
                                        # -- End function
	.globl	read_existing                   # -- Begin function read_existing
	.p2align	4, 0x90
	.type	read_existing,@function
read_existing:                          # @read_existing
	.cfi_startproc
# %bb.0:
	push	rbp
	.cfi_def_cfa_offset 16
	.cfi_offset rbp, -16
	mov	rbp, rsp
	.cfi_def_cfa_register rbp
	mov	qword ptr [rbp - 8], rdi
	mov	rax, qword ptr [rbp - 8]
	mov	rax, qword ptr [rax]
	mov	eax, dword ptr [rax]
	pop	rbp
	.cfi_def_cfa rsp, 8
	ret
.Lfunc_end11:
	.size	read_existing, .Lfunc_end11-read_existing
	.cfi_endproc
                                        # -- End function
	.globl	inlined_call                    # -- Begin function inlined_call
	.p2align	4, 0x90
	.type	inlined_call,@function
inlined_call:                           # @inlined_call
	.cfi_startproc
# %bb.0:
	push	rbp
	.cfi_def_cfa_offset 16
	.cfi_offset rbp, -16
	mov	rbp, rsp
	.cfi_def_cfa_register rbp
	sub	rsp, 16
	mov	dword ptr [rbp - 4], edi
	lea	rax, [rbp - 4]
	mov	qword ptr [rbp - 16], rax
	lea	rdi, [rbp - 16]
	call	read_existing
	add	eax, 1
	add	rsp, 16
	pop	rbp
	.cfi_def_cfa rsp, 8
	ret
.Lfunc_end12:
	.size	inlined_call, .Lfunc_end12-inlined_call
	.cfi_endproc
                                        # -- End function
	.globl	materialize_for_call            # -- Begin function materialize_for_call
	.p2align	4, 0x90
	.type	materialize_for_call,@function
materialize_for_call:                   # @materialize_for_call
	.cfi_startproc
# %bb.0:
	push	rbp
	.cfi_def_cfa_offset 16
	.cfi_offset rbp, -16
	mov	rbp, rsp
	.cfi_def_cfa_register rbp
	sub	rsp, 16
	mov	qword ptr [rbp - 8], rdi
	mov	rax, qword ptr [rbp - 8]
	mov	qword ptr [rbp - 16], rax
	lea	rdi, [rbp - 16]
	call	observe@PLT
	add	rsp, 16
	pop	rbp
	.cfi_def_cfa rsp, 8
	ret
.Lfunc_end13:
	.size	materialize_for_call, .Lfunc_end13-materialize_for_call
	.cfi_endproc
                                        # -- End function
	.globl	pointer_equivalent              # -- Begin function pointer_equivalent
	.p2align	4, 0x90
	.type	pointer_equivalent,@function
pointer_equivalent:                     # @pointer_equivalent
	.cfi_startproc
# %bb.0:
	push	rbp
	.cfi_def_cfa_offset 16
	.cfi_offset rbp, -16
	mov	rbp, rsp
	.cfi_def_cfa_register rbp
	mov	dword ptr [rbp - 4], edi
	lea	rax, [rbp - 4]
	mov	qword ptr [rbp - 16], rax
	mov	rax, qword ptr [rbp - 16]
	mov	eax, dword ptr [rax]
	add	eax, 1
	pop	rbp
	.cfi_def_cfa rsp, 8
	ret
.Lfunc_end14:
	.size	pointer_equivalent, .Lfunc_end14-pointer_equivalent
	.cfi_endproc
                                        # -- End function
	.globl	by_value_view                   # -- Begin function by_value_view
	.p2align	4, 0x90
	.type	by_value_view,@function
by_value_view:                          # @by_value_view
	.cfi_startproc
# %bb.0:
	push	rbp
	.cfi_def_cfa_offset 16
	.cfi_offset rbp, -16
	mov	rbp, rsp
	.cfi_def_cfa_register rbp
	mov	qword ptr [rbp - 8], rdi
	mov	rax, qword ptr [rbp - 8]
	mov	eax, dword ptr [rax]
	pop	rbp
	.cfi_def_cfa rsp, 8
	ret
.Lfunc_end15:
	.size	by_value_view, .Lfunc_end15-by_value_view
	.cfi_endproc
                                        # -- End function
	.globl	view_size                       # -- Begin function view_size
	.p2align	4, 0x90
	.type	view_size,@function
view_size:                              # @view_size
	.cfi_startproc
# %bb.0:
	push	rbp
	.cfi_def_cfa_offset 16
	.cfi_offset rbp, -16
	mov	rbp, rsp
	.cfi_def_cfa_register rbp
	mov	eax, 8
	pop	rbp
	.cfi_def_cfa rsp, 8
	ret
.Lfunc_end16:
	.size	view_size, .Lfunc_end16-view_size
	.cfi_endproc
                                        # -- End function
	.globl	_Z8make_bigv                    # -- Begin function _Z8make_bigv
	.p2align	4, 0x90
	.type	_Z8make_bigv,@function
_Z8make_bigv:                           # @_Z8make_bigv
	.cfi_startproc
# %bb.0:
	push	rbp
	.cfi_def_cfa_offset 16
	.cfi_offset rbp, -16
	mov	rbp, rsp
	.cfi_def_cfa_register rbp
	mov	rax, rdi
	mov	rcx, qword ptr [rip + .Lconstinit]
	mov	qword ptr [rdi], rcx
	mov	rcx, qword ptr [rip + .Lconstinit+8]
	mov	qword ptr [rdi + 8], rcx
	mov	rcx, qword ptr [rip + .Lconstinit+16]
	mov	qword ptr [rdi + 16], rcx
	mov	rcx, qword ptr [rip + .Lconstinit+24]
	mov	qword ptr [rdi + 24], rcx
	pop	rbp
	.cfi_def_cfa rsp, 8
	ret
.Lfunc_end17:
	.size	_Z8make_bigv, .Lfunc_end17-_Z8make_bigv
	.cfi_endproc
                                        # -- End function
	.type	.Lconstinit,@object             # @constinit
	.section	.rodata,"a",@progbits
	.p2align	2, 0x0
.Lconstinit:
	.long	1                               # 0x1
	.long	2                               # 0x2
	.long	3                               # 0x3
	.long	4                               # 0x4
	.long	5                               # 0x5
	.long	6                               # 0x6
	.long	7                               # 0x7
	.long	8                               # 0x8
	.size	.Lconstinit, 32

	.section	".linker-options","e",@llvm_linker_options
	.ident	"Ubuntu clang version 18.1.3 (1ubuntu1)"
	.section	".note.GNU-stack","",@progbits
	.addrsig
	.addrsig_sym read_existing
	.addrsig_sym observe
	.addrsig_sym .Lconstinit

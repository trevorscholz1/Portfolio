	.section	__TEXT,__text,regular,pure_instructions
	.build_version macos, 15, 0	sdk_version 15, 0
	.globl	_remove_file                    ; -- Begin function remove_file
	.p2align	2
_remove_file:                           ; @remove_file
	.cfi_startproc
; %bb.0:
	stp	x20, x19, [sp, #-32]!           ; 16-byte Folded Spill
	stp	x29, x30, [sp, #16]             ; 16-byte Folded Spill
	add	x29, sp, #16
	.cfi_def_cfa w29, 16
	.cfi_offset w30, -8
	.cfi_offset w29, -16
	.cfi_offset w19, -24
	.cfi_offset w20, -32
	mov	x19, x0
	bl	_remove
	mov	x20, x0
	cbnz	w0, LBB0_2
LBB0_1:
	mov	x0, x20
	ldp	x29, x30, [sp, #16]             ; 16-byte Folded Reload
	ldp	x20, x19, [sp], #32             ; 16-byte Folded Reload
	ret
LBB0_2:
	mov	x0, x19
	bl	_perror
	b	LBB0_1
	.cfi_endproc
                                        ; -- End function
	.globl	_delete_directory               ; -- Begin function delete_directory
	.p2align	2
_delete_directory:                      ; @delete_directory
	.cfi_startproc
; %bb.0:
	sub	sp, sp, #48
	stp	x20, x19, [sp, #16]             ; 16-byte Folded Spill
	stp	x29, x30, [sp, #32]             ; 16-byte Folded Spill
	add	x29, sp, #32
	.cfi_def_cfa w29, 16
	.cfi_offset w30, -8
	.cfi_offset w29, -16
	.cfi_offset w19, -24
	.cfi_offset w20, -32
	mov	x19, x0
Lloh0:
	adrp	x1, _remove_file@PAGE
Lloh1:
	add	x1, x1, _remove_file@PAGEOFF
	mov	w2, #64                         ; =0x40
	mov	w3, #5                          ; =0x5
	bl	_nftw
	cmn	w0, #1
	b.eq	LBB1_3
; %bb.1:
	str	x19, [sp]
Lloh2:
	adrp	x0, l_.str.1@PAGE
Lloh3:
	add	x0, x0, l_.str.1@PAGEOFF
	bl	_printf
	mov	w0, #0                          ; =0x0
LBB1_2:
	ldp	x29, x30, [sp, #32]             ; 16-byte Folded Reload
	ldp	x20, x19, [sp, #16]             ; 16-byte Folded Reload
	add	sp, sp, #48
	ret
LBB1_3:
Lloh4:
	adrp	x0, l_.str@PAGE
Lloh5:
	add	x0, x0, l_.str@PAGEOFF
	bl	_perror
	mov	w0, #1                          ; =0x1
	b	LBB1_2
	.loh AdrpAdd	Lloh0, Lloh1
	.loh AdrpAdd	Lloh2, Lloh3
	.loh AdrpAdd	Lloh4, Lloh5
	.cfi_endproc
                                        ; -- End function
	.globl	_create_directory               ; -- Begin function create_directory
	.p2align	2
_create_directory:                      ; @create_directory
	.cfi_startproc
; %bb.0:
	sub	sp, sp, #48
	stp	x20, x19, [sp, #16]             ; 16-byte Folded Spill
	stp	x29, x30, [sp, #32]             ; 16-byte Folded Spill
	add	x29, sp, #32
	.cfi_def_cfa w29, 16
	.cfi_offset w30, -8
	.cfi_offset w29, -16
	.cfi_offset w19, -24
	.cfi_offset w20, -32
	mov	x19, x0
	mov	w1, #511                        ; =0x1ff
	bl	_mkdir
	cmn	w0, #1
	b.ne	LBB2_2
; %bb.1:
	bl	___error
	ldr	w8, [x0]
	cmp	w8, #17
	b.ne	LBB2_4
LBB2_2:
	str	x19, [sp]
Lloh6:
	adrp	x0, l_.str.3@PAGE
Lloh7:
	add	x0, x0, l_.str.3@PAGEOFF
	bl	_printf
	mov	w0, #0                          ; =0x0
LBB2_3:
	ldp	x29, x30, [sp, #32]             ; 16-byte Folded Reload
	ldp	x20, x19, [sp, #16]             ; 16-byte Folded Reload
	add	sp, sp, #48
	ret
LBB2_4:
Lloh8:
	adrp	x0, l_.str.2@PAGE
Lloh9:
	add	x0, x0, l_.str.2@PAGEOFF
	bl	_perror
	mov	w0, #1                          ; =0x1
	b	LBB2_3
	.loh AdrpAdd	Lloh6, Lloh7
	.loh AdrpAdd	Lloh8, Lloh9
	.cfi_endproc
                                        ; -- End function
	.globl	_main                           ; -- Begin function main
	.p2align	2
_main:                                  ; @main
	.cfi_startproc
; %bb.0:
	stp	x28, x27, [sp, #-96]!           ; 16-byte Folded Spill
	stp	x26, x25, [sp, #16]             ; 16-byte Folded Spill
	stp	x24, x23, [sp, #32]             ; 16-byte Folded Spill
	stp	x22, x21, [sp, #48]             ; 16-byte Folded Spill
	stp	x20, x19, [sp, #64]             ; 16-byte Folded Spill
	stp	x29, x30, [sp, #80]             ; 16-byte Folded Spill
	add	x29, sp, #80
	mov	w9, #4176                       ; =0x1050
Lloh10:
	adrp	x16, ___chkstk_darwin@GOTPAGE
Lloh11:
	ldr	x16, [x16, ___chkstk_darwin@GOTPAGEOFF]
	blr	x16
	sub	sp, sp, #1, lsl #12             ; =4096
	sub	sp, sp, #80
	.cfi_def_cfa w29, 16
	.cfi_offset w30, -8
	.cfi_offset w29, -16
	.cfi_offset w19, -24
	.cfi_offset w20, -32
	.cfi_offset w21, -40
	.cfi_offset w22, -48
	.cfi_offset w23, -56
	.cfi_offset w24, -64
	.cfi_offset w25, -72
	.cfi_offset w26, -80
	.cfi_offset w27, -88
	.cfi_offset w28, -96
Lloh12:
	adrp	x8, ___stack_chk_guard@GOTPAGE
Lloh13:
	ldr	x8, [x8, ___stack_chk_guard@GOTPAGEOFF]
Lloh14:
	ldr	x8, [x8]
	stur	x8, [x29, #-96]
Lloh15:
	adrp	x0, l_.str.4@PAGE
Lloh16:
	add	x0, x0, l_.str.4@PAGEOFF
	bl	_printf
	sub	x19, x29, #106
	str	x19, [sp]
Lloh17:
	adrp	x0, l_.str.5@PAGE
Lloh18:
	add	x0, x0, l_.str.5@PAGEOFF
	bl	_scanf
	cmp	w0, #1
	b.ne	LBB3_14
; %bb.1:
	mov	w8, #29793                      ; =0x7461
	movk	w8, #97, lsl #16
	str	w8, [sp, #3168]
Lloh19:
	adrp	x8, l_.str.7@PAGE
Lloh20:
	add	x8, x8, l_.str.7@PAGEOFF
	ldp	q0, q1, [x8]
	str	q0, [sp, #3120]
	str	q1, [sp, #3136]
	ldr	q0, [x8, #32]
	str	q0, [sp, #3152]
	add	x20, sp, #3120
	stp	x20, x19, [sp]
Lloh21:
	adrp	x2, l_.str.8@PAGE
Lloh22:
	add	x2, x2, l_.str.8@PAGEOFF
	add	x21, sp, #2096
	add	x0, sp, #2096
	mov	w1, #1024                       ; =0x400
	bl	_snprintf
	stp	x20, x19, [sp]
Lloh23:
	adrp	x2, l_.str.9@PAGE
Lloh24:
	add	x2, x2, l_.str.9@PAGEOFF
	add	x19, sp, #1072
	add	x0, sp, #1072
	mov	w1, #1024                       ; =0x400
	bl	_snprintf
	mov	x28, #0                         ; =0x0
	str	x21, [sp, #1056]
	str	x19, [sp, #1064]
	add	x20, sp, #1056
Lloh25:
	adrp	x19, _remove_file@PAGE
Lloh26:
	add	x19, x19, _remove_file@PAGEOFF
Lloh27:
	adrp	x21, ___stderrp@GOTPAGE
Lloh28:
	ldr	x21, [x21, ___stderrp@GOTPAGEOFF]
Lloh29:
	adrp	x22, l_.str.1@PAGE
Lloh30:
	add	x22, x22, l_.str.1@PAGEOFF
Lloh31:
	adrp	x23, l_.str.12@PAGE
Lloh32:
	add	x23, x23, l_.str.12@PAGEOFF
Lloh33:
	adrp	x24, l_.str.11@PAGE
Lloh34:
	add	x24, x24, l_.str.11@PAGEOFF
Lloh35:
	adrp	x25, l_.str.13@PAGE
Lloh36:
	add	x25, x25, l_.str.13@PAGEOFF
	b	LBB3_5
LBB3_2:                                 ;   in Loop: Header=BB3_5 Depth=1
	ldr	x0, [x21]
	str	x26, [sp]
	mov	x1, x25
LBB3_3:                                 ;   in Loop: Header=BB3_5 Depth=1
	bl	_fprintf
LBB3_4:                                 ;   in Loop: Header=BB3_5 Depth=1
	add	x28, x28, #8
	cmp	x28, #8
	b.ne	LBB3_15
LBB3_5:                                 ; =>This Inner Loop Header: Depth=1
	ldr	x26, [x20, x28]
	add	x1, sp, #32
	mov	x0, x26
	bl	_stat
	cbnz	w0, LBB3_2
; %bb.6:                                ;   in Loop: Header=BB3_5 Depth=1
	ldrh	w8, [sp, #36]
	and	w8, w8, #0xf000
	mov	x0, x26
	cmp	w8, #4, lsl #12                 ; =16384
	b.ne	LBB3_10
; %bb.7:                                ;   in Loop: Header=BB3_5 Depth=1
	mov	x1, x19
	mov	w2, #64                         ; =0x40
	mov	w3, #5                          ; =0x5
	bl	_nftw
	mov	x27, x0
	cmn	w0, #1
	b.eq	LBB3_13
; %bb.8:                                ;   in Loop: Header=BB3_5 Depth=1
	str	x26, [sp]
	mov	x0, x22
	bl	_printf
	cmn	w27, #1
	b.ne	LBB3_4
LBB3_9:                                 ;   in Loop: Header=BB3_5 Depth=1
	ldr	x0, [x21]
	str	x26, [sp]
Lloh37:
	adrp	x1, l_.str.10@PAGE
Lloh38:
	add	x1, x1, l_.str.10@PAGEOFF
	b	LBB3_3
LBB3_10:                                ;   in Loop: Header=BB3_5 Depth=1
	bl	_remove
	cbz	w0, LBB3_12
; %bb.11:                               ;   in Loop: Header=BB3_5 Depth=1
	ldr	x0, [x21]
	str	x26, [sp]
	mov	x1, x24
	b	LBB3_3
LBB3_12:                                ;   in Loop: Header=BB3_5 Depth=1
	str	x26, [sp]
	mov	x0, x23
	bl	_printf
	b	LBB3_4
LBB3_13:                                ;   in Loop: Header=BB3_5 Depth=1
Lloh39:
	adrp	x0, l_.str@PAGE
Lloh40:
	add	x0, x0, l_.str@PAGEOFF
	bl	_perror
	cmn	w27, #1
	b.ne	LBB3_4
	b	LBB3_9
LBB3_14:
Lloh41:
	adrp	x8, ___stderrp@GOTPAGE
Lloh42:
	ldr	x8, [x8, ___stderrp@GOTPAGEOFF]
Lloh43:
	ldr	x3, [x8]
Lloh44:
	adrp	x0, l_.str.6@PAGE
Lloh45:
	add	x0, x0, l_.str.6@PAGEOFF
	mov	w19, #1                         ; =0x1
	mov	w1, #27                         ; =0x1b
	mov	w2, #1                          ; =0x1
	bl	_fwrite
	b	LBB3_25
LBB3_15:
	sub	x21, x29, #106
	add	x22, sp, #3120
	stp	x22, x21, [sp]
Lloh46:
	adrp	x2, l_.str.8@PAGE
Lloh47:
	add	x2, x2, l_.str.8@PAGEOFF
	add	x23, sp, #32
	add	x0, sp, #32
	mov	w1, #1024                       ; =0x400
	bl	_snprintf
	add	x0, sp, #32
	mov	w1, #511                        ; =0x1ff
	bl	_mkdir
	cmn	w0, #1
	b.ne	LBB3_17
; %bb.16:
	bl	___error
	ldr	w8, [x0]
	cmp	w8, #17
	b.ne	LBB3_27
LBB3_17:
	str	x23, [sp]
Lloh48:
	adrp	x19, l_.str.3@PAGE
Lloh49:
	add	x19, x19, l_.str.3@PAGEOFF
	mov	x0, x19
	bl	_printf
	mov	x25, #0                         ; =0x0
	mov	w24, #0                         ; =0x0
Lloh50:
	adrp	x26, l___const.main.subdirs@PAGE
Lloh51:
	add	x26, x26, l___const.main.subdirs@PAGEOFF
Lloh52:
	adrp	x20, l_.str.18@PAGE
Lloh53:
	add	x20, x20, l_.str.18@PAGEOFF
	b	LBB3_19
LBB3_18:                                ;   in Loop: Header=BB3_19 Depth=1
	str	x23, [sp]
	mov	x0, x19
	bl	_printf
	cmp	x25, #1
	add	x8, x25, #1
	cset	w24, hi
	mov	x25, x8
	cmp	x8, #3
	b.eq	LBB3_22
LBB3_19:                                ; =>This Inner Loop Header: Depth=1
	ldr	x8, [x26, x25, lsl #3]
	stp	x21, x8, [sp, #8]
	add	x0, sp, #32
	str	x22, [sp]
	mov	w1, #1024                       ; =0x400
	mov	x2, x20
	bl	_snprintf
	add	x0, sp, #32
	mov	w1, #511                        ; =0x1ff
	bl	_mkdir
	cmn	w0, #1
	b.ne	LBB3_18
; %bb.20:                               ;   in Loop: Header=BB3_19 Depth=1
	bl	___error
	ldr	w8, [x0]
	cmp	w8, #17
	b.eq	LBB3_18
; %bb.21:
	add	x0, sp, #32
	bl	_main.cold.1
	mov	w19, #1                         ; =0x1
	b	LBB3_23
LBB3_22:
	mov	w19, #0                         ; =0x0
LBB3_23:
	tbz	w24, #0, LBB3_25
; %bb.24:
Lloh54:
	adrp	x0, l_str@PAGE
Lloh55:
	add	x0, x0, l_str@PAGEOFF
	bl	_puts
	mov	w19, #0                         ; =0x0
LBB3_25:
	ldur	x8, [x29, #-96]
Lloh56:
	adrp	x9, ___stack_chk_guard@GOTPAGE
Lloh57:
	ldr	x9, [x9, ___stack_chk_guard@GOTPAGEOFF]
Lloh58:
	ldr	x9, [x9]
	cmp	x9, x8
	b.ne	LBB3_28
; %bb.26:
	mov	x0, x19
	add	sp, sp, #1, lsl #12             ; =4096
	add	sp, sp, #80
	ldp	x29, x30, [sp, #80]             ; 16-byte Folded Reload
	ldp	x20, x19, [sp, #64]             ; 16-byte Folded Reload
	ldp	x22, x21, [sp, #48]             ; 16-byte Folded Reload
	ldp	x24, x23, [sp, #32]             ; 16-byte Folded Reload
	ldp	x26, x25, [sp, #16]             ; 16-byte Folded Reload
	ldp	x28, x27, [sp], #96             ; 16-byte Folded Reload
	ret
LBB3_27:
	add	x0, sp, #32
	bl	_main.cold.2
	mov	w19, #1                         ; =0x1
	b	LBB3_25
LBB3_28:
	bl	___stack_chk_fail
	.loh AdrpAdd	Lloh17, Lloh18
	.loh AdrpAdd	Lloh15, Lloh16
	.loh AdrpLdrGotLdr	Lloh12, Lloh13, Lloh14
	.loh AdrpLdrGot	Lloh10, Lloh11
	.loh AdrpAdd	Lloh35, Lloh36
	.loh AdrpAdd	Lloh33, Lloh34
	.loh AdrpAdd	Lloh31, Lloh32
	.loh AdrpAdd	Lloh29, Lloh30
	.loh AdrpLdrGot	Lloh27, Lloh28
	.loh AdrpAdd	Lloh25, Lloh26
	.loh AdrpAdd	Lloh23, Lloh24
	.loh AdrpAdd	Lloh21, Lloh22
	.loh AdrpAdd	Lloh19, Lloh20
	.loh AdrpAdd	Lloh37, Lloh38
	.loh AdrpAdd	Lloh39, Lloh40
	.loh AdrpAdd	Lloh44, Lloh45
	.loh AdrpLdrGotLdr	Lloh41, Lloh42, Lloh43
	.loh AdrpAdd	Lloh46, Lloh47
	.loh AdrpAdd	Lloh52, Lloh53
	.loh AdrpAdd	Lloh50, Lloh51
	.loh AdrpAdd	Lloh48, Lloh49
	.loh AdrpAdd	Lloh54, Lloh55
	.loh AdrpLdrGotLdr	Lloh56, Lloh57, Lloh58
	.cfi_endproc
                                        ; -- End function
	.p2align	2                               ; -- Begin function main.cold.1
_main.cold.1:                           ; @main.cold.1
	.cfi_startproc
; %bb.0:
	sub	sp, sp, #48
	stp	x20, x19, [sp, #16]             ; 16-byte Folded Spill
	stp	x29, x30, [sp, #32]             ; 16-byte Folded Spill
	add	x29, sp, #32
	.cfi_def_cfa w29, 16
	.cfi_offset w30, -8
	.cfi_offset w29, -16
	.cfi_offset w19, -24
	.cfi_offset w20, -32
	mov	x19, x0
Lloh59:
	adrp	x0, l_.str.2@PAGE
Lloh60:
	add	x0, x0, l_.str.2@PAGEOFF
	bl	_perror
Lloh61:
	adrp	x8, ___stderrp@GOTPAGE
Lloh62:
	ldr	x8, [x8, ___stderrp@GOTPAGEOFF]
Lloh63:
	ldr	x0, [x8]
	str	x19, [sp]
Lloh64:
	adrp	x1, l_.str.17@PAGE
Lloh65:
	add	x1, x1, l_.str.17@PAGEOFF
	bl	_fprintf
	ldp	x29, x30, [sp, #32]             ; 16-byte Folded Reload
	b	_OUTLINED_FUNCTION_0
	.loh AdrpAdd	Lloh64, Lloh65
	.loh AdrpLdrGotLdr	Lloh61, Lloh62, Lloh63
	.loh AdrpAdd	Lloh59, Lloh60
	.cfi_endproc
                                        ; -- End function
	.p2align	2                               ; -- Begin function main.cold.2
_main.cold.2:                           ; @main.cold.2
	.cfi_startproc
; %bb.0:
	sub	sp, sp, #48
	stp	x20, x19, [sp, #16]             ; 16-byte Folded Spill
	stp	x29, x30, [sp, #32]             ; 16-byte Folded Spill
	add	x29, sp, #32
	.cfi_def_cfa w29, 16
	.cfi_offset w30, -8
	.cfi_offset w29, -16
	.cfi_offset w19, -24
	.cfi_offset w20, -32
	mov	x19, x0
Lloh66:
	adrp	x0, l_.str.2@PAGE
Lloh67:
	add	x0, x0, l_.str.2@PAGEOFF
	bl	_perror
Lloh68:
	adrp	x8, ___stderrp@GOTPAGE
Lloh69:
	ldr	x8, [x8, ___stderrp@GOTPAGEOFF]
Lloh70:
	ldr	x0, [x8]
	str	x19, [sp]
Lloh71:
	adrp	x1, l_.str.17@PAGE
Lloh72:
	add	x1, x1, l_.str.17@PAGEOFF
	bl	_fprintf
	ldp	x29, x30, [sp, #32]             ; 16-byte Folded Reload
	b	_OUTLINED_FUNCTION_0
	.loh AdrpAdd	Lloh71, Lloh72
	.loh AdrpLdrGotLdr	Lloh68, Lloh69, Lloh70
	.loh AdrpAdd	Lloh66, Lloh67
	.cfi_endproc
                                        ; -- End function
	.p2align	2                               ; -- Begin function OUTLINED_FUNCTION_0
_OUTLINED_FUNCTION_0:                   ; @OUTLINED_FUNCTION_0 Tail Call
	.cfi_startproc
; %bb.0:
	ldp	x20, x19, [sp, #16]
	add	sp, sp, #48
	ret
	.cfi_endproc
                                        ; -- End function
	.section	__TEXT,__cstring,cstring_literals
l_.str:                                 ; @.str
	.asciz	"nftw"

l_.str.1:                               ; @.str.1
	.asciz	"Directory and its contents deleted successfully: %s\n"

l_.str.2:                               ; @.str.2
	.asciz	"mkdir"

l_.str.3:                               ; @.str.3
	.asciz	"Directory created: %s\n"

l_.str.4:                               ; @.str.4
	.asciz	"Enter the sport you want to handle: "

l_.str.5:                               ; @.str.5
	.asciz	"%9s"

l_.str.6:                               ; @.str.6
	.asciz	"Failed to read sport input\n"

l_.str.7:                               ; @.str.7
	.asciz	"/Users/trevor/trevorscholz1/daily_lockz/models/data"

l_.str.8:                               ; @.str.8
	.asciz	"%s/%s_data"

l_.str.9:                               ; @.str.9
	.asciz	"%s/%s_games.csv"

l_.str.10:                              ; @.str.10
	.asciz	"Failed to delete directory: %s\n"

l_.str.11:                              ; @.str.11
	.asciz	"Failed to delete file: %s\n"

l_.str.12:                              ; @.str.12
	.asciz	"File deleted successfully: %s\n"

l_.str.13:                              ; @.str.13
	.asciz	"Failed to get file status: %s\n"

l_.str.14:                              ; @.str.14
	.asciz	"new_scores"

l_.str.15:                              ; @.str.15
	.asciz	"scores"

l_.str.16:                              ; @.str.16
	.asciz	"standings"

	.section	__DATA,__const
	.p2align	3, 0x0                          ; @__const.main.subdirs
l___const.main.subdirs:
	.quad	l_.str.14
	.quad	l_.str.15
	.quad	l_.str.16

	.section	__TEXT,__cstring,cstring_literals
l_.str.17:                              ; @.str.17
	.asciz	"Failed to create directory: %s\n"

l_.str.18:                              ; @.str.18
	.asciz	"%s/%s_data/%s"

l_str:                                  ; @str
	.asciz	"All operations completed successfully."

.subsections_via_symbols

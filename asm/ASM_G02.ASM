;====================================================================
; PolyMorphic Systems Assembler Version G02 (1976)
; Disassembly of asm_g02.bin
; Binary loaded at address $2000
;
; Disassembled with dsm85, annotated with labels and comments.
; 8085-only mnemonics replaced with .db directives.
;====================================================================

WH2	EQU	0C28H	; tape input
WH3	EQU	0C2CH	; tape output


;====================================================================
; ENTRY POINTS AND INITIALIZATION (0x2000)
;====================================================================
	ORG	2000H
cold_start:
	JMP	init	;Cold start entry point
warm_start:
	JMP	j2098	;Warm start / command loop re-entry
L2006:	DB	10H
L2007:	DB	00H
L2008:	DB	7FH
L2009:	DB	01H
L200A:	DB	01H
L200B:	DB	01H
L200C:	DB	3FH
L200D:	DB	7FH
L200E:	DB	0AH

j200f:	DB	0CDH
	DB	0ADH
	DB	002H
	DB	016H
	DB	0AAH
	DB	040H
	DB	0DAH
	DB	000H
	DB	0C9H
;j200f:	CALL	j02ad
;	MVI	D,0AAH
;	MOV	B,B
;	JC	jc900

;====================================================================
; UTILITY: COMPARE AND SUBTRACT (0x2018)
;====================================================================

cmp_hl_de:
	MOV	A,D	;Compare HL >= DE, return flags
	CMP	H
	RNZ
	MOV	A,E
	CMP	L
	RET

sub_hl_de:
	MOV	A,L	;HL = HL - DE
	SUB	E
	MOV	L,A
	MOV	A,H
	SBB	D
	MOV	H,A
	RET

init:	LXI	H,0000H	;Initialize: save SP, size memory, print banner
	DAD	SP
	SHLD	var_saved_sp
	CALL	reset_line_counter
	LXI	H,2494H
	CALL	print_line
	CALL	print_cr
	LXI	H,var_symbol_area+2
	SHLD	var_symbol_area
	PUSH	H
	MVI	H,00H
	MVI	D,00H
	LDA	L2006
	MOV	L,A
	MOV	E,A
	DAD	H
	DAD	H
	DAD	D
	DAD	H
	POP	D
	DAD	D
	LXI	D,000BH
	DAD	D
	MVI	M,0DH
	SHLD	var_buf_start
	SHLD	var_buf_end
j205a:	MOV	A,M
	CMA
	MOV	M,A
	CMP	M
	JNZ	j2067
	CMA
	MOV	M,A
	INX	H
	JMP	j205a
j2067:	DCX	H
	SHLD	var_mem_top
	LXI	H,top_mem_str
	CALL	print_line
	LDA	var_mem_top
	INR	A
	MVI	A,'?'
	JNZ	j207c
	MVI	A,'.'
j207c:	PUSH	PSW
	LDA	var_mem_top+1
	CALL	print_hex_byte
	LDA	var_mem_top
	CALL	print_hex_byte
	POP	PSW
	CALL	mon_char_output
	CALL	print_space
	CALL	show_free_mem
	MVI	A,00H
	STA	var_pass_flag
j2098:	LXI	H,keyboard_isr
	SHLD	0C18H
	MVI	A,0CDH
	STA	mon_listing_hook
	LXI	H,tape_char_io
	SHLD	0C3DH
	MVI	A,0C9H
	STA	0C3FH
	MVI	A,7DH
	SHLD	var_kbd_handler_id
	JMP	cmd_loop

;====================================================================
; KEYBOARD HANDLER AND COMMAND LOOP (0x20B6)
;====================================================================

keyboard_isr:
	IN	0F8H	;Keyboard interrupt handler - read char, dispatch
	ORA	A
	JZ	mon_warm_start
	MOV	B,A
	LDA	var_kbd_handler_id
	ORA	A
	CMP	B
	JZ	j20ca
	MVI	A,1BH
	JNZ	j20ce
j20ca:	LHLD	var_kbd_vector
	PCHL
j20ce:	MVI	A,1AH
	CMP	B
	JZ	j0117
	LXI	H,0C0CH
	MVI	M,00H
	INX	H
	MOV	M,B
	JMP	mon_warm_start
cmd_loop:
	LHLD	var_saved_sp	;Main command loop: restore SP, read & execute command
	SPHL
	CALL	print_cr
	LXI	H,cmd_loop
	SHLD	var_kbd_vector
	MVI	A,7DH
	STA	var_kbd_handler_id
	CALL	reset_line_counter
	LXI	D,var_cmd_prompt
	CALL	read_cmd_line
	CALL	parse_cmd_line
	CALL	cmd_dispatch
j20ff:	JMP	cmd_loop

;====================================================================
; COMMAND LINE INPUT (0x2102)
;====================================================================

read_cmd_line:
	LXI	H,input_command_buf	;Read command line into buffer at (HL)
	SHLD	var_hex_buf
	LDA	var_cmd_prompt
	CALL	mon_char_output
read_char_loop:
	CALL	mon_char_input
	MOV	B,A
	CPI	0DH
	JZ	j211c
	ANI	0E0H
	JZ	read_char_loop
j211c:	MOV	A,B
	MOV	M,A
	CPI	0DH
	RZ
	CPI	7FH
	JZ	j212d
	CALL	mon_char_output
	INX	H
	JMP	read_char_loop
j212d:	XCHG
	LXI	H,input_command_buf
	CALL	cmp_hl_de
	JZ	read_char_loop
	XCHG
	MVI	A,7FH
	CALL	mon_char_output
	DCX	H
	JMP	read_char_loop

;====================================================================
; PRINT UTILITIES (0x2141)
;====================================================================

print_cr:
	MVI	A,0DH
	JMP	mon_char_output
print_space:
	MVI	A,' '
	JMP	mon_char_output
print_tab:
	MVI	A,09H
	JMP	mon_char_output
print_string:
	MOV	A,M
	ORA	A
	RZ
	CALL	mon_char_output
	INX	H
	JMP	print_string
pad_spaces:
	CMP	L
	RZ
	MVI	M,' '
	INX	H
	JMP	pad_spaces
cmd_call:
	CALL	j2407
	CALL	print_cr
	LHLD	var_start_addr
	PCHL

;====================================================================
; COMMAND DISPATCH (0x216C)
;====================================================================

cmd_dispatch:
	LXI	D,cmd_table_start	;Dispatch: match 4-char command name against table at $235B
	MVI	B,0DH
	MVI	A,04H
	STA	var_cmd_name_len
	CALL	cmd_match_loop
	JNZ	error_illegal_cmd
	PCHL
cmd_match_loop:
	LHLD	var_hex_buf
	LDA	var_cmd_name_len
	MOV	C,A
	CALL	strcmp
	LDAX	D
	MOV	L,A
	INX	D
	LDAX	D
	MOV	H,A
	RZ
	INX	D
	DCR	B
	JNZ	cmd_match_loop
	INR	B
	RET

strcmp:	LDAX	D	;String compare: (DE) vs (HL), length in C
	CMP	M
	JNZ	strcmp_skip
	INX	H
	INX	D
	DCR	C
	JNZ	strcmp
	RET

strcmp_skip:
	INX	D
	DCR	C
	JNZ	strcmp_skip
	INR	C
	RET


;====================================================================
; COMMAND LINE PARSING (0x21A7)
;====================================================================

clear_params:
	XRA	A	;Clear 12 bytes of parameter area at $3B5D
	LXI	D,var_start_addr
	MVI	B,0CH
j21ad:	DCX	D
	STAX	D
	DCR	B
	JNZ	j21ad
	RET

parse_cmd_line:
	CALL	parse_filename
	JC	error_bad_params
	RET

parse_filename:
	LXI	H,0000H	;Parse command line: filename, addresses
	SHLD	var_end_addr
	SHLD	var_filename1
	CALL	clear_params
	LXI	H,3B9BH
skip_spaces:
	INX	H
	MOV	A,M
	CPI	' '
	CMC
	RNC
	JNZ	skip_spaces
	SHLD	var_source_ptr
parse_slashed_name:
	CALL	parse_next_field
	CMC
	RNC
	CPI	'/'
	JNZ	parse_hex_params
	LXI	D,var_filename1
	MVI	C,08H
copy_filename_chars:
	INX	H
	MOV	A,M
	CPI	'/'
	JZ	pad_filename
	DCR	C
	JM	error_bad_filename
	STAX	D
	INX	D
	JMP	copy_filename_chars
pad_filename:
	MVI	A,' '
j21f7:	DCR	C
	JM	parse_second_part
	STAX	D
	INX	D
	JMP	j21f7
parse_second_part:
	CALL	skip_to_field_end
	CMC
	RNC
parse_hex_params:
	LXI	D,var_filename2
	CALL	parse_expression
	MOV	A,B
	CPI	05H
	CMC
	RC
	LXI	B,var_filename2
	CALL	parse_hex
	RC
	SHLD	var_start_addr
	LXI	H,var_filename2
	CALL	right_justify
	CALL	parse_next_field
	CMC
	RNC
	LXI	D,3B61H
	CALL	parse_expression
	MOV	A,B
	CPI	05H
	CMC
	RC
	LXI	B,3B61H
	CALL	parse_hex
	RC
	SHLD	var_end_addr
	LXI	H,3B61H
	CALL	right_justify
	ORA	A
	RET


;====================================================================
; NUMBER CONVERSION ROUTINES (0x2242)
;====================================================================

parse_decimal:
	LXI	H,0000H	;Parse decimal number from (BC) into HL
parse_dec_loop:
	LDAX	B
	ORA	A
	RZ
	MOV	D,H
	MOV	E,L
	DAD	H
	DAD	H
	DAD	D
	DAD	H
	SUI	30H
	CPI	0AH
	CMC
	RC
	MOV	E,A
	MVI	D,00H
	DAD	D
	INX	B
	JMP	parse_dec_loop
parse_hex:
	LXI	H,0000H	;Parse hex number from (BC) into HL
parse_hex_loop:
	LDAX	B
	ORA	A
	RZ
	DAD	H
	DAD	H
	DAD	H
	DAD	H
	CALL	hex_char_to_val
	CPI	10H
	CMC
	RC
	ADD	L
	MOV	L,A
	INX	B
	JMP	parse_hex_loop
hex_char_to_val:
	SUI	30H	;Convert ASCII hex char to value 0-15
	CPI	0AH
	RC
	SUI	07H
	RET

print_hex_byte:
	CALL	byte_to_hex_ascii	;Print A as 2-digit hex
print_two_chars:
	LXI	H,var_hex_buf
	MOV	A,M
	CALL	mon_char_output
	INX	H
	MOV	A,M
	JMP	mon_char_output
	CALL	print_hex_byte
	JMP	print_space
print_decimal:
	CALL	byte_to_decimal
	CALL	print_two_chars
	INX	H
	MOV	A,M
	JMP	mon_char_output
	LHLD	var_start_addr
	LDA	3B6CH
	CMP	H
	JNZ	next_source_line
	LDA	var_end_addr
	CMP	L
	JNZ	next_source_line
	STC

;====================================================================
; SOURCE LINE HANDLING AND OUTPUT (0x22AD)
;====================================================================

next_source_line:
	INX	H
	SHLD	var_start_addr
	RET

reset_line_counter:
	MVI	A,0FH	;Reset line counter to 15
	STA	var_line_counter
	LDA	L200C
	STA	var_print_ctrl
	RET

print_line_with_num:
	LDA	var_pass_flag
	JMP	print_line_inner
print_line:
	XRA	A	;Print line pointed to by HL (with tab expansion)
print_line_inner:
	STA	var_listing_flag
	ORA	A
	JNZ	j22e3
	LDA	var_line_counter
	ORA	A
	JNZ	j22df
	PUSH	H
	LHLD	mon_screen_ptr
	MVI	M,0AEH
	CALL	mon_char_input
	MVI	A,0FH
	POP	H
j22df:	DCR	A
	STA	var_line_counter
j22e3:	MVI	B,00H
print_chars_loop:
	MOV	A,M
	CPI	0DH
	JZ	print_cr_if_listing
	CPI	09H
	JZ	expand_tab
	CALL	output_char
j22f3:	INX	H
	JMP	print_chars_loop
expand_tab:
	MVI	A,' '
	CALL	output_char
	MOV	A,B
	ANI	07H
	JNZ	expand_tab
	JMP	j22f3
output_char:
	MOV	C,A
	INR	B
	LDA	var_listing_flag
	ORA	A
	MOV	A,C
	CNZ	mon_listing_hook
	MOV	A,B
	CPI	40H
	RP
	MOV	A,C
	CALL	mon_char_output
	RET

print_cr_if_listing:
	LDA	var_listing_flag
	ORA	A
	RZ
	MVI	A,0DH
	CALL	mon_listing_hook
	RET


;====================================================================
; HEX / DECIMAL FORMATTING (0x2323)
;====================================================================

byte_to_hex_ascii:
	LXI	H,var_hex_buf	;Convert byte in A to two hex ASCII chars at (HL)
nibble_convert:
	MOV	B,A
	RAR
	RAR
	RAR
	RAR
	CALL	nibble_to_ascii
	MOV	M,A
	INX	H
	MOV	A,B
	CALL	nibble_to_ascii
	MOV	M,A
	RET

nibble_to_ascii:
	ANI	0FH
	ADI	30H
	CPI	3AH
	RC
	ADI	07H
	RET

byte_to_decimal:
	LXI	H,var_hex_buf
	MVI	B,64H
	CALL	decimal_digit
	MVI	B,0AH
	CALL	decimal_digit
	ADI	30H
	MOV	M,A
	RET

decimal_digit:
	MVI	M,'/'
j2353:	INR	M
	SUB	B
	JNC	j2353
	ADD	B
	INX	H
	RET


; === Start of cmd_table ===

;====================================================================
; COMMAND TABLE (0x235B)
;====================================================================

cmd_table_start:
	DB	46H	;Command table: 13 entries, 4-char name + 2-byte jump address
	DB	52H,45H,45H,0D9H,23H,53H,59H,4DH
	DB	54H,0F5H,2EH,4CH,4FH,41H,44H,7EH
	DB	33H,53H,41H,56H,45H,54H,35H,44H
	DB	55H,4DH,50H,0E5H,34H,43H,41H,4CH
	DB	4CH,62H,21H,41H,53H,4DH,42H,98H
	DB	2AH,4DH,4EH,54H,52H,38H,00H,45H
	DB	44H,49H,54H,7AH,26H,4BH,49H,4CH
	DB	4CH,0A9H,23H,48H,41H,52H,44H,0B2H
	DB	23H,53H,4FH,46H,54H,0BCH,23H,4CH
	DB	49H,53H,54H,0C1H,23H
; === End of cmd_table ===


;====================================================================
; SIMPLE COMMAND HANDLERS (0x23A9)
;====================================================================

cmd_kill:
	LHLD	var_buf_start
	SHLD	var_buf_end
	MVI	M,0DH
	RET

cmd_hard:
	MVI	A,01H
	STA	var_pass_flag
	XRA	A
	STA	var_error_flag
	RET

cmd_soft:
	XRA	A
	STA	var_pass_flag
	RET

cmd_list:
	CALL	print_cr_if_listing
	LHLD	var_buf_end
	XCHG
	LHLD	var_buf_start
list_loop:
	CALL	cmp_hl_de
	RC
	CALL	print_cr
	CALL	print_line_with_num
	INX	H
	JMP	list_loop
cmd_free:
	CALL	print_tab
show_free_mem:
	LHLD	var_buf_end
	XCHG
	LHLD	var_mem_top
	CALL	sub_hl_de
	SHLD	var_free_bytes
	MOV	A,H
	CALL	print_hex_byte
	LDA	var_free_bytes
	CALL	print_hex_byte
	LXI	H,2513H
	CALL	print_line
	LHLD	var_buf_end
	INX	H
	PUSH	H
	MOV	A,H
	CALL	print_hex_byte
	POP	H
	MOV	A,L
	JMP	print_hex_byte
j2407:	LDA	var_filename2
	ORA	A
	RNZ
	JMP	error_forgot_params

;====================================================================
; ERROR MESSAGES AND STRINGS (0x240F)
;====================================================================

print_error_return:
	CALL	print_cr	;Print string at HL, CR, return to command loop
	CALL	print_line
	JMP	j20ff
error_illegal_cmd:
	LXI	H,illegal_command_str	;Error: Illegal command
	JMP	print_error_return

illegal_command_str:
	DB	'Illegal command',13

error_bad_params:
	LXI	H,bad_param_str	;Error: Bad parameters
	JMP	print_error_return

bad_param_str:
	DB	'Bad parameters!',13

error_bad_filename:
	LXI	H,bad_file_str	;Error: Bad file name
	JMP	print_error_return

bad_file_str:
	DB	'Bad file name...',13

error_checksum:
	LXI	H,checksum_err_str	;Error: checksum error
	JMP	print_error_return

checksum_err_str:
	DB	'aaugh! checksum error...',13

error_line_too_long:
	LXI	H,line_too_long_str	;Error: Line too long
	JMP	print_error_return

line_too_long_str:
	DB	'Line too long',13

print_banner:
	LXI	H,banner	;Print assembler banner
	JMP	print_error_return

banner:
	DB	'PolyMorphic Systems Assembler Version G02.',13

error_forgot_params:
	LXI	H,missing_param_str	;Error: You forgot parameters
	JMP	print_error_return

missing_param_str:
	DB	'You forgot parameters!',13

mem_full_str:
	DB	'uh oh... memory full! (you lose...)',13

top_mem_str:
	DB	'Top of memory is',13

bytes_free_str:
	DB	' Bytes Free, starting at ',13

too_many_str:
	DB	'Too many assembly errors',13

; === Start of str_commands ===

help_text:
	DB	'Commands:',13
	DB	'^B - Beginning of buffer	^U - Up ',13
	DB	'^E - End of buffer		^D - Down',13
	DB	'^F - Find string		^R - Right',13
	DB	'^H - Help! (Give commands)	^L - Left',13
	DB	'^N - Next page			^W - Delete Word',13
	DB	'^P - Previous page		^X - Delete Line',13
	DB	13,13,'  ESC or ALTMD - Leave editor',13,12

; === Start of editor_dispatch_tbl ===

;====================================================================
; EDITOR (0x263A)
;====================================================================

;Editor dispatch table: 32 entries for ctrl-A through ctrl-Z + specials
	DW	editor_nop
	DW	editor_nop
	DW	move_down_to_fill	; ^B
	DW	find_string_2	; ^C
	DW	move_up		; ^D
	DW	move_up_lines	; ^E
	DW	find_string	; ^F
	DW	editor_nop
	DW	cmd_help	; ^H
	DW	insert_char	; ^I
	DW	move_up		; ^J
	DW	insert_char	; ^K
	DW	move_left	; ^L
	DW	insert_char	; ^M
	DW	page_up_multi	; ^N
	DW	editor_nop
	DW	page_down_multi	; ^P
	DW	editor_nop
	DW	move_right	; ^R
	DW	editor_nop
	DW	editor_nop
	DW	move_to_next_page	; ^U
	DW	editor_nop
	DW	delete_word	; ^W
	DW	delete_line		; ^X
	DW	editor_nop
	DW	editor_nop
	DW	edit_exit		; ESC
	DW	editor_nop
	DW	editor_nop
	DW	editor_nop
	DW	editor_nop
; === End of editor_dispatch_tbl ===

;Editor init: clear vars, set up screen
editor_init:
	XRA	A
	STA	var_kbd_handler_id
	LHLD	0C1EH
	MVI	L,00H
	SHLD	var_video_base
	LHLD	var_buf_end
	INX	H
	SHLD	var_gap_start
	LHLD	var_mem_top
	SHLD	var_text_end
	SHLD	var_gap_end
	LHLD	var_video_base
	XCHG
	LHLD	mon_screen_ptr
	CALL	sub_hl_de
	SHLD	var_screen_offset
	LXI	D,screen_template
	DAD	D
	MVI	M,0FFH
	CALL	move_down_to_fill
	CALL	editor_clear_screen

;Editor main loop: update display, get key, dispatch
editor_main_loop:
	CALL	editor_update_display
	CALL	mon_char_input
	CALL	editor_dispatch
	JMP	editor_main_loop

;Editor key dispatch: look up handler in table at $263A
editor_dispatch:
	MOV	B,A
	CPI	7DH
	JZ	editor_exit
	CPI	1CH
	JP	insert_char
	MOV	A,B
	ANI	1FH
	RLC
	MOV	E,A
	MVI	D,00H
	LXI	H,263AH
	DAD	D
	MOV	E,M
	INX	H
	MOV	D,M
	XCHG
	PCHL

editor_nop:
	RET

;Exit editor: restore buffer pointers, return to command loop
editor_exit:
	CALL	move_up_lines
	LHLD	var_gap_start
	DCX	H
	SHLD	var_buf_end
	MVI	A,0CH
	CALL	mon_char_output
	CALL	show_free_mem
	JMP	cmd_loop

;Clear editor screen buffer
editor_clear_screen:
	LXI	H,0000H
	SHLD	var_cursor_pos
	LHLD	var_gap_start
	SHLD	var_display_start

editor_fill_screen:
	LXI	D,screen_template
	LXI	H,var_cmd_prompt
j26fe:	XRA	A
	STAX	D
	INX	D
	CALL	cmp_hl_de
	JNZ	j26fe
	RET

;Refresh screen display from text buffer
editor_update_display:
	LXI	B,0000H
	MVI	A,0FFH
	STA	3B3FH
	LHLD	var_display_start
display_line_loop:
	XCHG
	LHLD	var_gap_start
	CALL	cmp_hl_de
	JZ	j273a
	LHLD	var_text_end
	XCHG
	CALL	cmp_hl_de
	JC	j274c
	MOV	A,M
	CPI	0DH
	JZ	j2755
	CPI	09H
	JZ	j275b
	CALL	j276c
	RC
	INX	H
	JMP	display_line_loop
j273a:	MVI	A,7FH
	MOV	H,B
	MOV	L,C
	SHLD	var_screen_offset
	CALL	j276c
	RC
	LHLD	var_gap_end
	INX	H
	JMP	display_line_loop
j274c:	MVI	A,' '
	CALL	j276c
	JNC	j274c
	RET

j2755:	LXI	D,3F7FH
	JMP	j275e
j275b:	LXI	D,073FH
j275e:	MOV	A,E
	CALL	j276e
	RC
	MOV	A,C
	ANA	D
	JNZ	j275e
	INX	H
	JMP	display_line_loop
j276c:	ORI	80H
j276e:	PUSH	H
	LXI	H,screen_template
	DAD	B
	CMP	M
	JZ	j277d
	MOV	M,A
	LHLD	var_video_base
	DAD	B
	MOV	M,A
j277d:	POP	H
	INX	B
	MVI	A,03H
	CMP	B
	RET

cursor_back_line:
	LHLD	var_gap_start
	DCX	H
	MOV	A,M
	LHLD	var_cursor_pos
	CPI	0DH
	JZ	j2799
	CPI	09H
	JZ	j27a1
	INX	H
	JMP	j27aa
j2799:	LXI	D,0040H
	MVI	B,0C0H
	JMP	j27a6
j27a1:	LXI	D,0008H
	MVI	B,0F8H
j27a6:	DAD	D
	MOV	A,L
	ANA	B
	MOV	L,A
j27aa:	SHLD	var_cursor_pos
	JMP	scroll_check
cursor_fwd_line:
	LHLD	var_gap_end
	INX	H
	MOV	A,M
j27b5:	CPI	09H
	JZ	j27c9
	CPI	0DH
	JZ	j27ce
	LHLD	var_cursor_pos
	DCX	H
	SHLD	var_cursor_pos
	JMP	scroll_check
j27c9:	MVI	B,3FH
	JMP	j27d0
j27ce:	MVI	B,7FH
j27d0:	LHLD	var_cursor_pos
	XCHG
	LXI	H,screen_template
	DAD	D
j27d8:	DCX	H
	DCX	D
	MOV	A,D
	ORA	A
	JM	j27f4
	INX	D
	MOV	A,M
	CMP	B
	JNZ	j27f4
	DCX	D
	MVI	C,07H
	CPI	3FH
	JZ	j27ef
	MVI	C,3FH
j27ef:	MOV	A,E
	ANA	C
	JNZ	j27d8
j27f4:	XCHG
	SHLD	var_cursor_pos
scroll_check:
	LDA	var_cursor_pos+1
	CPI	04H
	JC	scroll_done
	JNZ	j282b
	MVI	B,40H
j2805:	LHLD	var_display_start
	MOV	A,M
	INX	H
	SHLD	var_display_start
	CPI	0DH
	JZ	j2822
	DCR	B
	JZ	j2822
	CPI	09H
	JNZ	j2805
	MOV	A,B
	ANI	0F8H
	MOV	B,A
	JNZ	j2805
j2822:	LXI	H,03C0H
	SHLD	var_cursor_pos
	JMP	scroll_done
j282b:	LHLD	var_gap_start
	SHLD	var_display_start
	LXI	H,0000H
	SHLD	var_cursor_pos
scroll_done:
	ORI	01H
	RET

update_cursor_char:
	PUSH	H
	PUSH	D
	PUSH	PSW
	LHLD	var_screen_offset
	XCHG
	LXI	H,screen_template
	DAD	D
	LDA	mon_status_byte
	ANI	08H
	MOV	A,M
	JZ	j2853
	ANI	7FH
	JMP	j2855
j2853:	ORI	80H
j2855:	CMP	M
	JZ	j2863
	MOV	M,A
	LHLD	var_screen_offset
	XCHG
	LHLD	var_video_base
	DAD	D
	MOV	M,A
j2863:	POP	PSW
	POP	D
	POP	H
	RET

move_up_lines:
	CALL	move_up
	CALL	update_cursor_char
	JNZ	move_up_lines
	RET

move_down_to_fill:
	CALL	gap_move_left
	CALL	update_cursor_char
	JNZ	move_down_to_fill
	JMP	j282b
move_right:
	CALL	gap_move_right
	RZ
	CALL	cursor_back_line
	RET

move_left:
	CALL	gap_move_left
	RZ
	CALL	cursor_fwd_line
	ORI	01H
	RET

move_up:CALL move_right
	RZ
	LHLD	var_gap_start
	DCX	H
	MOV	A,M
	CPI	0DH
	JNZ	move_up
	ORI	01H
	RET

move_to_next_page:
	CALL	move_left
	JZ	j28c0
	LHLD	var_gap_end
	INX	H
	MOV	A,M
	CPI	0DH
	JNZ	move_to_next_page
page_down_scan:
	LHLD	var_gap_start
	DCX	H
	MOV	A,M
	CPI	0DH
	JZ	j28c0
	CALL	move_left
	JNZ	page_down_scan
j28c0:	ORI	01H
	RET

insert_char:
	MOV	A,B
	CPI	7FH
	JZ	delete_char
	LHLD	var_gap_end
	XCHG
	LHLD	var_gap_start
	CALL	cmp_hl_de
	RZ
	MOV	A,B
	MOV	M,A
	INX	H
	SHLD	var_gap_start
	JMP	cursor_back_line
delete_char:
	LHLD	var_buf_start
	XCHG
	LHLD	var_gap_start
	CALL	cmp_hl_de
	RZ
	DCX	H
	SHLD	var_gap_start
	MOV	A,M
	JMP	j27b5
delete_line:
	CALL	delete_char
	RZ
	LHLD	var_gap_start
	DCX	H
	MOV	A,M
	CPI	0DH
	JNZ	delete_line
	RET

delete_word:
	CALL	delete_char
	RZ
	LHLD	var_gap_start
	DCX	H
	MOV	A,M
	CPI	30H
	RC
	CPI	3AH
	JC	delete_word
	ANI	5FH
	CPI	41H
	RC
	CPI	5BH
	JC	delete_word
	RET

page_up_multi:
	MVI	B,0FH
j291d:	PUSH	B
	CALL	move_up
	POP	B
	RZ
	DCR	B
	JNZ	j291d
	RET

page_down_multi:
	MVI	B,0FH
j292a:	PUSH	B
	CALL	move_to_next_page
	POP	B
	RZ
	DCR	B
	JNZ	j292a
	RET

find_string:
	CALL	search_input
find_string_2:
	LHLD	var_gap_end
	XCHG
	INX	D
find_loop:
	LXI	H,3BECH
j2940:	PUSH	H
	LHLD	var_text_end
	CALL	cmp_hl_de
	POP	H
	JNC	j298a
	LDAX	D
	CMP	M
	JZ	j2954
	INX	D
	JMP	j2940
j2954:	PUSH	D
	XCHG
	LHLD	var_search_end
	CALL	cmp_hl_de
	XCHG
	POP	D
	JZ	find_found
	INX	D
	INX	H
	LDAX	D
	CMP	M
	JZ	j2954
	JMP	find_loop
find_found:
	LHLD	var_gap_end
	XCHG
	CALL	sub_hl_de
	SHLD	var_search_count
	CALL	editor_update_display
j2978:	CALL	move_right
	CALL	update_cursor_char
	LHLD	var_search_count
	DCX	H
	SHLD	var_search_count
	MOV	A,H
	ORA	L
	JNZ	j2978
j298a:	CALL	editor_update_display
	RET

gap_move_left:
	LHLD	var_buf_start	;Gap buffer: move char from right of gap to left
	XCHG
	LHLD	var_gap_start
	CALL	cmp_hl_de
	RZ
	DCX	H
	SHLD	var_gap_start
	MOV	A,M
	LHLD	var_gap_end
	MOV	M,A
	DCX	H
	SHLD	var_gap_end
	ORA	A
	RET

gap_move_right:
	LHLD	var_text_end	;Gap buffer: move char from left of gap to right
	XCHG
	LHLD	var_gap_end
	CALL	cmp_hl_de
	RZ
	INX	H
	SHLD	var_gap_end
	MOV	A,M
	LHLD	var_gap_start
	MOV	M,A
	INX	H
	SHLD	var_gap_start
	ORA	A
	RET

search_input:
	LHLD	var_gap_start	;Begin search string input mode
	XCHG
	LHLD	var_gap_end
	CALL	cmp_hl_de
	RNC
	XCHG
	SHLD	var_search_count
	MVI	M,0FFH
	INX	H
	SHLD	var_gap_start
	LXI	H,3BECH
	SHLD	var_search_ptr
search_char_loop:
	CALL	editor_update_display
	CALL	mon_char_input
	CPI	1BH
	JZ	search_done
	CPI	7FH
	JZ	search_delete_char
	CPI	18H
	JZ	search_cancel
	ORI	80H
	MOV	B,A
	LHLD	var_gap_start
	XCHG
	LHLD	var_gap_end
	CALL	cmp_hl_de
	JNC	search_char_loop
	XCHG
	MOV	M,B
	INX	H
	PUSH	H
	LXI	H,var_symbol_area
	XCHG
	LHLD	var_search_ptr
	CALL	cmp_hl_de
	JZ	search_char_loop
	MOV	A,B
	ANI	7FH
	MOV	M,A
	INX	H
	SHLD	var_search_ptr
	POP	H
	SHLD	var_gap_start
	JMP	search_char_loop
search_delete_char:
	LHLD	var_gap_start
	XCHG
	LHLD	var_search_count
	INX	H
	CALL	cmp_hl_de
	JZ	search_char_loop
	XCHG
	DCX	H
	SHLD	var_gap_start
	LHLD	var_search_ptr
	DCX	H
	SHLD	var_search_ptr
	JMP	search_char_loop
search_cancel:
	LXI	H,search_input
	PUSH	H
search_done:
	LHLD	var_search_ptr
	DCX	H
	SHLD	var_search_end
	LHLD	var_search_count
	SHLD	var_gap_start
	RET


;====================================================================
; EDITOR HELP AND UTILITIES (0x2A51)
;====================================================================

cmd_help:
	LXI	H,help_text
	MVI	A,0CH
	CALL	mon_char_output
j2a59:	MOV	A,M
	CPI	0CH
	JZ	j2a66
	CALL	mon_char_output
	INX	H
	JMP	j2a59
j2a66:	CALL	mon_char_input
	JMP	editor_fill_screen
copy_de_to_hl:
	LDAX	D
	INX	D
	CMP	C
	RZ
	MOV	M,A
	INX	H
	JMP	copy_de_to_hl
load_bcde_from_hl:
	MOV	B,M
	INX	H
	MOV	C,M
	INX	H
	MOV	D,M
	INX	H
	MOV	E,M
	RET

store_bcde_to_hl:
	MOV	M,E
	DCX	H
	MOV	M,D
	DCX	H
	MOV	M,C
	DCX	H
	MOV	M,B
	RET

right_justify:
	CALL	load_bcde_from_hl
	XRA	A
	CMP	B
	RZ
j2a8b:	CMP	E
	CNZ	store_bcde_to_hl
	RNZ
	MOV	E,D
	MOV	D,C
	MOV	C,B
	MVI	B,'0'
	JMP	j2a8b

;====================================================================
; ASSEMBLER (0x2A98)
;====================================================================

cmd_asmb:
	CALL	print_cr_if_listing	;ASMB command: begin assembly
	CALL	j2407
	LDA	3B61H
	ORA	A
	JNZ	j2aab
	LHLD	var_start_addr
	SHLD	var_end_addr
j2aab:	LDA	3BA0H
	STA	var_asm_option
	CPI	45H
	JNZ	j2abd
	XRA	A
	STA	var_asm_option
	LDA	3BA1H
j2abd:	CPI	53H
	JZ	j2ac7
	MVI	A,02H
	STA	var_option_byte
j2ac7:	XRA	A
asm_start:
	STA	var_asm_pass
	LXI	H,0000H
	SHLD	var_error_count
	LHLD	var_start_addr
	SHLD	var_asm_pc
	LHLD	var_buf_start
	SHLD	var_scan_ptr
asm_main_loop:
	LHLD	var_scan_ptr	;Assembler main loop: process source lines
	XCHG
	LHLD	var_buf_end
	CALL	cmp_hl_de
	JNC	asm_pass_done
	LXI	H,var_line_buf
	MVI	A,9CH
	CALL	pad_spaces
	LXI	H,input_command_buf
	MVI	C,0DH
	CALL	copy_de_to_hl
	MOV	M,C
	XCHG
	SHLD	var_scan_ptr
	LDA	var_asm_pass
	ORA	A
	JNZ	j2b0c
	CALL	j2b2e
	JMP	asm_main_loop
j2b0c:	CALL	j2c37
	LXI	H,var_line_buf
	CALL	j2b18
	JMP	asm_main_loop
j2b18:	LDA	var_asm_option
	ORA	A
	JNZ	j2b25
j2b1f:	LDA	var_line_buf
	CPI	20H
	RZ
j2b25:	LXI	H,var_line_buf
	CALL	print_cr
	JMP	print_line_with_num
j2b2e:	CALL	clear_params
	STA	var_asm_pass
	LXI	H,input_command_buf
	SHLD	var_source_ptr
	MOV	A,M
	CPI	20H
	JZ	j2bb0
	CPI	09H
	JZ	j2bb0
	CPI	3BH
	RZ
	CALL	j316e
	JC	j312d
	JZ	j330f
	CALL	j2bc7
	JNZ	j312d
	MVI	C,08H
	LXI	H,var_filename2
j2b5c:	MOV	A,M
	STAX	D
	INX	D
	INX	H
	DCR	C
	JNZ	j2b5c
	XCHG
	SHLD	var_asm_dummy
	LDA	3B72H
	MOV	M,A
	INX	H
	LDA	var_asm_pc
	MOV	M,A
	LXI	H,var_option_byte
	INR	M
	LDA	2006H
	CMP	M
	JNC	j2bb0
	CALL	print_cr
	LXI	H,str_symtab_overflow
	CALL	print_line
	JMP	cmd_loop

str_symtab_overflow:
	DB	'Symbol table overflow-assembly aborted! ',13

j2bb0:	CALL	clear_params
	CALL	parse_next_field
	JC	j3154
	CALL	parse_expression
	CPI	20H
	JC	encode_instruction
	JNZ	j3154
	JMP	encode_instruction
j2bc7:	LHLD	var_source_ptr
	MOV	A,M
	CPI	20H
	RZ
	CPI	09H
	RZ
	CPI	3AH
	RNZ
	INX	H
	SHLD	var_source_ptr
	RET

j2bd9:	CALL	parse_next_field
	LDAX	D
	CPI	07H
	RP
	ORA	A
	JZ	j2bf8
	JM	j2cd1
	JPO	j2c15
	CPI	05H
	JC	j2c2f
	JNZ	asm_pass_done
j2bf2:	MVI	C,02H
	XRA	A
	JMP	j3143
j2bf8:	CALL	parse_operand
	LDA	var_line_buf
	CPI	09H
	JZ	j2c06
	CPI	20H
	RNZ
j2c06:	SHLD	var_asm_pc
	LDA	input_command_buf
	CPI	09H
	RZ
	CPI	20H
	RZ
	JMP	j2c25
j2c15:	CALL	parse_operand
	LDA	input_command_buf
	CPI	09H
	JZ	j32ef
	CPI	20H
	JZ	j32ef
j2c25:	XCHG
	LHLD	var_asm_dummy
	MOV	M,D
	INX	H
	MOV	M,E
	JMP	j2b1f
j2c2f:	CALL	parse_operand
	MOV	B,H
	MOV	C,L
	JMP	j2ccd
j2c37:	LDA	input_command_buf
	CPI	3BH
	RZ
	LXI	H,3B8EH
	LDA	3B72H
	CALL	nibble_convert
	INX	H
	LDA	var_asm_pc
	CALL	nibble_convert
	INX	H
	SHLD	3B89H
	CALL	clear_params
	LXI	H,input_command_buf
	SHLD	var_source_ptr
	MOV	A,M
	CPI	09H
	JZ	j2bb0
	CPI	20H
	JZ	j2bb0
	CALL	j316e
	JC	j3307
	CALL	j2bc7
	JNZ	j3307
	JMP	j2bb0
j2c74:	LDAX	D
	CPI	07H
	JZ	j2c9d
	CPI	08H
	JZ	j2c9c
	CPI	09H
	JZ	cmd_symt
	ORA	A
	JZ	j2db6
	JM	j2cd1
	JPO	j2ca1
	CPI	05H
	JC	j2cc1
	JNZ	asm_pass_done
	CALL	j2e8a
	JMP	j2bf2
j2c9c:	XRA	A
j2c9d:	STA	var_asm_option
	RET

j2ca1:	CALL	j31e2
	SHLD	var_filename2
	LXI	H,2020H
	SHLD	3B8EH
	SHLD	3B90H
	LXI	H,3B93H
	LDA	3B5EH
	CALL	nibble_convert
	INX	H
	LDA	var_filename2
	CALL	nibble_convert
	RET

j2cc1:	CALL	j31e2
	MOV	B,H
	MOV	C,L
	LHLD	var_end_addr
	DAD	B
	SHLD	var_end_addr
j2ccd:	XRA	A
	JMP	j3146
j2cd1:	XRA	A
	STA	3B4CH
j2cd5:	CALL	clear_params
	CALL	parse_next_field
	JC	j2d59
	MOV	A,M
	CPI	3BH
	JZ	j2d59
	CPI	2CH
	JZ	j2d45
	CPI	27H
	JZ	j2d05
	CPI	30H
	JC	j32d7
	CPI	3AH
	JNC	j32d7
	CALL	j32b1
	JC	j32f7
	MOV	A,L
	STA	3B4CH
	JMP	j2cd5
j2d05:	LHLD	var_source_ptr
	INX	H
	SHLD	var_source_ptr
	MOV	A,M
	CPI	0DH
	JZ	j32d7
	CPI	27H
	JZ	j2d30
	PUSH	PSW
	LDA	3B4CH
	ORA	A
	JNZ	j2d26
	POP	PSW
	STA	3B4CH
	JMP	j2d05
j2d26:	CALL	j2d5a
	POP	PSW
	STA	3B4CH
	JMP	j2d05
j2d30:	LHLD	var_source_ptr
	INX	H
	SHLD	var_source_ptr
	MOV	A,M
	CPI	2CH
	JZ	j2cd5
	CPI	0DH
	JZ	j2cd5
	JMP	j32d7
j2d45:	LDA	3B4CH
	CALL	j2d5a
	XRA	A
	STA	3B4CH
	LHLD	var_source_ptr
	INX	H
	SHLD	var_source_ptr
	JMP	j2cd5
j2d59:	NOP
j2d5a:	LDA	var_asm_pass
	ORA	A
	JZ	j2d81
	LHLD	var_end_addr
	LDA	3B4CH
	MOV	M,A
	INX	H
	SHLD	var_end_addr
	PUSH	PSW
	LHLD	3B89H
	MOV	A,L
	CPI	9AH
	CP	j2d89
	POP	PSW
	LHLD	3B89H
	INX	H
	CALL	nibble_convert
	SHLD	3B89H
j2d81:	LHLD	var_asm_pc
	INX	H
	SHLD	var_asm_pc
	RET

j2d89:	LXI	H,var_line_buf
	CALL	j2b18
	LXI	H,var_line_buf
	MVI	B,0FH
	MVI	A,' '
j2d96:	MOV	M,A
	INX	H
	DCR	B
	JNZ	j2d96
	LXI	H,3B8EH
	LDA	3B72H
	CALL	nibble_convert
	INX	H
	LDA	var_asm_pc
	CALL	nibble_convert
	INX	H
	SHLD	3B89H
	MVI	A,0DH
	STA	3B9BH
	RET

j2db6:	CALL	j31e2
	LDA	var_line_buf
	CPI	09H
	JZ	j2dc4
	CPI	20H
	RNZ
j2dc4:	XCHG
	LHLD	var_asm_pc
	XCHG
	SHLD	var_asm_pc
	MOV	A,L
	SUB	E
	MOV	E,A
	MOV	A,H
	SBB	D
	MOV	D,A
	LHLD	var_end_addr
	DAD	D
	SHLD	var_end_addr
	RET

	CALL	j31e2
	CNZ	j32cf
	MOV	A,L
	ORA	A
	JZ	j2dfe
	CPI	02H
	CNZ	j32cf
	JMP	j2dfe
	CALL	j31e2
	CNZ	j32cf
	MOV	A,L
	RRC
	CC	j32cf
	RAL
	CPI	08H
	CNC	j32cf
j2dfe:	RLC
	RAL
	RAL
j2e01:	MOV	B,A
	LDAX	D
	ADD	B
	CPI	76H
	CZ	j32cf
	JMP	j2e97
	CALL	j31e2
	CNZ	j32cf
	MOV	A,L
	CPI	08H
	CNC	j32cf
	LDAX	D
	CPI	40H
	JZ	j2e2a
	CPI	0C7H
	MOV	A,L
	JZ	j2dfe
	JM	j2e01
	JMP	j2dfe
j2e2a:	DAD	H
	DAD	H
	DAD	H
	ADD	L
	STAX	D
	CALL	j2e68
	CALL	parse_operand
	CNZ	j32cf
	MOV	A,L
	CPI	08H
	CNC	j32cf
	JMP	j2e01
	CPI	06H
	CZ	j2e56
	CALL	j2e97
	CALL	j31e2
	INR	A
	CPI	02H
	CNC	j32e7
	MOV	A,L
	JMP	j2e97
j2e56:	CALL	j31e2
	CNZ	j32cf
	MOV	A,L
	CPI	08H
	CNC	j32cf
	DAD	H
	DAD	H
	DAD	H
	LDAX	D
	ADD	L
	MOV	E,A
j2e68:	LHLD	var_source_ptr
	MOV	A,M
	CPI	2CH
	INX	H
	SHLD	var_source_ptr
	JNZ	j32d7
	MOV	A,E
	RET

	CPI	01H
	JNZ	j2e87
	CALL	j2e56
	ANI	08H
	CNZ	j32cf
	MOV	A,E
	ANI	0F7H
j2e87:	CALL	j2e97
j2e8a:	CALL	j31e2
	MOV	A,L
	MOV	D,H
	CALL	j2e97
	MOV	A,D
	JMP	j2e97
	RET

j2e97:	LHLD	var_end_addr
	MOV	M,A
	INX	H
	SHLD	var_end_addr
	LHLD	3B89H
	INX	H
	CALL	nibble_convert
	SHLD	3B89H
	RET

asm_pass_done:
	LDA	var_asm_pass
	ORA	A
	JNZ	j2eb9
	CALL	print_cr
asm_list_symbol:
	MVI	A,01H
	JMP	asm_start
j2eb9:	CALL	print_cr
	CALL	print_cr
	LXI	H,too_man_str
	LDA	var_error_count+1
	ORA	A
	JNZ	j2eef
	LDA	var_error_count
	ORA	A
	JNZ	j2ede
asm_no_label:
	LXI	H,6F4EH
	SHLD	var_hex_buf
	MVI	A,0DH
	STA	var_hex_buf+2
	JMP	j2ee6
j2ede:	CALL	byte_to_decimal
	MVI	A,0DH
	STA	3B54H
j2ee6:	LXI	H,var_hex_buf
	CALL	print_line
	LXI	H,2535H
j2eef:	CALL	print_line
	JMP	j20ff

;====================================================================
; SYMBOL TABLE LISTING (0x2EF5)
;====================================================================

cmd_symt:
	CALL	print_cr
	CALL	print_cr
	LDA	var_option_byte
	LHLD	var_symbol_area
j2f01:	PUSH	PSW
	LXI	D,0008H
j2f05:	MOV	A,M
	ORA	A
	JZ	j2f16
	MOV	B,A
	CALL	mon_char_output
	INX	H
	DCR	E
	JNZ	j2f05
	JMP	j2f1e
j2f16:	CALL	print_space
	INX	H
	DCR	E
	JNZ	j2f16
j2f1e:	CALL	print_space
	MOV	A,M
	XCHG
	CALL	print_hex_byte
	XCHG
	INX	H
	MOV	A,M
	XCHG
	CALL	print_hex_byte
	XCHG
	INX	H
	CALL	print_space
	CALL	print_space
	CALL	print_space
	POP	PSW
	DCR	A
	JNZ	j2f01
	JMP	j20ff

;====================================================================
; ASSEMBLER PARSING AND LOOKUP (0x2F40)
;====================================================================

parse_next_field:
	LHLD	var_source_ptr
j2f43:	MOV	A,M
	CPI	09H
	JZ	skip_to_field_end
	CPI	20H
	JZ	skip_to_field_end
	RET

skip_to_field_end:
	INX	H
	SHLD	var_source_ptr
	JMP	j2f43
j2f56:	LXI	H,3B5EH
	SHLD	var_hex_buf
	MVI	B,02H
lookup_mnemonic:
	CALL	mnemonic_search
	RET


; === Start of asm_directive_tbl ===
directive_table:
	DB	4FH	;Assembler directive table: ORG, LON, ENDS, LOFF, EQU, DB, DS, DW, END
	DB	52H,47H,00H,00H,4CH,4FH,4EH,00H
	DB	07H,45H,4EH,44H,53H,09H,4CH,4FH
	DB	46H,46H,08H,45H,51H,55H,00H,01H
	DB	44H,42H,00H,00H,0FFH,44H,53H,00H
	DB	00H,03H,44H,57H,00H,00H,05H,45H
	DB	4EH,44H,00H
; === End of asm_directive_tbl ===


; === Start of asm_mnemonic_tbl ===
mnemonic_table:
	DB	06H	;8080 instruction mnemonic table
	DB	00H,48H,4CH,54H,76H,52H,4CH,43H
	DB	07H,52H,52H,43H,0FH,52H,41H,4CH
	DB	17H,52H,41H,52H,1FH,52H,45H,54H
	DB	0C9H,43H,4DH,41H,2FH,53H,54H,43H
	DB	37H,4BH,49H,4CH,0C7H,44H,41H,41H
	DB	27H,43H,4DH,43H,3FH,53H,56H,43H
	DB	0FFH,45H,49H,00H,0FBH,44H,49H,00H
	DB	0F3H,4EH,4FH,50H,00H,00H,58H,43H
	DB	48H,47H,0EBH,58H,54H,48H,4CH,0E3H
	DB	53H,50H,48H,4CH,0F9H,50H,43H,48H
	DB	4CH,0E9H,00H,53H,54H,41H,58H,02H
	DB	4CH,44H,41H,58H,0AH,00H,50H,55H
	DB	53H,48H,0C5H,50H,4FH,50H,00H,0C1H
	DB	49H,4EH,58H,00H,03H,44H,43H,58H
	DB	00H,0BH,44H,41H,44H,00H,09H,00H
	DB	49H,4EH,52H,04H,44H,43H,52H,05H
	DB	4DH,4FH,56H,40H,41H,44H,44H,80H
	DB	41H,44H,43H,88H,53H,55H,42H,90H
	DB	53H,42H,42H,98H,41H,4EH,41H,0A0H
	DB	58H,52H,41H,0A8H,4FH,52H,41H,0B0H
	DB	43H,4DH,50H,0B8H,00H,41H,44H,49H
	DB	0C6H,41H,43H,49H,0CEH,53H,55H,49H
	DB	0D6H,53H,42H,49H,0DEH,41H,4EH,49H
	DB	0E6H,58H,52H,49H,0EEH,4FH,52H,49H
	DB	0F6H,43H,50H,49H,0FEH,49H,4EH,00H
	DB	0DBH,4FH,55H,54H,0D3H,4DH,56H,49H
	DB	06H,00H,4AH,4DH,50H,00H,0C3H,43H
	DB	41H,4CH,4CH,0CDH,4CH,58H,49H,00H
	DB	01H,4CH,44H,41H,00H,3AH,53H,54H
	DB	41H,00H,32H,53H,48H,4CH,44H,22H
	DB	4CH,48H,4CH,44H,2AH,00H,4EH,5AH
	DB	00H,5AH,00H,08H,4EH,43H,10H,43H
	DB	00H,18H,50H,4FH,20H,50H,45H,28H
	DB	50H,00H,30H,4DH,00H,38H,00H
; === End of asm_mnemonic_tbl ===


;====================================================================
; INSTRUCTION ENCODING (0x309E)
;====================================================================

mnemonic_search:
	LHLD	var_hex_buf	;Mnemonic search routine
	LDAX	D
	ORA	A
	JZ	mnemonic_found
	MOV	C,B
	CALL	strcmp
	LDAX	D
	RZ
	INX	D
	JMP	mnemonic_search
mnemonic_found:
	INR	A
	INX	D
	RET

encode_instruction:
	LXI	H,var_filename2	;Instruction encoding and output
	SHLD	var_hex_buf
	LXI	D,directive_table
	MVI	B,04H
	CALL	mnemonic_search
	JZ	j315c
	DCR	B
	CALL	mnemonic_search
	JZ	j30cf
	INR	B
	CALL	mnemonic_search
j30cf:	LXI	H,j2e97
j30d2:	MVI	C,01H
	JZ	j312f
	CALL	mnemonic_search
	LXI	H,2DDAH
	JZ	j30d2
	CALL	mnemonic_search
	LXI	H,2DEDH
	JZ	j30d2
	DCR	B
	CALL	mnemonic_search
	LXI	H,2E0CH
	JZ	j30d2
	CALL	mnemonic_search
	LXI	H,2E41H
	MVI	C,02H
	JZ	j312f
	INR	B
	CALL	mnemonic_search
	JZ	j312a
	CALL	j2f56
	JNZ	j3154
	ADI	0C0H
	MOV	D,A
	MVI	B,03H
	LDA	var_filename2
	MOV	C,A
	CPI	52H
	MOV	A,D
	JZ	j30cf
	MOV	A,C
	INR	D
	INR	D
	CPI	4AH
	JZ	j3129
	CPI	43H
	JNZ	j3154
	INR	D
	INR	D
j3129:	MOV	A,D
j312a:	LXI	H,2E77H
j312d:	MVI	C,03H
j312f:	STA	3B84H
	MVI	A,5DH
	ADD	B
	MOV	E,A
	MVI	A,3BH
	ACI	00H
	MOV	D,A
	LDAX	D
	ORA	A
	JNZ	j3154
j3140:	LDA	var_asm_pass
j3143:	MVI	B,00H
	XCHG
j3146:	LHLD	var_asm_pc
	DAD	B
	SHLD	var_asm_pc
	ORA	A
	RZ
	LDA	3B84H
	XCHG
	PCHL
j3154:	LXI	H,32FFH
	MVI	C,03H
	JMP	j3140
j315c:	LXI	H,3B61H
	MOV	A,M
	ORA	A
	JNZ	j3154
	LDA	var_asm_pass
	ORA	A
	JZ	j2bd9
	JMP	j2c74
j316e:	CPI	41H
	RC
	CPI	5BH
	CMC
	RC
	CALL	parse_expression
	LXI	H,var_filename2
	SHLD	var_hex_buf
	DCR	B
	JNZ	j3192
	INR	B
	LXI	D,31B0H
	CALL	mnemonic_search
	JNZ	j3192
	MOV	L,A
	MVI	H,00H
	JMP	j31aa
j3192:	LDA	var_option_byte
	MOV	B,A
	XCHG
	LHLD	var_symbol_area
	XCHG
	ORA	A
	JZ	j31ad
	MVI	A,08H
	STA	var_cmd_name_len
	CALL	cmd_match_loop
	MOV	C,H
	MOV	H,L
	MOV	L,C
j31aa:	STC
	CMC
	RET

j31ad:	INR	A
	ORA	A
	RET

	MOV	B,C
	RLC
	MOV	D,B
	MVI	B,42H
	NOP
	MOV	B,E
	LXI	B,0244H
	MOV	B,L
	INX	B
	MOV	C,B
	INR	B
	MOV	C,H
	DCR	B
	MOV	C,L
	MVI	B,00H

;====================================================================
; EXPRESSION PARSER (0x31C3)
;====================================================================

parse_expression:
	MVI	B,00H
j31c5:	STAX	D
	INR	B
	MOV	A,B
	CPI	0BH
	RNC
	INX	D
	INX	H
	SHLD	var_source_ptr
	MOV	A,M
	CPI	30H
	RC
	CPI	3AH
	JC	j31c5
	CPI	41H
	RC
	CPI	5BH
	JC	j31c5
	RET

j31e2:	CALL	parse_next_field
parse_operand:
	LXI	H,0000H
	SHLD	var_free_bytes
	INR	H
	SHLD	3B82H
j31ef:	LHLD	var_source_ptr
	DCX	H
	CALL	clear_params
	STA	3B7CH
j31f9:	INX	H
	MOV	A,M
	CPI	20H
	JC	j32a1
	CPI	2CH
	JZ	j32a1
	CPI	2BH
	JZ	j3212
	CPI	2DH
	JNZ	j3222
	STA	3B7CH
j3212:	LDA	3B83H
	CPI	02H
	JZ	j32d7
	MVI	A,02H
	STA	3B83H
	JMP	j31f9
j3222:	MOV	C,A
	LDA	3B83H
	ORA	A
	JZ	j32d7
	MOV	A,C
	CPI	24H
	JNZ	j323a
	INX	H
	SHLD	var_source_ptr
	LHLD	var_asm_pc
	JMP	j3276
j323a:	CPI	27H
	JNZ	j3266
	LXI	D,0000H
	MVI	C,03H
j3244:	INX	H
	SHLD	var_source_ptr
	MOV	A,M
	CPI	0DH
	JZ	j32f7
	CPI	27H
	JNZ	j325d
	INX	H
	SHLD	var_source_ptr
	MOV	A,M
	CPI	27H
	JNZ	j3277
j325d:	DCR	C
	DB	0CAH,0CAH

;====================================================================
; CODE GENERATION (0x3260)
;====================================================================

emit_byte:
	STA	5F53H
	JMP	j3244
j3266:	CPI	'0'
	JC	j32f7
	CPI	'9'+1
	JNC	j3295
	CALL	j32b1
	JC	j32f7
j3276:	XCHG
j3277:	LHLD	var_free_bytes
	XRA	A
	STA	3B83H
	LDA	3B7CH
	ORA	A
	JNZ	j328c
	DAD	D
j3286:	SHLD	var_free_bytes
	JMP	j31ef
j328c:	MOV	A,L
	SUB	E
	MOV	L,A
	MOV	A,H
emit_word:
	SBB	D
	MOV	H,A
	JMP	j3286
j3295:	CALL	j316e
	JZ	j3276
	JC	j32f7
	JMP	j32df
j32a1:	LDA	3B83H
	ORA	A
	JNZ	j32d7
	LHLD	var_free_bytes
j32ab:	MOV	A,H
	LXI	D,3B84H
	ORA	A
	RET

j32b1:	CALL	parse_expression
	DCX	D
	LDAX	D
	LXI	B,var_filename2
	CPI	'H'
	JZ	j32c9
	CPI	'D'
	JNZ	j32c5
	XRA	A
	STAX	D
j32c5:	CALL	parse_decimal
encode_register:
	RET

j32c9:	XRA	A
	STAX	D
	CALL	parse_hex
	RET

j32cf:	MVI	B,'R'
	LXI	H,j3324
	JMP	j3317
j32d7:	MVI	B,'S'
	LXI	H,j3328
	JMP	j3317
j32df:	MVI	B,'U'
	LXI	H,j3328
	JMP	j3317
j32e7:	MVI	B,'V'
	LXI	H,j3328
	JMP	j3317
j32ef:	MVI	B,'M'
	LXI	H,j332e
	JMP	j3317
j32f7:	MVI	B,'A'
	LXI	H,j3328
	JMP	j3317
	MVI	B,'O'
	LXI	H,j3332
	JMP	j3317
j3307:	MVI	B,'L'
	LXI	H,j3332
	JMP	j3317
j330f:	MVI	B,'D'
	LXI	H,j3342
	JMP	j3317
j3317:	PUSH	H
	LXI	H,var_line_buf
	MOV	M,B
	LHLD	var_error_count
	INX	H
	SHLD	var_error_count
	RET

j3324:
	LXI	H,0000H
	RET

j3328:
	LXI	H,0000H
	JMP	j32ab
j332e:
	CALL	j2b25
	RET

j3332:
	LDA	var_asm_pass
	ORA	A
	RZ
	MVI	C,03H
	XRA	A
	CALL	j2e97
	DCR	C
	DB	0C2H,0C2H
tape_input:
	INX	SP
	RET

j3342:
	CALL	j2b18
	JMP	j2bb0
j3348:
	IN	01H
	RAR
	JC	j335e
	RAR
	JNC	mon_warm_start
	IN	00H
	LXI	H,0C0AH
	MVI	M,00H
	INX	H
	MOV	M,A
	JMP	mon_warm_start
j335e:	LXI	H,0C08H
	MOV	A,M
	ORA	A
	JZ	j336d
	MVI	A,0E6H
	OUT	00H
	JMP	mon_warm_start
j336d:	MVI	M,01H
	INX	H
	MOV	A,M
	OUT	00H
	DB	0C3H,0C3H
tape_output:
	NOP
	CALL	j360b
	RET

	CALL	j35fa
	RET


;====================================================================
; TAPE I/O (0x337E)
;====================================================================

cmd_load:
	LXI	H,33E5H	;LOAD command: load file from tape
	PUSH	H
	LXI	H,j34af
	SHLD	var_kbd_vector
j3388:	LXI	H,j3348
	SHLD	0C16H
	LXI	H,3376H
	LXI	D,WH2
	MVI	B,08H
j3396:	MOV	A,M
	STAX	D
	INX	H
	INX	D
	DCR	B
	JNZ	j3396
	LXI	H,0000H
	SHLD	0C08H
	SHLD	0C0AH
	CALL	cmd_soft
	CALL	parse_cmd_line
	LDA	3BA0H
	CPI	'B'
	JZ	j33bd
	CPI	'P'
	JZ	j33c6
	JMP	error_bad_params
j33bd:	CALL	j02ad
	MVI	B,0AAH
	MOV	B,B
	ACI	00H
	RET

j33c6:	CALL	j02ad
	MVI	B,0AAH
	MOV	B,B
	INR	C
	ANI	0E6H
	NOP
	RET

j33d1:	MVI	B,00H
tape_byte_out:
	CALL	WH2
	STAX	D
	INX	D
	PUSH	PSW
	ADD	B
	MOV	B,A
	POP	PSW
	DCR	C
	JNZ	tape_byte_out
	CALL	WH2
	ADD	B
	RET

	DB	0CDH
tape_file_open:
	MOV	B,C
	LXI	H,2821H
	DCR	M
	CALL	print_line
	CALL	print_cr
j33f1:	MVI	A,96H
	OUT	01H
	CALL	WH2
j33f8:	CPI	0E6H
	JNZ	j33f1
	CALL	WH2
	CPI	01H
	JNZ	j33f8
	LXI	D,0C60H
	MVI	C,0EH
	CALL	j33d1
	JNZ	j3497
	LXI	D,0C60H
	LXI	H,var_filename1
	MVI	C,08H
j3418:	LDAX	D
	CMP	M
	JNZ	j343c
	INX	H
	INX	D
	DCR	C
	JNZ	j3418
	LDA	0C6AH
	MOV	C,A
	LDA	0C6DH
	CPI	04H	; Data
	JZ	j3452
	CPI	02H	; End
	JZ	j34af
	CPI	01H	; Comment
	JZ	j3445
	JMP	j33f1
j343c:	CALL	j347c
	CALL	print_cr
	JMP	j33f1
j3445:	CALL	WH2
	CALL	mon_char_output
	DCR	C
	JNZ	j3445
	JMP	j33f1
j3452:	LHLD	var_buf_end
	XCHG
	CALL	j33d1
	XCHG
	JNZ	j3497
	XCHG
	LHLD	var_mem_top
	CALL	cmp_hl_de
	JP	j348b
	XCHG
	MVI	M,0DH
	SHLD	var_buf_end
	CALL	j347c
	LDA	0C68H
	CALL	print_decimal
	CALL	print_cr
	JMP	j33f1
j347c:	MVI	E,08H
	LXI	H,0C60H
j3481:	MOV	A,M
	CALL	mon_char_output
	INX	H
	DCR	E
	JNZ	j3481
	RET

j348b:	LXI	H,mem_full_str
	CALL	print_line
	CALL	print_cr
	JMP	j34af
j3497:	MVI	M,7FH
	INX	H
	SHLD	var_buf_end
	CALL	print_cr
	LXI	H,2461H
	CALL	print_line
	CALL	print_cr
	CALL	mon_char_input
	JMP	j33f1
j34af:	XRA	A
	OUT	01H
	LXI	H,j20ff
	PUSH	H
	JMP	cmd_loop
j34b9:	LHLD	var_buf_start
	MOV	D,H
	MOV	E,L
	MVI	A,0DH
j34c0:	CMP	M
	INX	H
	JNZ	j34c0
	CALL	sub_hl_de
	MOV	A,L
	STA	0C6AH
	XCHG
	SHLD	0C70H
	MVI	A,01H
	STA	0C6DH
	CALL	j358e
	LXI	H,0000H
	SHLD	0C6BH
	SHLD	0C68H
	CALL	j361a
	RET

cmd_dump:
	LXI	H,j34af	;DUMP command: hex dump memory
	SHLD	var_kbd_vector
	CALL	j3388
	LXI	H,3533H
	CALL	print_string
	CALL	j03aa
	PUSH	H
	LXI	H,str_start_addr
	CALL	print_string
	CALL	j03aa
	SHLD	3B4FH
	CALL	print_cr
	LXI	H,str_working_start
	CALL	print_line
	CALL	print_space
	CALL	j34b9
	POP	H
	SHLD	0C6BH
	XRA	A
	STA	0C6DH
	LHLD	var_start_addr
	SHLD	0C70H
	XCHG
	LHLD	var_end_addr
	DB	0C3H,0C3H
	DCR	M

;Working... message
str_working_start:
	DB	'Working...',13,13

;Load address? prompt
str_load_addr:
	DB	'Load address? ',0

str_start_addr:
;Start address? prompt
	DB	13,'Start address? ',0

cmd_save:
	LXI	H,j34af	;SAVE command: save file to tape
	SHLD	var_kbd_vector
	CALL	j3388
	CALL	print_cr
	LXI	H,str_working_start
	CALL	print_line
	CALL	print_cr
	CALL	j34b9
	MVI	A,04H
	STA	0C6DH
	LXI	H,0000H
	SHLD	0C6BH
	LHLD	var_buf_start
	SHLD	0C70H
	XCHG
	LHLD	var_buf_end
	CALL	sub_hl_de
	INX	H
	SHLD	0C6EH
	CALL	j358e
	JMP	j359f
j358e:	MVI	B,08H
	LXI	H,0C60H
	LXI	D,var_filename1
j3596:	LDAX	D
	MOV	M,A
	INX	H
	INX	D
	DCR	B
	JNZ	j3596
	RET

j359f:	LHLD	0C6EH
	MOV	A,H
	ORA	A
	JZ	j35c1
	LXI	D,0100H
	CALL	sub_hl_de
	SHLD	0C6EH
	XRA	A
	STA	0C6AH
	CALL	j361a
	LHLD	0C6BH
	INR	H
	SHLD	0C6BH
	JMP	j359f
j35c1:	MOV	A,L
	STA	0C6AH
	CALL	j361a
	MVI	A,01H
	STA	0C6AH
	MVI	A,03H
	STA	0C6DH
	LHLD	3B4FH
	SHLD	0C6BH
	CALL	j361a
	MVI	A,02H
	STA	0C6DH
	JMP	j361a
j35e3:	MVI	B,00H
	MOV	C,A
j35e6:	MOV	A,M
	INX	H
	PUSH	PSW
	ADD	B
	MOV	B,A
	POP	PSW
	CALL	WH3
	DCR	C
	JNZ	j35e6
	MOV	A,B
	CMA
	INR	A
	CALL	WH3
	RET

j35fa:	PUSH	H
	LXI	H,0C08H
	PUSH	PSW
j35ff:	MOV	A,M
	ORA	A
	JZ	j35ff
	MVI	M,00H
	INX	H
	POP	PSW
	MOV	M,A
	POP	H
	RET

j360b:	PUSH	H
	LXI	H,0C0AH
j360f:	MOV	A,M
	ORA	A
	JNZ	j360f
	MVI	M,01H
tape_status_setup:
	INX	H
	MOV	A,M
	POP	H
	RET

j361a:	MVI	A,21H
	OUT	01H
	LDA	0C68H
	CALL	print_decimal
	CALL	print_cr
	LXI	H,1FFFH
j362a:	DCX	H
	MOV	A,H
	ORA	A
	JNZ	j362a
	MVI	C,20H
j3632:	MVI	A,0E6H
	CALL	WH3
	DCR	C
	JNZ	j3632
	MVI	A,01H
	CALL	WH3
	MVI	A,0EH
	LXI	H,0C60H
	CALL	j35e3
	LDA	0C6AH
	LHLD	0C70H
	CALL	j35e3
	LHLD	0C70H
	INR	H
	SHLD	0C70H
	LHLD	0C68H
	INX	H
	SHLD	0C68H
	CALL	WH3
	CALL	WH3
	CALL	WH3
	XRA	A
	OUT	01H
	RET

tape_char_io:
	PUSH	H
	PUSH	PSW
	DI
	CPI	0CH
	JZ	j369c
	CPI	0DH
	JNZ	j36c7
	CALL	j36c5
	LDA	L2009
	MOV	L,A
	LDA	L2008
j3683:	CALL	j36c5
	DCR	L
	JNZ	j3683
	LDA	L200EH
	CALL	j36c5
	LDA	var_print_ctrl
	DCR	A
	STA	var_print_ctrl
	JNZ	j36f6
	MVI	A,0CH
j369c:	CALL	j36c5
	LDA	var_print_ctrl
	MOV	L,A
	LDA	L200C
	STA	var_print_ctrl
	MOV	A,L
	ORA	A
	JNZ	j36b4
	LDA	L200B
	JMP	j36b7
j36b4:	LDA	L200A
j36b7:	MOV	L,A
	LDA	L200D
j36bb:	CALL	j36c5
	DCR	L
	JNZ	j36bb
	JMP	j36f6
j36c5:	PUSH	H
	PUSH	PSW
j36c7:	ORA	A
	JZ	j36f6
	LDA	var_error_flag
	ORA	A
	JNZ	j36e4
	MVI	A,01H
	STA	var_error_flag
	CALL	j200f
	LXI	H,36F9H
	SHLD	0C16H
	MVI	A,27H
	OUT	01H
j36e4:	POP	PSW
	PUSH	PSW
	ANI	7FH
	STA	3B2EH
	STA	3B2DH
	EI
j36ef:	LDA	3B2DH
	ORA	A
	JNZ	j36ef
j36f6:	POP	PSW
	POP	H
	RET

	LDA	3B2DH
	ORA	A
	JNZ	j3718
	LDA	3B2EH
	ORA	A
	JZ	j3710
	XRA	A
	STA	3B2EH
	OUT	00H
	JMP	mon_warm_start
j3710:	STA	var_error_flag
	OUT	01H
	JMP	mon_warm_start
j3718:	XRA	A
	STA	3B2DH
	LDA	3B2EH
	OUT	00H
	JMP	mon_warm_start

; === Start of screen_header ===

;====================================================================
; SCREEN TEMPLATE AND VIDEO MEMORY (0x3724)
;====================================================================

screen_template:
	DB	0D0H	;Screen header template (high-bit ASCII)
	DB	0EFH,0ECH,0F9H,0CDH,0EFH,0F2H,0F0H,0E8H
	DB	0E9H,0E3H,0F3H,0A0H,0C7H,0B0H,0B2H,0A0H
	DB	0CDH,0EFH,0EEH,0E9H,0F4H,0EFH,0F2H,0AFH
	DB	0C5H,0E4H,0E9H,0F4H,0EFH,0F2H,0A0H,0A0H
	DB	0B8H,0CBH,0A0H,0A0H,0D3H,0E8H,0EFH,0F2H
	DB	0F4H,0A0H,0D3H,0F9H,0EDH,0E2H,0EFH,0ECH
	DB	0A0H,0D4H,0E1H,0E2H,0ECH,0E5H,7FH
; === End of screen_header ===


; === Start of video_fill_7f ===
	DB	7FH	;Video fill: 72 bytes of 0x7F (cursor/border area)
	DB	7FH,7FH,7FH,7FH,7FH,7FH,7FH,7FH
	DB	7FH,7FH,7FH,7FH,7FH,7FH,7FH,7FH
	DB	7FH,7FH,7FH,7FH,7FH,7FH,7FH,7FH
	DB	7FH,7FH,7FH,7FH,7FH,7FH,7FH,7FH
	DB	7FH,7FH,7FH,7FH,7FH,7FH,7FH,7FH
	DB	7FH,7FH,7FH,7FH,7FH,7FH,7FH,7FH
	DB	7FH,7FH,7FH,7FH,7FH,7FH,7FH,7FH
	DB	7FH,7FH,7FH,7FH,7FH,7FH,7FH,7FH
	DB	7FH,7FH,7FH,7FH,7FH,7FH,7FH
; === End of video_fill_7f ===


; === Start of video_fill_a0 ===
	DB	0A0H	;Video fill: 896 bytes of 0xA0 (blank screen, space with high bit)
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
	DB	0A0H,0A0H,0A0H,0A0H,0A0H,0A0H,0A0H
; === End of video_fill_a0 ===


; === Start of ram_variables ===

;====================================================================
; RAM VARIABLES (0x3B24)
;====================================================================

var_cmd_prompt:
	DB	2AH	;Start of RAM variable area
var_buf_start:
	DB	0ADH,3DH
var_buf_end:
	DB	0E5H,3DH
var_print_ctrl:
	DB	3FH
var_listing_flag:
	DB	00H
var_pass_flag:
	DB	00H
var_error_flag:
	DB	00H,00H,00H,00H,00H,00H
var_kbd_handler_id:
	DB	7DH
var_kbd_vector:
	DB	0AFH,34H
var_mem_top:
	DB	0FFH,3FH,00H
var_text_end:
	DB	0FFH,3FH
var_display_start:
	DB	0ADH,3DH
var_cursor_pos:
	DB	80H,00H
var_screen_offset:
	DB	40H,00H
var_gap_start:
	DB	0E6H,3DH
var_gap_end:
	DB	0FFH,3FH
var_search_count:
	DB	00H,00H
var_video_base:
	DB	00H,0F8H
var_search_ptr:
	DB	00H,00H
var_search_end:
	DB	00H,00H,00H
var_saved_sp:
	DB	0F6H,0FH,00H,20H
var_hex_buf:
	DB	30H,32H,38H,00H
var_filename1:
	DB	41H,53H,4DH,20H,20H,20H,20H,20H
var_filename2:
	DB	32H,30H,30H,30H,33H,44H,31H,35H
	DB	00H,00H,00H,00H
var_start_addr:
	DB	00H,20H
var_end_addr:
	DB	15H,3DH
var_line_counter:
	DB	0EH,00H
var_asm_dummy:
	DB	00H,00H
var_asm_pc:
	DB	00H,00H
var_asm_pass:
	DB	00H
var_error_count:
	DB	00H,00H
var_cmd_name_len:
	DB	04H
var_source_ptr:
	DB	0B1H,3BH,00H,00H
var_option_byte:
	DB	00H,00H
var_free_bytes:
	DB	1AH,02H,00H,00H,00H,00H,00H,00H
var_scan_ptr:
	DB	00H,00H
var_asm_option:
	DB	00H,00H,00H,00H,00H
var_line_buf:
	DB	00H,00H,00H,00H,00H,00H,00H,00H
	DB	00H,00H,00H,00H,00H,00H,00H,00H
input_command_buf:
	DB	44H	;Command input buffer
	DB	55H,4DH,50H,50H,20H,2FH,41H,53H
	DB	4DH,2FH,20H,32H,30H,30H,30H,20H
	DB	33H,44H,31H,35H,0DH,00H,00H,00H
	DB	00H,00H,00H,00H,00H,00H,00H,00H
	DB	00H,00H,00H,00H,00H,00H,00H,00H
	DB	00H,00H,00H,00H,00H,00H,00H,00H
	DB	00H,00H,00H,00H,00H,00H,00H,00H
	DB	00H,00H,00H,00H,00H,00H,00H,00H
	DB	00H,00H,00H,00H,00H,00H,00H,00H
	DB	00H,00H,00H,00H,00H,00H,00H,00H
	DB	00H,00H,00H,00H,00H,00H,00H,00H
	DB	00H,00H,00H,00H,00H,00H,00H,00H
	DB	00H,00H,00H,00H,00H,00H,00H,00H
	DB	00H,00H,00H,00H,00H,00H,00H,00H
	DB	00H,00H,00H,00H,00H,00H,00H,00H
	DB	00H,00H,00H,00H,00H,00H,00H,00H
	DB	00H,00H,00H,00H,00H,00H,00H,00H
	DB	00H,00H,00H,00H,00H,00H,00H,00H
	DB	00H,00H,00H,00H,00H,00H,00H,00H
	DB	00H,00H,00H,00H,00H,00H,00H,00H
	DB	00H,00H,00H,00H,00H,00H,00H,00H
	DB	00H,00H,00H,00H,00H,00H,00H,00H
	DB	00H,00H,00H,00H,00H,00H,00H,00H
	DB	00H,00H,00H,00H,00H,00H,00H,00H
	DB	00H,00H,00H,00H,00H,00H,00H,00H
	DB	00H,00H,00H,00H,00H,00H,00H,00H
	DB	00H,00H,00H,00H,00H,00H,00H,00H
	DB	00H,00H,00H,00H,00H,00H,00H,00H
	DB	00H,00H,00H,00H,00H,00H,00H,00H
	DB	00H,00H,00H,00H,00H,00H,00H,00H
	DB	00H,00H,00H,00H,00H,00H,00H,00H
	DB	00H,00H,00H,00H,00H,00H,00H,00H
	DB	00H,00H,00H,00H,00H,00H,00H,00H
	DB	00H,00H,00H,00H,00H,00H,00H,00H
	DB	00H,00H,00H,00H,00H,00H,00H,00H
	DB	00H,00H,00H,00H,00H,00H,00H,00H
	DB	00H,00H,00H,00H,00H,00H,00H,00H
	DB	00H,00H,00H,00H,00H,00H,00H,00H
	DB	00H,00H,00H,00H,00H,00H,00H,00H
	DB	00H,00H,00H,00H,00H,00H,00H,00H
	DB	00H,00H,00H,00H,00H,00H,00H,00H
	DB	00H,00H,00H,00H,00H,00H,00H,00H
	DB	00H,00H,00H,00H,00H,00H,00H,00H
	DB	00H,00H,00H,00H,00H,00H,00H,00H
	DB	00H,00H,00H
var_symbol_area:
	DB	02H	;Symbol table storage area
	DB	3DH,50H,53H,57H,00H,00H,00H,00H
	DB	00H,00H,06H,53H,50H,00H,00H,00H
	DB	00H,00H,00H,00H,06H
; === End of ram_variables ===
;
;====================================================================
; RAM VARIABLE ADDRESS MAP
;====================================================================
; var_cmd_prompt		EQU	3B24H
; var_buf_start			EQU	3B25H
; var_buf_end			EQU	3B27H
; var_print_ctrl		EQU	3B29H
; var_listing_flag		EQU	3B2AH
; var_pass_flag			EQU	3B2BH
; var_error_flag		EQU	3B2CH
; var_kbd_handler_id		EQU	3B32H
; var_kbd_vector		EQU	3B33H
; var_mem_top			EQU	3B35H
; var_text_end			EQU	3B38H
; var_display_start		EQU	3B3AH
; var_cursor_pos		EQU	3B3CH
; var_screen_offset		EQU	3B3EH
; var_gap_start			EQU	3B40H
; var_gap_end			EQU	3B42H
; var_search_count		EQU	3B44H
; var_video_base		EQU	3B46H
; var_search_ptr		EQU	3B48H
; var_search_end		EQU	3B4AH
; var_saved_sp			EQU	3B4DH
; var_hex_buf			EQU	3B51H
; var_filename1			EQU	3B55H
; var_filename2			EQU	3B5DH
; var_start_addr		EQU	3B69H
; var_end_addr			EQU	3B6BH
; var_line_counter		EQU	3B6DH
; var_asm_dummy			EQU	3B6FH
; var_asm_pc			EQU	3B71H
; var_asm_pass			EQU	3B73H
; var_error_count		EQU	3B74H
; var_cmd_name_len		EQU	3B76H
; var_source_ptr		EQU	3B77H
; var_option_byte		EQU	3B7BH
; var_free_bytes		EQU	3B7DH
; var_scan_ptr			EQU	3B85H
; var_asm_option		EQU	3B87H
; var_line_buf			EQU	3B8CH
; input_command_buf			EQU	3B9CH
; var_symbol_area		EQU	3D00H

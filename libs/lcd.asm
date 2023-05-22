/*
 * lcd.asm
 *
 *  Created: 5/21/2023 4:00:13 PM
 *   Author: Edouard
 */ 

.include "libs/printf.asm"


.macro	PRINT_ERROR
		rcall		LCD_clear
		PRINTF		LCD_putc
.db		"Error", LF, CR, 0
		.endmacro


.macro	LCD_PRINT
		rcall		LCD_clear
		PRINTF		LCD_putc
		.endmacro

.equ	PRINTABLE_LEN = 16
.equ	PRINT_SPEED = 200
; string addr in z, number of cycles in r16
circular_print:
		mov			r24,		zl
		mov			r25,		zh
		clr			r22								; r22 = cycle counter
		rcall		strslen							; r23 = len(z)
circular_print_loop_pre:							; this loop is for printing multiple cycles
		clr			r17								; r17 = current start position
circular_print_loop:								; this loop is for printing 1 entire cycle
		push		r16
		push		r17
		push		r22
		push		r23
		push		r24
		push		r25
		rcall		LCD_clear
		pop			r25
		pop			r24
		pop			r23
		pop			r22
		pop			r17
		pop			r16

		clr			r19								; r19 = current index
		mov			zl,			r24
		mov			zh,			r25
		add			zl,			r17					; increment the address of the string
		adc			zh,			r19					; r19 = 0 => zh = 0 + C (carry flag)
circular_print_loop_puts:							; this loop is for 1 screen print
		lpm			r21,		z					; load content of z into r21
		cpi			r19,		PRINTABLE_LEN		; check that index of next char to be printed is less than PRINTABLE_LEN
		brge		circular_print_loop_puts_done	; break from this loop if it is the case
		mov			a0,			r21					; copy content of r21 into a0
		tst			r21								; check if r21 = '\0'
		breq		circular_print_loop_puts_done	; break from this loop if it is the case
		
		push		r16
		push		r17
		push		r18
		push		r19
		push		r20
		push		r21
		push		r22
		push		r23
		push		r24
		push		r25
		rcall		LCD_putc						; print the char
		pop			r25
		pop			r24
		pop			r23
		pop			r22
		pop			r21
		pop			r20
		pop			r19
		pop			r18
		pop			r17
		pop			r16
		
		adiw		z,			1					; increment z pointer
		inc			r19								; increment the current index in the string
		rjmp		circular_print_loop_puts		; continue printing characters
circular_print_loop_puts_done:
		push		r16
		push		r17
		push		r22
		push		r23
		push		r24
		push		r25
		WAIT_MS		PRINT_SPEED						; wait before "sliding" the text
		pop			r25
		pop			r24
		pop			r23
		pop			r22
		pop			r17
		pop			r16

		inc			r17								; increment the starting position
		cp			r17,		r23					; check if string has done the entire cycle
		breq		circular_print_loop_done		; if it is the case, start again from the beginning
		rjmp		circular_print_loop
circular_print_loop_done:
		inc			r22
		cp			r22,		r16					; check if we have reached the max number of cycles
		brge		circular_print_ret
		jmp			circular_print_loop_pre
circular_print_ret:
		rcall		LCD_clear
		ret
		


strslen:											; returns the string length (z) in reg r23
		clr			r23
strlen_tst:
		lpm			r17,		z
		tst			r17
		breq		strstrlen_ret
		inc			r23
		adiw		z,			1
		rjmp		strlen_tst
strstrlen_ret:
		ret

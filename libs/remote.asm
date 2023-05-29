; ===================================================================================
; file		remote.asm
; purpose	offer routines for the remote (IR Controller)
; target	ATmega128L-4MHz-STK300
; authors	Edouard Michelin, Elena Dick
; ===================================================================================

.equ		REMOTE_MAX_DIGITS = 2
.equ		WAITING_TIME_BETWEEN_PRESSES = 400

; === Remote_wait_for_ok ============================================================
; purpose	wait for the user to press the OK button on the remote
; ===================================================================================
Remote_wait_for_ok:
IRC_STOP_REG_CLEAR
			rcall			IRC_get_value
			cpi				a0,					BTN_OK
			brne			Remote_wait_for_ok
			ret			


; === Remote_read_dec_until_ok ======================================================
; purpose	read the decimal number input by the user on the remote (0..99) until the OK button is pressed
;			and display each pressed number on the LCD screen
; out:		a	returned value ranges from 0 to 99
;				high(a) can therefore be ignored
; note		Even if REMOTE_MAX_DIGITS > 2, the routine will not be able to handle values above 2^8
;			but is written such that there are not too many things to modify in case someone upgrades it in the future
; ===================================================================================		
Remote_read_dec_until_ok:
			IRC_STOP_REG_CLEAR
			CLR2			b1,b0									; b = temp output value
			clr				r16										; r16 = loop counter/digit counter
Remote_read_dec_until_ok_loop:
			GOTO_IIRCSS		Remote_read_dec_until_ok_err			; if stop-register = 1 => exit (before IRC_get_value)

			push			r16
			PUSH2			b0,b1
			rcall			IRC_get_value							; wait for an input
			WAIT_MS			WAITING_TIME_BETWEEN_PRESSES			; wait for some time in case the user presses for too long
			clr				a1										; ignore high(a) (cf IRC_get_value)
			POP2			b0,b1
			pop				r16
			
			GOTO_IIRCSS		Remote_read_dec_until_ok_err			; if stop-register = 1 => exit (after IRC_get_value)

			; handle non-numeric buttons
			cpi				a0,					BTN_OK
			breq			Remote_read_dec_until_ok_ret			; if OK was pressed, return the value
			cpi				a0,					BTN_ERR
			breq			Remote_read_dec_until_ok_loop			; if an error occured, just keep looping

			; at this point, there can only be numbers
			push			r16
			push			a0
			PUSH2			b0,b1

			LCD_PRINT_APPEND
			.db				FDEC, a, 0
			
			POP2			b0,b1

			ldi				a0,					10					; set a = 10
			clr				a1										; for sanity
			rcall			mul22									; c = a * b = 10 * b
			movw			b1:b0,				c1:c0				; put the result of the multiplication back in b
			pop				a0										; pop a0 => a0 = value from the remote
			add				b0,					a0					; high(b) can be ignored as handled values range from 0 to 99
			pop				r16

			inc				r16										; increment the loop counter
			cpi				r16,				REMOTE_MAX_DIGITS
			brge			Remote_read_dec_until_ok_wait_ok		; if loop-counter >= REMOTE_MAX_DIGITS => wait for ok

			rjmp			Remote_read_dec_until_ok_loop
Remote_read_dec_until_ok_ret:
			movw			a1:a0,				b1:b0				; put the final value in a
			ret 
Remote_read_dec_until_ok_wait_ok:
			PUSH2			b0,b1
			rcall			Remote_wait_for_ok
			POP2			b0,b1
			rjmp			Remote_read_dec_until_ok_ret
Remote_read_dec_until_ok_err:
			CLR2			b0,b1
			rjmp			Remote_read_dec_until_ok_ret
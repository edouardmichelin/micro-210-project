; ===================================================================================
; file		ir_controller.asm
; purpose	offer communication with the infrared controller
; target	ATmega128L-4MHz-STK300
; authors	Edouard Michelin, Elena Dick
; ===================================================================================

.equ		BTN_OK = -1
.equ		BTN_ERR = -2
.equ		PERIOD = 1940											; freq = 515Hz => bit period PERIOD = 1940 usec

.def		IRC_stop_register = r25


; === IRC_STOP_REG_CLEAR ============================================================
; purpose	clears the IRC stop register
; ===================================================================================
.macro		IRC_STOP_REG_CLEAR
			clr			IRC_stop_register
			.endmacro		


; === IRC_STOP_REG_SET ==============================================================
; purpose	sets the IRC stop register
; ===================================================================================
.macro		IRC_STOP_REG_SET
			ldi			IRC_stop_register,	1
			.endmacro	



; === GOTO_IIRCSS ===================================================================
; purpose	Go to if IRC_stop(_register) set
;			branch to the given label if IRC_stop_register = 1
; in:		@0	the label to jump to
; ===================================================================================
.macro		GOTO_IIRCSS
			sbrc		IRC_stop_register,	1
			jmp			@0
			.endmacro



; === IRC_get_value ================================================================
; purpose	returns the value entered via the IR controller
; out:		a1:a0	the pressed button or BTN_ERR (=-2) on error
;					from button 0 to button 9 the returned value is the decimal
;					value on the button
;					for the MUTE (OK) button the returned value is BTN_OK = -1
;					the returned value is available on register a (a1:a0) but can
;					also be read from only a0
; ===================================================================================
IRC_get_value:
			CLR2		b1,					b0
			ldi			b2,					14 						; load bit-counter
IRC_get_value_check:
			GOTO_IIRCSS	IRC_get_value_err
			sbic		PINE,				IR						; wait if PINE_7 = 1
			rjmp		IRC_get_value_check
			WAIT_US		(PERIOD/4)									; wait a quarter period

IRC_get_value_loop:
			GOTO_IIRCSS	IRC_get_value_err							; if stop-register = 1 => exit

			P2C			PINE,				IR						; move pin to carry
			ROL2		b1,					b0						; roll carry into 2-byte reg
			WAIT_US		(PERIOD-4)									; wait bit-period (-compensation)
			DJNZ		b2,					IRC_get_value_loop		; decrement and Jump if not zero
			com			b0											; complement b0
IRC_get_value_test:
			ldi			r16,				-1						; start counter from -1
			LDIZ		(2*IRC_lookup_table)
IRC_get_value_lookup:
			lpm			r17,				z						; load value from the lookup_table
			adiw		z,					2						; look-up table values are word-addressed => next data is 2 byte addresses further
			cp			b0,					r17						; check if value received by the IR sensor matches the loaded one
			breq		IRC_get_value_ret							; if true => goto return
			inc			r16											; else => increment r16 and keep looking
			cpi			r16,				(IRC_lookup_table_size-1)	; check if we have reached the maximum index in the look-up table
			brge		IRC_get_value_err							; if true => goto err
			rjmp		IRC_get_value_lookup						; else (there are more values to check and we still have no match) => loop
IRC_get_value_ret:
			mov			a0,					r16						; put output value in a (a1:a0)
			tst			a0
			brmi		IRC_get_value_ret_neg						; if a0 < 0 => jump to extend sign to high byte of a
			clr			a1
			rjmp		IRC_get_value_ret_next
IRC_get_value_ret_neg:
			ser			a1
IRC_get_value_ret_next:
			ret
IRC_get_value_err:
			ldi			r16,				BTN_ERR					; on error return BTN_ERR=-2
			rjmp		IRC_get_value_ret



; === IRC_lookup_table ==============================================================
.equ		IRC_lookup_table_size = 11

IRC_lookup_table:
			.db			0xe4										; OK / Mute
			.db			0xfe										; 0
			.db			0xfc										; 1
			.db			0xfa										; 2
			.db			0xf8										; 3
			.db			0xf6										; 4
			.db			0xf4										; 5
			.db			0xf2										; 6
			.db			0xf0										; 7
			.db			0xee										; 8
			.db			0xec										; 9

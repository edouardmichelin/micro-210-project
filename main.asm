; ===================================================================================
; file		main.asm
; purpose	Projet de fin de semestre de Micro-contrôleurs (MICRO-210)
; target	ATmega128L-4MHz-STK300
; authors	Edouard Michelin, Elena Dick
; ===================================================================================


.include "definitions.asm"
.include "macros.asm"

.equ	ZERO_FLAG = 1
.equ	LEDS_STATUS = 0x200
.equ	LEDS_DEFAULT_VALUE = 0b11111111


; ===================================================================================
; ===================================== IVT =========================================
; ===================================================================================
.org	0
		jmp			reset

.org	OVF0addr
		jmp			handle_timer_ovf

.org	ADCCaddr
		jmp			DIST_SENSOR_isr


.org	0x30

; ===================================================================================
; ===================================== DRIVERS =====================================
; ===================================================================================
.include "drivers/lcd.asm"
.include "drivers/distance_sensor.asm"
.include "drivers/ir_controller.asm"

; ===================================================================================
; ===================================== LIBS ========================================
; ===================================================================================
.include "libs/lcd.asm"
.include "libs/sound.asm"
.include "libs/remote.asm"


; ===================================================================================
; ===================================== MACROS ======================================
; ===================================================================================

; === RESET_LEDS ====================================================================
; purpose	resets LEDs and LEDs status in SRAM
; ===================================================================================
.macro	RESET_LEDS
		OUTI		PORTB,			0xFF			; Turn LEDs off
		ldi			r16,			LEDS_DEFAULT_VALUE
		sts			LEDS_STATUS,	r16
		.endmacro
		

; === STOP_TIMER ====================================================================
; purpose	stops timer 1 and reset LEDs
; ===================================================================================
.macro	STOP_TIMER
		OUTI		TCCR0,						0				; stopped
		RESET_LEDS
		.endmacro

; === START_TIMER ===================================================================
; purpose	starts timer 1
; ===================================================================================
.macro	START_TIMER
		OUTI		TCCR0,						6				; CK/256 => overflow every 2s
		.endmacro


; ===================================================================================
; ===================================== INT ROUTINES ================================
; ===================================================================================


; === handle_timer_ovf ==============================================================
; purpose	increments the LEDs counter and checks if the current player is runnning out of time
;			the CURR_ROUND memory location is updated accordingly
; ===================================================================================
handle_timer_ovf:
		in			_sreg,			SREG											; save status
		push		r16
		; INCREMENT LEDS COUNTER
		lds			r16,			LEDS_STATUS
		lsr			r16
		sts			LEDS_STATUS,	r16
		out			PORTB,			r16

		; CHECK IF TIMES IS UP
		brbs		ZERO_FLAG,		handle_timer_ovf_player_out_of_time
handle_timer_ovf_ret:
		out			SREG,			_sreg											; restore status
		pop			r16
		reti
handle_timer_ovf_player_out_of_time:
		RESET_LEDS		
		
		lds			r16,			CURR_ROUND
		inc			r16
		sts			CURR_ROUND,	r16

		rjmp		handle_timer_ovf_ret


; ===================================================================================
; ===================================== GAME ========================================
; ===================================================================================
.include "game.asm"

; ===================================================================================
; ===================================== PROGRAM =====================================
; ===================================================================================


; === reset =========================================================================
reset:
		; INIT STACK
		LDSP		RAMEND

		; INIT/RESET PROGRAM MEMORY
		ldi			r16,			0
		sts			LEDS_STATUS,	r16
		sts			CURR_MENU,		r16
		sts			CURR_ROUND,		r16
		sts			SOLO_GAME,		r16

		; INIT LEDS
		OUTI		DDRB,			0xFF						; Make PORTB output
		RESET_LEDS

		; INIT SPEAKER
		sbi			DDRE,			SPEAKER

		; INIT RANGE FINDER
		call		DIST_SENSOR_init

		; INIT LCD
		call		LCD_init
		call		LCD_clear

		; INIT TIMER
		OUTI		TIMSK,						(1 << TOIE0)	; Timer0 overflow interrupt enable
		OUTI		ASSR,						(1 << AS0)		; Clock from TOSC1 (external)
		STOP_TIMER

		sei														; Enable interrupts

		rjmp		main


; === main =========================================================================
main:
		rcall		welcome

main_after_welcome:
		lds			menu_reg,					CURR_MENU

		CHECK_MENU	0,							menu0
		CHECK_MENU	1,							menu1
		CHECK_MENU	2,							menu2
		CHECK_MENU	3,							menu3
		CHECK_MENU	4,							menu4

main_after:
		; Check if we want to go to a menu that does not exist
		lds			menu_reg,					CURR_MENU
		cpi			menu_reg,					NUM_MENUS
		brge		main_after_menu_overflow
		rjmp		main_after_welcome
main_after_menu_overflow:
		jmp			inf_loop

inf_loop:
		rjmp		inf_loop
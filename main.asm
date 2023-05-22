; ===================================================================================
; file		main.asm
; purpose	Projet de fin de semestre de Micro-contr�leurs (MICRO-210)
; target	ATmega128L-4MHz-STK300
; authors	Edouard Michelin, Elena Dick
; ===================================================================================


.include "definitions.asm"
.include "macros.asm"

.equ	ZERO_FLAG = 1
.equ	LEDS_STATUS = 0x200
.equ	LEDS_DEFAULT_VALUE = 0b11111111

.equ	CURR_PLAYER = 0x502
.equ	CURR_MENU = 0x504

.equ	MENU0addr = 0x550
.equ	MENU1addr = 0x552
.equ	MENU2addr = 0x554
.equ	MENU3addr = 0x556

.equ	NUM_MENUS = 4
.equ	MAX_PLAYERS = 9
.equ	MAX_SOLO_ROUNDS = 9


.def	menu_reg = r18



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

; ===================================================================================
; ===================================== LIBS ========================================
; ===================================================================================
.include "libs/lcd.asm"
.include "libs/sound.asm"


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
		

; === CHECK_MENU ====================================================================
; purpose	check with the menu register if the given menu should be displayed
; @0:		menu index
; @1:		menu routine
; ===================================================================================
.macro	CHECK_MENU
		cpi			menu_reg,		@0
		brne		CHECK_MENU_no_match
		jmp			@1
CHECK_MENU_no_match:
		.endmacro


; === NEXT_MENU =====================================================================
; purpose	updates the menu register with the next menu id
; ===================================================================================
.macro	NEXT_MENU
		lds			menu_reg,		CURR_MENU
		inc			menu_reg
		sts			CURR_MENU,		menu_reg
		.endmacro	



; ===================================================================================
; ===================================== INT ROUTINES ================================
; ===================================================================================


; === handle_timer_ovf ===============================================================
; purpose	increments the LEDs counter and checks if the current player is runnning out of time
;			the CURR_PLAYER memory location is updated accordingly
; ===================================================================================
handle_timer_ovf:
		push	r16
		; INCREMENT LEDS COUNTER
		lds			r16,			LEDS_STATUS
		lsr			r16
		sts			LEDS_STATUS,	r16
		out			PORTB,			r16

		; CHECK IF TIMES IS UP
		brbs		ZERO_FLAG,		handle_timer_ovf_player_out_of_time
handle_timer_ovf_ret:
		pop			r16
		reti
handle_timer_ovf_player_out_of_time:
		RESET_LEDS		
		
		lds			r16,			CURR_PLAYER
		inc			r16
		sts			CURR_PLAYER,	r16

		rjmp		handle_timer_ovf_ret



; ===================================================================================
; ===================================== PROGRAM =====================================
; ===================================================================================
reset:
		; INIT STACK
		LDSP		RAMEND

		; INIT/RESET PROGRAM MEMORY
		ldi			r16,			0
		sts			LEDS_STATUS,	r16
		sts			CURR_PLAYER,	r16
		sts			CURR_MENU,		r16

		; INIT LEDS
		OUTI		DDRB,			0xFF			; Make PORTB output
		RESET_LEDS

		; INIT SPEAKER
		sbi			DDRE,			SPEAKER

		; INIT RANGE FINDER
		rcall		DIST_SENSOR_init
	
		; to be removed
		OUTI		DDRE,			0xFF

		; INIT LCD
		rcall		LCD_init
		rcall		LCD_clear


		; INIT TIMER
		OUTI		TIMSK,			(1 << TOIE0)	; Timer0 overflow interrupt enable
		OUTI		ASSR,			(1 << AS0)		; Clock from TOSC1 (external)
		OUTI		TCCR0,			6				; CK/256 => overflow every 2s

		sei											; Enable interrupts

		rjmp		main


welcome_message:	.db "Bienvenue ! Pour demarrer, pressez le bouton MUTE de la telecommande.", 0
how_to_play:		.db "Placez la carte STK300 sous une surface, puis appuyez sur la touche MUTE de la telecommande afin de mesurer la distance et lancer la partie.", 0
number_of_players:	.db "Combien de joueurs participeront au jeu ? Entrez une valeur entre 1 et 9 a l'aide de la telecommande.", 0
number_of_rounds:	.db "Lorsque vous etes seul, vous pouvez choisir le nombre de tentatives auxquelles vous aurez le droit. Entrez une valeur entre 1 et 0 a l'aide de la telecommande.", 0



main:
		rcall		welcome

main_after_welcome:
		lds			menu_reg,		CURR_MENU

		CHECK_MENU	0,				menu0
		CHECK_MENU	1,				menu1
		CHECK_MENU	2,				menu2
		CHECK_MENU	3,				menu3

main_after:
		; NEXT_MENU
		; Check if we want to go to a menu that does not exist
		lds			menu_reg,		CURR_MENU
		cpi			menu_reg,		NUM_MENUS
		brge		main_after_menu_overflow
		rjmp		main_after_welcome
main_after_menu_overflow:
		jmp			inf_loop


welcome:
		LCD_PRINT
		.db			"Bienvenue !", 0

		rcall		play_welcome_sound
		ret

menu0:
		LDIZ		2*welcome_message
		ldi			r16,			2
		rcall		circular_print
		; Simulate start
		WAIT_MS		1000
		NEXT_MENU
		jmp			main_after


menu1:
		LDIZ		2*how_to_play
		ldi			r16,			1
		rcall		circular_print
		; Simulate start
		WAIT_MS		1000
		NEXT_MENU

		jmp			main_after



menu2:
		PRINTF		LCD_putc
.db		"Menu 2", LF, CR, "BTN0 to measure.", 0
		in			w,				PIND
		sbrc		w,				0
		jmp			PC-2
		rcall		DIST_SENSOR_get_dist

		LCD_PRINT
		.db			CR, CR, "Distance=", FDEC2, a, "     ", 0

		jmp			inf_loop
		jmp			main_after



menu3:
		PRINTF		LCD_putc
.db		"Menu 3", 0
		jmp			main_after


inf_loop:
		rjmp		inf_loop
; ===================================================================================
; file		game.asm
; purpose	routines des menus du jeu
; target	ATmega128L-4MHz-STK300
; authors	Edouard Michelin, Elena Dick
; ===================================================================================


.def	menu_reg = r18

.equ	CURR_ROUND = 0x502
.equ	SOLO_GAME = 0x504
.equ	CURR_MENU = 0x506
.equ	NUM_OF_PLAYERS = 0x508
.equ	NUM_OF_ROUNDS = 0x50A
.equ	MEASURED_DIST = 0x50C
.equ	SCORES = 0x50E

.equ	NUM_MENUS = 4
.equ	MAX_PLAYERS = 9
.equ	MAX_SOLO_ROUNDS = 9
.equ	DISTANCE_EPSILON = 3

welcome_message:	.db "Bienvenue ! ", 0, "Pour demarrer, pressez le bouton MUTE de la telecommande.", 0
how_to_play:		.db "Placez la carte", 0, " STK300 sous une surface, puis appuyez sur la touche MUTE de la telecommande afin de mesurer la distance et lancer la partie.", 0
number_of_players:	.db "Combien de joueurs", 0, " participeront au jeu ? Entrez une valeur entre 1 et 9 a l'aide de la telecommande.", 0
number_of_rounds:	.db "Lorsque vous etes", 0, " seul, vous pouvez choisir le nombre de tentatives auxquelles vous aurez le droit. Entrez une valeur entre 1 et 9 a l'aide de la telecommande.", 0
ready_to_start:		.db "La partie est", 0, " maintenant prete a debuter. Chaque tour est limite dans le temps ; vous devez entrez votre choix avant que la barre de LEDs rouge ne se remplisse. Pour valider votre reponse, pressez le bouton OK de la telecommande. A la fin de ce message, vous disposerez de 3 secondes avant que le debut du chronometre. Alors etes-vous pret ?", 0
value_too_low:		.db	"Vous etes trop en dessous...", 0
value_too_high:		.db	"Vous etes trop en dessus !", 0
play_again:			.db	"Pour recommencer la partie, appuyez sur la touche OK de votre telecommande"



; ===================================================================================
; ===================================== MACROS ======================================
; ===================================================================================


; === CHECK_MENU ====================================================================
; purpose	check with the menu register if the given menu should be displayed
; @0:		menu index
; @1:		menu routine
; ===================================================================================
.macro	CHECK_MENU
		cpi			menu_reg,		@0
		brne		CHECK_MENU_no_match
		rcall		@1
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


; === RESET_MENUS ===================================================================
; purpose	reset the menu register to the default value i.e. the first menu
; ===================================================================================
.macro	RESET_MENUS
		ldi			menu_reg,		0
		sts			CURR_MENU,		menu_reg
		.endmacro

; === NEXT_ROUND ====================================================================
; purpose	increments the round
; ===================================================================================
.macro	NEXT_ROUND
		lds			r16,						CURR_ROUND
		inc			r16
		sts			CURR_ROUND,					r16
		.endmacro




; ===================================================================================
; ===================================== ROUTINES ====================================
; ===================================================================================


; === welcome =======================================================================
; purpose	welcome the player(s)
; ===================================================================================
welcome:
		LCD_PRINT
		.db			"Bienvenue !", 0

		rcall		play_welcome_sound
		ret

; === menu0 =========================================================================
; purpose	first menu of the game
;			displays the welcome message and waits for player(s) to be ready
; ===================================================================================
menu0:
		CIRC_PRINT_ONCE	welcome_message
		LCD_PRINT
		.db				"Pressez OK", 0
		rcall			Remote_wait_for_ok
		NEXT_MENU
		ret


; === menu1 =========================================================================
; purpose	setup the game configuration
;			asks for number of players, rounds and captures the distance
;			if only 1 player => asks for the number of rounds
;			otherwise number of rounds = number of players (1 round per player)
; ===================================================================================
menu1:
		CIRC_PRINT_ONCE	number_of_players

menu1_ask_n_players:													; let the user choose the number of players
		LCD_PRINT
		.db				"Joueurs (1..9)", LF, CR, "-> ", 0
		rcall			Remote_read_dec_until_ok
		cpi				a0,							(MAX_PLAYERS + 1)	; if input number of players > MAX_PLAYERS => ask again
		brge			menu1_ask_n_players
		tst				a0												; if input number of players == 0 => ask again
		breq			menu1_ask_n_players

		sts				NUM_OF_PLAYERS,				a0					; store chosen number of players in RAM

		cpi				a0,							1					; if there is only one player, go to solo game configuration
		breq			menu1_solo_game

menu1_multi_game:
		sts				NUM_OF_ROUNDS,				a0					; if there are multiple players, NUM_OF_ROUNDS = NUM_OF_PLAYERS
		rjmp			menu1_next

menu1_solo_game:
		ldi				r16,						1					; SOLO_GAME = 1, NUM_OF_PLAYERS = 1
		sts				SOLO_GAME,					r16
		CIRC_PRINT_ONCE	number_of_rounds

menu1_ask_n_rounds:														; let the player choose the number of rounds
		LCD_PRINT
		.db				"Rounds (1..9)", LF, CR, "-> ", 0
		rcall			Remote_read_dec_until_ok
		cpi				a0,							(MAX_SOLO_ROUNDS + 1); if input number of players > MAX_SOLO_ROUNDS => ask again
		brge			menu1_ask_n_rounds
		tst				a0												; if input number of players == 0 => ask again
		breq			menu1_ask_n_rounds

		sts				NUM_OF_ROUNDS,				a0					; store chosen number of rounds in RAM
		
menu1_next:
		CIRC_PRINT_ONCE	how_to_play
		LCD_PRINT
		.db				"OK pour mesurer", LF, CR, "Valeur = ", 0
		rcall			Remote_wait_for_ok

		rcall			DIST_SENSOR_get_dist

		sts				MEASURED_DIST,				a0					; store measured distance

		CIRC_PRINT_ONCE	ready_to_start
		
		LCD_PRINT
		.db				"3", 0
		WAIT_MS			1000
		LCD_PRINT
		.db				"2", 0
		WAIT_MS			1000
		LCD_PRINT
		.db				"1", 0
		WAIT_MS			1000
		LCD_PRINT
		.db				"Go !!!", 0
		WAIT_MS			500

		NEXT_MENU

		ret


; === menu2 =========================================================================
; purpose	process of guessing distance
;			either in solo- or multi-player
; ===================================================================================
menu2:
		lds				r16,						SOLO_GAME
		cpi				r16,						1					; if SOLO_GAME = 1 => go to solo game
		breq			menu2_solo_game

		inc				a0												; increment CURR_ROUND because players indexing is 1-based whereas rounds are 0-based
		LCD_PRINT
		.db				"Joueur ", FDEC, a, LF, CR, "Valeur = ", 0

menu2_multi_game: ; TODO
		LCD_PRINT
		.db				"Valeur = ", 0

		START_TIMER

		; ask the user to enter a value
		rcall			Remote_read_dec_until_ok

		rjmp			menu2_done

menu2_solo_game:
		lds				a0,							CURR_ROUND			; a = CURR_ROUND
		clr				a1
		lds				r17,						NUM_OF_ROUNDS
		cp				a0,							r17					; if CURR_ROUND >= NUM_OF_ROUNDS => go to next menu
		brge			menu2_done

		LCD_PRINT
		.db				"Solo", LF, CR, "Valeur = ", 0

		START_TIMER

		; ask the user to enter a value
		rcall			Remote_read_dec_until_ok

		STOP_TIMER

		lds				r16,						MEASURED_DIST		; load actual distance from RAM
		PUSH2			a0,							r16					; a0 = guess distance | r16 = actual distance
		sub				a0,							r16					; compute the distance between MEASURED_DIST and value input by user
		rcall			abs1											; c0 = abs(a0)
		sts				SCORES,						c0					; register the score (the distance between guessed and actual value)
		mov				r16,						c0

		cpi				r16,						DISTANCE_EPSILON	; check that the distance is less than DISTANCE_EPSILON
		POP2			a0,							r16
		brlt			menu2_done										; if it is the case, that's a win
		PUSH2			a0, r16
		rcall			play_wrong_sound								; play the "wrong answer" sound
		POP2			a0,							r16
		
		cp				a0,							r16					; check whether the guessed value is below or above the real one
		brlt			menu2_solo_game_less

menu2_solo_game_more:
		CIRC_PRINT_ONCE	value_too_high
		rjmp			menu2_solo_game_next

menu2_solo_game_less:
		CIRC_PRINT_ONCE	value_too_low

menu2_solo_game_next:
		NEXT_ROUND
		rjmp			menu2_solo_game
		

menu2_done:
		NEXT_MENU
		ret


; === menu3 =========================================================================
; purpose	game summary, displays the actual distance and the winner/loser
;			in solo-player displays whether the player won or lost
;			in multi-player displays the player that arrived the closest
; ===================================================================================
menu3:
		lds				r16,						SOLO_GAME
		cpi				r16,						1					; if SOLO_GAME = 1 => go to solo game
		breq			menu3_solo_game

menu3_multi_game: ; TODO
		rjmp			menu3_done

menu3_solo_game:
		lds				a0,							SCORES				; a = SCORE
		clr				a1
		cpi				a0,							DISTANCE_EPSILON
		lds				a0,							MEASURED_DIST		; get the measured distance to display it
		clr				a1
		brlt			menu3_solo_game_win

menu3_solo_game_win:													; display the victory message and play the victory sound
		LCD_PRINT
		.db				"Victoire !", LF, CR, "Reponse = ", FDEC, a, 0
		rcall			play_victory_sound
		rjmp			menu3_done
menu3_solo_game_defeat:													; display the defeat message and play the defeat sound
		LCD_PRINT
		.db				"Defaite...", LF, CR, "Reponse = ", FDEC, a, 0
		rcall			play_defeat_sound
		rjmp			menu3_done

menu3_done:	
		WAIT_MS			5000
		NEXT_MENU
		ret


; === menu4 =========================================================================
; purpose	asks the user whether they want to play again
; ===================================================================================
menu4:
		CIRC_PRINT_ONCE	play_again
		LCD_PRINT
		.db				"OK pour relancer", 0

		rcall			Remote_wait_for_ok
		RESET_MENUS
		ret

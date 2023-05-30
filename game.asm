; ===================================================================================
; file		game.asm
; purpose	routines des menus du jeu
; target	ATmega128L-4MHz-STK300
; authors	Edouard Michelin, Elena Dick
; ===================================================================================


.equ	SETTINGS_SOUND_STATE = 0x500
.equ	SETTINGS_TUTO_STATE = 0x502
.equ	CURR_ROUND = 0x504
.equ	SOLO_GAME = 0x506
.equ	CURR_MENU = 0x508
.equ	NUM_OF_PLAYERS = 0x50A
.equ	NUM_OF_ROUNDS = 0x50C
.equ	MEASURED_DIST = 0x50E
.equ	SCORES = 0x510

.equ	NUM_MENUS = 5
.equ	MAX_PLAYERS = 9
.equ	MAX_SOLO_ROUNDS = 9
.equ	DISTANCE_EPSILON = 3

welcome_message:	.db "Bienvenue ! Pour demarrer, pressez le bouton MUTE de la telecommande. Le bouton MUTE fera office de bouton OK", 0
how_to_play:		.db "Placez la carte sous une surface, puis appuyez sur la touche OK de la telecommande afin de mesurer la distance et lancer la partie.", 0
number_of_players:	.db "Combien de joueurs participeront au jeu ? Entrez une valeur entre 1 et 9 a l'aide de la telecommande.", 0
number_of_rounds:	.db "Lorsque vous etes seul, vous pouvez choisir le nombre de tentatives auxquelles vous aurez le droit. Entrez une valeur entre 1 et 9 a l'aide de la telecommande.", 0
ready_to_start:		.db "La partie est maintenant prete a debuter. Chaque tour est limite dans le temps ; vous devez entrez votre choix avant que la barre de LEDs rouge ne se remplisse. Pour valider votre reponse, pressez le bouton OK de la telecommande. A la fin de ce message, vous disposerez de 3 secondes avant que le debut du chronometre. Alors etes-vous pret ?", 0
value_too_low:		.db	"Vous etes trop en dessous...", 0
value_too_high:		.db	"Vous etes trop en dessus !", 0
play_again:			.db	"Pour recommencer la partie, appuyez sur la touche OK de votre telecommande", 0



; ===================================================================================
; ===================================== MACROS ======================================
; ===================================================================================


; === MUTE_SOUND ====================================================================
; purpose	mute mutable sounds
;			clear SETTINGS_SOUND_STATE
; ===================================================================================
.macro	MUTE_SOUND
		clr				w
		sts				SETTINGS_SOUND_STATE,		w
		.endmacro

; === UNMUTE_SOUND ==================================================================
; purpose	unmute mutable sounds
;			set SETTINGS_SOUND_STATE
; ===================================================================================
.macro	UNMUTE_SOUND
		ser				w
		sts				SETTINGS_SOUND_STATE,		w
		.endmacro

; === TOGGLE_SOUND ==================================================================
; purpose	toggle SETTINGS_SOUND_STATE
;			SETTINGS_SOUND_STATE decides whether sounds will be played or not
; ===================================================================================
.macro	TOGGLE_SOUND
		ser				a0
		lds				w,							SETTINGS_SOUND_STATE
		tst				w												; if SETTINGS_SOUND_STATE == 0 => SETTINGS_SOUND_STATE = 1
		breq			PC+2
		clr				a0
		sts				SETTINGS_SOUND_STATE,		a0
		.endmacro

; === PLAY_MUTABLE ==================================================================
; purpose	plays a sound by calling the given routine iff SETTINGS_SOUND_STATE != 0
; in:		@0	the sound routine to call
; ===================================================================================
.macro	PLAY_MUTABLE
		lds				w,							SETTINGS_SOUND_STATE
		tst				w
		breq			PC+2
		call			@0
		.endmacro

; === HIDE_TUTO =====================================================================
; purpose	hides tuto texts
;			clear SETTINGS_TUTO_STATE
; ===================================================================================
.macro	HIDE_TUTO
		clr				w
		sts				SETTINGS_TUTO_STATE,		w
		.endmacro

; === DISPLAY_TUTO ==================================================================
; purpose	unhides tuto texts
;			set SETTINGS_TUTO_STATE
; ===================================================================================
.macro	DISPLAY_TUTO
		ser				w
		sts				SETTINGS_TUTO_STATE,		w
		.endmacro

; === TOGGLE_TUTO ===================================================================
; purpose	toggle SETTINGS_TUTO_STATE
;			SETTINGS_TUTO_STATE decides whether tuto texts  will be displayed or not
; ===================================================================================
.macro	TOGGLE_TUTO
		ser				a0
		lds				w,							SETTINGS_TUTO_STATE
		tst				w												; if SETTINGS_TUTO_STATE == 0 => SETTINGS_TUTO_STATE = 1
		breq			PC+2
		clr				a0
		sts				SETTINGS_TUTO_STATE,		a0
		.endmacro

; === PRINT_TUTO ====================================================================
; purpose	prints the given tuto message iff SETTINGS_TUTO_STATE != 0
; in:		@0	pointer to the string to print
; ===================================================================================
.macro	PRINT_TUTO
		LDIZ			(2*@0)
		ldi				r16,						1
		lds				r17,						SETTINGS_SOUND_STATE
		tst				r17
		breq			PC+2
		call			circular_print
		.endmacro

; === COUNT_DOWN ====================================================================
; purpose	counts down before a race (3, 2, 1, GO!)
;			displays the numbers on the LCD screen and plays a sound
; ===================================================================================
.macro	COUNT_DOWN
		LCD_PRINT
		.db				"3", 0
		PLAY_MUTABLE	play_race_3_sound ; duration: 1/4 second
		WAIT_MS			750
		LCD_PRINT
		.db				"2", 0
		PLAY_MUTABLE	play_race_2_sound ; duration: 1/4 second
		WAIT_MS			750
		LCD_PRINT
		.db				"1", 0
		PLAY_MUTABLE	play_race_1_sound ; duration: 1/4 second
		WAIT_MS			750
		LCD_PRINT
		.db				"Go !!!", 0
		PLAY_MUTABLE	play_race_go_sound ; duration: 1/2 second
		.endmacro

; === BR_MENU_OVF ===================================================================
; purpose	branch if menu overflow
; in:		@0:	label to jump to
; ===================================================================================
.macro	BR_MENU_OVF
		lds				w,							CURR_MENU
		cpi				w,							NUM_MENUS
		brge			@0
		.endmacro

; === CHECK_MENU ====================================================================
; purpose	check with the menu register if the given menu should be displayed
; in:		@0:	menu index
;			@1:	menu routine
; ===================================================================================
.macro	CHECK_MENU
		lds				w,							CURR_MENU
		cpi				w,							@0
		brne			CHECK_MENU_no_match
		rcall			@1
CHECK_MENU_no_match:
		.endmacro


; === NEXT_MENU =====================================================================
; purpose	updates the menu register with the next menu id
; ===================================================================================
.macro	NEXT_MENU
		lds				w,							CURR_MENU
		inc				w
		sts				CURR_MENU,					w
		.endmacro


; === RESET_MENUS ===================================================================
; purpose	reset the menu register to the default value i.e. the first menu
; ===================================================================================
.macro	RESET_MENUS
		ldi				w,							0
		sts				CURR_MENU,					w
		.endmacro

; === NEXT_ROUND ====================================================================
; purpose	increments the round
; ===================================================================================
.macro	NEXT_ROUND
		lds				w,							CURR_ROUND
		inc				w
		sts				CURR_ROUND,					w
		.endmacro








; ===================================================================================
; ===================================== ROUTINES ====================================
; ===================================================================================


; === welcome =======================================================================
; purpose	welcome the player(s)
; ===================================================================================
welcome:
		LCD_PRINT
		.db				"Bienvenue !", 0

		PLAY_MUTABLE	play_welcome_sound
		ret

; === menu0 =========================================================================
; purpose	first menu of the game
;			displays the welcome message and waits for player(s) to be ready
; ===================================================================================
menu0:
		PRINT_TUTO		welcome_message
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
		PRINT_TUTO		number_of_players

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
		PRINT_TUTO		number_of_rounds

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
		PRINT_TUTO		how_to_play
		LCD_PRINT
		.db				"OK pour mesurer", 0
		rcall			Remote_wait_for_ok

		rcall			DIST_SENSOR_get_dist

		sts				MEASURED_DIST,				a0					; store measured distance

		PRINT_TUTO		ready_to_start

		NEXT_MENU

		ret


; === menu2 =========================================================================
; purpose	process of guessing distance
;			either in solo- or multi-player
; ===================================================================================
menu2:
		lds				r16,						SOLO_GAME
		cpi				r16,						1					; if SOLO_GAME = 1 => go to solo game
		brne			menu2_multi_game
		jmp				menu2_solo_game

menu2_multi_game:
		lds				r16,						CURR_ROUND			; a = current-round
		clr				a1
		lds				r17,						NUM_OF_PLAYERS
		cp				r16,						r17					; if CURR_ROUND >= NUM_OF_PLAYERS => go to next menu
		brlt			menu2_multi_game_cont
		jmp				menu2_multi_game_done

menu2_multi_game_cont:
		COUNT_DOWN
		START_TIMER
		
		lds				a0,							CURR_ROUND			; a = current-round
		inc				a0												; increment CURR_ROUND for printing because players indexing is 1-based whereas rounds are 0-based
		LCD_PRINT
		.db				"Joueur ", FDEC, a, LF, CR, "Valeur = ", 0

		; ask the user to enter a value
		rcall			Remote_read_dec_until_ok						; a0 = value

		STOP_TIMER
		GOTO_IIRCSS		menu2_multi_game_timeout						; if stop-register = 1 => go to next player

		; compute the score (the distance between guessed and actual value) of the current player
		lds				r16,						MEASURED_DIST		; load actual distance from RAM
		sub				a0,							r16					; compute the distance between MEASURED_DIST and value input by user
		rcall			abs1											; c0 = abs(a0)
		
		; register the score of the current player
		LDIZ			SCORES											; z = SCORES + *CURR_ROUND
		lds				r16,						CURR_ROUND
		ADDZ			r16
		st				z,							c0					; register the score
		
menu2_multi_game_next:
		NEXT_ROUND
		rjmp			menu2_multi_game

menu2_multi_game_timeout:
		PLAY_MUTABLE	play_wrong_sound
		rjmp			menu2_multi_game_next

menu2_multi_game_done:
		rjmp			menu2_done


menu2_solo_game:
		lds				a0,							CURR_ROUND			; a = CURR_ROUND
		clr				a1
		lds				r17,						NUM_OF_ROUNDS
		cp				a0,							r17					; if CURR_ROUND >= NUM_OF_ROUNDS => go to next menu
		brlt			menu2_solo_game_cont
		jmp				menu2_solo_game_done

menu2_solo_game_cont:		
		COUNT_DOWN
		START_TIMER

		LCD_PRINT
		.db				"Solo", LF, CR, "Valeur = ", 0

		; ask the user to enter a value
		rcall			Remote_read_dec_until_ok

		STOP_TIMER
		GOTO_IIRCSS		menu2_solo_game_timeout							; if stop-register = 1 => go to next round

		lds				r16,						MEASURED_DIST		; load actual distance from RAMRemote_read_dec_until_ok
		PUSH2			a0,							r16					; a0 = guess distance | r16 = actual distance
		sub				a0,							r16					; compute the distance between MEASURED_DIST and value input by user
		rcall			abs1											; c0 = abs(a0)
		sts				SCORES,						c0					; register the score (the distance between guessed and actual value)



		mov				r16,						c0

		cpi				r16,						DISTANCE_EPSILON	; check that the distance is less than DISTANCE_EPSILON
		POP2			a0,							r16
		brlt			menu2_solo_game_done							; if it is the case, that's a win
		PUSH2			a0, r16
		PLAY_MUTABLE	play_wrong_sound								; play the "wrong answer" sound
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

menu2_solo_game_timeout:
		PLAY_MUTABLE	play_wrong_sound
		rjmp			menu2_solo_game_next

menu2_solo_game_done:
		rjmp			menu2_done
		

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
		brne			menu3_multi_game
		jmp				menu3_solo_game

menu3_multi_game: ; TODO

		; find the best score
		CLR3			r16, r17, r18									; r16 = best-player-id
		ldi				r17,						120					; r17 = current best score (lower is better) - set to an arbitrary high enough default value
																		; r18 = loop counter
		lds				r19,						NUM_OF_PLAYERS
		LDIZ			SCORES

menu3_multi_game_loop:
		ld				r20,						z+					; load score of current player
		cp				r20,						r17					; compare the score with the current best
		brge			menu3_multi_game_loop_continue					; if the score is not better (lower = better), continue
		mov				r16,						r18					; update current best player
		mov				r17,						r20					; update current best score
	
menu3_multi_game_loop_continue:
		inc				r18												; increment loop counter
		cp				r18,						r19					; loop while loop counter < num-of-players
		brlt			menu3_multi_game_loop
		
		; display the winner
		mov				a0,							r16					; load best player id
		inc				a0												; increment because players are 1-based and player ids are 0-based
		clr				a1
		lds				b0,							MEASURED_DIST		; b = actual distance
		clr				b1
		LCD_PRINT
		.db				"Victoire de : ", FDEC, a, LF, CR, "Reponse = ", FDEC, b, 0
		PLAY_MUTABLE	play_victory_sound
		
		rjmp			menu3_done

menu3_solo_game:
		lds				a0,							MEASURED_DIST		; get the measured distance to display it
		clr				a1
		lds				r16,						SCORES				; r16 = SCORE
		cpi				r16,						DISTANCE_EPSILON	; if score < DISTANCE_EPSILON => victory
		brge			menu3_solo_game_defeat							; else defeat

menu3_solo_game_win:													; display the victory message and play the victory sound
		LCD_PRINT
		.db				"Victoire !", LF, CR, "Reponse = ", FDEC, a, 0
		PLAY_MUTABLE	play_victory_sound
		rjmp			menu3_done
menu3_solo_game_defeat:													; display the defeat message and play the defeat sound
		LCD_PRINT
		.db				"Defaite...", LF, CR, "Reponse = ", FDEC, a, 0
		PLAY_MUTABLE	play_defeat_sound
		rjmp			menu3_done

menu3_done:
		WAIT_MS			5000
		NEXT_MENU
		ret


; === menu4 =========================================================================
; purpose	asks the user if they want to play again
; ===================================================================================
menu4:
		PRINT_TUTO	play_again
		LCD_PRINT
		.db				"OK pour relancer", 0

		rcall			Remote_wait_for_ok
		rcall			reset
		ret

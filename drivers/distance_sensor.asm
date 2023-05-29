; ===================================================================================
; file		distance_sensor.asm
; purpose	offer communication with the infrared distance sensor GP2Y0A21
; target	ATmega128L-4MHz-STK300
; authors	Edouard Michelin, Elena Dick
; ===================================================================================

.def	DIST_SENSOR_flag_reg = r23
.equ	DIST_SENSOR_factor = 122									; 27 * output voltage = 27 * 4.5 = 121.5 ~= 122


; === str_len =======================================================================
; purpose	initializes the distance sensor
; ===================================================================================
DIST_SENSOR_init:
		OUTI		ADCSR,			(1 << ADEN) + (1 << ADIE) + 6	; AD Enable, AD int. enable, PS=CK/64
		OUTI		ADMUX,			GP2_AVAL						; Select channel GP2_AVAL (distance measuring sensor)
		ret

; === DIST_SENSOR_get_dist ==========================================================
; purpose	returns the distance measured by the distance sensor
; out:		a		the distance in cm
; ===================================================================================
DIST_SENSOR_get_dist:
		clr			DIST_SENSOR_flag_reg
		sbi			ADCSR,					ADSC					; AD start conversion
		WB0			DIST_SENSOR_flag_reg,	0						; wait for conversion to be done
		ldi			a0,						DIST_SENSOR_factor		; load DIST_SENSOR_factor in a
		ldi			b0,						100
		rcall		mul11											; c = a*b = DIST_SENSOR_factor * 100
		movw		a1:a0,					c1:c0					; a = c
		in			b0,						ADCL					; store result in register b
		in			b1,						ADCH
		rcall		div22											; c = a/b = (100*DIST_SENSOR_factor)/result
		movw		a1:a0,					c1:c0					; move the result to register a

		ret


; === DIST_SENSOR_isr ===============================================================
; purpose	interrupt service routine (ISR) for the distance sensor
; ===================================================================================
DIST_SENSOR_isr:
		ldi			DIST_SENSOR_flag_reg,	0x01
		reti

; ===================================================================================
; file		distance_sensor.asm
; purpose	offer communication with the infrared distance sensor GP2Y0A21
; target	ATmega128L-4MHz-STK300
; authors	Edouard Michelin, Elena Dick
; ===================================================================================

.def DIST_SENSOR_flag_reg = r23


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
		clr			r23
		sbi			ADCSR,					ADSC					; AD start conversion
		WB0			DIST_SENSOR_flag_reg,	0						; wait for conversion to be done
		in			a0,						ADCL					; store result in register a
		in			a1,						ADCH
		rcall		DIST_SENSOR_lookup_dist
		ret


; === DIST_SENSOR_isr ===============================================================
; purpose	interrupt service routine (ISR) for the distance sensor
; ===================================================================================
DIST_SENSOR_isr:
		ldi			DIST_SENSOR_flag_reg,	0x01
		reti


; === DIST_SENSOR_lookup_dist =======================================================
; purpose	converts the measure returned by the distance sensor in centimeters
; in:		a		the distance in whatever unit
; out:		a		the distance in cm
; ===================================================================================
DIST_SENSOR_lookup_dist:
		; TODO
		ret


; ===================================================================================
; file		math.asm
; purpose	library, mathematical routines
; target	ATmega128L-4MHz-STK300
; authors	Edouard Michelin, Elena Dick, R. Holzer
; ===================================================================================


; ===================================================================================
; =========================== absolute value ( c = abs(a) ) =========================
; ===================================================================================


; === abs1 ==========================================================================
; purpose	return the absolute value of the input
; in:		a	input of abs(.)
; out:		c	output of abs(.)
; ===================================================================================
abs1:
	tst		a0
	brmi	abs1_neg
abs1_ret:
	mov		c0,		a0
	ret
abs1_neg:
	neg		a0
	rjmp	abs1_ret


; copyright R.Holzer
; === unsigned multiplication (c=a*b) ===

mul11:	clr	c1			; clear upper half of result c
	mov	c0,b0			; place b in lower half of c
	lsr	c0			; shift LSB (of b) into carry
	ldi	w,8			; load bit counter
_m11:	brcc	PC+2			; skip addition if carry=0
	add	c1,a0			; add a to upper half of c
	ROR2	c1,c0			; shift-right c, LSB (of b) into carry
	DJNZ	w,_m11			; Decrement and Jump if bit-count Not Zero
	ret

mul21:	CLR2	c2,c1			; clear upper half of result c
	mov	c0,b0			; place b in lower half of c
	lsr	c0			; shift LSB (of b) into carry
	ldi	w,8			; load bit counter
_m21:	brcc	PC+3			; skip addition if carry=0
	ADD2	c2,c1, a1,a0		; add a to upper half of c
	ROR3	c2,c1,c0		; shift-right c, LSB (of b) into carry
	DJNZ	w,_m21			; Decrement and Jump if bit-count Not Zero
	ret

mul22:	CLR2	c3,c2			; clear upper half of result c
	MOV2	c1,c0, b1,b0		; place b in lower half of c
	LSR2	c1,c0			; shift LSB (of b) into carry
	ldi	w,16			; load bit counter
_m22:	brcc	PC+3			; skip addition if carry=0
	ADD2	c3,c2, a1,a0		; add a to upper half of c
	ROR4	c3,c2,c1,c0		; shift-right c, LSB (of b) into carry
	DJNZ	w,_m22			; Decrement and Jump if bit-count Not Zero
	ret


; === unsigned division c=a/b ===

div22:	MOV2	c1,c0, a1,a0		; c will contain the result
	CLR2	d1,d0			; d will contain the remainder
	ldi	w,16			; load bit counter
_d22:	ROL4	d1,d0,c1,c0		; shift carry into result c
	SUB2	d1,d0, b1,b0		; subtract b from remainder
	brcc	PC+3	
	ADD2	d1,d0, b1,b0		; restore if remainder became negative
	DJNZ	w,_d22			; Decrement and Jump if bit-count Not Zero
	ROL2	c1,c0			; last shift (carry into result c)
	COM2	c1,c0			; complement result
	ret

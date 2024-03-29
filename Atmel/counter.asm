.include "m8def.inc"
.EQU	PORT	=PORTB
.DEF	ON		=R16
.DEF	OFF		=R17
.DEF	TIMEON	=R18
.DEF	SLOWWAIT=R0
		LDI		ON,255
		LDI		OFF,0
		LDI		R19,1	;TESTING COUNTER
TIMING:
		MOV		TIMEON,R19
		INC		R19
		DEC		TIMEON
		LDI		ZL,low(SHORTTIME)
		ADD		ZL,TIMEON
		SUBI	TIMEON,4
		BRCC	T6
		LDI		ZH,32
SLOW_DOWN:
		DEC		ZH
		BRNE	SLOW_DOWN
		LDI		ZH,high(SHORTTIME)
		IJMP
SHORTTIME:
		RJMP	T1	;*!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!*
		RJMP	T2	;*  THESE LINES CAN'T CROSS BYTE BOUNDARY AS THEY ARE *
		RJMP	T3	;* INDIRECTLY ADRESSED/RUN BY TIMEON+SHORTTIME & IJMP *
		RJMP	T4	;*!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!*
TI:

T1:
		OUT		PORT,ON	;0,13mkrs @ 8MHz
		OUT		PORT,OFF
		RJMP	TIMING
T2:
		OUT		PORT,ON	;0,25
		NOP
T22:
		OUT		PORT,OFF
		RJMP	TIMING
T3:
		OUT		PORT,ON	;0,38
		RJMP	T22
T4:
		OUT		PORT,ON	;0,50
		NOP		;*!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!*
		NOP		;* THESE LINES CAN'T CROSS BYTE BOUNDARY AS THEY ARE *
		NOP		;* INDIRECTLY ADRESSED/RUN BY ZL-(TIMEREST%3) & IJMP *
TI:				;*!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!*
		OUT		PORT,OFF
		RJMP	TIMING
T6:
		CLR		ZL
		CLR		SLOWWAIT
		INC		SLOWWAIT
		SEC
DIV:
		ROL		TIMEON
		BREQ	EDIV
		ROL		ZH
		CPI		ZH,3
		SBC		ZL,ZL
		ROL		SLOWWAIT
		COM		ZL
		ANDI	ZL,3
		SUB		ZH,ZL
		RJMP	DIV
EDIV:
		COM		SLOWWAIT
		LDI		ZL,low(TI)
		SUB		ZL,ZH
		INC		SLOWWAIT
		LDI		ZH,high(TI)
		OUT		PORT,ON	;>=0,63
SLW:
		DEC		SLOWWAIT
		BRNE	SLW
		IJMP
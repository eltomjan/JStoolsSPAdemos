.include "m8def.inc"
#define	WPBIT	5
#define	WPPORT	PORTD
#define	WPDIR	DDRD
#define	SCLBIT	6
#define	SCLPORT	PORTD
#define	SCLDIR	DDRD
#define	SDABIT	0
#define	SDAPIN	PINB
#define	SDAPORT	PORTB
#define	SDADIR	DDRB
.ORG	0x0000
		RJMP RESET	;Reset Handle
.db 255,207,255,207,255,207	;rjmp self - hang when go there
.ORG	OVF2addr
		CLI
		PUSH		R16
		IN		R16,SREG
		PUSH		R16
		INC		R20
		CPI		R20,4
		BRCS	OC1END
		SBIW	R29:R28,1
		BRNE	WAV
NEXT_LETTER:
		RCALL	STOP
		LPM		R20,Z+	; NEXT LETTER
		AND		R20,R20
		BRNE	VALID
		LDI		ZH,HIGH(TEXT<<1)
		LDI		ZL,LOW(TEXT<<1)+TEXT%2
VALID:
		CPI		R20,32
		BRNE	VALID2
		LDI		R20,10	;0.24640241s = MEZERA
MEZERA:
		DEC		R28
		BRNE	MEZERA
		DEC		R29
		BRNE	MEZERA
		DEC		R20
		BRNE	MEZERA
		RJMP	NEXT_LETTER
VALID2:
		PUSH	ZH
		PUSH	ZL
		LDI		ZH,HIGH(LETTER<<1)
		LDI		ZL,LOW(LETTER<<1)+LETTER%2
CHECK_LETTER:
		LPM		R16,Z+
		CP		R20,R16
		BREQ	FOUND
		AND		R16,R16
		BRNE	CHECK_LETTER
		POP		ZL
		POP		ZH
		RJMP	NEXT_LETTER
FOUND:
		MOV		R20,ZL
		SUBI	R20,LOW(LETTER<<1)+LETTER%2	; LETTER INDEX
		LDI		ZL,LOW(SIZES<<1)+SIZES%2
SKIP_PREC:
		DEC		R20
		BREQ	WAV_LEN
		LPM		R16,Z+
		ADD		R28,R16
		LPM		R16,Z+
		ADC		R29,R16
		RJMP	SKIP_PREC
WAV_LEN:
		RCALL	START	;6.88mks @ 8MHz <=> 145349 Hz
		LDI		R16,0b10100000	;CONTROL BYTE, DEVICE 0, WRITE
		RCALL	SEND	;45mks @ 8MHz <=> 22222 Hz
		MOV		R16,R29			;ADDR HIGH
		RCALL	SEND
		MOV		R16,R28			;ADDR LOW
		RCALL	SEND
		RCALL	DISABLE_WRITE
		RCALL	START
		LDI		R16,0b10100001	;CONTROL BYTE, DEVICE 0, READ
		RCALL	SEND	;45mks @ 8MHz <=> 22222 Hz
		LPM		R28,Z+
		LPM		R29,Z+
		POP		ZL
		POP		ZH
WAV:
		RCALL	GET		;53.63mks @ 8MHz <=> 18646 Hz
		OUT		OCR2,R16
		CLR		R20
OC1END:
		POP		R16
		OUT		SREG,R16
		POP		R16
		SEI
		RETI
RESET:
		LDI		R16,HIGH(RAMEND)	;nastaveni zasobniku		
		OUT		SPH,R16
		LDI		R16,LOW(RAMEND)
		OUT		SPL,R16
		LDI 	R16, 0xFF	; set all pins to output
		OUT 	DDRC,R16
		OUT 	DDRB,R16
		ldi		r16,127
		OUT 	DDRD,R16
		LDI		R16,0b01111001;Fast PWM, set OC2 on compare match
		OUT		TCCR2,R16
;  7	6	  5		4	  3		2	1	 0
;FOC2 WGM20 COM21 COM20 WGM21 CS22 CS21 CS20
		LDI		R16,0b01000000
;  7	 6		5	   4	  3		2	1	0
;OCIE2 TOIE2 TICIE1 OCIE1A OCIE1B TOIE1 � TOIE0
;TOIE2: Timer/Counter2 Overflow Interrupt Enable
		OUT		TIMSK,R16

		SBI		SDAPORT,SDABIT
		SBI		SCLPORT,SCLBIT
		SBI		WPPORT,WPBIT
		LDI		R16,0b01111001
		OUT		TCCR2,R16
		LDI		R16,0b01000000
		OUT		TIMSK,R16

		RCALL	SETSDA;INIT
		RCALL	SETSCL;INIT

		RCALL	ENABLE_WRITE
		RCALL	START	;6.88mks @ 8MHz <=> 145349 Hz
		LDI		R16,0b10100000	;CONTROL BYTE, DEVICE 0, WRITE
		RCALL	SEND	;45mks @ 8MHz <=> 22222 Hz
		LDI		R16,0			;ADDR HIGH
		RCALL	SEND
		LDI		R16,0			;ADDR LOW
		RCALL	SEND
		RCALL	DISABLE_WRITE
		RCALL	START
		LDI		R16,0b10100001	;CONTROL BYTE, DEVICE 0, READ
		RCALL	SEND	;45mks @ 8MHz <=> 22222 Hz
		SEI
		LDI		ZH,HIGH(TEXT<<1)
		LDI		ZL,LOW(TEXT<<1)+TEXT%2
		CLR		R29
		LDI		R28,1
HANG:
		RJMP	HANG

SEND:
		PUSH	R21
		LDI		R21,8
SENDBIT:
		LSL		R16
		RCALL	CLRSCL
		RCALL	CF2SDA
		CBI		SCLDIR,SCLBIT
		DEC		R21
		BRNE	SENDBIT
		RCALL	CLRSCL
		CBI		SDADIR,SDABIT
		CBI		SCLDIR,SCLBIT
		POP		R21
		RET
GET:
		LDI		R21,8
GETBIT:
		RCALL	CLRSCL
		CBI		SDADIR,SDABIT
		CBI		SCLDIR,SCLBIT
		RCALL	READSDA
		ROL		R16
		DEC		R21
		BRNE	GETBIT
		RCALL	CLRSCL
		RCALL	CLRSDA	;SEND ACK
		CBI		SCLDIR,SCLBIT
		RET
ENABLE_WRITE:
		RCALL	CLRWP
		RET
DISABLE_WRITE:
		RCALL	SETWP
		RET
CF2SDA:
		BRCC	CLRSDA
		CBI		SDADIR,SDABIT
		RET
START:
		RCALL	CLRSCL
		CBI		SDADIR,SDABIT
		CBI		SCLDIR,SCLBIT

		RCALL	CLRSDA
		RET
STOP:
		RCALL	CLRSCL
		RCALL	CLRSDA
		CBI		SCLDIR,SCLBIT
		CBI		SDADIR,SDABIT
		RET

READSDA:
		PUSH	R16
		IN		R16,SDAPIN
		CLC
		SBRC	R16,SDABIT
		SEC
		POP		R16
		RET

SETWP:
		SBI		WPPORT,WPBIT
		SBI		WPDIR,WPBIT
		RET
CLRWP:
		CBI		WPPORT,WPBIT
		SBI		WPDIR,WPBIT
		RET
SETSCL:
		SBI		SCLDIR,SCLBIT
		SBI		SCLPORT,SCLBIT
		RET
CLRSCL:
		SBI		SCLDIR,SCLBIT
		CBI		SCLPORT,SCLBIT
		RET
SETSDA:
		SBI		SDAPORT,SDABIT
		SBI		SDADIR,SDABIT
		RET
CLRSDA:
		CBI		SDAPORT,SDABIT
		SBI		SDADIR,SDABIT
		RET
TEXT:
;.db	"abCcHdDeEfghijklmnNoprRsStTuvzZ",0	;31+1 H=ch
.db	"stanislav lem kyberiAda bajky kybernetickEho vWku ..."
.ORG	FLASHEND-255
LETTER:
.db "aAbcHCdDeEWfghiIjklmnNoOprRsStTuUvyYzZ",0	;38+1 H=ch,W=�

SIZES:
;low,high
.db	56,2,223,3,85,1,44,3,169,5,207,2,213,2,218,2,220,1,135,4,156,5,84,3,75,4,0,2,117,3,93,4,85,4,238,5,134,1,95,4,19,4,74,2,60,2,36,3,61,1,66,2,135,2,20,2,64,4,194,1,44,1,144,2,212,3,236,2,122,1,96,3,244,1,135,4
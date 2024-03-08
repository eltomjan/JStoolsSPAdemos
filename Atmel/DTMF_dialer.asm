;***************************************************************************
;* A P P L I C A T I O N   N O T E   F O R   T H E   A V R   F A M I L Y
;*
;* Number               : AVR314 -> DTMF dialer
;* File Name            : "dtmf.asm"
;* Title                : DTMF Generator
;* Date                 : 00.06.27
;* Version              : 1.1
;* Target MCU           : Any AVR with SRAM, 8 I/O pins and PWM
;*
;* DESCRIPTION
;* This Application note describes how to generate DTMF tones using a single
;* 8 bit PWM output.
;*
;***************************************************************************

.include "m8def.inc"

;**************************************************************************
;  REGISTERS
;**************************************************************************
.def   ptr_Ltmp = r1                    ; low  part temporary register
.def   ptr_Htmp = r2                    ; high part temporary register
.def   ptr_Lb   = r3                    ; low  part low frequency pointer
.def   ptr_Hb   = r4                    ; high part low frequency pointer

.def   ptr_La   = r5                    ; low  part high frequency pointer
.def   ptr_Ha   = r6                    ; high part high frequency pointer

.def   addb_out = r7                    ; low  frequency value to be written                            
.def   adda_out = r8                    ; High frequency value to be written

.def   x_SWa = r9                    	; high frequency x_SW
.def   x_SWb = r10                   	; low  frequency x_SW

.def   tmp      = r16                   ; temp register

.def   input    = r17                   ; input from portB

;**************************************************************************
;**************************************************************************
.equ     Xtal      = 8000000            ; system clock frequency
.equ     prescaler = 1                  ; timer1 prescaler
.equ     N_samples = 128                ; Number of samples in lookup table
.equ     Fck = Xtal/prescaler           ; timer1 working frequency
.equ	 delaycyc  = 10			; port B setup delay cycles

;**************************************************************************
;  PROGRAM START - EXECUTION STARTS HERE
;**************************************************************************
.cseg
.org    $0
    rjmp    start                       ; Reset handler
.org    OVF1addr
    rjmp    tim1_ovf                    ; Timer1 overflow Handle

;**************************************************************************
; Interrupt timer1
;**************************************************************************
tim1_ovf:
   push   tmp    			; Store temporary register
   in     tmp,SREG
   push   tmp                           ; Store status register
   push   ZL
   push   ZH                            ; Store Z-Pointer
   push   r0                            ; Store R0 Register

;high frequency
   mov    ptr_Ltmp,ptr_La
   mov    ptr_Htmp,ptr_Ha
   rcall  getsample                     ; read from sample table
   mov    adda_out,r0                   ; adda_out = high frquency value
   add    ptr_La,x_SWa
   clr    tmp                           ; (tmp is cleared, but not the carry flag)
   adc    ptr_Ha,tmp                    ; Refresh pointer for the next sample

;low frequency
   mov    ptr_Ltmp,ptr_Lb
   mov    ptr_Htmp,ptr_Hb
   rcall  getsample                     ; read from sample table
   mov    addb_out,r0                   ; addb_out = low frequency value
   add    ptr_Lb,x_SWb
   clr    tmp                           ; (tmp is cleared, but not the carry flag)
   adc    ptr_Hb,tmp                    ; refresh pointer for the next sample

; scale amplitude
   ldi     tmp,2
   add     addb_out,tmp
   lsr     addb_out
   lsr     addb_out                     ; divide 4 and round off
   sub     r0,addb_out                  ; 4/4 - 1/4 = 3/4
   mov     addb_out,r0                  ; now addb_out has the right amplitude

   clr     tmp
   out     OCR1AH,tmp
   mov     tmp,adda_out
   add     tmp,addb_out
   out     OCR1AL,tmp                   ; send the sum of the two amplitudes to PWM
//DEBUG
//   OUT		PORTC,tmp

   pop     r0                           ; Restore R0 Register
   pop     ZH
   pop     ZL                           ; Restore Z-Pointer
   pop     tmp
   out     SREG,tmp                     ; Restore SREG
   pop     tmp                          ; Restore temporary register;
   reti

;*********************************
; RESET Interrupt
;*********************************
start:
	LDI		R16,0xC4
	OUT		OSCCAL,R16
    sbi   DDRD,PD5                      ; Set pin PD5 as output
    ldi   tmp,low(RAMEND)
    out   SPL,tmp
    ldi   tmp,high(RAMEND)
    out   SPH,tmp                       ; Initialize Stackpointer

;Initialization of the registers
    clr   ptr_La
    clr   ptr_Ha
    clr   ptr_Lb
    clr   ptr_Hb                        ; Set both table ponters to 0x0000

;enable timer1 interrupt
    ldi   tmp,(1<<TOIE1)
    out   TIMSK,tmp                     ; Enable Timer1_ovf interrupt

;set timer1 PWM mode
     ldi   tmp,(1<<PWM10)+(1<<COM1A1)
     out   TCCR1A,tmp                   ; 8 bit PWM not reverse (Fck/510)
     ldi   tmp,(1<<CS10)
     out   TCCR1B,tmp                   ; prescaler = 1
     sei                                ; Enable interrupts

;**************************************************************************
; MAIN
; fix x_SWa and x_SWb
;**************************************************************************

main:
;high frequency (Esteem only high nibble that is row)
;PB_High_Nibble:
   clr   x_SWa
   clr   x_SWb
//DEBUG
//   OUT		PORTC,x_SWa

NEW_LOOP:	// start hlavní smyèky od prvního èísla
   	LDI		ZL,low(TConto*2)
	LDI		ZH,high(TConto*2)
	LDI		tmp,3
	OUT		DDRB,tmp
	COM		tmp
	OUT		PORTB,tmp	// aktivuj pul-up na volných pinec portu B
	LDI		tmp,3
	RCALL	DELAY1
KEY_START:
	CLR		x_SWa
	CLR		x_SWb
	IN		tmp,PINB
	ORI		tmp,3
	INC		tmp
	BREQ	KEY_START	// žádný volný pin portu B neuzemnìn ? = èekej
NUM_SEQ:
	CLR		x_SWa
	CLR		x_SWb
	LDI		tmp,2
	RCALL	DELAY1
	LPM		R0,Z+
	LDI		tmp,46
	CP		R0,tmp
	BRCC	PLAY
	CLR		x_SWa	// nejsou-li èísla k pøehrání, ztiš PWM
	CLR		x_SWb
KEY_NEXT:
	IN		tmp,PINB
	ORI		tmp,3
	INC		tmp
	BREQ	KEY_NEXT	// a èekej na klávesu pøed dalším blokem/opakováním
	DEC		R0
	BREQ	NEW_LOOP	// konec dat=opakuj celý cyklus
	RJMP	NUM_SEQ
PLAY:
   mov   x_SWb,r0                    	; this is low frequency x_SW
//DEBUG
//   OUT		PORTC,R0
	   
;low frequency
;PB_Low_Nibble:
	LPM		R0,Z+
   mov   x_SWa,r0                    	; this is high frequency x_SW
//DEBUG
//   OUT		PORTC,R0
	LDI		tmp,8
	RCALL	DELAY1
   rjmp  NUM_SEQ


;******************   DELAY   ***********************************
;****************************************************************
DELAY1:
	CLR		R20
	CLR		R21
;	LDI		tmp,4
D1_LOOP:
	DEC		R21
	BRNE	D1_LOOP
	DEC		R20
	BRNE	D1_LOOP
	DEC		tmp
	BRNE	D1_LOOP
	RET

DELAY2:
	CLR		x_SWa
	CLR		x_SWb
//DEBUG
//   OUT		PORTC,x_SWa
	LDI		R22,6
D2_LOOP:
	RCALL	DELAY1
	DEC		R22
	BRNE	D2_LOOP
	RET
;******************   GET SAMPLE   ******************************
;****************************************************************
getsample:
   ldi    tmp,0x0f
   and    ptr_Htmp,tmp

; ROUND	
   ldi    tmp,4
   add    ptr_Ltmp,tmp
   clr    tmp
   adc    ptr_Htmp,tmp

;shift (divide by eight):
   lsr    ptr_Htmp
   ror    ptr_Ltmp
   lsr    ptr_Htmp
   ror    ptr_Ltmp
   lsr    ptr_Htmp
   ror    ptr_Ltmp

   ldi    tmp,0x7f
   and    ptr_Ltmp,tmp                  ; module 128 (samples number sine table)

   ldi    ZL,low(sine_tbl*2)
   ldi    ZH,high(sine_tbl*2)
   add    ZL,ptr_Ltmp
   clr    tmp
   adc    ZH,tmp                        ; Z is a pointer to the correct
                                        ; sine_tbl value
   lpm
   ret

;*************************** SIN TABLE *************************************
; Samples table : one period sampled on 128 samples and
; quantized on 7 bit
;******************************************************************************
sine_tbl:
.db 64,67
.db 70,73
.db 76,79
.db 82,85
.db 88,91
.db 94,96
.db 99,102
.db 104,106
.db 109,111
.db 113,115
.db 117,118
.db 120,121
.db 123,124
.db 125,126
.db 126,127
.db 127,127
.db 127,127
.db 127,127
.db 126,126
.db 125,124
.db 123,121
.db 120,118
.db 117,115
.db 113,111
.db 109,106
.db 104,102
.db 99,96
.db 94,91
.db 88,85
.db 82,79
.db 76,73
.db 70,67
.db 64,60
.db 57,54
.db 51,48
.db 45,42
.db 39,36
.db 33,31
.db 28,25
.db 23,21
.db 18,16
.db 14,12
.db 10,9
.db 7,6
.db 4,3
.db 2,1
.db 1,0
.db 0,0
.db 0,0
.db 0,0
.db 1,1
.db 2,3
.db 4,6
.db 7,9
.db 10,12
.db 14,16
.db 18,21
.db 23,25
.db 28,31
.db 33,36
.db 39,42
.db 45,48
.db 51,54
.db 57,60

;*******************************  x_SW  ***********************************
;Table of x_SW (excess 8): x_SW = ROUND(8*N_samples*f*510/Fck)
;**************************************************************************

;high frequency (column)
;1209hz  ---> x_SW = 79  -> 1 4 7 * 
;1336hz  ---> x_SW = 87  -> 2 5 8 0
;1477hz  ---> x_SW = 96  -> 3 6 9 #
;1633hz  ---> x_SW = 107 -> A B C D

;low frequency (row)
;697hz  ---> x_SW = 46 -> 1 2 3 A
;770hz  ---> x_SW = 50 -> 4 5 6 B
;852hz  ---> x_SW = 56 -> 7 8 9 C
;941hz  ---> x_SW = 61 -> * 0 # D

TConto:	// pøíklad 822112233 volací èíslo (nefunguje pøes DTMF z budky), èíslo karty#, pin#, pøípadnì telefonní èíslo#
// data jsou zadávána v poøadí øádek, sloupec
// pøístupové èíslo,0 = konec èísla
//	8		2	2		1	1		2	2		3	3
.db 56,87,46,87,46,87,46,79,46,79,46,87,46,87,46,96,46,96,0
// èíslo karty,#,0 = konec èísla
//.db xx,xx,xx,xx,xx,xx,xx,xx,xx,xx,xx,xx,xx,xx,xx,xx,61,96,0
//pin,#,1 = konec dat
//.db xx,xx,xx,xx,xx,xx,xx,xx,61,96,1

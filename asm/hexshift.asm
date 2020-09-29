; Blinks LEDR every half second and write 0xbEEF to HEX 

.NAME Handler = 0x2000
.NAME HEX   = 0xFFFFF000
.NAME LEDR  = 0xFFFFF020
.NAME TCNT  = 0xFFFFF100
.NAME TLIM  = 0xFFFFF104
.NAME TCTL  = 0xFFFFF108

.ORG 0x100
	XOR 	Zero,Zero,Zero
	ADDI 	Zero,FP,1 		; FP: Value to shift
	ADDI 	Zero,SP,4 		; SP: Shift value
	XOR 	SSP,SSP,SSP 	; SSP: Interrupt count

	WSR 	PCS,FP
	ADDI 	Zero,S0,Handler
	WSR 	IHA,S0
	ADDI 	Zero,S0,16
	SW 		S0,TCTL(Zero)
	ADDI 	Zero,S0,250
	SW 		S0,TLIM(Zero)

	XOR 	T0,T0,T0

;; How to shift values accross the hex display:
	XOR 	SP,SP,SP 			; SP = 0
	ADDI 	Zero,T0,0xF 		; T0 = 0xf   
	LSHF 	A0,T0,SP 			; A0 = 0x000f
	ADD 	SSP,Zero,A0 		; SSP = 0x00f 
	ADDI 	Zero,T0,0xE
	ADDI 	SP,SP,4 			; SP = 4
	LSHF 	A1,T0,SP 			; A1 = 0x00e0
	ADD 	SSP,SSP,A1 			; SSP = 0x00ef
	ADDI 	SP,SP,4				; SP = 8
	LSHF 	A2,T0,SP 			; A2 = 0x0e00
	ADD 	SSP,SSP,A2 			; SSP = 0x0eef
	ADDI 	Zero,T0,0xB
	ADDI 	SP,SP,4
	LSHF 	A3,T0,SP 			; A3 = 0xb000
	ADD 	SSP,SSP,A3 			; SSP = 0xbeef
	SW 		SSP,HEX(Zero)

Loop:
	BR 		Loop


.ORG 0x2000
	BLT 	Zero,FP,ToggleOn
	XOR 	S2,S2,S2
	ADDI 	Zero,FP,1
	BR 		Finish

ToggleOn:
	ADDI 	Zero,S2,0x3fff
	XOR 	FP,FP,FP

Finish:
	SW 		S2,LEDR(Zero)
	LW 		S1,TCTL(Zero) 		; Load contents of timer control reg 
	ADDI 	Zero,S2,18 			; 18 = 0b10010
	AND 	S1,S1,S2 			; Clear Ready bit 0, preserve bits 4 and 1
	SW 		S1,TCTL(Zero) 		; Update timer control register 
	RETI
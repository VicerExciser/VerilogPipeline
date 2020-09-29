; Switch interrupt test

.NAME HandlerAddr = 0x10  ;0xF000
.NAME HEX= 0xFFFFF000
.NAME LEDR = 0xFFFFF020
.NAME KDATA = 0xFFFFF080
.NAME KCTRL = 0xFFFFF084
.NAME SDATA = 0xFFFFF090
.NAME SCTRL = 0xFFFFF094
.NAME TCNT = 0xFFFFF100
.NAME TLIM = 0xFFFFF104
.NAME TCTL = 0xFFFFF108

.ORG 0x10 		; Handler code
	LW 		A1,SDATA(FP) ; Read switch state
	;SW 		A1,LEDR(FP) ; Light up LEDR[i] if SW[i] active
	ADDI Zero,SSP,1
	;ADD  A2,Zero,SSP 	; A2: Our data to display 
	XOR  A3,A3,A3  		; A3: Our left shift value for A2 
	; T0: Our comparison value for determining which switch is on (leftmost given priority)
	ADDI 	Zero,T0,16
	BGE 	A1,T0,Hex5 	; If SDATA >= 16, show on HEX5
	SUBI 	T0,T0,4
	BGE 	A1,T0,Hex4 	; If SDATA >= 12, show on HEX4
	SUBI 	T0,T0,4
	BGE 	A1,T0,Hex3 	; If SDATA >= 8, show on HEX3
	SUBI 	T0,T0,4
	BGE 	A1,T0,Hex2 	; If SDATA >= 4, show on HEX2
	SUBI 	T0,T0,4
	BGE 	A1,T0,Hex1 	; If SDATA >= 2, show on HEX1
	; Else, show on HEX0 (always/default)
Hex0:
	SW 	SSP,HEX(Zero)
	RETI

Hex1:
	ADDI 	A3,A3,1
	BR 		Display

Hex2:
	ADDI 	A3,A3,2
	BR 		Display

Hex3:
	ADDI 	A3,A3,3
	BR 		Display

Hex4:
	ADDI 	A3,A3,4
	BR 		Display

Hex5:
	ADDI 	A3,A3,5
	BR 		Display

Display:
	LSHF 	A2,SSP,A3 		; A2 = 1 << A3
	SW 		A2,HEX(Zero)
	RETI


.ORG 0x100 		; Main program code
	XOR		Zero,Zero,Zero	; Put a zero in the Zero register
	XOR 	FP,FP,FP 		; FP: will also be zero
	ADDI	FP,SP,1 		; SP will just hold a constant 1
	ADDI 	FP,S1,4 		
	LSHF 	S0,SP,S1 		; Set S0 to 0b10000	(1 << 4, to set bit 4)	
	SW 		S0,SCTRL(FP)		; Enable interrupts from switches
	ADDI	FP,S2,HandlerAddr	; S2: Our handler address
	WSR 	IHA,S2 				; Ensure IHA can be written to
	XOR 	SSP,SSP,SSP ; init ssp as our switch counter
	;ADDI 	Zero,A3,6 	; exclusive upper bound for HEX index
	;XOR 	A2,A2,A2 	; A2 is our byte offset for HEX writes

Main:
	BR 	Main
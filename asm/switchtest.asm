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
	SW 		A1,LEDR(FP) ; Light up LEDR[i] if SW[i] active
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

Main:
	BR 	Main
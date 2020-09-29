; Timer interrupt test

.NAME HandlerAddr = 0x10  ;0xF000
.NAME HEX= 0xFFFFF000
.NAME LEDR = 0xFFFFF020
.NAME KEY = 0xFFFFF080
.NAME SW = 0xFFFFF090
.NAME TCNT = 0xFFFFF100
.NAME TLIM = 0xFFFFF104
.NAME TCTL = 0xFFFFF108

.ORG 0x10 			; Timer Interrupt Handler
	;RSR 	A3,IRA 		; Read int return addr into A3 (for debug)
	ADDI 	T0,T0,1 	; Increment interrupt count 
	;SW 		T0,HEX(FP)
	;SW 		S2,LEDR(FP)
	;RSR 	A1,IDN			; A1: Interrupt register only (to avoid clobbering)
	
	;SW 		A3,HEX(FP) 	; Display IRA before RETI jumps to it
	;BEQ 	A3,Zero,Fail 
	;; Check device # the interrupt originated from

	;BNE 	Zero,A1,Fail 	; IDN should contain 4'h0, if not then show's over

	;; Don't forget to clear Ready bit after interrupt taken care of!
	ADDI 	Zero,A1,16
	SW		A1,TCTL(FP)	; Clear all TCTL bits except IE for TCTL reg 

	;ADDI 	Zero,A1,0x148	; 0148 is the address for Main loop 
	;WSR 	IRA,A1 			; Hardcoding return address for interrupt ...

	RETI 				; Resume program execution from main

.ORG 0x100
	XOR		Zero,Zero,Zero	; Put a zero in the Zero register
	XOR 	FP,FP,FP 		; FP: will also be zero
	XOR 	T0,Zero,Zero 	; T0: Our interrupt counter (for debug & termination)
	ADDI 	Zero,SP,1 		; SP: Just holds 1
	ADDI 	Zero,S2,1024	; S2: Our debug LEDR code for initialization failures
	;; Right shift S2 by SP for each possible init failure point
	ADD 	S0,SP,FP		; S0: For reads from timer device registers
	;----------------------------------------------------------------------------
	;; FAILURE HERE SHOWS LEDR 9 LIT 
	ADDI 	Zero,S1,4 		
	LSHF 	S0,S0,S1 		; Set S0 to 0b10000	(1 << 4, to set bit 4)	
	SW 		S0,TCTL(FP)		; Enable interrupts from the timer
	;LW 		S1,TCTL(FP)
	;BNE 	S1,S0,InitFail 	; Verify interrupts have been enabled for timer 
	;----------------------------------------------------------------------------
	;; FAILURE HERE SHOWS LEDR 8 LIT 
	RSHF 	S2,S2,SP 		; Init error code = led 8
	SW 		Zero,TCNT(FP) 	; Init timer device counter to 0
	ADDI	Zero,A0,2000 	; A0: Our timer limit value (1000 = 1 second)
	SW 		A0,TLIM(FP)		; Set device timer limit
	;LW 		S0,TLIM(FP)
	;BNE 	S0,A0,InitFail
	;----------------------------------------------------------------------------
	;; FAILURE HERE SHOWS LEDR 7 LIT 
	RSHF 	S2,S2,SP 		; Init error code = led 7
	ADDI	FP,S1,HandlerAddr	; S1: Our handler address
	WSR 	IHA,S1 				; Ensure IHA can be written to
	RSR 	S0,IHA 				
	;BNE 	S0,S1,InitFail 		; Ensure correct address read from IHA
	;; ^ Note that 0xF000 is also the default IHA value in the processor, try changing
	RSHF 	S2,S2,SP 		; Init error code = led 6

Main:
	SW 		T0,HEX(FP)
	SUBI 	T0,T1,15 		; 15 interrupts should occur (totaling 30 seconds)
	BLT 	T1,FP,Main 		; Keep looping while (T0 - 15) < 0
Success:
	SW 		T0,HEX(FP)
	NOT 	T0,FP			; T0 = 0xFFFF
	SW 		T0,LEDR(FP)
	;ADDI 	Zero,T1,0xBEEF
	;SW 		T1,HEX(FP)
Done:
	JMP 	Done(FP)
InitFail:
	;ADDI 	FP,T0,0xF0F0 
	;JMP 	Fail(FP)
	ADD 	T0,S2,FP 	; Load init debug code into T0
Fail:
	SW 		T0,LEDR(FP)
	ADDI 	Zero,T1,0xBAD
	SW 		T1,HEX(FP)
	JMP 	Fail(FP)


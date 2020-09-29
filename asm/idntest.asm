.NAME GenHandler = 0x10  
.NAME HEX   = 0xFFFFF000
.NAME LEDR  = 0xFFFFF020
.NAME KDATA = 0xFFFFF080
.NAME KCTRL = 0xFFFFF084
.NAME SDATA = 0xFFFFF090
.NAME SCTRL = 0xFFFFF094
.NAME TCNT  = 0xFFFFF100
.NAME TLIM  = 0xFFFFF104
.NAME TCTL  = 0xFFFFF108


.ORG 0x10 
ADDI 	Zero,FP,1
	RSR 	A0,IDN
	BNE 	A0,FP,Finish

;TctlClean:
	ADDI 	Zero,A2,16 
	SW 		A2,TCTL(Zero) 		; Update timer control register 

Finish:
	SW 		A0,HEX(Zero)
	RETI

.ORG 0x100 
	ADDI	Zero,S0,GenHandler	; S0: Temporary setup variable
	WSR 	IHA,S0 				; Ensure IHA has correct handler address
	;ADDI 	Zero,S0,1 			
	;WSR 	PCS,S0 				; Ensure processor interrupts enabled
	ADDI 	Zero,S0,16 			; Set S0 to 0b10000 mask (to set bit 4)		
	SW 		S0,TCTL(Zero)		; Enable interrupts from timer device
	SW 		S0,KCTRL(Zero)		; Enable interrupts from keys
	SW 		S0,SCTRL(Zero)		; Enable interrupts from switches
	ADDI 	Zero,T0,1  		; Initial blink speed = 1/2 second 
	SW 		T0,TLIM(Zero) 		; Set timer limit to kick off the blinks

Loop:
	BR 		Loop









.NAME	HEX= 0xFFFFF000
.NAME	LEDR=0xFFFFF020
.NAME	KEY= 0xFFFFF080
.NAME	SW=  0xFFFFF090

.NAME 	HardcodeLimit=50000000
.NAME	CntLimit=256

.ORG 0x100

	addi zero,t0,0x0	; initialize t0 to be our counter
	addi zero,a0,0x0	; initialize a0 to be our display value
	addi zero,s0,HardcodeLimit 	; s0 is our Limit reg1 (for t0)
	addi zero,s1,CntLimit		; s1 is our Limit reg2 (for a0)
	sw 	zero,LEDR(zero)
	sw  zero,HEX(zero)
Main:
	addi t0,t0,0x1 		; increment counter
	;beq  a0,s1,DispOut
	blt  t0,s0,Main		; keep looping until Limit met
	; once counter has reached limit:
	addi zero,t0,0x0 	; reset it

DispOut:
	sw a0,LEDR(zero)
	sw a0,HEX(zero)
	addi a0,a0,0x1
	blt  a0,s1,Main
	addi zero,a0,0x0
	jmp  Main(zero)

	;rsr a0,idn
	;wsr ira,a1
	;reti

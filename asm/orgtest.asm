; .ORG Generated Output Test

.NAME HandlerAddr = 0xF000
.NAME LEDR = 0xFFFFF020
.NAME	HEX= 0xFFFFF000

.ORG 0x100
	ADDI Zero,T1,0x0F
	sw 	t1,LEDR(zero)
	addi	Zero,t0,0xBAD
	sw		t0,HEX(Zero)
	ADDI Zero,A0,HandlerAddr 	; Store interrupt handler address in A0
	WSR IHA,A0					; Populate IHA with handler address
	RSR SP,IHA 					; Read handler address register into stack pointer
	JMP HandlerAddr(Zero) ;0(SP)					; Jump to handler higher in memory

.ORG 0xF000
	addi	Zero,t0,0xDEAD
	sw		t0,HEX(Zero)
	ADDI Zero,RV,0xFF 		; Store value 0xFF in RV reg
	SW 	RV,LEDR(Zero)			; Turn on leds
Forever:
	JMP Forever(Zero)


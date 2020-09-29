; Addresses for I/O
.NAME	HEX= 0xFFFFF000
.NAME	LEDR=0xFFFFF020
.NAME	KEY= 0xFFFFF080
.NAME	SW=  0xFFFFF090

	.ORG 0x100
; Simple Test Code #2 (ALU with dependency)
	addi s1, s0, 0x1 	; s0 <= 1
	addi s0, s2, 0x1		; s2 <= 2
	addi s2, a0, 0x1		; a0 <= 3

Done:
	sw a0, HEX(Zero) 	; Display 3 on HEX0 if successful
	br Done
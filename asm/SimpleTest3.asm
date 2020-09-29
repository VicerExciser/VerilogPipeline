; Addresses for I/O
.NAME	HEX= 0xFFFFF000
.NAME	LEDR=0xFFFFF020
.NAME	KEY= 0xFFFFF080
.NAME	SW=  0xFFFFF090

	.ORG 0x100
; Simple Test Code #3 (ALU with dependency for same R/W)
	addi s1, s1, 0x1 	; s1 <= 1
	addi s1, s1, 0x1		; s1 <= 2
	addi s1, s1, 0x1		; s1 <= 3

Done:
	sw s1, HEX(Zero) 	; Display 3 on HEX0 if successful
	br Done
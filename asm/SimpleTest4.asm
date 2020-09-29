; Addresses for I/O
.NAME	HEX= 0xFFFFF000
.NAME	LEDR=0xFFFFF020
.NAME	KEY= 0xFFFFF080
.NAME	SW=  0xFFFFF090

	.ORG 0x100
; Simple Test Code #4 (Basic JAL test)
	addi s2, s1, 0x1 	; s1 <= 1
	subi a0, s1, 0x1 	; s1 <= -1
	addi Zero, a1, 0xDAB
	addi Zero, a2, 0xBAD
	jal t1, Dab(t0)

Bad:
	sw a2, HEX(Zero) 	; Display 'BAD' on HEX for failure
	br Bad

Dab:
	sw s1, LEDR(Zero)
	sw a1, HEX(Zero)	; Display 'DAB' on HEX for success
	br Dab
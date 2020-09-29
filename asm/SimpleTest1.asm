; Addresses for I/O
.NAME	HEX= 0xFFFFF000
.NAME	LEDR=0xFFFFF020
.NAME	KEY= 0xFFFFF080
.NAME	SW=  0xFFFFF090

	.ORG 0x100
	; Simple ALU code: No dependencies
Start:
	add	fp, Zero, Zero
	addi	Zero, s0, 0x1	;s0 = Zero + 1
	addi	Zero, s1, 0x1	;s1 = Zero + 1
	add 	s2, Zero, Zero	;s2 = Zero + Zero
	addi	Zero, t1, 0x0
	addi	Zero, sp, 0x0
	addi	Zero, a0, 0x3	;a0 = 3
	addi 	Zero, a1, 0x2	;a1 = 2
	eq	a2, s0, s1 		; a2 = (s0 == s1)
	; s0 and s1 should both be 1
	addi	Zero, s0, 0x0	
	addi	Zero, s1, 0x0
	addi	Zero, s2, 0x0
	addi	Zero, sp, 0x0
	add	t0, a0, a1		;t0 = 5
	addi	a1, fp, 0x1		;fp = 3
	addi	Zero, s0, 0x0	
	addi	Zero, s1, 0x0
	addi	Zero, s2, 0x0	
	addi	Zero, t1, 0x0
	
	
	sw	a2, HEX(Zero)		; Should display 1 on HEX0
	sw 	a2, LEDR(Zero)	; Should light up LEDR
	
	sw	fp, HEX(t0)		; HEX5 should show 3
	sw	a1, HEX(fp)	; HEX3 should show 2
Done:
	beq	a1, a1, Done
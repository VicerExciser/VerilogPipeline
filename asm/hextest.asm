; Testing assembler output for 32-bit I/O addresses being used as immediate values
.NAME	HEX= 0xFFFFF000
.NAME	LEDR=0xFFFFF020
.NAME	KEY= 0xFFFFF080
.NAME	SW=  0xFFFFF090
.NAME	TIME=  0xFFFFF100

.ORG 0x100
ADDI 	Zero,T1,0x7	; T1 = 32'b0111
ADD		T0,Zero,T1
SW		T0,LEDR(Zero)	; Turn on first 3 LEDs
SW		T0,HEX(Zero)	
SW		T0,TIME(Zero)	
SW		T0,SW(Zero)	
SW		T0,KEY(Zero)	

RSR 		A0,PCS
WSR		IRA,SSP
RETI

Forever:
JMP 	Forever(Zero)
 
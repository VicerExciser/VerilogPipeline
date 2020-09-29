; Full interrupt test

.NAME GenHandler  = 0x10  
;.NAME TimeHandler = 0x40 
;.NAME KeyHandler  = 0x80 
;.NAME SwHandler   = 0xC0
.NAME HEX   = 0xFFFFF000
.NAME LEDR  = 0xFFFFF020
.NAME KDATA = 0xFFFFF080
.NAME KCTRL = 0xFFFFF084
.NAME SDATA = 0xFFFFF090
.NAME SCTRL = 0xFFFFF094
.NAME TCNT  = 0xFFFFF100
.NAME TLIM  = 0xFFFFF104
.NAME TCTL  = 0xFFFFF108

; System stack begins at the top of memory
.NAME SysStkTop = 0x10000
; General purpose stack begins 4kB below top of memory
.NAME StkTop = 0xF000

; Timer limit is measured in milliseconds (our PLL outputs 97MHz)
; .25 seconds = 250 ms , 1 ms = 97000 counts
.NAME QuartSec = 24250000 		; 97000 * 250 = 1/4 second 
.NAME HalfSec = 48500000
.NAME MaxLimit = 194000000 		; 2 seconds is maximum timer limit 

.NAME LowerLED = 0x01F			; 0000011111
.NAME UpperLED = 0x3E0 			; 1111100000


;; General handler code
.ORG 0x10 			
	; Save general purpose registers using SSP 
	ADDI 	SSP,SSP,-16 		; Allocate space for A0-A3
	SW 		A0,12(SSP) 			; Save A0
	SW 		A1,8(SSP) 			; Save A1
	SW 		A2,4(SSP) 			; Save A2
	SW 		A3,0(SSP) 			; Save A3 

	RSR 	A0,IDN 				; Get cause of interrupt 
	ADDI 	Zero,A1,1 			; If IDN is 1,
	BEQ 	A0,A1,TimeHandler	; Jump to timer handler 
	ADDI 	Zero,A1,1 			; Else if IDN is 2,
	BEQ 	A0,A1,KeyHandler	; Jump to Key handler 
	ADDI 	Zero,A1,1 			; Else if IDN is 3,
	BEQ 	A0,A1,SwHandler		; Jump to switch handler 
	BR 		IntReturn 			; Else, return (invalid device ID)

;---------------------------------------------------------------------------------

;; Timer handler code 	-- priority level #1
;  Responsible for blinking LEDRs when time limit reached
;  (Reminder: MOD 2 is the same as checking if bit[0] is set -- AND with 1)
;  (micro % 2 == 0) <--> (micro & 1 == 0)
TimeHandler:
	ADDI 	Zero,A2,5 			; Let A2 be a constant 5 here for max microstate check 
	ADDI 	Zero,A3,1 			; Let A3 be a constant 1 here for masking check 

; First, determine the current blinking sequence macrostate (S1)
;~~~~~~~~~~~ State 0 -- Blink upper half of LEDR 
	XOR 	A0,A0,A0 			; A0 = 0
	BNE 	S1,A0,State1		; If not state 0, check state 1

; Next, check if the microstate (S2) is either [0,2,4] or [1,3,5]
	AND 	A0,S2,A3 			; A0 = S2 & 0x1 
	BEQ 	A0,A3,LedrOff 		; Turn off LEDR for odd microstate
	BR 		UpperOn 			; Else, turn on UpperLED

;~~~~~~~~~~~ State 1 -- Blink lower half of LEDR 
State1:
	ADDI 	A0,A0,1 			; A0 = 1
	BNE 	S1,A0,State2 		; If not state 1, check state 2
	AND 	A0,S2,A3 			; A0 = S2 & 0x1 
	BEQ 	A0,A3,LedrOff 		; Turn off LEDR for odd microstate
	BR 		LowerOn				; Else, turn on LowerLED

;~~~~~~~~~~~ State 2 -- Blink upper and lower halves of LEDR alternatively 
State2:
	AND 	A0,S2,A3 			; A0 = 1 if odd microstate, 0 if even
	BEQ 	A0,A3,LowerOn 		; Turn on LowerLED for odd microstate
	BR 		UpperOn				; Else, turn on UpperLED	

UpperOn:
	ADDI 	Zero,A1,UpperLED
	SW 		A1,LEDR(Zero)
	BR 		UpdateState

LowerOn:
	ADDI 	Zero,A1,LowerLED
	SW 		A1,LEDR(Zero)
	BR 		UpdateState

LedrOff: 	; Microstates [1,3,5] of macrostates 0 & 1 -- turn all LEDR off
	XOR 	A1,A1,A1 
	SW 		A1,LEDR(Zero)
	;BR 		UpdateState

UpdateState:
	ADDI 	S2,S2,1 			; Increment microstate
	BLE 	S2,A2,CleanTctl 	; If microstate <= 5, we're good
	XOR 	S2,S2,S2			; Else, wrap back to zero and increment macrostate
	ADDI 	S1,S1,1 			; Increment macrostate, then ensure it's between 0-2
	ADDI 	Zero,A0,2 			; A0 = max macrostate 
	BLE 	S1,A0,CleanTctl 	; If macrostate <= 2, we're good
	XOR 	S1,S1,S1 			; Else, set macrostate back to 0
	;BR 		CleanTctl 			; Finish up and RETI 

CleanTctl:
	LW 		A0,TCTL(Zero) 		; Load contents of timer control reg 
	ADDI 	Zero,A1,18 			; 18 = 0b10010
	AND 	A0,A0,A1 			; Clear Ready bit 0, preserve bits 4 and 1
	SW 		A0,TCTL(Zero) 		; Update timer control register 
	BR 		IntReturn

;---------------------------------------------------------------------------------

;; Key handler code 	-- priority level #2
;  Adjusts blinking speed of the LEDs by setting new timer limit
;  KEY[0] slows speed by .25 seconds (max value is 2 sec.)
;  KEY[1] increases speed by .25 sec. (min value is .25 sec.)
KeyHandler:
	LW 		A0,KDATA(Zero) 		; Load state of KEY[3:0]
	ADDI 	Zero,A1,1 			; A1 = 1
	BNE 	A1,A0,CheckK1		; If not KEY[0] pressed, check KEY[1]
	ADDI 	Zero,A2,194000000	; Else, check if speed can be slowed
	BEQ 	T0,A2,IntReturn		; If speed already 2 seconds, ignore request
	ADDI 	T0,T0,24250000 		; Else, add 1/4 sec. to timer limit 
	SW 		T0,TLIM(Zero) 		; Update device timer limit
	BR 		IntReturn

CheckK1:						; Check if KEY[1] was pressed (if KDATA == 2)
	ADDI 	A1,A1,1 			; A1 = 2
	BNE 	A0,A1,IntReturn		; If not KEY[0] or KEY[1], ignore request
	ADDI 	Zero,A2,24250000 	; Else, check if speed can be increased 
	BEQ 	T0,A2,IntReturn 	; If speed already 1/4 second, ignore request
	SUBI 	T0,T0,24250000 		; Else, subtract 1/4 sec. from timer limit
	SW 		T0,TLIM(Zero) 		; Update device timer limit
	BR 		IntReturn

;---------------------------------------------------------------------------------

;; Switch handler code 	-- priority level #3
;  Controls which HEX[m] segment to display blinking speed on
;  (m is the index between 0 and 5)
SwHandler:

	LW 		A0,SDATA(Zero) 		; Read switch state

	; ... TODO

	BR 		IntReturn

;; Interrupt handler cleanup code for program resumption
IntReturn:
	; Restore general purpose registers from system stack
	LW 		A3,0(SSP)
	LW 		A2,4(SSP)
	LW 		A1,8(SSP)
	LW 		A0,12(SSP)
	ADDI 	SSP,SSP,16
	RETI 						; Return and enable interrupts

;;;======================================================================

;; Program initialization code
.ORG 0x100 			
	XOR		Zero,Zero,Zero		; Clear Zero register
	XOR 	FP,FP,FP 			; Clear frame pointer
	ADDI	Zero,SP,StkTop 		; Init general SP
	ADDI 	Zero,SSP,SysStkTop	; Init system stack pointer

	ADDI	Zero,S0,GenHandler	; S0: Temporary setup variable
	WSR 	IHA,S0 				; Ensure IHA has correct handler address
	ADDI 	Zero,S0,1 			
	WSR 	PCS,S0 				; Ensure processor interrupts enabled
	ADDI 	Zero,S0,16 			; Set S0 to 0b10000 mask (to set bit 4)		
	SW 		S0,TCTL(Zero)		; Enable interrupts from timer device
	SW 		S0,KCTRL(Zero)		; Enable interrupts from keys
	SW 		S0,SCTRL(Zero)		; Enable interrupts from switches
	;SW 		Zero,TCNT(Zero) 	; Init timer device counter to 0

	;; S1 WILL ONLY BE USED TO HOLD OUR MACROSTATE (0 - 2)
	XOR 	S1,S1,S1

	;; S2 WILL ONLY BE USED TO HOLD OUR MICROSTATE (0 - 5)
	XOR 	S2,S2,S2

	;; T0 WILL ONLY BE USED FOR THE ADJUSTABLE TIMER LIMIT (BLINK SPEED)
	ADDI 	Zero,T0,48500000 	; Initial blink speed = 1/2 second 
	SW 		T0,TLIM(Zero) 		; Set timer limit to kick off the blinks

;; Main loop (just waits for interrupts from I/O)
Main:				
	BR 	Main
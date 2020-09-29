module Key(INPUT,ABUS,DBUS,WE,INTR,CLK,RST);
	parameter BITS;
	parameter KEY_BITS;
	parameter BASE;
	
	parameter KDATA_ADDR = BASE; 		// 0xFFFFF080;
	parameter KCTRL_ADDR = BASE + 4;	// 0xFFFFF084;
	
	input wire [KEY_BITS-1:0] INPUT;
	input wire [BITS-1:0] ABUS;
	inout wire [BITS-1:0] DBUS;
	input wire WE;
	input wire CLK;
	input wire RST;
	output wire INTR;

	reg [KEY_BITS-1:0] KDATA;
	reg [BITS-1:0] KCTRL;
	// reg [KEY_BITS-1:0] prev_data;

	wire selData = (ABUS == KDATA_ADDR);
	wire selCtrl = (ABUS == KCTRL_ADDR);
	wire rdData = selData && (!WE);
	wire wrCtrl = selCtrl && WE;
	wire rdCtrl = selCtrl && (!WE);

	always @ (posedge CLK or posedge RST) begin
		
		if (RST) begin
			KCTRL <= {BITS{1'b0}};
		end
		else begin
			if (rdData == 1'b1) begin
				KCTRL[0] <= 1'b0;
			end
			// Ready bit set when change in KDATA detected
			else if (INPUT != KDATA) begin
				// Set the Overrun bit instead if Ready bit is already 1
				if   (KCTRL[0] == 1'b1) KCTRL[1] <= 1'b1;
				else  KCTRL[0] <= 1'b1;
			end 

			if (wrCtrl == 1'b1) begin
				// Allow writing a 0 to the Overrun bit
				if (DBUS[1] == 1'b0) begin
					KCTRL[1] <= DBUS[1];
				end
				// For interrupt enable/disable
				KCTRL[4] <= DBUS[4];
			end
			
			// if (KDATA[KEY_BITS-1:0] != prev_data[KEY_BITS-1:0]) begin
				
			// end
			KDATA <= (INPUT);		// Physical input from board
		end
	end

	// always @ (negedge CLK) begin
	// 	prev_data <= KDATA;
	// end

	assign DBUS = 	rdData  ? {{(BITS-KEY_BITS){1'b0}}, ~(KDATA[KEY_BITS-1:0])}
				:	rdCtrl  ? KCTRL[BITS-1:0]
							:	{BITS{1'bz}};

	assign INTR = (KCTRL[0]) && (KCTRL[4]);

endmodule
/**
•KDATA register at 0xFFFFF080
–Current state of KEY[3:0]
–Writes to these bits are ignored
•KCTRL (control/status) register at 0xFFFFF084
–Bit 0 is the Ready bit
	•Becomes 1 if change in KDATA state detected
	•A read from KDATA changes it to 0
	•Writes to this bit are ignored
–Bit 1 is the Overrun bit
	•Set to 1 if Ready bit still 1 when KDATA changes
	•Writing a zero to this bit changes it to zero, writing a 1 is ignored
–Bit 4 is the IE bit
	•If 0, KEY device does not generate interrupts
	•Can be both read and written
–Start the device off with KCTRL all-zeros!
**/

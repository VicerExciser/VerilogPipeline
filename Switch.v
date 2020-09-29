`define TENMS 	1000000 	// 10 milliseconds in ticks for 100 MHz clock (debounce stabilization period)
// `define TENMS 	500000	// 10 milliseconds in ticks for 50 MHz clock (debounce stabilization period)
//`define MS 	100000 	// Millisecond in ticks for 100 MHz clock
`define MS 96000 	// Ms for 96 MHz PLL
// `define MS 	50000	// Millisecond in ticks for 50 MHz clock

module Switch(INPUT,ABUS,DBUS,WE,INTR,CLK,RST);
	parameter BITS;
	parameter SW_BITS;
	parameter BASE;
	
	parameter SDATA_ADDR = BASE; 		// 0xFFFFF090;
	parameter SCTRL_ADDR = BASE + 4;	// 0xFFFFF094;

	input wire [SW_BITS-1:0] INPUT;
	input wire [BITS-1:0] ABUS;
	inout wire [BITS-1:0] DBUS;
	input wire WE;
	input wire CLK;
	input wire RST;
	output wire INTR;

	reg [SW_BITS-1:0] SDATA;	// Debounced value of SW
	reg [BITS-1:0] SCTRL;
	reg [SW_BITS-1:0] prev_data;
	reg [SW_BITS-1:0] raw_data;	// Non-stable raw value of SW input
	reg save_raw;
	reg toggle_save_raw;
	reg save_debounced;
	reg toggle_save_debounced;

	wire selData = (ABUS == SDATA_ADDR);
	wire selCtrl = (ABUS == SCTRL_ADDR);
	wire rdData = selData && (!WE);
	wire wrCtrl = selCtrl && WE;
	wire rdCtrl = selCtrl && (!WE);

	integer tick_cnt = 0;
	integer debounce_cnt = 0;

	always @ (posedge CLK or posedge RST) begin
		raw_data <= INPUT;		// Physical input from board
		if (RST) begin
			SCTRL <= {BITS{1'b0}};
			toggle_save_raw = 1'b0;
			toggle_save_debounced = 1'b0;
		end
		else begin
			if (wrCtrl) begin
				// Clearing the Overrun bit is allowed (but not writing a 1 to it)
				if (DBUS[1] == 1'b0) begin
					SCTRL[1] <= DBUS[1];
				end
				// Write passed in value to the IE bit for enabling/disabling SW interrupts
				SCTRL[4] <= DBUS[4];
			end
			else if (rdData) begin
				// A read from SDATA will clear the Ready bit
				SCTRL[0] <= 1'b0;
			end

			if (tick_cnt >= `MS) begin
				// Wrap counter back to 0 to begin measuring next 1ms period
				tick_cnt = 0;
				// Verify raw SW value has not changed over the last 10ms
				if (raw_data == prev_data) begin
					debounce_cnt = debounce_cnt + 1;
				end
				else begin
					// 10ms period of consecutive same value SW readings not met; restart debounce counter
					debounce_cnt = 0;
				end
				// Set flag to save last raw input value every 1ms
				toggle_save_raw = 1'b1;

				// Debounce counter will reach 10 after the raw SW value has been stable for 10ms
				if (debounce_cnt == 10) begin
					debounce_cnt = 0;
					// Raw value is now the new debounced SW value, SDATA is old
					if (SDATA != raw_data) begin
						// Ready bit set when change in SDATA detected; if already set, then set the Overrun bit
						if 	 (SCTRL[0] == 1'b1) SCTRL[1] <= 1'b1;
						else  SCTRL[0] <= 1'b1;
					end
					toggle_save_debounced = 1'b1;
				end
			end
			else begin
				tick_cnt = tick_cnt + 1;
				toggle_save_raw = 1'b0;
				toggle_save_debounced = 1'b0;
			end
		end
	end

	always @ (negedge CLK or posedge RST) begin
		if (RST) begin
			save_raw = 1'b1;
			save_debounced = 1'b1;
		end
		else begin
			if (toggle_save_raw) save_raw = 1'b1;
			if (save_raw) begin
				prev_data <= raw_data; 
				save_raw = 1'b0;
			end
			if (toggle_save_debounced) save_debounced = 1'b1;
			if (save_debounced) begin
				SDATA <= raw_data;
				save_debounced = 1'b0;
			end
		end
	end

	assign DBUS = 	rdData  ? {{(BITS-SW_BITS){1'b0}}, SDATA[SW_BITS-1:0]}
				:	rdCtrl  ? SCTRL[BITS-1:0]
				:			 {BITS{1'bz}};

	assign INTR = (SCTRL[0]) && (SCTRL[4]);

endmodule

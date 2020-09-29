//`define MS 	100000 	// Millisecond in ticks for 100 MHz clock
// `define MS 	50000	// Millisecond in ticks for 50 MHz clock
`define MS 96000 	// Ms for 96 MHz PLL

module Timer(ABUS,DBUS,WE,INTR,CLK,LOCK,RST);
	parameter BITS;
  	parameter BASE;

	input wire [(BITS-1):0] ABUS;
	inout wire [(BITS-1):0] DBUS;
	input wire WE,CLK,LOCK,RST;
	output wire INTR;

	parameter TCNT_ADDR 	= BASE; 	// 32'hFFFFF100;
	parameter TLIM_ADDR 	= BASE+4;	// 32'hFFFFF104;
	parameter TCTL_ADDR 	= BASE+8;	// 32'hFFFFF108;

	reg [(BITS-1):0] TCNT;	// Read/Write
	reg [(BITS-1):0] TLIM;	// Read/Write
	reg [(BITS-1):0] TCTL;	// Same bits as KCTRL and SCTRL

	// wire selCtl=(ABUS==BASE);
	wire selCtl = (ABUS==TCTL_ADDR);
	wire wrCtl= selCtl && WE;
	wire rdCtl= selCtl && (!WE);

	wire selCnt = (ABUS==TCNT_ADDR);
	wire wrCnt = selCnt && WE;
	wire rdCnt = selCnt && (!WE);

	wire selLim = (ABUS==TLIM_ADDR);
	wire wrLim = selLim && WE;
	wire rdLim = selLim && (!WE);

	wire limitEn = TLIM > {BITS{1'b0}};
	wire limitMet = limitEn && (TCNT >= (TLIM - 1)); //(TCNT[(BITS-1):0] == (TLIM[(BITS-1):0]-1));

	assign DBUS = 
		rdCtl ? TCTL[(BITS-1):0] :
		rdCnt ? TCNT[(BITS-1):0] :
		rdLim ? TLIM[(BITS-1):0] :
     /* default */ {BITS{1'bz}};


	reg [31:0] timer_cnt;// = 32'h0;

	always @ (posedge CLK or posedge RST) begin
		if (RST) begin
			TCNT[(BITS-1):0] <= {BITS{1'b0}};
			TLIM[(BITS-1):0] <= {BITS{1'b0}};
			TCTL[(BITS-1):0] <= {BITS{1'b0}};
			timer_cnt <= 32'h0;
		end
		else begin 
			if (timer_cnt >= `MS) begin 
				// Increment TCNT every 1ms
				TCNT <= TCNT + 1;
				timer_cnt <= 0;
			end
			else begin
				timer_cnt <= timer_cnt + 1;
			end

			if (limitMet) begin
				// Wrap counter back to 0
				TCNT[(BITS-1):0] <= {BITS{1'b0}};
				// Set Ready bit (or Overflow if Ready already set)
				if (TCTL[0] == 1'b0) begin
					TCTL[0] <= 1'b1;	// Set Ready bit
				end
				else begin
					TCTL[1] <= 1'b1;	// Set Overflow bit
				end
			end

			if (wrCnt) begin
				TCNT <= DBUS;
			end
			else if (wrCtl) begin
				if (DBUS[0] == 1'b0) begin
					TCTL[0] <= 1'b0;
				end
				if (DBUS[1] == 1'b0) begin
					TCTL[1] <= 1'b0;
				end
				TCTL[4] <= DBUS[4];	// IE bit
			end
			else if (wrLim) begin
				TLIM <= DBUS;
				TCNT <= {BITS{1'b0}};	// reseting counter when limit updated
				timer_cnt <= 0;
			end
			
		end
		
	end

	assign INTR = (TCTL[0]) && (TCTL[4]);

endmodule 
	
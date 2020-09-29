module IO(ABUS,DBUS,WE,INTR,CLK,RST);
	parameter BITS;

	input wire [(BITS-1):0] ABUS;
	inout wire [(BITS-1):0] DBUS;
	input wire WE;
	input wire CLK;
	input wire RST;
	output wire INTR;

	parameter HEX_ADDR 		= 32'hFFFFF000;
	parameter LEDR_ADDR 	= 32'hFFFFF020;
	parameter KDATA_ADDR 	= 32'hFFFFF080;
	parameter KCTRL_ADDR 	= 32'hFFFFF084;
	parameter SDATA_ADDR 	= 32'hFFFFF090;
	parameter SCTRL_ADDR 	= 32'hFFFFF094;
	parameter TCNT_ADDR 	= 32'hFFFFF100;
	parameter TLIM_ADDR 	= 32'hFFFFF104;
	parameter TCTL_ADDR 	= 32'hFFFFF108;

	reg [(BITS-1):0] HDATA;	// Read/Write
	reg [(BITS-1):0] LDATA;	// Read/Write
	reg [(BITS-1):0] KDATA;	// Read only  <-- should this be only 4 bits?
	reg [(BITS-1):0] KCTRL;	// Can only Write to bits 1 and 4
	reg [(BITS-1):0] SDATA;	// Read only
	reg [(BITS-1):0] SCTRL;	// Same as bits for KCTRL
	reg [(BITS-1):0] TCNT;	// Read/Write
	reg [(BITS-1):0] TLIM;	// Read/Write
	reg [(BITS-1):0] TCTL;	// Same bits as KCTRL and SCTRL

	/*  Each device has an IRQ signal:  assign IRQ = Ready && IE;  */

	wire KEY_IRQ = (KCTRL[0]) && (KCTRL[4]);
	wire SW_IRQ = (SCTRL[0]) && (SCTRL[4]);
	wire TIMER_IRQ = (TCTL[0]) && (TCTL[4]);

	assign INTR = KEY_IRQ | SW_IRQ | TIMER_IRQ;

	wire rdHex = (ABUS == HEX_ADDR) && (!WE);
	wire wrHex = (ABUS == HEX_ADDR) && WE;
	wire rdLed = (ABUS == LEDR_ADDR) && (!WE);
	wire wrLed = (ABUS == LEDR_ADDR) && WE;
	wire rdKdata = (ABUS == KDATA_ADDR) && (!WE);
	wire rdKctrl = (ABUS == KCTRL_ADDR) && (!WE);
	wire wrKctrl = (ABUS == KCTRL_ADDR) && WE;
	wire rdSdata = (ABUS == SDATA_ADDR) && (!WE);
	wire rdSctrl = (ABUS == SCTRL_ADDR) && (!WE);
	wire wrSctrl = (ABUS == SCTRL_ADDR) && WE;
	wire rdTcnt = (ABUS == TCNT_ADDR) && (!WE);
	wire wrTcnt = (ABUS == TCNT_ADDR) && WE;
	wire rdTlim = (ABUS == TLIM_ADDR) && (!WE);
	wire wrTlim = (ABUS == TLIM_ADDR) && WE;
	wire rdTctl = (ABUS == TCTL_ADDR) && (!WE);
	wire wrTctl = (ABUS == TCTL_ADDR) && WE; 


	always @ (posedge CLK or posedge RST) begin
		if (RST) begin
			KCTRL 	<= {BITS{1'b0}};
			SCTRL 	<= {BITS{1'b0}};
			TCTL 	<= {BITS{1'b0}};
		end
		else if (WE) begin 
			case (ABUS)
				HEX_ADDR : 
			endcase
			if (rdHex) begin
				
			end
			else if (wrHex)
		end 
		else begin
			if (rdKdata) begin
				KCTRL[0] <= 1'b0;
			end
			else if (rdSdata) begin
				SCTRL[0] <= 1'b0;
			end
			else if (rdT)
		end
	end

	always 

	assign DBUS = (!WE) ? 
		(ABUS==LEDR_ADDR) ? {(BITS-10){1'b0}, LDATA[9:0]} :
		(ABUS==HEX_ADDR) ? {(BITS-24){1'b0}, HDATA[23:0]} :
		(ABUS==KDATA_ADDR) ? KDATA[(BITS-1):0] :
		(ABUS==KCTRL_ADDR) ? ... :
		(ABUS==SDATA_ADDR) ? SDATA[(BITS-1):0] :
		(ABUS==SCTRL_ADDR) ? ... :
		(ABUS==TCNT_ADDR) ? TCNT[(BITS-1):0] :
		(ABUS==TLIM_ADDR) ? ... :
		(ABUS==TCTL_ADDR) ? ... :
		/* default */ {BITS{1'bz}};










endmodule
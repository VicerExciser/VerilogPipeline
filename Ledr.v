module Ledr(ABUS,DBUS,WE,CLK,RST);
	parameter BITS;
	parameter LED_BITS;
	parameter BASE;

	parameter LEDR_ADDR = BASE;	// 32'hFFFFF020;

	input wire [(BITS-1):0] ABUS;
	inout wire [(BITS-1):0] DBUS;
	input wire WE;
	input wire CLK;
	input wire RST;

	reg [(LED_BITS-1):0] LDATA;	// Read/Write (10-bits)

	wire selLedr = (ABUS == BASE);

	always @ (posedge CLK or posedge RST) begin
		if (RST) begin
			LDATA <= {LED_BITS{1'b0}};
		end
		else begin
			if (selLedr && WE) begin
				LDATA <= DBUS[(LED_BITS-1):0];
			end
		end
	end

	assign DBUS = ((!WE) && selLedr) ? {{(BITS-LED_BITS){1'b0}}, LDATA[(LED_BITS-1):0]}
			: {BITS{1'bz}};

endmodule

module Hex(ABUS,DBUS,WE,CLK,RST); //,OUTLO,OUTHI);
	parameter BITS;
	parameter HEX_BITS;	// 	= 24;
	parameter BASE;
	
	parameter HEX_ADDR 	= BASE; //32'hFFFFF000;

	input wire [(BITS-1):0] ABUS;
	inout wire [(BITS-1):0] DBUS;
	input wire WE;
	input wire CLK;
	input wire RST;
	// output wire [20:0] OUTLO;
	// output wire [20:0] OUTHI;

	reg [(HEX_BITS-1):0] HDATA;	// Read/Write (24-bits)
	// wire [6:0] ss0;
	// wire [6:0] ss1;
	// wire [6:0] ss2;
	// wire [6:0] ss3;
	// wire [6:0] ss4;
	// wire [6:0] ss5;
	wire selHex = //(ABUS == BASE);
			(ABUS >= BASE) && (ABUS < (BASE + BITS));
	/* Valid hex addr range --> [FFFFF000:FFFFF020)

	// function [6:0] translate (input [3:0] raw);
	// 	begin
	// 		translate = (raw == 4'h0) ? 7'b1000000 :
	// 					(raw == 4'h1) ? 7'b1111001 :
	// 					(raw == 4'h2) ? 7'b0100100 :
	// 					(raw == 4'h3) ? 7'b0110000 :
	// 					(raw == 4'h4) ? 7'b0011001 :
	// 					(raw == 4'h5) ? 7'b0010010 :
	// 					(raw == 4'h6) ? 7'b0000010 :
	// 					(raw == 4'h7) ? 7'b1111000 :
	// 					(raw == 4'h8) ? 7'b0000000 :
	// 					(raw == 4'h9) ? 7'b0010000 :
	// 					(raw == 4'hA) ? 7'b0001000 :
	// 					(raw == 4'hb) ? 7'b0000011 :
	// 					(raw == 4'hc) ? 7'b1000110 :
	// 					(raw == 4'hd) ? 7'b0100001 :
	// 					(raw == 4'he) ? 7'b0000110 :
	// 					/*raw == 4'hf*/ //7'b0001110 ;
	// 	end
	// endfunction

	always @ (posedge CLK or posedge RST) begin
		if (RST) begin
			HDATA <= {HEX_BITS{1'b0}};
		end
		else begin
			if (selHex && WE) begin
				HDATA <= DBUS[(HEX_BITS-1):0];
			end
		end
	end

// 	assign ss0 = translate(HDATA[3:0]);
// 	assign ss1 = translate(HDATA[7:4]);
// 	assign ss2 = translate(HDATA[11:8]);
// //	assign OUTLO = (ss2 << 8) + (ss1 << 4) + ss0;
// 	assign OUTLO = {ss2,ss1,ss0};
// 	assign ss3 = translate(HDATA[15:12]);
// 	assign ss4 = translate(HDATA[19:16]);
// 	assign ss5 = translate(HDATA[23:20]);
// //	assign OUTHI = (ss5 << 8) + (ss4 << 4) + ss3;
// 	assign OUTHI = {ss5,ss4,ss3};

	assign DBUS = ((!WE) && selHex) ? {{(BITS-HEX_BITS){1'b0}}, HDATA[(HEX_BITS-1):0]}
			: {BITS{1'bz}};

endmodule

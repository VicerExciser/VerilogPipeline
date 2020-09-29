module KeyTest(
  input        CLOCK_50,
  input        RESET_N,
  input  [3:0] KEY
);

parameter DBITS    = 32;
wire [(DBITS-1):0] abus;
wire [(DBITS-1):0] dbus;
wire clk;
wire rst;
wire we;
wire intr_key;

assign clk = CLOCK_50;
assign rst = RESET_N;
assign abus = 32'hFFFFF080;
assign dbus = 32'h0;
assign we = 1'b0;
assign intr_key = 1'b0;


//always @ (posedge RESET_N) begin



Key #(.BITS(DBITS), .BASE(32'hFFFFF080)) key(
	.ABUS(abus), .DBUS(dbus), .WE(we),
	.INTR(intr_key),
	.CLK(CLOCK_50)
);

endmodule
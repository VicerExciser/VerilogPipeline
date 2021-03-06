module Project(
  input        CLOCK_50,
  input        RESET_N,
  input  [3:0] KEY,
  input  [9:0] SW,
  output [6:0] HEX0,
  output [6:0] HEX1,
  output [6:0] HEX2,
  output [6:0] HEX3,
  output [6:0] HEX4,
  output [6:0] HEX5,
  output [9:0] LEDR
);

  parameter DBITS    = 32;
  parameter INSTSIZE = 32'd4;
  parameter INSTBITS = 32;
  parameter REGNOBITS = 4;
  parameter REGWORDS = (1 << REGNOBITS);
  parameter IMMBITS  = 16;
  parameter STARTPC  = 32'h100;
  parameter MSB_IDX = INSTBITS-1;

  //parameter STARTSYSSTACK = 32'hF000;
  parameter ADDRHANDLER = 32'h2000; //32'h10; // Single hardcoded interrupt handler address, will change later

  parameter ADDRHEX  = 32'hFFFFF000;
  parameter ADDRLEDR = 32'hFFFFF020;
  parameter ADDRKEY  = 32'hFFFFF080;
  parameter ADDRSW   = 32'hFFFFF090;
  parameter ADDRTIME = 32'hFFFFF100;

//  parameter IMEMINITFILE = "Test.mif";
   parameter IMEMINITFILE = "fmedian2.mif";
	// parameter IMEMINITFILE = "newisatest.mif";
//	parameter IMEMINITFILE = "orgtest.mif";
//  parameter IMEMINITFILE = "timertest.mif";
//  parameter IMEMINITFILE = "keytest.mif";
//  parameter IMEMINITFILE = "switchtest.mif";
//parameter IMEMINITFILE = "switchtest2.mif";
//  parameter IMEMINITFILE = "xmas.mif";
  
  parameter IMEMADDRBITS = 16;
  parameter IMEMWORDBITS = 2;
  parameter IMEMWORDS	 = (1 << (IMEMADDRBITS - IMEMWORDBITS));
  parameter DMEMADDRBITS = 16;
  parameter DMEMWORDBITS = 2;
  parameter DMEMWORDS	 = (1 << (DMEMADDRBITS - DMEMWORDBITS));
   
  parameter OP1BITS  = 6;
  parameter OP1_ALUR = 6'b000000;   // Used for EXT-type instructions
  parameter OP1_BEQ  = 6'b001000;
  parameter OP1_BLT  = 6'b001001;
  parameter OP1_BLE  = 6'b001010;
  parameter OP1_BNE  = 6'b001011;
  parameter OP1_JAL  = 6'b001100;
  parameter OP1_LW   = 6'b010010;
  parameter OP1_SW   = 6'b011010;
  parameter OP1_ADDI = 6'b100000;
  parameter OP1_ANDI = 6'b100100;
  parameter OP1_ORI  = 6'b100101;
  parameter OP1_XORI = 6'b100110;
  
  // Add parameters for secondary opcode values 
  /* OP2 */
  parameter OP2BITS  = 8;
  parameter OP2_EQ   = 8'b00001000;
  parameter OP2_LT   = 8'b00001001;
  parameter OP2_LE   = 8'b00001010;
  parameter OP2_NE   = 8'b00001011;
  parameter OP2_ADD  = 8'b00100000;
  parameter OP2_AND  = 8'b00100100;
  parameter OP2_OR   = 8'b00100101;
  parameter OP2_XOR  = 8'b00100110;
  parameter OP2_SUB  = 8'b00101000;
  parameter OP2_NAND = 8'b00101100;
  parameter OP2_NOR  = 8'b00101101;
  parameter OP2_NXOR = 8'b00101110;
  parameter OP2_RSHF = 8'b00110000;
  parameter OP2_LSHF = 8'b00110001;

  // System instruction opcode values
  // parameter SYSOPBITS = OP1BITS;
  parameter OP1_SYS   = 6'h3F;  // i.e., `assign is_sys_op = (inst_FE[MSB_IDX:(MSB_IDX-SYSOPBITS)] == OP1_SYS);`
  parameter OP2_RETI  = 8'h1;
  parameter OP2_RSR   = 8'h2;
  parameter OP2_WSR   = 8'h3;
  parameter PCSREGNO  = 4'b0000;
  parameter IHAREGNO  = 4'b0001;
  parameter IRAREGNO  = 4'b0010;
  parameter IDNREGNO  = 4'b0011;

  parameter NOP = {INSTBITS{1'b0}};
  
  parameter HEXBITS  = 24;
  parameter LEDRBITS = 10;
  parameter KEYBITS = 4;
  parameter SWBITS = 10;
 
  //*** PLL ***//
  // The reset signal comes from the reset button on the DE0-CV board
  // RESET_N is active-low, so we flip its value ("reset" is active-high)
  // The PLL is wired to produce clk and locked signals for our logic
  wire clk;
  wire locked;
  wire reset;

  NineSixPll myPll( 	// 96MHz output clock
	 .refclk	(CLOCK_50),
    .rst     	(!RESET_N),
    .outclk_0 	(clk),
    .locked   	(locked)
  );

  assign reset = !locked;

  // System registers & signals
  reg [DBITS-1:0] PCS;  // Processor Control & Status (bit 0 is IE)   # 0000
  reg [DBITS-1:0] IHA;  // Interrupt Handler Address                  # 0001
  reg [DBITS-1:0] IRA;  // Interrupt Return Address                   # 0010
  reg [DBITS-1:0] IDN;  // Interrupt Device Number                    # 0011
  // NOTE: SSP (System Stack Pointer) is R11 in the general register file
  // reg is_reti_ID;
  wire is_reti_ID_w;
  wire IE;  // Interrupt-enable bit value in PCS
  wire IRQ; // Processor Interrupt Request signal (OR all I/O device IRQs)
 // reg IRQ_r;
  // These three device buses get assigned in the MEM stage:
  wire [DBITS-1:0] abus;  // Address bus
  tri [DBITS-1:0] dbus;   // Bidirectional data bus
  wire we;                // Write enable signal

  wire intr_keys;
  wire intr_sws;
  wire intr_timer;
  wire [3:0] intnum;  // Priority encoder for IDN value

  //*** FETCH STAGE ***//
  // The PC register and update logic
  wire [DBITS-1:0] pcplus_FE;
  wire [DBITS-1:0] pcpred_FE;
  wire [INSTBITS-1:0] inst_FE_w;
  wire stall_pipe;        // Stall signal feedback
  wire mispred_EX_w;      // Jump to new PC signal feedback
  wire jump_stall;        // A Branch or JAL inst dtetected in ID/RR stage
  wire [DBITS-1:0] pcgood_EX_w;
  
  reg [DBITS-1:0] pcgood_EX;  // Branch taken/JAL new PC
  reg [DBITS-1:0] PC_FE;
  reg [INSTBITS-1:0] inst_FE;
  reg [DBITS-1:0] latch_PC_FE;

  // I-MEM
  (* ram_init_file = IMEMINITFILE *)
  reg [DBITS-1:0] imem [IMEMWORDS-1:0];   // IMEM: 16384-entry, 32-bit memory
  reg mispred_EX;   // Whether or not to use predicted PC (PC+4), true for Branch taken or any JAL
  
  // This statement is used to initialize the I-MEM
  // during simulation using Model-Sim
  initial begin
//   $readmemh("test.hex", imem);
//	 // For fmedian2:
	  $readmemh("fmedian2.hex", imem);
	  $readmemh("fmedian2.hex", dmem);
//		$readmemh("orgtest.hex", imem);
//	  $readmemh("orgtest.hex", dmem);
//	  $readmemh("timertest.hex", imem);
//    $readmemh("timertest.hex", dmem);
//		$readmemh("keytest.hex", imem);
//		$readmemh("keytest.hex", dmem);
//		$readmemh("switchtest.hex", imem);
//		$readmemh("switchtest.hex", dmem);
//$readmemh("switchtest2.hex", imem);
//		$readmemh("switchtest2.hex", dmem);
	  // $readmemh("newisatest.hex", imem);
	  // $readmemh("newisatest.hex", dmem);
//		$readmemh("xmas.hex", imem);
//		$readmemh("xmas.hex", dmem);
  end
  
  assign inst_FE_w = imem[PC_FE[IMEMADDRBITS-1:IMEMWORDBITS]]; 	// imem[PC_FE[15:2]]

  // I/O devices
  // assign abus = memaddr_M;
  // assign we = wrmem_M;
  // assign dbus = wrmem_M ? wmemval_M : {DBITS{1'bz}};

  Key #(.BITS(DBITS), .KEY_BITS(KEYBITS), .BASE(ADDRKEY)) keys (
    .INPUT(KEY),
    .ABUS(abus),
    .DBUS(dbus),
    .WE(we),
    .INTR(intr_keys),
    .CLK(clk),
    .RST(reset)
  );
  Switch #(.BITS(DBITS), .SW_BITS(SWBITS), .BASE(ADDRSW)) switch (
    .INPUT(SW),
    .ABUS(abus),
    .DBUS(dbus),
    .WE(we),
    .INTR(intr_sws),
    .CLK(clk),
    .RST(reset)
  );
  Timer #(.BITS(DBITS), .BASE(ADDRTIME)) timer (
    .ABUS(abus),
    .DBUS(dbus),
    .WE(we),
    .INTR(intr_timer),
    .CLK(clk),
    .LOCK(locked),
    .RST(reset)
  );
  // Hex #(.BITS(DBITS), .HEX_BITS(HEXBITS), .BASE(ADDRHEX)) hex (
  //   .ABUS(abus),
  //   .DBUS(dbus),
  //   .WE(we),
  //   .CLK(clk),
  //   .RST(reset)
  // );
  // Ledr #(.BITS(DBITS), .LED_BITS(LEDRBITS), .BASE(ADDRLEDR)) ledr (
  //   .ABUS(abus),
  //   .DBUS(dbus),
  //   .WE(we),
  //   .CLK(clk),
  //   .RST(reset)
  // );

  // Interrupt controller
  assign intnum = 
    intr_timer  ? 4'h1:
    intr_keys   ? 4'h2:
    intr_sws    ? 4'h3:
                  4'hF;
  assign IE = PCS[0];
  assign IRQ = (!reset) && (IE && (intr_keys || intr_sws || intr_timer));
  

  always @ (posedge clk or posedge reset) 
    begin
      if (reset)
        begin
          PC_FE <= STARTPC;
          latch_PC_FE <= STARTPC;
        end
      // else if (is_reti_ID_w == 1'b1)
      //   begin
      //     PC_FE <= IRA;
      //     latch_PC_FE <= IRA;
      //   end
      else if (mispred_EX_w)
        begin
          PC_FE <= pcgood_EX_w;
          latch_PC_FE <= pcgood_EX_w;
        end
      else if (stall_pipe)
        begin
          PC_FE <= PC_FE;
          latch_PC_FE <= PC_FE;
        end
      else if (jump_stall)
        begin 
          PC_FE <= PC_FE;
          latch_PC_FE <= {DBITS{1'b0}};
        end 
      else
        begin 
          PC_FE <= pcpred_FE;
          latch_PC_FE <= pcpred_FE;
        end
    end

  // This is the value of "incremented PC", computed in the FE stage
  assign pcplus_FE = PC_FE + INSTSIZE;  // == PC + 4
  // This is the predicted value of the PC that we use to fetch the next instruction
  assign pcpred_FE = pcplus_FE;

  // FE_latch
  always @ (posedge clk or posedge reset) 
    begin
      if(reset)
        begin
          inst_FE <= {INSTBITS{1'b0}};
        end
      else
        begin
          if (stall_pipe)
            begin
              inst_FE <= inst_FE; // Stall the instruction, ID/RR stage will forward a NOP
            end
          else if (jump_stall || mispred_EX_w) // If JAL or Branch encountered in ID/RR or EX, or on interrupt request
            begin
              inst_FE <= NOP;	     // Insert bubble
            end
          else
            begin
              inst_FE <= inst_FE_w;
            end
          end
        end

  //*** DECODE STAGE ***//
  wire [OP1BITS-1:0] op1_ID_w;   // 6-bit OP identifier
  wire [OP2BITS-1:0] op2_ID_w;   // 8-bit OP identifier
  wire [IMMBITS-1:0] imm_ID_w;   // 16-bit immediate value
  wire [REGNOBITS-1:0] rd_ID_w; // 4-bit Rd specifier
  wire [REGNOBITS-1:0] rs_ID_w; // 4-bit Rs specifier
  wire [REGNOBITS-1:0] rt_ID_w; // 4-bit Rt specifier
  // Two read ports, always using rs and rt for register numbers
  wire [DBITS-1:0] regval1_ID_w;
  wire [DBITS-1:0] regval2_ID_w;
  wire [DBITS-1:0] sxt_imm_ID_w;
  wire is_br_ID_w;
  wire is_jmp_ID_w;
  wire rd_mem_ID_w;   // Read mem enable signal, grouped into ctrlsig_ID
  wire wr_mem_ID_w;   // Write mem enable signal, grouped into ctrlsig_ID
  wire wr_reg_ID_w;   // Write reg enable signal, grouped into ctrlsig_ID
  wire [4:0] ctrlsig_ID_w;
  wire [REGNOBITS-1:0] wregno_ID_w; // 4-bit
  wire wr_reg_EX_w;   // Write enable bit/signal for EX
  wire wr_reg_MEM_w;  // Write enable bit/signal for MEM
  // Declared here for stall check
  wire is_EXT_ID_w;
  wire wregno_match_rs;
  wire wregno_match_rt;
  wire stall_cond_1;
  wire stall_cond_2;
  wire stall_cond_3;
  wire stall_cond_4;

  wire sys_op_ID_w; // = (inst_FE[MSB_IDX:(MSB_IDX-OP1BITS)] == OP1_SYS);
  // wire is_reti_ID_w; 
  wire is_rsr_ID_w;                 // Uses Rd and Ss
  wire is_wsr_ID_w;                 // Uses Sd and Rs
  wire [REGNOBITS-1:0] ss_ID_w;     // System src regno
  wire [REGNOBITS-1:0] sd_ID_w;     // System dst regno
  wire [DBITS-1:0] sregval_ID_w;    // Value read from a system register
  reg [DBITS-1:0] last_valid_pcgood;

  // Register file
  reg [DBITS-1:0] PC_ID;
  //   reg [31:0] regs [15:0];
  reg [DBITS-1:0] regs [REGWORDS-1:0];  // DPRF: a 16-entry, 32-bit memory (register file)
  reg signed [DBITS-1:0] regval1_ID;
  reg signed [DBITS-1:0] regval2_ID;  // 32-bit values
  reg signed [DBITS-1:0] immval_ID;
  reg [OP1BITS-1:0] op1_ID;   // 6-bit OP identifier
  reg [OP2BITS-1:0] op2_ID;   // 8-bit OP identifier
  reg [4:0] ctrlsig_ID;
  reg [REGNOBITS-1:0] wregno_ID;    // Destination reg specifier
  // Declared here for stall check
  reg [REGNOBITS-1:0] wregno_EX;
  reg [REGNOBITS-1:0] wregno_MEM;
  reg [INSTBITS-1:0] inst_ID;   // 32-bit instruction

  // Specify decoded instruction signals such as op*_ID_w, imm_ID_w, r*_ID_w			
  assign op1_ID_w = inst_FE[31:26]; // 6-bit OP1 specifier
  assign op2_ID_w = inst_FE[25:18]; // 8-bit OP2 specifier
  assign imm_ID_w = inst_FE[23:8];  // 16-bit immediate val
  assign sys_op_ID_w = (op1_ID_w == OP1_SYS);
  assign is_reti_ID_w = (sys_op_ID_w && (op2_ID_w == OP2_RETI)); // : 1'b0;
  assign is_rsr_ID_w = (sys_op_ID_w && (op2_ID_w == OP2_RSR));
  assign is_wsr_ID_w = (sys_op_ID_w && (op2_ID_w == OP2_WSR));
  assign ss_ID_w = is_rsr_ID_w ? inst_FE[13:10] : 4'hF;
  assign rd_ID_w = is_rsr_ID_w ? inst_FE[17:14] : inst_FE[11:8];   // 4-bit Rd specifier
  assign sd_ID_w = is_wsr_ID_w ? inst_FE[17:14] : 4'hF;
  assign rs_ID_w = is_wsr_ID_w ? inst_FE[13:10] : inst_FE[7:4];    // 4-bit Rs specifier
  assign rt_ID_w = inst_FE[3:0];    // 4-bit Rt specifier
  assign wregno_ID_w = (op1_ID_w == OP1_ALUR) || is_rsr_ID_w ? rd_ID_w : (is_br_ID_w || wr_mem_ID_w) ? 4'b0000 : rt_ID_w;  
  // ^ 4-bit DR: Rt for OP1 (not Branch or SW), Rd for OP2, and 0000 for Branch or SW instructions

  // Read register values
  assign sregval_ID_w = is_rsr_ID_w ?
        ((ss_ID_w == PCSREGNO) ? PCS[DBITS-1:0]
      : (ss_ID_w == IHAREGNO) ? IHA[DBITS-1:0]
      : (ss_ID_w == IRAREGNO) ? IRA[DBITS-1:0]
      : (ss_ID_w == IDNREGNO) ? IDN[DBITS-1:0]
      : 32'h0) : 32'h0;
  assign regval1_ID_w = regs[rs_ID_w];   // A (32-bit, Rs == SR1)
  assign regval2_ID_w = is_rsr_ID_w ? sregval_ID_w : regs[rt_ID_w];   // B (32-bit, Rt == SR2)
  // ^ regval2_ID is passed straight through EX if not ALU op, 
  //   regval1_ID is sent through ALU, only ALU output is passed to MEM (will be lost if not a valid ALU op)

  // Sign extension for immediate value
  SXT mysxt (.IN(imm_ID_w), .OUT(sxt_imm_ID_w));
 
  assign is_br_ID_w = (op1_ID_w[OP1BITS-1:2] == 4'b0010);    
  assign is_jmp_ID_w = (op1_ID_w[OP1BITS-1:0] == OP1_JAL); 
  assign rd_mem_ID_w = (op1_ID_w[OP1BITS-1:0] == OP1_LW);
  assign wr_mem_ID_w = (op1_ID_w[OP1BITS-1:0] == OP1_SW);
  assign wr_reg_ID_w = !(is_br_ID_w || wr_mem_ID_w || is_wsr_ID_w || is_reti_ID_w);
  //  ^ if not branch or SW instruction, assert writeback to reg signal
  
  assign ctrlsig_ID_w = {is_br_ID_w, is_jmp_ID_w, rd_mem_ID_w, wr_mem_ID_w, wr_reg_ID_w};
  
  assign wregno_match_rs = (rs_ID_w[REGNOBITS-1:0] != 4'b0000) &&
                          ((rs_ID_w[REGNOBITS-1:0] == wregno_ID[REGNOBITS-1:0]) 
      								 || (rs_ID_w[REGNOBITS-1:0] == wregno_EX[REGNOBITS-1:0]) 
      								 || (rs_ID_w[REGNOBITS-1:0] == wregno_MEM[REGNOBITS-1:0])
      								 );
  assign wregno_match_rt = (rt_ID_w[REGNOBITS-1:0] != 4'b0000) &&
                          ((rt_ID_w[REGNOBITS-1:0] == wregno_ID[REGNOBITS-1:0]) 
      								 || (rt_ID_w[REGNOBITS-1:0] == wregno_EX[REGNOBITS-1:0]) 
      								 || (rt_ID_w[REGNOBITS-1:0] == wregno_MEM[REGNOBITS-1:0])
      								 );
							
  assign is_EXT_ID_w = (op1_ID_w[OP1BITS-1:0] == OP1_ALUR) && (op2_ID_w[OP2BITS-1:0] != {OP2BITS{1'b0}});

	/* If uses OP2 (an EXT type instruction) and any future destination reg matches either source reg (Rs or Rt) */
  assign stall_cond_1 = is_EXT_ID_w && (wregno_match_rs || wregno_match_rt);
  
  /* If current instruction in ID/RR or EX stage is a Branch or Jump (inject NOP bubble from Fetch) */
  assign stall_cond_2 = is_br_ID_w && (wregno_match_rs || wregno_match_rt);
  
  /* If current decoded instruction is SW and any future destination reg matches either source reg (Rs or Rt) */
  assign stall_cond_3 = wr_mem_ID_w && (wregno_match_rs || wregno_match_rt);
  
  /* If current decoded instruction is JAL, LW, or ALUI, only dependency checks needed for source reg Rs */
  assign stall_cond_4 = (is_jmp_ID_w || rd_mem_ID_w || op1_ID_w[OP1BITS-1]) && (wregno_match_rs);
  
  
  assign stall_pipe = stall_cond_1 || stall_cond_2 || stall_cond_3 || stall_cond_4;

  assign jump_stall = is_br_ID_w || is_jmp_ID_w;
  
  reg INTA;   // Signals that we are currently handling an interrupt; set on IRQ, cleared on RETI

  // Handling interrupts & system read/writes
  always @ (posedge clk or posedge reset) 
    begin
      if (reset)
        begin
          PCS <= {{(DBITS-1){1'b0}}, {1'b1}}; // Initialize with interrupts enabled
          IHA <= ADDRHANDLER;
          // TODO: ^ Assigned address will need to be multiplexed based on value of IDN
          IRA <= STARTPC;
          IDN <= {{(DBITS-4){1'b0}}, 4'hF};
          //IRQ_r <= 1'b0;
          INTA <= 1'b0;
        end
      else 
        begin
          if (!(is_wsr_ID_w==1'b1 && sd_ID_w==IRAREGNO))
            begin
              IRA <= last_valid_pcgood;
            end
          //IRQ_r <= IRQ;
          if (IRQ)// || IRQ_r)  // On an interrupt
            begin
              INTA <= 1'b1;
              PCS[1:0] <= {IE,1'b0};  // Disable interrupts, set OIE bit to previous IE value
              IDN <= {{(DBITS-4){1'b0}}, intnum};   // Put interrupting device ID into IDN
              //IRA <= pcpred_FE;// PC_FE != {DBITS{1'b0}} ? PC_FE : STARTPC; //last_valid_pcgood > STARTPC ? last_valid_pcgood : PC_ID  > STARTPC ? PC_ID : PC_FE  > STARTPC ? PC_FE : latch_PC_FE  > STARTPC ? latch_PC_FE : aluout_EX  > STARTPC ? aluout_EX : STARTPC;
              // IRA <= last_valid_pcgood;
				  //...
            end
          if (is_reti_ID_w)
            begin
              PCS[0] <= PCS[1];   // On RETI: IE <= OIE (restore Interrupt Enable bit to previous state)
              INTA <= 1'b0;
              //...  Elsewhere, the IRA is loaded into PC_FE
            end
          else if (is_wsr_ID_w)
            begin
              case (sd_ID_w)  
                // Write to a system register
                PCSREGNO : PCS <= regval1_ID_w;
                IHAREGNO : IHA <= regval1_ID_w;
                IRAREGNO : IRA <= regval1_ID_w;
                IDNREGNO : IDN <= regval1_ID_w;
              endcase
            end
        end
    end

  // ID_latch
  always @ (posedge clk or posedge reset) begin
    if(reset) 
      begin
        PC_ID	 <= {DBITS{1'b0}};
  		  inst_ID	 <= {INSTBITS{1'b0}};
        op1_ID	 <= {OP1BITS{1'b0}};
        op2_ID	 <= {OP2BITS{1'b0}};
        regval1_ID  <= {DBITS{1'b0}};
        regval2_ID  <= {DBITS{1'b0}};
        wregno_ID	 <= {REGNOBITS{1'b0}};
        ctrlsig_ID <= 5'h0;
        immval_ID <= {DBITS{1'b0}};
      end 
    else 
      begin
        PC_ID  <= !stall_pipe ? /*PC_FE*/ latch_PC_FE : {DBITS{1'b0}};
        inst_ID <= (!stall_pipe) ? inst_FE : NOP;
        op1_ID <= !stall_pipe ? op1_ID_w : {OP1BITS{1'b0}};
        op2_ID <= !stall_pipe ? op2_ID_w : {OP2BITS{1'b0}};
        regval1_ID <= !stall_pipe ? regval1_ID_w : {DBITS{1'b0}};   // A: regs[Rs] (32-bit register value)
        regval2_ID <= !stall_pipe ? regval2_ID_w : {DBITS{1'b0}};   // B: regs[Rt] (32-bit register value)
        wregno_ID <= !stall_pipe ? wregno_ID_w : {REGNOBITS{1'b0}};
        ctrlsig_ID <= !stall_pipe ? ctrlsig_ID_w : 5'h0;
        immval_ID <= !stall_pipe ? sxt_imm_ID_w : {DBITS{1'b0}};
      end
  end

  //*** AGEN/EXEC STAGE ***//

  wire is_br_EX_w;
  wire is_jmp_EX_w;
  // wire is_reti_EX_w;

  reg [INSTBITS-1:0] inst_EX; /* This is for debugging */
  reg br_cond_EX;
  reg [2:0] ctrlsig_EX;
  // Note that aluout_EX_r is declared as reg, but it is output signal from combi logic
  reg signed [DBITS-1:0] aluout_EX_r;
  reg [DBITS-1:0] aluout_EX;
  reg [DBITS-1:0] regval2_EX;

  // assign is_reti_EX_w

  always @ (op1_ID or regval1_ID or regval2_ID) 
    begin
      case (op1_ID)
        OP1_BEQ : br_cond_EX = (regval1_ID == regval2_ID);
        OP1_BLT : br_cond_EX = (regval1_ID < regval2_ID);
        OP1_BLE : br_cond_EX = (regval1_ID <= regval2_ID);
        OP1_BNE : br_cond_EX = (regval1_ID != regval2_ID);
        default : br_cond_EX = 1'b0;
      endcase
    end

  always @ (op1_ID or op2_ID or regval1_ID or regval2_ID or immval_ID) 
    begin
      if(op1_ID == OP1_ALUR)  // if OP1 == 6'b000000
        case (op2_ID)
  			  OP2_EQ	 : aluout_EX_r = {31'b0, regval1_ID == regval2_ID};
  			  OP2_LT	 : aluout_EX_r = {31'b0, regval1_ID < regval2_ID};
          OP2_LE   : aluout_EX_r = {31'b0, regval1_ID <= regval2_ID};
          OP2_NE   : aluout_EX_r = {31'b0, regval1_ID != regval2_ID};
          OP2_ADD  : aluout_EX_r = regval1_ID + regval2_ID;
          OP2_AND  : aluout_EX_r = regval1_ID & regval2_ID;
          OP2_OR   : aluout_EX_r = regval1_ID | regval2_ID;
          OP2_XOR  : aluout_EX_r = regval1_ID ^ regval2_ID;
          OP2_SUB  : aluout_EX_r = regval1_ID - regval2_ID;
          OP2_NAND : aluout_EX_r = ~(regval1_ID & regval2_ID);
          OP2_NOR  : aluout_EX_r = ~(regval1_ID | regval2_ID);
          OP2_NXOR : aluout_EX_r = ~(regval1_ID ^ regval2_ID);
          OP2_RSHF : aluout_EX_r = regval1_ID >>> regval2_ID;   // Sign-extended shift `>>>`
          OP2_LSHF : aluout_EX_r = regval1_ID <<< regval2_ID;   // Could also use `<<` for 0-padded left shift
  	      default	 : aluout_EX_r = {DBITS{1'b0}};
        endcase
      else if(op1_ID == OP1_LW || op1_ID == OP1_SW || op1_ID == OP1_ADDI)
        aluout_EX_r = regval1_ID + immval_ID;
      else if(op1_ID == OP1_ANDI)
        aluout_EX_r = regval1_ID & immval_ID;
      else if(op1_ID == OP1_ORI)
        aluout_EX_r = regval1_ID | immval_ID;
      else if(op1_ID == OP1_XORI)
        aluout_EX_r = regval1_ID ^ immval_ID;
      else
        aluout_EX_r = {DBITS{1'b0}};
    end

  assign is_br_EX_w = ctrlsig_ID[4];
  assign is_jmp_EX_w = ctrlsig_ID[3];
  assign wr_reg_EX_w = ctrlsig_ID[0];	  // wr_reg_ID
  
  assign mispred_EX_w = is_jmp_EX_w || (is_br_EX_w && br_cond_EX) || IRQ || is_reti_ID_w;  // Triggered when branch or JAL in ID/RR or EX, or on interrupt
  
  assign pcgood_EX_w = is_reti_ID_w ? IRA
		: (IRQ /*|| IRQ_r*/) ? IHA                              // PC = IHA if interrupt request signal active
      : is_jmp_EX_w ? regval1_ID + (4*immval_ID)              // PC = Rs + 4*sxt(Imm)
      : (is_br_EX_w && br_cond_EX) ? PC_ID + (4*immval_ID)    // PC = PC + 4 + 4*sxt(Imm) 
      : PC_FE;

  // EX_latch
  always @ (posedge clk or posedge reset) begin
    if(reset) 
      begin
	      inst_EX	 <= {INSTBITS{1'b0}};
        aluout_EX	 <= {DBITS{1'b0}};
        wregno_EX	 <= {REGNOBITS{1'b0}};
        ctrlsig_EX <= 3'h0;
        mispred_EX <= 1'b0;
		    pcgood_EX  <= {DBITS{1'b0}};
		    regval2_EX	<= {DBITS{1'b0}};
        last_valid_pcgood <= STARTPC;
      end 
    else 
      begin
        inst_EX <= inst_ID;
        aluout_EX <= is_jmp_EX_w ? PC_ID : aluout_EX_r;   // Write PC_ID to regs[wregno_EX] for JAL
        wregno_EX <= wregno_ID;
        ctrlsig_EX <= ctrlsig_ID[2:0];  // 3-bits: rd_mem, wr_mem, wr_reg
        mispred_EX <= mispred_EX_w;
        pcgood_EX <= pcgood_EX_w;
        regval2_EX <= regval2_ID;
        last_valid_pcgood <= (pcgood_EX_w != {DBITS{1'b0}}) && (!INTA) ? pcgood_EX_w : last_valid_pcgood;
        //PC_ID != NOP ? PC_ID : PC_FE != NOP ? PC_FE : pcpred_FE; //pcgood_EX; //inst_ID != NOP ? pcgood_EX_w : last_valid_pcgood;
      end
  end
  

  //*** MEM STAGE ***//

  wire rd_mem_MEM_w;
  wire wr_mem_MEM_w;

  // wire sel_keys;
  // wire sel_sws;
  wire rd_hex;
  wire wr_hex;
  wire rd_ledr;
  wire wr_ledr;
  // wire sel_timer;
  // wire sel_io_device;   // Active when the sxt_imm_ID_w holds a valid I/O device address for a SW/LW instruction
  
  wire [DBITS-1:0] memaddr_MEM_w;
  wire [DBITS-1:0] rd_val_MEM_w;
  wire [DBITS-1:0] wr_val_MEM_w;

  reg [INSTBITS-1:0] inst_MEM; /* This is for debugging */
  reg [DBITS-1:0] regval_MEM;  
  reg ctrlsig_MEM;
  // D-MEM
  (* ram_init_file = IMEMINITFILE *)
  reg [DBITS-1:0] dmem[DMEMWORDS-1:0];

  assign memaddr_MEM_w = aluout_EX;
  assign rd_mem_MEM_w = ctrlsig_EX[2];
  assign wr_mem_MEM_w = ctrlsig_EX[1];
  assign wr_reg_MEM_w = ctrlsig_EX[0];
  assign wr_val_MEM_w = regval2_EX;

  // assign sel_io_device = (wr_mem_MEM_w || rd_mem_MEM_w) && (
  //   (memaddr_MEM_w == ADDRHEX
  // );

  assign abus = memaddr_MEM_w;
  assign we = wr_mem_MEM_w;
  assign dbus = wr_mem_MEM_w ? wr_val_MEM_w : {DBITS{1'bz}};
  assign rd_hex = (!wr_mem_MEM_w) && (memaddr_MEM_w >= ADDRHEX) && (memaddr_MEM_w < ADDRLEDR);
  assign wr_hex = wr_mem_MEM_w && (memaddr_MEM_w >= ADDRHEX) && (memaddr_MEM_w < ADDRLEDR);
  assign rd_ledr = (!wr_mem_MEM_w) && (memaddr_MEM_w == ADDRLEDR);
  assign wr_ledr = wr_mem_MEM_w && (memaddr_MEM_w == ADDRLEDR);

  wire isio;
  assign isio = (abus >= ADDRHEX && abus < 32'hFFFFF120); //(ADDRTIME + 8));  // I/O Address range from 0xFFFFF000 to 0xFFFFF120

  // Read from D-MEM
  assign rd_val_MEM_w = (isio && !we) ? dbus :
      //(!rd_mem_MEM_w ||   // we || (memaddr_MEM_w == ADDRHEX) || (memaddr_MEM_w == ADDRLEDR) ||
      // (memaddr_MEM_w == ADDRKEY) ? {{(DBITS-KEYBITS){1'b0}}, ~KEY} :  // <-- old code since implementing Key device...still necessary>
			(memaddr_MEM_w == NOP)  ? {DBITS{1'b0}} :		// My addition to avoid illegal memory accesses
			dmem[memaddr_MEM_w[DMEMADDRBITS-1:DMEMWORDBITS]];

  // Write to D-MEM
  always @ (posedge clk) 
    begin
      if(wr_mem_MEM_w)
        dmem[memaddr_MEM_w[DMEMADDRBITS-1:DMEMWORDBITS]] <= wr_val_MEM_w;
    end

  // MEM_latch
  always @ (posedge clk or posedge reset) 
    begin
      if(reset) 
        begin
	        inst_MEM		<= {INSTBITS{1'b0}};
          regval_MEM  <= {DBITS{1'b0}};
          wregno_MEM  <= {REGNOBITS{1'b0}};
          ctrlsig_MEM <= 1'b0;
        end 
      else 
        begin
		      inst_MEM		<= inst_EX;
          regval_MEM  <= rd_mem_MEM_w ? rd_val_MEM_w : aluout_EX;
          wregno_MEM  <= wregno_EX;
          ctrlsig_MEM <= wr_reg_MEM_w; // ctrlsig_EX[0];   // wr_reg signal
        end
    end


  /*** WRITE BACK STAGE ***/ 

  wire wr_reg_WB_w; 
  // regs are already declared in the ID stage

  assign wr_reg_WB_w = ctrlsig_MEM;
  
  always @ (negedge clk or posedge reset) 
    begin
      if(reset) 
        begin
      		regs[0] <= {DBITS{1'b0}};
      		regs[1] <= {DBITS{1'b0}};
      		regs[2] <= {DBITS{1'b0}};
      		regs[3] <= {DBITS{1'b0}};
      		regs[4] <= {DBITS{1'b0}};
      		regs[5] <= {DBITS{1'b0}};
      		regs[6] <= {DBITS{1'b0}};
      		regs[7] <= {DBITS{1'b0}};
      		regs[8] <= {DBITS{1'b0}};
      		regs[9] <= {DBITS{1'b0}};
      		regs[10] <= {DBITS{1'b0}};
      		regs[11] <= {DBITS{1'b0}};
      		regs[12] <= {DBITS{1'b0}};
      		regs[13] <= {DBITS{1'b0}};
      		regs[14] <= {DBITS{1'b0}};
      		regs[15] <= {DBITS{1'b0}};
	      end 
      else if(wr_reg_WB_w) 
        begin
          regs[wregno_MEM] <= regval_MEM;
	      end
    end
  
  
  /*** I/O ***/
 // Create and connect HEX and LEDR devices and value registers
  reg [HEXBITS-1:0] HEX_out;
  reg [LEDRBITS-1:0] LEDR_out;
  // wire [20:0] seven_seg_0_2;
  // wire [20:0] seven_seg_3_5;

  Hex #(.BITS(DBITS), .HEX_BITS(HEXBITS), .BASE(ADDRHEX)) hex (
    .ABUS(abus),
    .DBUS(dbus),
    .WE(we),
    .CLK(clk),
    .RST(reset)
    // .OUTLO(seven_seg_0_2),
    // .OUTHI(seven_seg_3_5)
  );
  Ledr #(.BITS(DBITS), .LED_BITS(LEDRBITS), .BASE(ADDRLEDR)) ledr (
    .ABUS(abus),
    .DBUS(dbus),
    .WE(we),
    .CLK(clk),
    .RST(reset)
  );
  
	always @ (posedge clk or posedge reset) 
		begin
			if(reset)
				begin
					HEX_out <= 24'hFEDEAD;
					LEDR_out <= {LEDRBITS{1'b0}};
				end
			else			// wr_mem_MEM_w && (memaddr_MEM_w == ADDRHEX))
  //        // HEX_out <= regval2_EX[HEXBITS-1:0];
				begin
					// HEX_out <= abus==ADDRHEX /*rd_hex*/ ? regval2_EX[HEXBITS-1:0] /*dbus[HEXBITS-1:0]*/ : HEX_out;
          HEX_out <= rd_hex ? dbus[HEXBITS-1:0] : wr_hex ? regval2_EX[HEXBITS-1:0] : HEX_out;
					// LEDR_out <= abus==ADDRLEDR /*rd_ledr*/ ? regval2_EX[LEDRBITS-1:0] /*dbus[LEDRBITS-1:0]*/ : LEDR_out;
          LEDR_out <= rd_ledr ? dbus[LEDRBITS-1:0] : wr_ledr ? regval2_EX[LEDRBITS-1:0] : LEDR_out;
				end
		end
		
	// assign HEX0 = seven_seg_0_2[6:0];       // HEX_out[3:0];
	// assign HEX1 = seven_seg_0_2[13:7];      // HEX_out[7:4];
	// assign HEX2 = seven_seg_0_2[20:14];     // HEX_out[11:8];
	// assign HEX3 = seven_seg_3_5[6:0];       // HEX_out[15:12];
	// assign HEX4 = seven_seg_3_5[13:7];      // HEX_out[19:16];
	// assign HEX5 = seven_seg_3_5[20:14];     // HEX_out[23:20];
  SevenSeg ss5(.OUT(HEX5), .IN(HEX_out[23:20]), .OFF(1'b0));
  SevenSeg ss4(.OUT(HEX4), .IN(HEX_out[19:16]), .OFF(1'b0));
  SevenSeg ss3(.OUT(HEX3), .IN(HEX_out[15:12]), .OFF(1'b0));
  SevenSeg ss2(.OUT(HEX2), .IN(HEX_out[11:8]), .OFF(1'b0));
  SevenSeg ss1(.OUT(HEX1), .IN(HEX_out[7:4]), .OFF(1'b0));
  SevenSeg ss0(.OUT(HEX0), .IN(HEX_out[3:0]), .OFF(1'b0));
	
	assign LEDR = LEDR_out;

//  assign HEX0 = hex.HDATA[3:0];		//  <-- This reference to a device instance's internal data makes compiler cough up blood
//  // assign HEX0 = DBUS[]
//  assign HEX1 = hex.HDATA[7:4];
//  assign HEX2 = hex.HDATA[11:8];
//  assign HEX3 = hex.HDATA[15:12];
//  assign HEX4 = hex.HDATA[19:16];
//  assign HEX5 = hex.HDATA[23:20];

	
//   always @ (posedge clk or posedge reset)
//     begin
//       if(reset)
//         LEDR_out <= {LEDRBITS{1'b0}};
//       else if(wr_mem_MEM_w && (memaddr_MEM_w == ADDRLEDR))
//         LEDR_out <= regval2_EX[LEDRBITS-1:0];
// 		 // For debug:
// 		 // else
// 			// begin
// 			// 	LEDR_out <= {mispred_EX, is_jmp_EX_w, (is_br_EX_w && br_cond_EX), (inst_FE == NOP), 1'b0, stall_pipe, stall_cond_4, stall_cond_3, stall_cond_2, stall_cond_1};
				
// 					*	LEDR Debug Key
//   							[0]: ID/RR instruction is some EXT and its SR1(Rs) or SR2(Rt) matches a DR for EX, MEM, or WB
//   							[1]: ID/RR instruction is some Branch and its SR1(Rs) or SR2(Rt) matches a DR for EX, MEM, or WB
//   							[2]: ID/RR instruction is SW and its SR1(Rs) or SR2(Rt) matches a DR for EX, MEM, or WB
//   							[3]: ID/RR instruction is JAL, LW, or ALUI and its SR1(Rs) matches a DR for EX, MEM, or WB
//   							[4]: stall_pipe signal is asserted for one of the above reasons [0-3]
//                 [5]: Unused
//   							[6]: ID/RR instruction is a NOP bubble passed from inst_FE
//   							[7]: EX instruction is a Branch with its jump condition satified
//                 [8]: EX instruction is JAL
//                 [9]: mispred_EX signal is asserted for one of the above reasons [7-8]
// 					*
// //			end
//     end

//  assign LEDR = ledr.LDATA;    //LEDR_out;
  
endmodule


module SXT(IN, OUT);
  parameter IBITS = 16;
  parameter OBITS = 32;

  input  [IBITS-1:0] IN;
  output [OBITS-1:0] OUT;

  assign OUT = {{(OBITS-IBITS){IN[IBITS-1]}}, IN};
endmodule


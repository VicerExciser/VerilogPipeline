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
  parameter ADDRHEX  = 32'hFFFFF000;
  parameter ADDRLEDR = 32'hFFFFF020;
  parameter ADDRKEY  = 32'hFFFFF080;
  parameter ADDRSW   = 32'hFFFFF090;

  // parameter IMEMINITFILE = "Test.mif";
  parameter IMEMINITFILE = "fmedian2.mif";
  
  parameter IMEMADDRBITS = 16;
  parameter IMEMWORDBITS = 2;
  parameter IMEMWORDS	 = (1 << (IMEMADDRBITS - IMEMWORDBITS));
  parameter DMEMADDRBITS = 16;
  parameter DMEMWORDBITS = 2;
  parameter DMEMWORDS	 = (1 << (DMEMADDRBITS - DMEMWORDBITS));
   
  parameter OP1BITS  = 6;
  parameter OP1_ALUR = 6'b000000;
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
  
  parameter NOP = {INSTBITS{1'b0}};
  
  parameter HEXBITS  = 24;
  parameter LEDRBITS = 10;
  parameter KEYBITS = 4;

  parameter BTB_IDX_BITS = 10;
  parameter BTB_WIDTH = 44; // 10-bit index + 32-bit predicted PC + 1 bit for T/NT + 1 valid bit
  parameter BTB_DEPTH = 1 << BTB_IDX_BITS; // 1024 entries
 
 
  //*** PLL ***//
  // The reset signal comes from the reset button on the DE0-CV board
  // RESET_N is active-low, so we flip its value ("reset" is active-high)
  // The PLL is wired to produce clk and locked signals for our logic
  wire clk;
  wire locked;
  wire reset;

  Pll myPll(
    .refclk	(CLOCK_50),
    .rst     	(!RESET_N),
    .outclk_0 	(clk),
    .locked   	(locked)
  );

  assign reset = !locked;


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

  // Branch Target Buffer
  wire btb_row_w[BTB_WIDTH-1:0];
  wire btb_valid_w;
  wire btb_taken_w;
  wire btb_target_w[IMEMADDRBITS-1:0];
  reg [BTB_WIDTH-1:0] btb [BTB_DEPTH-1:0];  // 47-bit width: 14 for Look up, 32 for Predicted PC, 1 for Direction
  
  // This statement is used to initialize the I-MEM
  // during simulation using Model-Sim
 initial begin
//    $readmemh("test.hex", imem);
//	 // For fmedian2:
	 $readmemh("fmedian2.hex", imem);
	 $readmemh("fmedian2.hex", dmem);
 end
  
  assign inst_FE_w = imem[PC_FE[IMEMADDRBITS-1:IMEMWORDBITS]]; 	// imem[PC_FE[15:2]]

  // assign btb_index_w = PC_FE[15:2];
  assign btb_row_w = btb [PC_FE[6:2]]  // [BTB_WIDTH-2:BTB_WIDTH-BTB_IDX_BITS-1];
  // or...
  // assign btb_row_w = [BTB_WIDTH-1:BTB_WIDTH-BTB_IDX_BITS-1] btb[PC_FE[15:2]];
  // unsure of this syntax ^ need to test

  assign btb_valid_w = btb_row_w[BTB_WIDTH-1];
  assign btb_taken_w = btb[PC_FE[15:2]] [0];
  assign btb_target_w = btb_row_w[32:1];
  
  always @ (posedge clk or posedge reset) 
    begin
      if (reset)
        begin
          PC_FE <= STARTPC;
          latch_PC_FE <= STARTPC;
        end
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
  assign pcpred_FE = (btb_valid_w == 1'b0) || (btb_row_w[46:33]) ? pcplus_FE;

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
	  else if (jump_stall || mispred_EX_w) // If JAL or Branch encountered in ID/RR or EX
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
  assign rd_ID_w = inst_FE[11:8];   // 4-bit Rd specifier
  assign rs_ID_w = inst_FE[7:4];    // 4-bit Rs specifier
  assign rt_ID_w = inst_FE[3:0];    // 4-bit Rt specifier
  assign wregno_ID_w = (op1_ID_w == OP1_ALUR) ? rd_ID_w : (is_br_ID_w || wr_mem_ID_w) ? 4'b0000 : rt_ID_w;  
  // ^ 4-bit DR: Rt for OP1 (not Branch or SW), Rd for OP2, and 0000 for Branch or SW instructions

  // Read register values
  assign regval1_ID_w = regs[rs_ID_w];   // A (32-bit, Rs == SR1)
  assign regval2_ID_w = regs[rt_ID_w];   // B (32-bit, Rt == SR2)

  // Sign extension for immediate value
  SXT mysxt (.IN(imm_ID_w), .OUT(sxt_imm_ID_w));

 
  assign is_br_ID_w = (op1_ID_w[OP1BITS-1:2] == 4'b0010);    
  assign is_jmp_ID_w = (op1_ID_w[OP1BITS-1:0] == OP1_JAL); 
  assign rd_mem_ID_w = (op1_ID_w[OP1BITS-1:0] == OP1_LW);
  assign wr_mem_ID_w = (op1_ID_w[OP1BITS-1:0] == OP1_SW);
  assign wr_reg_ID_w = (!(is_br_ID_w)) && (!(wr_mem_ID_w));
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

  // assign forward_rs_ID_w = (rs_ID_w[REGNOBITS-1:0] == wregno_ID[REGNOBITS-1:0]) 
  //       && (is_EXT_ID_w || wr_mem_ID || rd_mem_ID_w || op1_ID_w[OP1BITS-1]);
  
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

  reg [INSTBITS-1:0] inst_EX; /* This is for debugging */
  reg br_cond_EX;
  reg [2:0] ctrlsig_EX;  // ctrlsig_ID = {is_br_ID, is_jmp_ID, rd_mem_ID, wr_mem_ID, wr_reg_ID};

  // Note that aluout_EX_r is declared as reg, but it is output signal from combi logic
  reg signed [DBITS-1:0] aluout_EX_r;
  reg [DBITS-1:0] aluout_EX;
  reg [DBITS-1:0] regval2_EX;

  // regval1 = Rs
  // regval2 = Rt

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
        begin
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
        end
      else if(op1_ID == OP1_LW || op1_ID == OP1_SW || op1_ID == OP1_ADDI)
        begin
          aluout_EX_r = regval1_ID + immval_ID;
        end
      else if(op1_ID == OP1_ANDI)
        begin
          aluout_EX_r = regval1_ID & immval_ID;
        end
      else if(op1_ID == OP1_ORI)
        begin
          aluout_EX_r = regval1_ID | immval_ID;
        end
      else if(op1_ID == OP1_XORI)
        begin
          aluout_EX_r = regval1_ID ^ immval_ID;
        end      
      else
        begin
          aluout_EX_r = {DBITS{1'b0}};
        end    
    end

  // assign rs_forward_EX_w = 

  assign is_br_EX_w = ctrlsig_ID[4];
  assign is_jmp_EX_w = ctrlsig_ID[3];
  assign wr_reg_EX_w = ctrlsig_ID[0];	  // wr_reg_ID
  
  assign mispred_EX_w = is_jmp_EX_w || (is_br_EX_w && br_cond_EX);  // Triggered when branch or JAL in ID/RR or EX
  assign pcgood_EX_w = is_jmp_EX_w ? regval1_ID + (4*immval_ID)     // PC = Rs + 4*sxt(Imm)
      : (is_br_EX_w && br_cond_EX) ? PC_ID + (4*immval_ID)          // PC = PC + 4 + 4*sxt(Imm) 
      : PC_FE;

  integer i;
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
        for (i=0; i<IMEMWORDS; i=i+1) btb[i] <= {BTB_WIDTH{1'b0}};  // initialize BTB
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
        // TODO: update Branch Target Buffer
      end
  end
  

  //*** MEM STAGE ***//

  wire rd_mem_MEM_w;
  wire wr_mem_MEM_w;
  
  wire [DBITS-1:0] memaddr_MEM_w;
  wire [DBITS-1:0] rd_val_MEM_w;

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
  // Read from D-MEM
  assign rd_val_MEM_w = (memaddr_MEM_w == ADDRKEY) ? {{(DBITS-KEYBITS){1'b0}}, ~KEY} :
									(memaddr_MEM_w == NOP)  ? {DBITS{1'b0}} :		// My addition to avoid illegal memory accesses
									dmem[memaddr_MEM_w[DMEMADDRBITS-1:DMEMWORDBITS]];

  // Write to D-MEM
  always @ (posedge clk) 
    begin
      if(wr_mem_MEM_w)
        dmem[memaddr_MEM_w[DMEMADDRBITS-1:DMEMWORDBITS]] <= regval2_EX;
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
  // Create and connect HEX register
  reg [23:0] HEX_out;
  
  SevenSeg ss5(.OUT(HEX5), .IN(HEX_out[23:20]), .OFF(1'b0));
  SevenSeg ss4(.OUT(HEX4), .IN(HEX_out[19:16]), .OFF(1'b0));
  SevenSeg ss3(.OUT(HEX3), .IN(HEX_out[15:12]), .OFF(1'b0));
  SevenSeg ss2(.OUT(HEX2), .IN(HEX_out[11:8]), .OFF(1'b0));
  SevenSeg ss1(.OUT(HEX1), .IN(HEX_out[7:4]), .OFF(1'b0));
  SevenSeg ss0(.OUT(HEX0), .IN(HEX_out[3:0]), .OFF(1'b0));
  
  always @ (posedge clk or posedge reset) 
    begin
      if(reset)
	      HEX_out <= 24'hFEDEAD;
	   else if(wr_mem_MEM_w && (memaddr_MEM_w == ADDRHEX))
         HEX_out <= regval2_EX[HEXBITS-1:0];
    end


  reg [9:0] LEDR_out;

  always @ (posedge clk or posedge reset)
    begin
      if(reset)
        LEDR_out <= {LEDRBITS{1'b0}};
      else if(wr_mem_MEM_w && (memaddr_MEM_w == ADDRLEDR))
        LEDR_out <= regval2_EX[LEDRBITS-1:0];
		 // For debug:
		 // else
			// begin
			// 	LEDR_out <= {mispred_EX, is_jmp_EX_w, (is_br_EX_w && br_cond_EX), (inst_FE == NOP), 1'b0, stall_pipe, stall_cond_4, stall_cond_3, stall_cond_2, stall_cond_1};
				
					/**	LEDR Debug Key
  							[0]: ID/RR instruction is some EXT and its SR1(Rs) or SR2(Rt) matches a DR for EX, MEM, or WB
  							[1]: ID/RR instruction is some Branch and its SR1(Rs) or SR2(Rt) matches a DR for EX, MEM, or WB
  							[2]: ID/RR instruction is SW and its SR1(Rs) or SR2(Rt) matches a DR for EX, MEM, or WB
  							[3]: ID/RR instruction is JAL, LW, or ALUI and its SR1(Rs) matches a DR for EX, MEM, or WB
  							[4]: stall_pipe signal is asserted for one of the above reasons [0-3]
                [5]: Unused
  							[6]: ID/RR instruction is a NOP bubble passed from inst_FE
  							[7]: EX instruction is a Branch with its jump condition satified
                [8]: EX instruction is JAL
                [9]: mispred_EX signal is asserted for one of the above reasons [7-8]
					**/
//			end
    end

  assign LEDR = LEDR_out;
  
endmodule


module SXT(IN, OUT);
  parameter IBITS = 16;
  parameter OBITS = 32;

  input  [IBITS-1:0] IN;
  output [OBITS-1:0] OUT;

  assign OUT = {{(OBITS-IBITS){IN[IBITS-1]}}, IN};
endmodule


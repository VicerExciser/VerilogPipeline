
int ALU(int a, int b, bool op[4])
{
    switch(op)
    {
        case 0000:  return (a + b);     // ADD or ADDI
        case 0100:  return (a & b);     // AND or ANDI
        case 0101:  return (a | b);     // OR or ORI
        case 0110:  return (a ^ b);     // XOR or XORI
        case 1000:  return (a - b);     // SUB
        case 1100:  return ~(a & b);    // NAND
        case 1101:  return ~(a | b);    // NOR
        case 1110:  return ~(a ^ b);    // NXOR
    }
}

void main()
{
    bool opcode[6];     // 6-bit opcode, either OP1 or OP2
    bool op2;           // Signal for whether OP2 is being used as opcode or not

    bool DR[4];         // 4-bit Destination Register identifier (Rd if op2, else Rt)

    // bool STALL;
    bool UPDATE_PC = 0; // Asserted when PC needs to be updated for a Branch or Jump

    int PC,             // Incremented Program Counter
        A,              // A = MEM(Rs)
        B,              // B = (op2 == True) ? MEM(Rt) : sext(Immediate)
        RES;            // 32-bit RESult of the EXecute stage


    if (op2)    // Instruction args format: { Rd <-- Rs, Rt }
    {

        if (opcode[5] == 0)         // Comparator operation
        {

            switch(opcode[1:0])
            {
                case 00:
                            RES = (A == B);     // EQ instruction
                            break;
                case 01:    RES = (A < B);      // LT instruction
                            break;
                case 10:    RES = (A <= B);     // LE instruction
                            break;
                case 11:    RES = (A != B);     // NE instruction
                            break;
            }

        }

        else if (opcode[5] == 1)     // ALU or Shift operation
        {

            if (opcode[4] == 1)      // Shift operation
            {

                if (opcode[0] == 0)
                {
                    RES = A >> B;       // RSHF instruction
                    // RSHF needs sign extension
                }

                else if (opcode[0] == 1)
                {
                    RES = A << B;       // LSHF instruction
                }
            }

            else if (opcode[4] == 0)   // ALU operation
            {
                RES = ALU(A, B, opcode[3:0]);   // ALU func selector only needs 4 bits
            }

        }

    }

    else if (!op2)    // Instruction args format: { Rt <-- Immediate, Rs }
    {

        if (opcode[5] == 1)     // ALUI operation
        {
            RES = ALU(A, B, opcode[3:0]);
        }

        else if (opcode[5] == 0)    // Will be a BRx, JAL, LW, or SW operation
        {

            bool ADD_OP[4] = {0,0,0,0};

            if (opcode[4] == 1)     // Load Word or Store Word
            {
                if (opcode[3] == 1) // SW instruction
                {
                    RES = ALU(A, B, ADD_OP); // A + B  <-- calculating address offset
                }

                else if (opcode[3] == 0) // LW instruction
                {
                    RES = ALU(A, B, ADD_OP); // A + B  <-- calculating address offset
                }
            }

            else if (opcode[4] == 0)    // Branch or Jump operation
            {
                if (opcode[2] == 1)     // JAL instruction
                {
                    DR = PC;
                    PC = ALU(PC, 4*B, ADD_OP);
                    UPDATE_PC = 1;
                }

                else if (opcode[2] == 0)    // BRx instruction
                {
                    switch(opcode[1:0])
                    {
                        case 00:    if (A == B)    // BEQ instruction
                                    {
                                        PC = ALU(PC, 4*B, ADD_OP);
                                        UPDATE_PC = 1;
                                    }
                        break;

                        case 01:    if (A < B)    // BLT instruction
                                    {
                                        PC = ALU(PC, 4*B, ADD_OP);
                                        UPDATE_PC = 1;
                                    }
                        break;

                        case 10:    if (A <= B)    // BLE instruction
                                    {
                                        PC = ALU(PC, 4*B, ADD_OP);
                                        UPDATE_PC = 1;
                                    }
                        break;

                        case 11:    if (A != B)    // BNE instruction
                                    {
                                        PC = ALU(PC, 4*B, ADD_OP);
                                        UPDATE_PC = 1;
                                    }
                        break;
                    }
                }
            }
        }
    }
}







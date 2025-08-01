module pipeline12345(
    input wire clk, reset,
    output [31:0] pc_out
);
    reg [31:0] PC;
    reg [31:0] instruction;
    //reg instruction = instruction_memory[PC[9:2]];
    assign pc_out = PC;

    reg [31:0] instruction_memory[0:255];
    reg [31:0] data_memory[0:255];
    reg [31:0] registers[0:31];
    integer i;
    initial begin
        $readmemh("instruction_memory.mem", instruction_memory);
        for (i = 0; i < 32; i = i + 1)
            registers[i] = 32'h00000000;
        for (i = 0; i < 256; i = i + 1)
            data_memory[i] = 32'h00000000;
    end

    // IF/ID
    reg [31:0] IF_ID_PC, IF_ID_Instruction;

    // ID/EX
    reg [31:0] ID_EX_PC, ID_EX_Read1, ID_EX_Read2, ID_EX_ImmExt;
    reg [4:0]  ID_EX_rs, ID_EX_rt, ID_EX_rd, ID_EX_shamt;
    reg [2:0]  ID_EX_ALUOp;
    reg        ID_EX_RegDst, ID_EX_ALUSrc, ID_EX_RegWrite, ID_EX_MemRead, ID_EX_MemWrite, ID_EX_MemtoReg;
    reg [5:0]  ID_EX_funct;

    // EX/MEM
    reg [31:0] EX_MEM_ALUResult, EX_MEM_WriteData;
    reg [4:0]  EX_MEM_WriteReg;
    reg        EX_MEM_RegWrite, EX_MEM_MemRead, EX_MEM_MemWrite, EX_MEM_MemtoReg;

    // MEM/WB
    reg [31:0] MEM_WB_ReadData, MEM_WB_ALUResult;
    reg [4:0]  MEM_WB_WriteReg;
    reg        MEM_WB_RegWrite, MEM_WB_MemtoReg;

    // Instruction Decode
    wire [5:0] opcode = IF_ID_Instruction[31:26];
    wire [4:0] rs = IF_ID_Instruction[25:21];
    wire [4:0] rt = IF_ID_Instruction[20:16];
    wire [4:0] rd = IF_ID_Instruction[15:11];
    wire [4:0] shamt = IF_ID_Instruction[10:6];
    wire [15:0] immediate = IF_ID_Instruction[15:0];
    wire [31:0] immediate_ext = {{16{immediate[15]}}, immediate};
    wire [25:0] jump = IF_ID_Instruction[25:0];
    wire [5:0] funct = IF_ID_Instruction[5:0];

    wire [31:0] readA = registers[rs];
    wire [31:0] readB = registers[rt];

    reg [31:0] ALU_result;
    wire [31:0] ALU_input_B = ID_EX_ALUSrc ? ID_EX_ImmExt : forwardB;
    wire zero = (ALU_result == 0);
    
    wire [31:0] forwardA, forwardB;
    
    wire load_use_hazard = (ID_EX_MemRead && ((ID_EX_rt == rs) || (ID_EX_rt == rt)));
    wire stall = load_use_hazard;
    
    // Control Signals
    reg regdst, ALUsource, MemtoReg, MemRead, MemWrite, Branch, regwrite, Jump, JAL, JumpReg;
    reg [2:0] ALUop;
    reg ID_EX_JAL;
   

        
            // Control Unit
   always @(*) begin
    
    regdst     = 0;
    ALUsource  = 0;
    regwrite   = 0;
    MemtoReg   = 0;
    MemRead    = 0;
    MemWrite   = 0;
    Branch     = 0;
    Jump       = 0;
    JumpReg    = 0;
    JAL        = 0;
    ALUop      = 3'b000;

    case (opcode)
        6'b000000: begin // R-type
            regdst = 1;
            regwrite = 1;
            ALUop = 3'b010;
            if (funct == 6'b001000) begin // JR
                JumpReg = 1;
                regwrite = 0; // Ensure no write-back
            end
        end
        6'b100011: begin // LW
            regwrite = 1;
            MemtoReg = 1;
            MemRead = 1;
            ALUsource = 1;
        end
        6'b101011: begin // SW
            MemWrite = 1;
            ALUsource = 1;
        end
        6'b000100: begin // BEQ
            Branch = 1;
            ALUop = 3'b001;
        end
        6'b000101: begin // BNE
            Branch = 1;
            ALUop = 3'b001;
        end
        6'b000010: begin // J
            Jump = 1;
        end
        6'b000011: begin // JAL
            Jump = 1;
            JAL = 1;
            regwrite = 1;
        end
        6'b001000: begin // ADDI
            regwrite = 1;
            ALUsource = 1;
        end
        6'b001011: begin // SLTIU
            regwrite = 1;
            ALUsource = 1;
            ALUop = 3'b101;
        end
        6'b100101: begin // LHU (if supported)
            regwrite = 1;
            MemtoReg = 1;
            MemRead = 1;
            ALUsource = 1;
        end
        default: begin
            
        end
    endcase
end

        assign forwardA = (EX_MEM_RegWrite && EX_MEM_WriteReg != 0 && EX_MEM_WriteReg == ID_EX_rs) ? EX_MEM_ALUResult :
                  (MEM_WB_RegWrite && MEM_WB_WriteReg != 0 && MEM_WB_WriteReg == ID_EX_rs) ? write_back_data :
                  ID_EX_Read1;

        assign forwardB = (EX_MEM_RegWrite && EX_MEM_WriteReg != 0 && EX_MEM_WriteReg == ID_EX_rt) ? EX_MEM_ALUResult :
                  (MEM_WB_RegWrite && MEM_WB_WriteReg != 0 && MEM_WB_WriteReg == ID_EX_rt) ? write_back_data :
                  ID_EX_Read2;
  // ALU
    always @(*) begin
    
       case (ID_EX_ALUOp)
    3'b000: ALU_result = forwardA + ALU_input_B;
    3'b001: ALU_result = forwardA - ALU_input_B;
    3'b010: begin
        case (ID_EX_funct)
            6'b100000: ALU_result = forwardA + ALU_input_B;
            6'b100010: ALU_result = forwardA - ALU_input_B;
            6'b100100: ALU_result = forwardA & ALU_input_B;
            6'b100101: ALU_result = forwardA | ALU_input_B;
            6'b000010: ALU_result = forwardA >> ID_EX_shamt;
            6'b101010: ALU_result = ($signed(forwardA) < $signed(ALU_input_B)) ? 1 : 0;
            default:   ALU_result = 0;
        endcase
    end
    3'b101: ALU_result = (forwardA < ID_EX_ImmExt) ? 1 : 0;
    default: ALU_result = 0;
endcase

    end

    reg [31:0] next_PC;
    always @(*) begin
        next_PC = PC + 4;
        if (JumpReg) next_PC = readA;
        else if (Jump) next_PC = {PC[31:28], jump, 2'b00};
        else if (Branch && ((opcode == 6'b000100 && zero) || (opcode == 6'b000101 && !zero)))
            next_PC = IF_ID_PC + (immediate_ext << 2);
    end

    wire [31:0] write_back_data = MEM_WB_MemtoReg ? MEM_WB_ReadData : MEM_WB_ALUResult;

    always @(posedge clk) begin
        if (reset) begin
            PC <= 0;
        end else begin
            if (!stall) 
            PC <= next_PC;
            instruction <= instruction_memory[PC[9:2]];
            
           if (stall) begin
    
    IF_ID_PC <= IF_ID_PC;
    IF_ID_Instruction <= IF_ID_Instruction;
end else begin
    IF_ID_PC <= PC;
    IF_ID_Instruction <= instruction;
end



           
     if (stall) begin   //nop
    ID_EX_PC        <= 0;
    ID_EX_Read1     <= 0;
    ID_EX_Read2     <= 0;
    ID_EX_ImmExt    <= 0;
    ID_EX_rs        <= 0;
    ID_EX_rt        <= 0;
    ID_EX_rd        <= 0;
    ID_EX_RegDst    <= 0;
    ID_EX_ALUSrc    <= 0;
    ID_EX_RegWrite  <= 0;
    ID_EX_MemRead   <= 0;
    ID_EX_MemWrite  <= 0;
    ID_EX_MemtoReg  <= 0;
    ID_EX_ALUOp     <= 3'b000;
    ID_EX_funct     <= 0;
end else begin
    ID_EX_PC        <= IF_ID_PC;
    ID_EX_Read1     <= readA;
    ID_EX_Read2     <= readB;
    ID_EX_ImmExt    <= immediate_ext;
    ID_EX_rs        <= rs;
    ID_EX_rt        <= rt;
    ID_EX_rd        <= rd;
    ID_EX_RegDst    <= regdst;
    ID_EX_ALUSrc    <= ALUsource;
    ID_EX_RegWrite  <= regwrite;
    ID_EX_MemRead   <= MemRead;
    ID_EX_MemWrite  <= MemWrite;
    ID_EX_MemtoReg  <= MemtoReg;
    ID_EX_ALUOp     <= ALUop;
    ID_EX_funct     <= funct;
end


            // EX/MEM
            EX_MEM_ALUResult <= ALU_result;
            EX_MEM_WriteData <= ID_EX_Read2;
            EX_MEM_WriteReg <= ID_EX_RegDst ? ID_EX_rd : ID_EX_rt;
            EX_MEM_RegWrite <= ID_EX_RegWrite;
            EX_MEM_MemRead <= ID_EX_MemRead;
            EX_MEM_MemWrite <= ID_EX_MemWrite;
            EX_MEM_MemtoReg <= ID_EX_MemtoReg;

            // MEM
            if (EX_MEM_MemWrite)
                data_memory[EX_MEM_ALUResult[9:2]] <= EX_MEM_WriteData;
                if(EX_MEM_MemRead)
            MEM_WB_ReadData <= data_memory[EX_MEM_ALUResult[9:2]];
            MEM_WB_ALUResult <= EX_MEM_ALUResult;
            MEM_WB_WriteReg <= EX_MEM_WriteReg;
            MEM_WB_RegWrite <= EX_MEM_RegWrite;
            MEM_WB_MemtoReg <= EX_MEM_MemtoReg;

            // WB
            if (MEM_WB_RegWrite && MEM_WB_WriteReg != 0)
                registers[MEM_WB_WriteReg] <= write_back_data;

            // Write $ra for JAL
            if (ID_EX_JAL)
                registers[31] <= ID_EX_PC + 4;
        end
    end
endmodule

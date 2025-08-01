module multi_cycle12345 (
    input wire clk,
    input wire reset
);

    wire [31:0] PC;
    wire [31:0] instruction;
    reg [31:0] read_data1_reg;
    reg [31:0] read_data2_reg;
    reg [31:0] alu_result;
    wire [31:0] write_data;
    reg [31:0] read_data_mem_reg;
    wire [31:0] sign_extended_imm;
    wire [31:0] shifted_imm;
    wire [31:0] jump_address;

    wire [4:0] rs_addr;
    wire [4:0] rt_addr;
    wire [4:0] rd_addr;
    wire [4:0] write_reg_addr;

    wire [5:0] opcode;
    wire [5:0] funct;

    wire MemRead;
    wire IorD;
    wire ALUSrcA;
    wire [1:0] ALUSrcB;
    wire [1:0] ALUOp;
    wire PCWrite;
    wire [1:0] PCSource;
    wire IRWrite;
    wire MemWrite;
    wire RegDst;
    wire RegWrite;
    wire MemtoReg;
    wire PCWriteCond;
    wire zero;
    wire is_lw;

    integer i;

    control_unit cu (
        .clk(clk),
        .reset(reset),
        .opcode(opcode),
        .zero(zero),
        .is_lw(is_lw),
        .MemRead(MemRead),
        .IorD(IorD),
        .ALUSrcA(ALUSrcA),
        .ALUSrcB(ALUSrcB),
        .ALUOp(ALUOp),
        .PCWrite(PCWrite),
        .PCSource(PCSource),
        .IRWrite(IRWrite),
        .MemWrite(MemWrite),
        .RegDst(RegDst),
        .RegWrite(RegWrite),
        .MemtoReg(MemtoReg),
        .PCWriteCond(PCWriteCond)
    );

    reg [31:0] PC_reg;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            PC_reg <= 32'h00000000;
        end else if (PCWrite || (PCWriteCond && zero)) begin
            case (PCSource)
                2'b00: PC_reg <= alu_result;
                2'b01: PC_reg <= alu_result;
                2'b10: PC_reg <= jump_address;
                2'b11: PC_reg <= read_data1_reg;  // For 'jr' instruction
                default: PC_reg <= PC_reg;
            endcase
        end
    end
    assign PC = PC_reg;

    reg [31:0] instr_mem [0:1023];
    initial begin
        $readmemh("instruction_memory.mem", instr_mem);
    end
    assign instruction = instr_mem[PC[11:2]];

    reg [31:0] IR_reg;
    always @(posedge clk) begin
        if (IRWrite) begin
            IR_reg <= instruction;
        end
    end

    assign opcode = IR_reg[31:26];
    assign funct = IR_reg[5:0];  // Capture the function code for R-type instructions
    assign rs_addr = IR_reg[25:21];
    assign rt_addr = IR_reg[20:16];
    assign rd_addr = IR_reg[15:11];

    reg [31:0] reg_file [0:31];
    initial begin
        for (i = 0; i < 32; i = i + 1) begin
            reg_file[i] = 32'h00000000;
        end
    end

    wire [31:0] reg_file_read_data1_out;
    wire [31:0] reg_file_read_data2_out;
    assign reg_file_read_data1_out = reg_file[rs_addr];
    assign reg_file_read_data2_out = reg_file[rt_addr];

    always @(posedge clk) begin
        read_data1_reg <= reg_file_read_data1_out;
        read_data2_reg <= reg_file_read_data2_out;
    end

    always @(posedge clk) begin
        if (RegWrite) begin
            if (write_reg_addr != 5'b00000) begin
                reg_file[write_reg_addr] <= write_data;
            end
        end
    end

    assign write_reg_addr = RegDst ? rd_addr : rt_addr;

    assign sign_extended_imm = {{16{IR_reg[15]}}, IR_reg[15:0]};
    assign shifted_imm = sign_extended_imm << 2;
    assign jump_address = {PC[31:28], IR_reg[25:0], 2'b00};

    wire [31:0] alu_src1;
    reg [31:0] alu_src2;

    assign alu_src1 = (opcode == 6'b000000 && funct == 6'b001000) ? read_data1_reg : (ALUSrcA ? read_data1_reg : PC);  
    always @(*) begin
        case (ALUSrcB)
            2'b00: alu_src2 = read_data2_reg;
            2'b01: alu_src2 = 32'd4;
            2'b10: alu_src2 = shifted_imm;
            2'b11: alu_src2 = sign_extended_imm;
            default: alu_src2 = 32'hxxxxxxxx;
        endcase
    end

    always @(*) begin
        case (ALUOp)
            2'b00: alu_result = alu_src1 + alu_src2;
            2'b01: alu_result = alu_src1 - alu_src2;
            2'b10: alu_result = alu_src1 + alu_src2;
            default: alu_result = 32'hxxxxxxxx;
        endcase
    end

    assign zero = (alu_result == 32'b0);

    reg [31:0] data_mem [0:1023];
    initial begin
        $readmemh("data_memory.mem", data_mem);
    end

    wire [31:0] memory_address;
    assign memory_address = IorD ? alu_result : PC;

    wire [31:0] data_mem_read_out;
    assign data_mem_read_out = data_mem[memory_address[11:2]];

    always @(posedge clk) begin
        if (MemRead && IorD) begin
            read_data_mem_reg <= data_mem_read_out;
        end
    end

    always @(posedge clk) begin
        if (MemWrite && IorD) begin
            data_mem[memory_address[11:2]] <= read_data2_reg;
        end
    end

    assign write_data = MemtoReg ? read_data_mem_reg : alu_result;

    localparam OP_LW = 6'b100011;
    localparam OP_SW = 6'b101011;
    localparam OP_R_TYPE = 6'b000000;
    localparam OP_BEQ = 6'b000100;
    localparam OP_J = 6'b000010;
    localparam OP_LHU = 6'b100111;  // Add the opcodes for the new instructions

    assign is_lw = (opcode == OP_LW || opcode == OP_LHU);

endmodule

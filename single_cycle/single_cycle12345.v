`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11.04.2025 23:50:07
// Design Name: 
// Module Name: single_cycle12345
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module single_cycle12345(
input wire clk, reset,
output[31:0] pc_out
    );
    reg[31:0]PC;
    reg[31:0] next_PC;
    reg[31:0] instruction_memory[0:255];
    integer i;
    reg[31:0] registers[0:31];
    initial begin
    $readmemh("instructions.mem", instruction_memory); // Load instructions at simulation start
    for (i=0; i<32; i=i+1) begin
    registers[i]= 32'h00000000;
    end
end
    wire[31:0] instruction;
    wire[5:0] opcode=instruction[31:26];
    wire[4:0] rs=instruction[25:21];
    wire[4:0] rt=instruction[20:16];
    wire[4:0] rd=instruction[15:11];
    wire[4:0] shamt=instruction[10:6];
    wire[5:0] funct=instruction[5:0];
    wire[15:0] immediate=instruction[15:0];
    wire[25:0] jump=instruction[25:0];
   
    wire[31:0] immediate_ext={{16{immediate[15]}}, immediate};
    //reg[31:0] registers[0:31];
    
   
    wire[31:0] readA=registers[rs];
    wire[31:0] readB=registers[rt];
    reg[31:0] write_data;
    
    reg[31:0] ALU_result;
    wire zero= (ALU_result==0);
    reg[31:0] data_memory[0:255];
    integer j;
    initial begin
    for (j=0; j<256; j=j+1) begin
    data_memory[j]= 32'h00000000;
    end
    end
    wire[31:0] MemoryReadData= data_memory[ALU_result[9:2]];
    reg regdst, ALUsource, MemtoReg, MemRead, MemWrite, Branch, regwrite, Jump, JAL, JumpReg;
    reg[2:0] ALUop;
    assign pc_out= PC;
    assign instruction= instruction_memory[PC[9:2]];
    
    always @(*) begin
    next_PC=PC+4;
    
    if(JumpReg)begin
    next_PC= readA;
    end
    else if(Jump) begin
    next_PC= {PC[31:28], jump, 2'b00};
    end
    else if(Branch) begin
    if ((opcode== 6'b000101 && !zero) || (opcode== 6'b000100 && zero)) begin
    next_PC= PC+4+(immediate_ext<<2);
    end 
    end
    end
   // assign next_PC=  Branch && ((opcode == 6'b000101) ? !zero : zero) ? PC+4+(immediate_ext<<2) : (Jump ? {PC[31:28], jump, 2'b00} : PC+4);
    
    always @(*) begin
    regdst = 0;
    ALUsource = 0;
    regwrite = 0;
    MemtoReg = 0;
    MemRead = 0;
    MemWrite = 0;
    Branch = 0;
    Jump = 0; // Default Jump Immediate
    JumpReg = 0; // Default Jump Register
    JAL = 0;     // Default Jump and Link
    ALUop = 3'b000;
    case(opcode)
    6'b000000: begin  //r-type
    regdst=1; 
    ALUsource=0;
    regwrite=1;
    MemtoReg=0;
    MemRead=0;
    MemWrite=0;
    Branch=0;
    Jump=0;
    ALUop=3'b010;
    case(funct)
    6'b000100: begin  //jr
    JumpReg=1;
    regwrite=0;
    end
    endcase
    end

    
    6'b100011: begin  //loadword
    regdst=0; 
    ALUsource=1;
    regwrite=1;
    MemtoReg=1;
    MemRead=1;
    MemWrite=0;
    Branch=0;
    Jump=0;
    ALUop=3'b000;
    end
    
    6'b101011: begin   //storeword
    regdst=0; 
    ALUsource=1;
    regwrite=0;
    MemtoReg=0;
    MemRead=0;
    MemWrite=1;
    Branch=0;
    Jump=0;
    ALUop=3'b000;
    end
    
    6'b000100: begin   //branchifequal
    regdst=0; 
    ALUsource=0;
    regwrite=0;
    MemtoReg=0;
    MemRead=0;
    MemWrite=0;
    Branch=1;
    Jump=0;
    ALUop=3'b001;
    end
    
    6'b000101: begin   //bne
    regdst=0; 
    ALUsource=0;
    regwrite=0;
    MemtoReg=0;
    MemRead=0;
    MemWrite=0;
    Branch=1;
    Jump=0;
    ALUop=3'b001;
    end
    
    /* 6'b101010: begin   //slt
    regdst=1; 
    ALUsource=0;
    regwrite=1;
    MemtoReg=0;
    MemRead=0;
    MemWrite=0;
    Branch=0;
    Jump=0;
    ALUop=3'b010;
    end   */
    
    6'b000010: begin   //J  ---
    Jump=1;
    ALUop=3'b010;
    end  
    
    6'b000011: begin   //jal
    Jump=1;
    JAL=1;
    regwrite = 1;
    ALUop=3'b000;
    end 
    
    6'b001011: begin  //sltiu
    regdst=0; 
    ALUsource=1;
    regwrite=1;
    MemtoReg=0;
    MemRead=0;
    MemWrite=0;
    Branch=0;
    Jump=0;
    ALUop=3'b101;
    end
    
    6'b100101:begin   //lhu
    regdst=0; 
    ALUsource=1;
    regwrite=1;
    MemtoReg=1;
    MemRead=1;
    MemWrite=0;
    Branch=0;
    //ByteEnable/size to interpret this as halfword
    //zeroextend 1
    Jump=0;
    ALUop=3'b000;
    end
    
    6'b001000: begin   //addi
    regdst=0; 
    ALUsource=1;
    regwrite=1;
    MemtoReg=0;
    MemRead=0;
    MemWrite=0;
    Branch=0;
    Jump=0;
    ALUop=3'b000;
    end 
    
    default: begin  
    regdst=0; 
    ALUsource=0;
    regwrite=0;
    MemtoReg=0;
    MemRead=0;
    MemWrite=0;
    Branch=0;
    Jump=0;
    
    end
    
    endcase
    end
    
    always@(*) begin
    case(ALUop)
    3'b000: ALU_result=readA+(ALUsource?immediate_ext:readB);
    3'b001: ALU_result=readA-readB;
    3'b010: begin
    case(funct)
    6'b100000: ALU_result=readA+readB;
    6'b100010: ALU_result=readA-readB;
    6'b100100: ALU_result=readA & readB;
    6'b100101: ALU_result=readA | readB;
    6'b000010: ALU_result=readA >> shamt;    //srl
    6'b101010: ALU_result=($signed(readA) < $signed(readB))?1:0;   //slt
    
    default: ALU_result=0;
    endcase
    end
    3'b011: ALU_result=(readA < immediate_ext)?1:0;   //sltiu
    default: ALU_result=0;
    endcase
    end
    
    
    always @(posedge clk) begin
    if(MemWrite)
    data_memory[ALU_result[9:2]]<= readB;
    end
   
    
    always @(*) begin
    if(MemtoReg)
    case(opcode)
    6'b100011: begin
    write_data= MemoryReadData;
    end
    6'b100101: begin
    if(ALU_result [1]==1'b0) begin
    write_data= {16'h0000, MemoryReadData[15:0]};   // lower
    end
    else begin 
    write_data={16'h0000, MemoryReadData[31:16]};    //upper
    end
    end
    default: begin
    write_data= MemoryReadData;
    end
    endcase
    
    else begin
    write_data=ALU_result;
    end
    end
    always @(posedge clk) begin
    
    if(reset)
    PC<=32'h00000000;
   
    else begin
    PC<= next_PC;
    
    if(regwrite) begin
    if(JAL) begin
    registers[31]<=PC+4;
    end 
    
     else begin          
     if(regdst) begin // regdst = 1 (for R-type)
     if (rd != 5'b00000) registers[rd] <= write_data;
     end
     else begin // regdst = 0 (for I-type like addi, lw, sltiu)
     if (rt != 5'b00000) registers[rt] <= write_data;
     end
     end
     end
     end
    
     end
    endmodule

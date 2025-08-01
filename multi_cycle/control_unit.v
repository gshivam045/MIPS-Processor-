

module control_unit (
    input wire clk,
    input wire reset,
    input wire [5:0] opcode,    
    input wire zero,            
    input wire is_lw,           
    input wire [5:0] funct,      
    output reg MemRead,    
    output reg IorD,         
    output reg ALUSrcA,      
    output reg [1:0] ALUSrcB, 
    output reg [1:0] ALUOp,
    output reg PCWrite,     
    output reg [1:0] PCSource, 
    output reg IRWrite,      
    output reg MemWrite,     
    output reg RegDst,      
    output reg RegWrite,     
    output reg MemtoReg,
    output reg PCWriteCond  
);

    // State Definitions
    localparam STATE_0 = 4'd0; 
    localparam STATE_1 = 4'd1; 
    localparam STATE_2 = 4'd2; 
    localparam STATE_3 = 4'd3; 
    localparam STATE_4 = 4'd4;

    // Opcodes
    localparam OP_LW    = 6'b100011; 
    localparam OP_SW    = 6'b101011; 
    localparam OP_R_TYPE = 6'b000000; 
    localparam OP_BEQ   = 6'b000100; 
    localparam OP_BNE   = 6'b000101;  // BNE opcode
    localparam OP_J     = 6'b000010; 
    localparam OP_LHU   = 6'b100101;  // LHU opcode

    // Function codes for R-type instructions
    localparam FUNC_JR = 6'b001000; 
    localparam FUNC_SLL = 6'b000000; 
    localparam FUNC_SLT = 6'b101010;

    reg [3:0] current_state;
    reg [3:0] next_state;
    
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            current_state <= STATE_0;
        end else begin
            current_state <= next_state;
        end
    end

    always @(*) begin
        next_state = current_state; 
        case (current_state)
            STATE_0: begin 
                next_state = STATE_1;
            end
            STATE_1: begin 
                case (opcode)
                    OP_LW, OP_SW: next_state = STATE_2; 
                    OP_R_TYPE:   next_state = STATE_2; 
                    OP_BEQ:    next_state = STATE_2; 
                    OP_BNE:    next_state = STATE_2; 
                    OP_J:      next_state = STATE_0; 
                    OP_LHU:    next_state = STATE_2; 
                    default:   next_state = STATE_0; 
                endcase
            end
            STATE_2: begin 
                case (opcode)
                    OP_LW, OP_SW: next_state = STATE_3; 
                    OP_R_TYPE:   next_state = STATE_4; 
                    OP_BEQ:      next_state = STATE_0; 
                    OP_BNE:      next_state = STATE_0; 
                    OP_LHU:      next_state = STATE_3; 
                    default:     next_state = STATE_0;
                endcase
            end
            STATE_3: begin
                case (opcode)
                    OP_LW: next_state = STATE_4; 
                    OP_SW: next_state = STATE_0; 
                    OP_LHU: next_state = STATE_4;
                    default: next_state = STATE_0; 
                endcase
            end
            STATE_4: begin 
                next_state = STATE_0;
            end
            default: begin
                next_state = STATE_0; 
            end
        endcase
    end

    always @(*) begin
        // Default values for control signals
        MemRead = 0;
        IorD = 0;
        ALUSrcA = 0;
        ALUSrcB = 2'b00;
        ALUOp = 2'b00;
        PCWrite = 0;
        PCSource = 2'b00;
        IRWrite = 0;
        MemWrite = 0;
        RegDst = 0;
        RegWrite = 0;
        MemtoReg = 0;
        PCWriteCond = 0;

        case (current_state)
            STATE_0: begin
                MemRead = 1;
                IorD = 0;       
                ALUSrcA = 0;    
                ALUSrcB = 2'b01; 
                ALUOp = 2'b00;  
                PCWrite = 1;    
                PCSource = 2'b00; 
                IRWrite = 1;    
            end
            STATE_1: begin
                ALUSrcA = 0;   
                ALUSrcB = 2'b10; 
                ALUOp = 2'b00;
            end
            STATE_2: begin 
                case (opcode)
                    OP_LW, OP_SW: begin
                        ALUSrcA = 1;    
                        ALUSrcB = 2'b11;
                        ALUOp = 2'b00;  
                    end
                    OP_R_TYPE: begin
                        ALUSrcA = 1;
                        ALUSrcB = 2'b00;
                        ALUOp = 2'b10; 
                    end
                    OP_BEQ: begin
                        ALUSrcA = 1;
                        ALUSrcB = 2'b00; 
                        ALUOp = 2'b01;  
                        PCWriteCond = 1;
                        PCSource = 2'b01; 
                    end
                    OP_BNE: begin
                        ALUSrcA = 1;
                        ALUSrcB = 2'b00; 
                        ALUOp = 2'b01;  
                        PCWriteCond = 1;
                        PCSource = 2'b01; 
                    end
                    OP_LHU: begin
                        ALUSrcA = 1;
                        ALUSrcB = 2'b11;
                        ALUOp = 2'b00; 
                    end
                    default: begin end 
                endcase
            end
            STATE_3: begin
                IorD = 1; 
                case (opcode)
                    OP_LW: begin
                        MemRead = 1; 
                    end
                    OP_SW: begin
                        MemWrite = 1; 
                    end
                    OP_LHU: begin
                        MemRead = 1; 
                    end
                    default: begin end
                endcase
            end
            STATE_4: begin 
                RegWrite = 1;
                case (opcode)
                    OP_LW: begin
                        RegDst = 0;   
                        MemtoReg = 1;   
                    end
                    OP_R_TYPE: begin
                        case (funct)
                            FUNC_SLT: begin
                                RegDst = 1;
                                MemtoReg = 0;
                            end
                            FUNC_SLL: begin
                                RegDst = 1;
                                MemtoReg = 0;
                            end
                            FUNC_JR: begin
                                PCWrite = 1;
                                PCSource = 2'b11;  
                            end
                            default: begin
                                RegDst = 1;
                                MemtoReg = 0;
                            end
                        endcase
                    end
                    OP_LHU: begin
                        RegDst = 0;
                        MemtoReg = 1;
                    end
                    default: begin end
                endcase
            end
            default: begin
            end
        endcase
    end

endmodule

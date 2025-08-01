`timescale 1ns / 1ps

module pipeline12345_tb;
 reg clk;
    reg reset;
    wire [31:0] pc_out;

   pipeline12345 uut (
        .clk(clk),
        .reset(reset),
        .pc_out(pc_out)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        reset = 1;
        $monitor("At time %t, PC=%h, $t0=%h, $t1=%h, $t2=%h, $t3=%h, $t4=%h, $ra=%h",
             $time, uut.pc_out, uut.registers[8], uut.registers[9], uut.registers[10],
             uut.registers[11], uut.registers[12], uut.registers[31]);
     
        #10;
        reset = 0;
 
        #150;
    $finish;
    end

endmodule

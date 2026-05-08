`timescale 1ns/1ps

module pc_logic_tb;

    reg clk;
    reg reset;
    reg stall;

    reg branch_taken;
    reg [31:0] branch_target;

    reg jump;
    reg [31:0] jump_target;

    wire [31:0] pc;

    pc_logic uut (
        .clk(clk),
        .reset(reset),
        .stall(stall),
        .branch_taken(branch_taken),
        .branch_target(branch_target),
        .jump(jump),
        .jump_target(jump_target),
        .pc(pc)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        reset = 1;
        stall = 0;
        branch_taken = 0;
        branch_target = 0;
        jump = 0;
        jump_target = 0;

        #10 reset = 0;

        // Normal PC increment
        #20;

        // Stall test
        stall = 1;
        #10;
        stall = 0;

        // Branch test
        branch_taken = 1;
        branch_target = 32'd100;
        #10;
        branch_taken = 0;

        // Jump test
        jump = 1;
        jump_target = 32'd200;
        #10;
        jump = 0;

        #20;

        $finish;
    end

    initial begin
        $monitor(
            "Time=%0t | PC=%d | stall=%b | branch=%b | jump=%b",
            $time, pc, stall, branch_taken, jump
        );
    end

    initial begin
        $dumpfile("pc_logic_tb.vcd");
        $dumpvars(0, pc_logic_tb);
    end

endmodule
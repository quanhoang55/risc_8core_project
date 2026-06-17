`timescale 1ns / 1ps

module tb_if_id;

    reg clk;
    reg reset;
    reg clear;
    reg hold;

    reg [31:0] if_pc;
    reg [31:0] if_instr;

    wire id_valid;
    wire [31:0] id_pc;
    wire [31:0] id_instr;

    // DUT = Device Under Test
    if_id dut (
        .clk(clk),
        .reset(reset),
        .clear(clear),
        .hold(hold),
        .if_pc(if_pc),
        .if_instr(if_instr),
        .id_valid(id_valid),
        .id_pc(id_pc),
        .id_instr(id_instr)
    );

    // Clock 10ns
    always #5 clk = ~clk;

    initial begin

        $dumpfile("if_id.vcd");
        $dumpvars(0, tb_if_id);

        clk = 0;
        reset = 1;
        clear = 0;
        hold = 0;
        if_pc = 0;
        if_instr = 0;

        #10;

        // bỏ reset
        reset = 0;

        // instruction 1
        if_pc = 32'h00000000;
        if_instr = 32'h11111111;

        #10;

        // instruction 2
        if_pc = 32'h00000004;
        if_instr = 32'h22222222;

        #10;

        // test stall
        hold = 1;

        if_pc = 32'h00000008;
        if_instr = 32'h33333333;

        #10;

        // bỏ stall
        hold = 0;

        #10;

        // test flush
        clear = 1;

        #10;

        clear = 0;

        #10;

        $finish;
    end

endmodule
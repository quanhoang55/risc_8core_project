`timescale 1ns / 1ps

module tb_ex_mem;

    reg clk, reset, hold;

    reg ex_valid, ex_reg_write, ex_mem_read, ex_mem_write, ex_mem_to_reg;
    reg ex_mem_lr, ex_mem_sc, ex_mem_amo;
    reg [3:0] ex_amo_op;
    reg [31:0] ex_result, ex_store_data;
    reg [4:0] ex_rd_addr;

    wire mem_valid, mem_reg_write, mem_mem_read, mem_mem_write, mem_mem_to_reg;
    wire mem_mem_lr, mem_mem_sc, mem_mem_amo;
    wire [3:0] mem_amo_op;
    wire [31:0] mem_result, mem_store_data;
    wire [4:0] mem_rd_addr;

    ex_mem dut(
        .clk(clk),
        .reset(reset),
        .hold(hold),

        .ex_valid(ex_valid),
        .ex_reg_write(ex_reg_write),
        .ex_mem_read(ex_mem_read),
        .ex_mem_write(ex_mem_write),
        .ex_mem_to_reg(ex_mem_to_reg),
        .ex_mem_lr(ex_mem_lr),
        .ex_mem_sc(ex_mem_sc),
        .ex_mem_amo(ex_mem_amo),
        .ex_amo_op(ex_amo_op),
        .ex_result(ex_result),
        .ex_store_data(ex_store_data),
        .ex_rd_addr(ex_rd_addr),

        .mem_valid(mem_valid),
        .mem_reg_write(mem_reg_write),
        .mem_mem_read(mem_mem_read),
        .mem_mem_write(mem_mem_write),
        .mem_mem_to_reg(mem_mem_to_reg),
        .mem_mem_lr(mem_mem_lr),
        .mem_mem_sc(mem_mem_sc),
        .mem_mem_amo(mem_mem_amo),
        .mem_amo_op(mem_amo_op),
        .mem_result(mem_result),
        .mem_store_data(mem_store_data),
        .mem_rd_addr(mem_rd_addr)
    );

    always #5 clk = ~clk;

    initial begin
        $dumpfile("ex_mem.vcd");
        $dumpvars(0, tb_ex_mem);

        clk = 0;
        reset = 1;
        hold = 0;

        #10 reset = 0;

        ex_valid = 1;
        ex_reg_write = 1;
        ex_mem_read = 0;
        ex_mem_write = 0;
        ex_mem_to_reg = 0;
        ex_mem_lr = 0;
        ex_mem_sc = 0;
        ex_mem_amo = 0;
        ex_amo_op = 4'd0;
        ex_result = 32'd123;
        ex_store_data = 32'd456;
        ex_rd_addr = 5'd10;

        #10;

        hold = 1;
        ex_result = 32'd999;

        #10;

        hold = 0;

        #10;

        $finish;
    end

endmodule
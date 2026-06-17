`timescale 1ns / 1ps

module tb_mem_wb;

    reg clk, reset, clear;

    reg mem_wb_in_valid;
    reg mem_wb_in_reg_write;
    reg [4:0] mem_wb_in_rd_addr;
    reg [31:0] mem_wb_in_write_data;

    wire wb_valid;
    wire wb_reg_write;
    wire [4:0] wb_rd_addr;
    wire [31:0] wb_write_data;

    mem_wb dut(
        .clk(clk),
        .reset(reset),
        .clear(clear),

        .mem_wb_in_valid(mem_wb_in_valid),
        .mem_wb_in_reg_write(mem_wb_in_reg_write),
        .mem_wb_in_rd_addr(mem_wb_in_rd_addr),
        .mem_wb_in_write_data(mem_wb_in_write_data),

        .wb_valid(wb_valid),
        .wb_reg_write(wb_reg_write),
        .wb_rd_addr(wb_rd_addr),
        .wb_write_data(wb_write_data)
    );

    always #5 clk = ~clk;

    initial begin
        $dumpfile("mem_wb.vcd");
        $dumpvars(0, tb_mem_wb);

        clk = 0;
        reset = 1;
        clear = 0;

        #10 reset = 0;

        mem_wb_in_valid = 1;
        mem_wb_in_reg_write = 1;
        mem_wb_in_rd_addr = 5'd15;
        mem_wb_in_write_data = 32'd777;

        #10;

        clear = 1;

        #10;

        clear = 0;

        mem_wb_in_write_data = 32'd888;

        #10;

        $finish;
    end

endmodule
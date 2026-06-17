`timescale 1ns / 1ps
module mem_wb (
    input wire clk, reset, clear, hold,
    input wire        mem_wb_in_valid, mem_wb_in_reg_write,
    input wire [ 4:0] mem_wb_in_rd_addr,
    input wire [31:0] mem_wb_in_write_data,

    output reg        wb_valid, wb_reg_write,
    output reg [ 4:0] wb_rd_addr,
    output reg [31:0] wb_write_data
);
    always @(posedge clk or posedge reset) begin
        if (reset || clear) begin
            wb_valid      <= 1'b0;
            wb_reg_write  <= 1'b0;
            wb_rd_addr    <= 5'd0;
            wb_write_data <= 32'd0;
        end else if(!hold)
        begin
            wb_valid      <= mem_wb_in_valid;
            wb_reg_write  <= mem_wb_in_reg_write;
            wb_rd_addr    <= mem_wb_in_rd_addr;
            wb_write_data <= mem_wb_in_write_data;
        end
    end
endmodule
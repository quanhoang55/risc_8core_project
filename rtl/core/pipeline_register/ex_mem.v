`timescale 1ns / 1ps
module ex_mem (
    input wire clk, reset, hold,
    input wire        ex_valid, ex_reg_write, ex_mem_read, ex_mem_write, ex_mem_to_reg,
    input wire        ex_mem_lr, ex_mem_sc, ex_mem_amo,
    input wire [ 3:0] ex_amo_op,
    input wire [31:0] ex_result, ex_store_data,
    input wire [ 4:0] ex_rd_addr,

    output reg        mem_valid, mem_reg_write, mem_mem_read, mem_mem_write, mem_mem_to_reg,
    output reg        mem_mem_lr, mem_mem_sc, mem_mem_amo,
    output reg [ 3:0] mem_amo_op,
    output reg [31:0] mem_result, mem_store_data,
    output reg [ 4:0] mem_rd_addr
);
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            mem_valid <= 1'b0; mem_reg_write <= 1'b0;
            mem_mem_read <= 1'b0; mem_mem_write <= 1'b0;
            mem_mem_to_reg <= 1'b0; mem_mem_lr <= 1'b0;
            mem_mem_sc <= 1'b0; mem_mem_amo <= 1'b0;
            mem_amo_op <= 4'd0; mem_result <= 32'd0;
            mem_store_data <= 32'd0; mem_rd_addr <= 5'd0;
        end else if (!hold) begin
            mem_valid <= ex_valid;
            mem_reg_write <= ex_reg_write;
            mem_mem_read <= ex_mem_read;
            mem_mem_write <= ex_mem_write;
            mem_mem_to_reg <= ex_mem_to_reg;
            mem_mem_lr <= ex_mem_lr;
            mem_mem_sc <= ex_mem_sc;
            mem_mem_amo <= ex_mem_amo;
            mem_amo_op <= ex_amo_op;
            mem_result <= ex_result;
            mem_store_data <= ex_store_data;
            mem_rd_addr <= ex_rd_addr;
        end
    end
endmodule
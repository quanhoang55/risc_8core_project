`timescale 1ns / 1ps
module id_ex (
    input wire clk, reset, clear, hold,
    input wire        id_valid,
    input wire [31:0] id_pc, id_rs1_data, id_rs2_data, id_imm,
    input wire [ 4:0] id_rs1_addr, id_rs2_addr, id_rd_addr,
    input wire [ 3:0] id_alu_control,
    input wire [ 2:0] id_branch_type,
    input wire [ 3:0] id_amo_op,
    input wire        id_reg_write, id_alu_src, id_mem_read, id_mem_write, id_mem_to_reg,
    input wire        id_branch, id_jump, id_jalr, id_lui, id_auipc, id_mem_lr, id_mem_sc, id_mem_amo,

    output reg        ex_valid,
    output reg [31:0] ex_pc, ex_rs1_data, ex_rs2_data, ex_imm,
    output reg [ 4:0] ex_rs1_addr, ex_rs2_addr, ex_rd_addr,
    output reg [ 3:0] ex_alu_control,
    output reg [ 2:0] ex_branch_type,
    output reg [ 3:0] ex_amo_op,
    output reg        ex_reg_write, ex_alu_src, ex_mem_read, ex_mem_write, ex_mem_to_reg,
    output reg        ex_branch, ex_jump, ex_jalr, ex_lui, ex_auipc, ex_mem_lr, ex_mem_sc, ex_mem_amo
);
    always @(posedge clk or posedge reset) begin
        if (reset || clear) begin
            ex_valid <= 1'b0;
            ex_pc <= 32'd0;
            ex_rs1_data <= 32'd0;
            ex_rs2_data <= 32'd0;
            ex_imm <= 32'd0;
            ex_rs1_addr <= 5'd0;
            ex_rs2_addr <= 5'd0;
            ex_rd_addr <= 5'd0;
            ex_alu_control <= 4'd0;
            ex_branch_type <= 3'd0;
            ex_amo_op <= 4'd0;
            ex_reg_write <= 1'b0;
            ex_alu_src <= 1'b0;
            ex_mem_read <= 1'b0;
            ex_mem_write <= 1'b0;
            ex_mem_to_reg <= 1'b0;
            ex_branch <= 1'b0;
            ex_jump <= 1'b0;
            ex_jalr <= 1'b0;
            ex_lui <= 1'b0;
            ex_auipc <= 1'b0;
            ex_mem_lr <= 1'b0;
            ex_mem_sc <= 1'b0;
            ex_mem_amo <= 1'b0;
        end else if (!hold) begin
            ex_valid <= id_valid;
            ex_pc <= id_pc;
            ex_rs1_data <= id_rs1_data;
            ex_rs2_data <= id_rs2_data;
            ex_imm <= id_imm;
            ex_rs1_addr <= id_rs1_addr;
            ex_rs2_addr <= id_rs2_addr;
            ex_rd_addr <= id_rd_addr;
            ex_alu_control <= id_alu_control;
            ex_branch_type <= id_branch_type;
            ex_amo_op <= id_amo_op;
            ex_reg_write <= id_valid ? id_reg_write : 1'b0;
            ex_alu_src <= id_valid ? id_alu_src : 1'b0;
            ex_mem_read <= id_valid ? id_mem_read : 1'b0;
            ex_mem_write <= id_valid ? id_mem_write : 1'b0;
            ex_mem_to_reg <= id_valid ? id_mem_to_reg : 1'b0;
            ex_branch <= id_valid ? id_branch : 1'b0;
            ex_jump <= id_valid ? id_jump : 1'b0;
            ex_jalr <= id_valid ? id_jalr : 1'b0;
            ex_lui <= id_valid ? id_lui : 1'b0;
            ex_auipc <= id_valid ? id_auipc : 1'b0;
            ex_mem_lr <= id_valid ? id_mem_lr : 1'b0;
            ex_mem_sc <= id_valid ? id_mem_sc : 1'b0;
            ex_mem_amo <= id_valid ? id_mem_amo : 1'b0;
        end
    end
endmodule
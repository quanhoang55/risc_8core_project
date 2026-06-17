`timescale 1ns / 1ps

module tb_id_ex;

    reg clk, reset, clear, hold;

    reg         id_valid;
    reg [31:0]  id_pc, id_rs1_data, id_rs2_data, id_imm;
    reg [4:0]   id_rs1_addr, id_rs2_addr, id_rd_addr;
    reg [3:0]   id_alu_control;
    reg [2:0]   id_branch_type;
    reg [3:0]   id_amo_op;
    reg         id_reg_write, id_alu_src, id_mem_read, id_mem_write, id_mem_to_reg;
    reg         id_branch, id_jump, id_jalr, id_lui, id_auipc;
    reg         id_mem_lr, id_mem_sc, id_mem_amo;

    wire        ex_valid;
    wire [31:0] ex_pc, ex_rs1_data, ex_rs2_data, ex_imm;
    wire [4:0]  ex_rs1_addr, ex_rs2_addr, ex_rd_addr;
    wire [3:0]  ex_alu_control;
    wire [2:0]  ex_branch_type;
    wire [3:0]  ex_amo_op;
    wire        ex_reg_write, ex_alu_src, ex_mem_read, ex_mem_write, ex_mem_to_reg;
    wire        ex_branch, ex_jump, ex_jalr, ex_lui, ex_auipc;
    wire        ex_mem_lr, ex_mem_sc, ex_mem_amo;

    id_ex dut (
        .clk(clk), .reset(reset), .clear(clear), .hold(hold),
        .id_valid(id_valid),
        .id_pc(id_pc),
        .id_rs1_data(id_rs1_data),
        .id_rs2_data(id_rs2_data),
        .id_imm(id_imm),
        .id_rs1_addr(id_rs1_addr),
        .id_rs2_addr(id_rs2_addr),
        .id_rd_addr(id_rd_addr),
        .id_alu_control(id_alu_control),
        .id_branch_type(id_branch_type),
        .id_amo_op(id_amo_op),
        .id_reg_write(id_reg_write),
        .id_alu_src(id_alu_src),
        .id_mem_read(id_mem_read),
        .id_mem_write(id_mem_write),
        .id_mem_to_reg(id_mem_to_reg),
        .id_branch(id_branch),
        .id_jump(id_jump),
        .id_jalr(id_jalr),
        .id_lui(id_lui),
        .id_auipc(id_auipc),
        .id_mem_lr(id_mem_lr),
        .id_mem_sc(id_mem_sc),
        .id_mem_amo(id_mem_amo),

        .ex_valid(ex_valid),
        .ex_pc(ex_pc),
        .ex_rs1_data(ex_rs1_data),
        .ex_rs2_data(ex_rs2_data),
        .ex_imm(ex_imm),
        .ex_rs1_addr(ex_rs1_addr),
        .ex_rs2_addr(ex_rs2_addr),
        .ex_rd_addr(ex_rd_addr),
        .ex_alu_control(ex_alu_control),
        .ex_branch_type(ex_branch_type),
        .ex_amo_op(ex_amo_op),
        .ex_reg_write(ex_reg_write),
        .ex_alu_src(ex_alu_src),
        .ex_mem_read(ex_mem_read),
        .ex_mem_write(ex_mem_write),
        .ex_mem_to_reg(ex_mem_to_reg),
        .ex_branch(ex_branch),
        .ex_jump(ex_jump),
        .ex_jalr(ex_jalr),
        .ex_lui(ex_lui),
        .ex_auipc(ex_auipc),
        .ex_mem_lr(ex_mem_lr),
        .ex_mem_sc(ex_mem_sc),
        .ex_mem_amo(ex_mem_amo)
    );

    always #5 clk = ~clk;

    initial begin
        $dumpfile("id_ex.vcd");
        $dumpvars(0, tb_id_ex);

        clk = 0;
        reset = 1;
        clear = 0;
        hold = 0;

        #10 reset = 0;

        id_valid = 1;
        id_pc = 32'h1000;
        id_rs1_data = 32'd10;
        id_rs2_data = 32'd20;
        id_imm = 32'd4;
        id_rs1_addr = 5'd1;
        id_rs2_addr = 5'd2;
        id_rd_addr = 5'd3;
        id_alu_control = 4'd1;
        id_branch_type = 3'd0;
        id_amo_op = 4'd0;
        id_reg_write = 1;
        id_alu_src = 1;
        id_mem_read = 0;
        id_mem_write = 0;
        id_mem_to_reg = 0;
        id_branch = 0;
        id_jump = 0;
        id_jalr = 0;
        id_lui = 0;
        id_auipc = 0;
        id_mem_lr = 0;
        id_mem_sc = 0;
        id_mem_amo = 0;

        #10;

        hold = 1;
        id_pc = 32'h2000;

        #10;

        hold = 0;

        #10;

        clear = 1;

        #10;

        clear = 0;

        #10;

        $finish;
    end

endmodule
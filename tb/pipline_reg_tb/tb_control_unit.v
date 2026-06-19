`timescale 1ns / 1ps

module tb_control_unit;

    // --- Inputs ---
    reg [31:0] instruction;

    // --- Outputs ---
    wire        reg_write;
    wire        alu_src;
    wire [3:0]  alu_control;
    wire        mem_read;
    wire        mem_write;
    wire        mem_to_reg;
    wire        branch;
    wire [2:0]  branch_type;
    wire        jump;
    wire        jalr;
    wire        lui;
    wire        auipc;
    wire        mem_lr;
    wire        mem_sc;
    wire        mem_amo;
    wire [3:0]  amo_op;
    wire [31:0] imm;
    wire [4:0]  rs1_addr;
    wire [4:0]  rs2_addr;
    wire [4:0]  rd_addr;

    // --- Instantiate UUT (Unit Under Test) ---
    control_unit uut (
        .instruction (instruction),
        .reg_write   (reg_write),
        .alu_src     (alu_src),
        .alu_control (alu_control),
        .mem_read    (mem_read),
        .mem_write   (mem_write),
        .mem_to_reg  (mem_to_reg),
        .branch      (branch),
        .branch_type (branch_type),
        .jump        (jump),
        .jalr        (jalr),
        .lui         (lui),
        .auipc       (auipc),
        .mem_lr      (mem_lr),
        .mem_sc      (mem_sc),
        .mem_amo     (mem_amo),
        .amo_op      (amo_op),
        .imm         (imm),
        .rs1_addr    (rs1_addr),
        .rs2_addr    (rs2_addr),
        .rd_addr     (rd_addr)
    );

    // =========================================================================
    // KHỐI GHI FILE SÓNG DÀNH CHO GTKWAVE
    // =========================================================================
    initial begin
        $dumpfile("control_unit_waveform.vcd");
        $dumpvars(0, tb_control_unit);
    end

    // --- Test Stimulus ---
    initial begin
        $display("=========================================================================");
        $display("STARTING CONTROL UNIT TESTING WITH REAL INSTRUCTION HEX");
        $display("=========================================================================");

        //----------------------------------------------------------------------
        // 1. Lệnh R-type: ADD x3, x1, x2  (Mã máy: 002081B3)
        //----------------------------------------------------------------------
        instruction = 32'h002081B3; 
        #10;
        $display("[ADD]    reg_write=%b, alu_src=%b, alu_ctrl=%b, rs1=%d, rs2=%d, rd=%d", 
                  reg_write, alu_src, alu_control, rs1_addr, rs2_addr, rd_addr);

        //----------------------------------------------------------------------
        // 2. Lệnh I-type: ADDI x5, x4, -10 (Mã máy: FF620293)
        //----------------------------------------------------------------------
        instruction = 32'hFF620293; 
        #10;
        $display("[ADDI]   reg_write=%b, alu_src=%b, alu_ctrl=%b, imm=%d (Hex: %h)", 
                  reg_write, alu_src, alu_control, $signed(imm), imm);

        //----------------------------------------------------------------------
        // 3. Lệnh Load: LW x6, 4(x5)      (Mã máy: 0042A303)
        //----------------------------------------------------------------------
        instruction = 32'h0042A303; 
        #10;
        $display("[LW]     reg_write=%b, mem_read=%b, mem_to_reg=%b, imm=%d", 
                  reg_write, mem_read, mem_to_reg, imm);

        //----------------------------------------------------------------------
        // 4. Lệnh Store: SW x7, 8(x5)     (Mã máy: 0072A423)
        //----------------------------------------------------------------------
        instruction = 32'h0072A423; 
        #10;
        $display("[SW]     mem_write=%b, alu_src=%b, imm=%d", 
                  mem_write, alu_src, imm);

        //----------------------------------------------------------------------
        // 5. Lệnh Branch: BNE x1, x2, 16  (Mã máy: 00209863)
        //----------------------------------------------------------------------
        instruction = 32'h00209863; 
        #10;
        $display("[BNE]    branch=%b, branch_type=%b, alu_ctrl=%b, imm=%d", 
                  branch, branch_type, alu_control, $signed(imm));

        //----------------------------------------------------------------------
        // 6. Lệnh Jump: JAL x1, 2000      (Mã máy: 7D0000EF)
        //----------------------------------------------------------------------
        instruction = 32'h7D0000EF; 
        #10;
        $display("[JAL]    jump=%b, reg_write=%b, imm=%d", 
                  jump, reg_write, $signed(imm));

        //----------------------------------------------------------------------
        // 7. Lệnh Atomic LR: LR.W x10, (x11) (Mã máy: 1005A52F)
        //----------------------------------------------------------------------
        instruction = 32'h1005A52F; 
        #10;
        $display("[LR.W]   mem_lr=%b, reg_write=%b, alu_ctrl=%b", 
                  mem_lr, reg_write, alu_control);

        //----------------------------------------------------------------------
        // 8. Lệnh Atomic SC: SC.W x12, x13, (x11) (Mã máy: 18D5A62F)
        //----------------------------------------------------------------------
        instruction = 32'h18D5A62F; 
        #10;
        $display("[SC.W]   mem_sc=%b, reg_write=%b, rs2=%d", 
                  mem_sc, reg_write, rs2_addr);

        //----------------------------------------------------------------------
        // 9. Lệnh Atomic AMOADD: AMOADD.W x14, x15, (x11) (Mã máy: 00F5A72F)
        //----------------------------------------------------------------------
        instruction = 32'h00F5A72F; 
        #10;
        $display("[AMOADD] mem_amo=%b, amo_op=%d, reg_write=%b", 
                  mem_amo, amo_op, reg_write);

        //----------------------------------------------------------------------
        // 10. Trạng thái NOP / Không hợp lệ
        //----------------------------------------------------------------------
        instruction = 32'h00000000;
        #10;

        $display("=========================================================================");
        $display("TESTBENCH COMPLETED SUCCESFULLY - OPEN GTKWAVE TO VIEW WAVEFORM");
        $display("=========================================================================");
        $finish;
    end

endmodule
// =============================================================================
// risc_core.v - RV32I core with a simple 5-stage pipeline
//
// Stages:
//   IF  - fetch instruction from per-core instruction memory
//   ID  - decode, read register file, generate control signals
//   EX  - ALU, branch/jump decision, forwarding
//   MEM - shared-memory bus request/response
//   WB  - register-file writeback
//
// The external bus interface is kept compatible with the original multi-cycle
// core so top_8core, bus_ctrl, and the existing testbenches can still connect.
// =============================================================================
`timescale 1ns / 1ps

module risc_core #(
    parameter CORE_ID = 0,
    parameter INIT_FILE = "program.hex",
    parameter PROGRAM_WORDS = 256
) (
    input wire clk,
    input wire reset,

    output reg        mem_req,
    output reg [31:0] mem_addr,
    output reg [31:0] mem_wdata,
    output reg        mem_we,
    output reg        mem_re,
    output reg        mem_lr,
    output reg        mem_sc,
    output reg        mem_amo,
    output reg [ 3:0] mem_amo_op,

    input wire [31:0] mem_rdata,
    input wire        mem_ready,
    input wire        mem_sc_result
);

  // --- Các dây kết nối nội bộ giữa các tầng ---
  reg  [31:0] pc;
  wire [31:0] instr_from_mem;
  
  // Các dây đầu ra tầng IF/ID
  wire        if_id_valid;
  wire [31:0] if_id_pc;
  wire [31:0] if_id_instr;

  // Các dây đầu ra Control Unit
  wire cu_reg_write, cu_alu_src, cu_mem_read, cu_mem_write, cu_mem_to_reg;
  wire cu_branch, cu_jump, cu_jalr, cu_lui, cu_auipc, cu_mem_lr, cu_mem_sc, cu_mem_amo;
  wire [3:0] cu_alu_control, cu_amo_op;
  wire [2:0] cu_branch_type;
  wire [31:0] cu_imm;
  wire [4:0] cu_rs1_addr, cu_rs2_addr, cu_rd_addr;

  // Các dây đầu ra tầng ID/EX
  wire ex_valid, ex_reg_write, ex_alu_src, ex_mem_read, ex_mem_write, ex_mem_to_reg;
  wire ex_branch, ex_jump, ex_jalr, ex_lui, ex_auipc, ex_mem_lr, ex_mem_sc, ex_mem_amo;
  wire [3:0] ex_alu_control, ex_amo_op;
  wire [2:0] ex_branch_type;
  wire [31:0] ex_pc, ex_rs1_data, ex_rs2_data, ex_imm, ex_rs1_addr, ex_rs2_addr, ex_rd_addr;

  // Các dây điều khiển của Hazard Controller
  wire [1:0] forward_a, forward_b;
  wire load_use_stall, mem_wait;
  wire if_id_hold, if_id_clear, id_ex_hold, id_ex_clear, ex_mem_hold, mem_wb_clear;

  // Các dây tầng EX/ALU
  reg  [31:0] fwd_rs1_data, fwd_rs2_data, alu_input_a, alu_input_b;
  wire [31:0] alu_result, ex_stage_result, redirect_target;
  wire alu_zero;
  wire redirect_taken;

  // Các dây đầu ra tầng EX/MEM
  wire mem_valid, mem_reg_write, mem_mem_read, mem_mem_write, mem_mem_to_reg;
  wire mem_mem_lr, mem_mem_sc, mem_mem_amo;
  wire [3:0] mem_amo_op;
  wire [31:0] mem_result, mem_store_data, mem_rd_addr;

  // Các dây đầu ra tầng MEM/WB & Register File
  wire wb_valid, wb_reg_write;
  wire [4:0] wb_rd_addr;
  wire [31:0] wb_write_data, rs1_data, rs2_data;
  reg  [31:0] mem_wb_in_write_data;

  // --- Hệ thống Counters Phục Vụ Thuyết Trình Waveform ---
  reg [31:0] pipeline_cycle_count, retired_count, mem_stall_count, load_use_stall_count, flush_count;

  // =========================================================================
  // GỌI CÁC MODULE CON ĐỂ ĐẤU NỐI (INSTANTIATION)
  // =========================================================================

  // --- TẦNG 1: FETCH (IF) ---
  instr_mem #(.INIT_FILE(INIT_FILE), .PROGRAM_WORDS(PROGRAM_WORDS)) u_instr_mem (
      .addr(pc), .instruction(instr_from_mem)
  );

  if_id u_pipe_if_id (
      .clk(clk), .reset(reset), .clear(if_id_clear), .hold(if_id_hold),
      .if_pc(pc), .if_instr(instr_from_mem),
      .id_valid(if_id_valid), .id_pc(if_id_pc), .id_instr(if_id_instr)
  );

  // --- TẦNG 2: DECODE (ID) ---
  control_unit u_cu (
      .instruction(if_id_instr), .reg_write(cu_reg_write), .alu_src(cu_alu_src), .alu_control(cu_alu_control),
      .mem_read(cu_mem_read), .mem_write(cu_mem_write), .mem_to_reg(cu_mem_to_reg), .branch(cu_branch),
      .branch_type(cu_branch_type), .jump(cu_jump), .jalr(cu_jalr), .lui(cu_lui), .auipc(cu_auipc),
      .mem_lr(cu_mem_lr), .mem_sc(cu_mem_sc), .mem_amo(cu_mem_amo), .amo_op(cu_amo_op), .imm(cu_imm),
      .rs1_addr(cu_rs1_addr), .rs2_addr(cu_rs2_addr), .rd_addr(cu_rd_addr)
  );

  reg_file u_rf (
      .clk(clk), .reset(reset), .rs1_addr(cu_rs1_addr), .rs2_addr(cu_rs2_addr),
      .rd_addr(wb_rd_addr), .write_data(wb_write_data), .reg_write(wb_valid && wb_reg_write),
      .rs1_data(rs1_data), .rs2_data(rs2_data)
  );

  id_ex u_pipe_id_ex (
      .clk(clk), .reset(reset), .clear(id_ex_clear), .hold(id_ex_hold),
      .id_valid(if_id_valid), .id_pc(if_id_pc), .id_rs1_data(rs1_data), .id_rs2_data(rs2_data), .id_imm(cu_imm),
      .id_rs1_addr(cu_rs1_addr), .id_rs2_addr(cu_rs2_addr), .id_rd_addr(cu_rd_addr), .id_alu_control(cu_alu_control),
      .id_branch_type(cu_branch_type), .id_amo_op(cu_amo_op), .id_reg_write(cu_reg_write), .id_alu_src(cu_alu_src),
      .id_mem_read(cu_mem_read), .id_mem_write(cu_mem_write), .id_mem_to_reg(cu_mem_to_reg), .id_branch(cu_branch),
      .id_jump(cu_jump), .id_jalr(cu_jalr), .id_lui(cu_lui), .id_auipc(cu_auipc), .id_mem_lr(cu_mem_lr),
      .id_mem_sc(cu_mem_sc), .id_mem_amo(cu_mem_amo),
      // Ngõ ra
      .ex_valid(ex_valid), .ex_pc(ex_pc), .ex_rs1_data(ex_rs1_data), .ex_rs2_data(ex_rs2_data), .ex_imm(ex_imm),
      .ex_rs1_addr(ex_rs1_addr), .ex_rs2_addr(ex_rs2_addr), .ex_rd_addr(ex_rd_addr), .ex_alu_control(ex_alu_control),
      .ex_branch_type(ex_branch_type), .ex_amo_op(ex_amo_op), .ex_reg_write(ex_reg_write), .ex_alu_src(ex_alu_src),
      .ex_mem_read(ex_mem_read), .ex_mem_write(ex_mem_write), .ex_mem_to_reg(ex_mem_to_reg), .ex_branch(ex_branch),
      .ex_jump(ex_jump), .ex_jalr(ex_jalr), .ex_lui(ex_lui), .ex_auipc(ex_auipc), .ex_mem_lr(ex_mem_lr),
      .ex_mem_sc(ex_mem_sc), .ex_mem_amo(ex_mem_amo)
  );

  // --- TẦNG 3: EXECUTE (EX) & MẠCH NỐI MUX CHỌN DỮ LIỆU FORWARD ---
  wire mem_can_forward = mem_valid && mem_reg_write && (mem_rd_addr != 5'd0) && 
                         !(mem_mem_read || mem_mem_lr || mem_mem_sc || mem_mem_amo);
  wire wb_can_forward  = wb_valid && wb_reg_write && (wb_rd_addr != 5'd0);

  always_comb begin
      fwd_rs1_data = (forward_a == 2'b10) ? mem_result : ((forward_a == 2'b01) ? wb_write_data : ex_rs1_data);
      fwd_rs2_data = (forward_b == 2'b10) ? mem_result : ((forward_b == 2'b01) ? wb_write_data : ex_rs2_data);
      alu_input_a  = fwd_rs1_data;
      alu_input_b  = ex_alu_src ? ex_imm : fwd_rs2_data;
  end

  alu u_alu (.a(alu_input_a), .b(alu_input_b), .alu_control(ex_alu_control), .result(alu_result), .zero(alu_zero));

  // Tính toán rẽ nhánh
  branch_checker u_branch_check (
      .branch_type(ex_branch_type), .rs1(fwd_rs1_data), .rs2(fwd_rs2_data), .ex_valid(ex_valid),
      .ex_jump(ex_jump), .ex_branch(ex_branch), .ex_jalr(ex_jalr), .ex_pc(ex_pc), .ex_imm(ex_imm),
      .ex_lui(ex_lui), .ex_auipc(ex_auipc), .alu_result(alu_result),
      .redirect_taken(redirect_taken), .redirect_target(redirect_target), .ex_stage_result(ex_stage_result)
  );

  ex_mem u_pipe_ex_mem (
      .clk(clk), .reset(reset), .hold(ex_mem_hold),
      .ex_valid(ex_valid), .ex_reg_write(ex_reg_write), .ex_mem_read(ex_mem_read), .ex_mem_write(ex_mem_write),
      .ex_mem_to_reg(ex_mem_to_reg), .ex_mem_lr(ex_mem_lr), .ex_mem_sc(ex_mem_sc), .ex_mem_amo(ex_mem_amo), .ex_amo_op(ex_amo_op),
      .ex_result(ex_stage_result), .ex_store_data(fwd_rs2_data), .ex_rd_addr(ex_rd_addr),
      // Ngõ ra
      .mem_valid(mem_valid), .mem_reg_write(mem_reg_write), .mem_mem_read(mem_mem_read), .mem_mem_write(mem_mem_write),
      .mem_mem_to_reg(mem_mem_to_reg), .mem_mem_lr(mem_mem_lr), .mem_mem_sc(mem_mem_sc), .mem_mem_amo(mem_mem_amo), .mem_amo_op(mem_amo_op),
      .mem_result(mem_result), .mem_store_data(mem_store_data), .mem_rd_addr(mem_rd_addr)
  );

  // --- TẦNG 4: MEMORY (MEM) GIAO TIẾP BUS HỆ THỐNG ---
  wire mem_uses_bus = mem_valid && (mem_mem_read || mem_mem_write || mem_mem_lr || mem_mem_sc || mem_mem_amo);
  assign mem_wait   = mem_uses_bus && !mem_ready;
  wire mem_complete = mem_uses_bus && mem_ready;

  always_comb begin
      mem_req    = mem_uses_bus;
      mem_addr   = mem_result;
      mem_wdata  = mem_store_data;
      mem_we     = mem_mem_write || mem_mem_sc || mem_mem_amo;
      mem_re     = mem_mem_read || mem_mem_lr || mem_mem_amo;
      mem_lr     = mem_mem_lr;
      mem_sc     = mem_mem_sc;
      mem_amo    = mem_mem_amo;
      mem_amo_op = mem_amo_op;

      if (mem_mem_sc)            mem_wb_in_write_data = {31'b0, mem_sc_result};
      else if (mem_re)           mem_wb_in_write_data = mem_rdata;
      else                       mem_wb_in_write_data = mem_result;
  end

  mem_wb u_pipe_mem_wb (
      .clk(clk), .reset(reset), .clear(mem_wb_clear),
      .mem_wb_in_valid(mem_wait ? 1'b0 : mem_valid), 
      .mem_wb_in_reg_write(mem_wait ? 1'b0 : mem_reg_write),
      .mem_wb_in_rd_addr(mem_rd_addr), .mem_wb_in_write_data(mem_wb_in_write_data),
      // Ngõ ra kết nối trực tiếp vào chân ghi của Register File ở tầng 2 (WB Stage)
      .wb_valid(wb_valid), .wb_reg_write(wb_reg_write), .wb_rd_addr(wb_rd_addr), .wb_write_data(wb_write_data)
  );

  // --- 💡 BỘ ĐIỀU KHIỂN HAZARD TRUNG TÂM (HAZARD CONTROLLER) ---
  hazard_controller u_hazard_center (
      .ex_valid(ex_valid), .ex_reg_write(ex_reg_write), .ex_rs1_addr(ex_rs1_addr), .ex_rs2_addr(ex_rs2_addr),
      .mem_can_forward(mem_can_forward), .mem_rd_addr(mem_rd_addr), .wb_can_forward(wb_can_forward), .wb_rd_addr(wb_rd_addr),
      .id_valid(if_id_valid), .cu_rs1_addr(cu_rs1_addr), .cu_rs2_addr(cu_rs2_addr),
      .ex_load_like(ex_valid && ex_reg_write && (ex_mem_read || ex_mem_lr || ex_mem_sc || ex_mem_amo)), .ex_rd_addr(ex_rd_addr),
      .mem_wait(mem_wait), .redirect_taken(redirect_taken),
      // Cứu nguy
      .forward_a(forward_a), .forward_b(forward_b), .load_use_stall(load_use_stall),
      .if_id_hold(if_id_hold), .if_id_clear(if_id_clear), .id_ex_hold(id_ex_hold), .id_ex_clear(id_ex_clear),
      .ex_mem_hold(ex_mem_hold), .mem_wb_clear(mem_wb_clear)
  );

  // --- KHỐI ĐỒNG BỘ PC & CẬP NHẬT COUNTERS ---
  always @(posedge clk or posedge reset) begin
      if (reset) begin
          pc <= 32'd0;
          pipeline_cycle_count <= 0; retired_count <= 0; mem_stall_count <= 0; load_use_stall_count <= 0; flush_count <= 0;
      end else begin
          pipeline_cycle_count <= pipeline_cycle_count + 1;
          if (wb_valid) retired_count <= retired_count + 1;
          if (mem_wait) mem_stall_count <= mem_stall_count + 1;
          if (load_use_stall && !mem_wait) load_use_stall_count <= load_use_stall_count + 1;
          if (redirect_taken && !mem_wait) flush_count <= flush_count + 1;

          if (redirect_taken)
              pc <= redirect_target;
          else if (!if_id_hold)
              pc <= pc + 32'd4;
                end
  end

endmodule

// --- Module phụ trợ cho tầng EX để code Top sạch sẽ ---
module branch_checker (
    input wire [2:0] branch_type, input wire [31:0] rs1, rs2, input wire ex_valid, ex_jump, ex_branch, ex_jalr, ex_pc, ex_imm, ex_lui, ex_auipc, alu_result,
    output reg redirect_taken, output reg [31:0] redirect_target, output reg [31:0] ex_stage_result
);
    always_comb begin
        reg condition_met;
        condition_met = 1'b0;
        case (branch_type)
            3'b000: condition_met = (rs1 == rs2);
            3'b001: condition_met = (rs1 != rs2);
            3'b100: condition_met = ($signed(rs1) < $signed(rs2));
            3'b101: condition_met = ($signed(rs1) >= $signed(rs2));
            default: condition_met = 1'b0;
        endcase

        redirect_taken  = 1'b0;
        redirect_target = 32'd0;
        if (ex_valid && ex_jump) begin
            redirect_taken = 1'b1;
            redirect_target = ex_jalr ? ((rs1 + ex_imm) & 32'hFFFF_FFFE) : (ex_pc + ex_imm);
        end else if (ex_valid && ex_branch && condition_met) begin
            redirect_taken  = 1'b1;
            redirect_target = ex_pc + ex_imm;
        end

        ex_stage_result = alu_result;
        if (ex_lui)        ex_stage_result = ex_imm;
        else if (ex_auipc) ex_stage_result = ex_pc + ex_imm;
        else if (ex_jump)  ex_stage_result = ex_pc + 32'd4;
    end
endmodule
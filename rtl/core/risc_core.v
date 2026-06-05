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

  // -------------------------------------------------------------------------
  // Debug counters for waveform/demo evidence
  // -------------------------------------------------------------------------
  reg  [31:0] pipeline_cycle_count;
  reg  [31:0] retired_count;
  reg  [31:0] mem_stall_count;
  reg  [31:0] load_use_stall_count;
  reg  [31:0] flush_count;

  // -------------------------------------------------------------------------
  // IF stage
  // -------------------------------------------------------------------------
  reg  [31:0] pc;
  wire [31:0] instr_from_mem;

  instr_mem #(
      .INIT_FILE(INIT_FILE),
      .PROGRAM_WORDS(PROGRAM_WORDS)
  ) u_instr_mem (
      .addr       (pc),
      .instruction(instr_from_mem)
  );

  reg         if_id_valid;
  reg  [31:0] if_id_pc;
  reg  [31:0] if_id_instr;

  // -------------------------------------------------------------------------
  // ID stage
  // -------------------------------------------------------------------------
  wire        cu_reg_write;
  wire        cu_alu_src;
  wire [ 3:0] cu_alu_control;
  wire        cu_mem_read;
  wire        cu_mem_write;
  wire        cu_mem_to_reg;
  wire        cu_branch;
  wire [ 2:0] cu_branch_type;
  wire        cu_jump;
  wire        cu_jalr;
  wire        cu_lui;
  wire        cu_auipc;
  wire        cu_mem_lr;
  wire        cu_mem_sc;
  wire        cu_mem_amo;
  wire [ 3:0] cu_amo_op;
  wire [31:0] cu_imm;
  wire [ 4:0] cu_rs1_addr;
  wire [ 4:0] cu_rs2_addr;
  wire [ 4:0] cu_rd_addr;

  control_unit u_cu (
      .instruction(if_id_instr),
      .reg_write  (cu_reg_write),
      .alu_src    (cu_alu_src),
      .alu_control(cu_alu_control),
      .mem_read   (cu_mem_read),
      .mem_write  (cu_mem_write),
      .mem_to_reg (cu_mem_to_reg),
      .branch     (cu_branch),
      .branch_type(cu_branch_type),
      .jump       (cu_jump),
      .jalr       (cu_jalr),
      .lui        (cu_lui),
      .auipc      (cu_auipc),
      .mem_lr     (cu_mem_lr),
      .mem_sc     (cu_mem_sc),
      .mem_amo    (cu_mem_amo),
      .amo_op     (cu_amo_op),
      .imm        (cu_imm),
      .rs1_addr   (cu_rs1_addr),
      .rs2_addr   (cu_rs2_addr),
      .rd_addr    (cu_rd_addr)
  );

  wire        rf_write_en;
  wire [ 4:0] rf_rd_addr;
  wire [31:0] rf_write_data;
  wire [31:0] rs1_data;
  wire [31:0] rs2_data;

  reg_file u_rf (
      .clk       (clk),
      .reset     (reset),
      .rs1_addr  (cu_rs1_addr),
      .rs2_addr  (cu_rs2_addr),
      .rd_addr   (rf_rd_addr),
      .write_data(rf_write_data),
      .reg_write (rf_write_en),
      .rs1_data  (rs1_data),
      .rs2_data  (rs2_data)
  );

  // -------------------------------------------------------------------------
  // ID/EX pipeline register
  // -------------------------------------------------------------------------
  reg         id_ex_valid;
  reg  [31:0] id_ex_pc;
  reg  [31:0] id_ex_rs1_data;
  reg  [31:0] id_ex_rs2_data;
  reg  [31:0] id_ex_imm;
  reg  [ 4:0] id_ex_rs1_addr;
  reg  [ 4:0] id_ex_rs2_addr;
  reg  [ 4:0] id_ex_rd_addr;
  reg         id_ex_reg_write;
  reg         id_ex_alu_src;
  reg  [ 3:0] id_ex_alu_control;
  reg         id_ex_mem_read;
  reg         id_ex_mem_write;
  reg         id_ex_mem_to_reg;
  reg         id_ex_branch;
  reg  [ 2:0] id_ex_branch_type;
  reg         id_ex_jump;
  reg         id_ex_jalr;
  reg         id_ex_lui;
  reg         id_ex_auipc;
  reg         id_ex_mem_lr;
  reg         id_ex_mem_sc;
  reg         id_ex_mem_amo;
  reg  [ 3:0] id_ex_amo_op;

  // -------------------------------------------------------------------------
  // EX stage with forwarding
  // -------------------------------------------------------------------------
  reg  [31:0] fwd_rs1_data;
  reg  [31:0] fwd_rs2_data;
  reg  [31:0] alu_input_a;
  reg  [31:0] alu_input_b;
  wire [31:0] alu_result;
  wire        alu_zero;

  alu u_alu (
      .a          (alu_input_a),
      .b          (alu_input_b),
      .alu_control(id_ex_alu_control),
      .result     (alu_result),
      .zero       (alu_zero)
  );

  // -------------------------------------------------------------------------
  // EX/MEM pipeline register
  // -------------------------------------------------------------------------
  reg        ex_mem_valid;
  reg [31:0] ex_mem_result;
  reg [31:0] ex_mem_store_data;
  reg [ 4:0] ex_mem_rd_addr;
  reg        ex_mem_reg_write;
  reg        ex_mem_mem_read;
  reg        ex_mem_mem_write;
  reg        ex_mem_mem_to_reg;
  reg        ex_mem_mem_lr;
  reg        ex_mem_mem_sc;
  reg        ex_mem_mem_amo;
  reg [ 3:0] ex_mem_amo_op;

  // -------------------------------------------------------------------------
  // MEM/WB pipeline register
  // -------------------------------------------------------------------------
  reg        mem_wb_valid;
  reg        mem_wb_reg_write;
  reg [ 4:0] mem_wb_rd_addr;
  reg [31:0] mem_wb_write_data;

  assign rf_write_en   = mem_wb_valid && mem_wb_reg_write;
  assign rf_rd_addr    = mem_wb_rd_addr;
  assign rf_write_data = mem_wb_write_data;

  wire ex_mem_uses_memory =
        ex_mem_valid &&
        (ex_mem_mem_read || ex_mem_mem_write || ex_mem_mem_lr ||
         ex_mem_mem_sc || ex_mem_mem_amo);

  wire ex_mem_can_forward =
        ex_mem_valid && ex_mem_reg_write && (ex_mem_rd_addr != 5'd0) &&
        !(ex_mem_mem_read || ex_mem_mem_lr || ex_mem_mem_sc || ex_mem_mem_amo);

  wire mem_wb_can_forward = mem_wb_valid && mem_wb_reg_write && (mem_wb_rd_addr != 5'd0);

  always_comb begin
    fwd_rs1_data = id_ex_rs1_data;
    fwd_rs2_data = id_ex_rs2_data;

    if (ex_mem_can_forward && (ex_mem_rd_addr == id_ex_rs1_addr)) begin
      fwd_rs1_data = ex_mem_result;
    end else if (mem_wb_can_forward && (mem_wb_rd_addr == id_ex_rs1_addr)) begin
      fwd_rs1_data = mem_wb_write_data;
    end

    if (ex_mem_can_forward && (ex_mem_rd_addr == id_ex_rs2_addr)) begin
      fwd_rs2_data = ex_mem_result;
    end else if (mem_wb_can_forward && (mem_wb_rd_addr == id_ex_rs2_addr)) begin
      fwd_rs2_data = mem_wb_write_data;
    end

    alu_input_a = fwd_rs1_data;
    alu_input_b = id_ex_alu_src ? id_ex_imm : fwd_rs2_data;
  end

  reg        branch_condition_met;
  reg        redirect_taken;
  reg [31:0] redirect_target;
  reg [31:0] ex_stage_result;

  always_comb begin
    branch_condition_met = 1'b0;
    case (id_ex_branch_type)
      3'b000:  branch_condition_met = (fwd_rs1_data == fwd_rs2_data);  // BEQ
      3'b001:  branch_condition_met = (fwd_rs1_data != fwd_rs2_data);  // BNE
      3'b100:  branch_condition_met = ($signed(fwd_rs1_data) < $signed(fwd_rs2_data));  // BLT
      3'b101:  branch_condition_met = ($signed(fwd_rs1_data) >= $signed(fwd_rs2_data));  // BGE
      default: branch_condition_met = 1'b0;
    endcase

    redirect_taken  = 1'b0;
    redirect_target = 32'd0;
    if (id_ex_valid && id_ex_jump) begin
      redirect_taken = 1'b1;
      redirect_target = id_ex_jalr ? ((fwd_rs1_data + id_ex_imm) & 32'hFFFF_FFFE)
                                         : (id_ex_pc + id_ex_imm);
    end else if (id_ex_valid && id_ex_branch && branch_condition_met) begin
      redirect_taken  = 1'b1;
      redirect_target = id_ex_pc + id_ex_imm;
    end

    ex_stage_result = alu_result;
    if (id_ex_lui) begin
      ex_stage_result = id_ex_imm;
    end else if (id_ex_auipc) begin
      ex_stage_result = id_ex_pc + id_ex_imm;
    end else if (id_ex_jump) begin
      ex_stage_result = id_ex_pc + 32'd4;
    end
  end

  wire id_ex_load_like =
        id_ex_valid && id_ex_reg_write &&
        (id_ex_mem_read || id_ex_mem_lr || id_ex_mem_sc || id_ex_mem_amo);

  wire load_use_stall =
        if_id_valid && id_ex_load_like && (id_ex_rd_addr != 5'd0) &&
        ((id_ex_rd_addr == cu_rs1_addr) || (id_ex_rd_addr == cu_rs2_addr));

  wire mem_wait = ex_mem_uses_memory && !mem_ready;
  wire mem_complete = ex_mem_uses_memory && mem_ready;

  always_comb begin
    mem_req    = ex_mem_uses_memory;
    mem_addr   = ex_mem_result;
    mem_wdata  = ex_mem_store_data;
    mem_we     = ex_mem_mem_write || ex_mem_mem_sc || ex_mem_mem_amo;
    mem_re     = ex_mem_mem_read || ex_mem_mem_lr || ex_mem_mem_amo;
    mem_lr     = ex_mem_mem_lr;
    mem_sc     = ex_mem_mem_sc;
    mem_amo    = ex_mem_mem_amo;
    mem_amo_op = ex_mem_amo_op;
  end

  // -------------------------------------------------------------------------
  // Pipeline register update
  // -------------------------------------------------------------------------
  always @(posedge clk or posedge reset) begin
    if (reset) begin
      pc                   <= 32'd0;

      if_id_valid          <= 1'b0;
      if_id_pc             <= 32'd0;
      if_id_instr          <= 32'd0;

      id_ex_valid          <= 1'b0;
      id_ex_pc             <= 32'd0;
      id_ex_rs1_data       <= 32'd0;
      id_ex_rs2_data       <= 32'd0;
      id_ex_imm            <= 32'd0;
      id_ex_rs1_addr       <= 5'd0;
      id_ex_rs2_addr       <= 5'd0;
      id_ex_rd_addr        <= 5'd0;
      id_ex_reg_write      <= 1'b0;
      id_ex_alu_src        <= 1'b0;
      id_ex_alu_control    <= 4'd0;
      id_ex_mem_read       <= 1'b0;
      id_ex_mem_write      <= 1'b0;
      id_ex_mem_to_reg     <= 1'b0;
      id_ex_branch         <= 1'b0;
      id_ex_branch_type    <= 3'd0;
      id_ex_jump           <= 1'b0;
      id_ex_jalr           <= 1'b0;
      id_ex_lui            <= 1'b0;
      id_ex_auipc          <= 1'b0;
      id_ex_mem_lr         <= 1'b0;
      id_ex_mem_sc         <= 1'b0;
      id_ex_mem_amo        <= 1'b0;
      id_ex_amo_op         <= 4'd0;

      ex_mem_valid         <= 1'b0;
      ex_mem_result        <= 32'd0;
      ex_mem_store_data    <= 32'd0;
      ex_mem_rd_addr       <= 5'd0;
      ex_mem_reg_write     <= 1'b0;
      ex_mem_mem_read      <= 1'b0;
      ex_mem_mem_write     <= 1'b0;
      ex_mem_mem_to_reg    <= 1'b0;
      ex_mem_mem_lr        <= 1'b0;
      ex_mem_mem_sc        <= 1'b0;
      ex_mem_mem_amo       <= 1'b0;
      ex_mem_amo_op        <= 4'd0;

      mem_wb_valid         <= 1'b0;
      mem_wb_reg_write     <= 1'b0;
      mem_wb_rd_addr       <= 5'd0;
      mem_wb_write_data    <= 32'd0;

      pipeline_cycle_count <= 32'd0;
      retired_count        <= 32'd0;
      mem_stall_count      <= 32'd0;
      load_use_stall_count <= 32'd0;
      flush_count          <= 32'd0;
    end else begin
      pipeline_cycle_count <= pipeline_cycle_count + 32'd1;
      if (mem_wb_valid) begin
        retired_count <= retired_count + 32'd1;
      end

      if (mem_wait) begin
        mem_wb_valid <= 1'b0;
        mem_stall_count <= mem_stall_count + 32'd1;
      end else if (mem_complete) begin
        mem_wb_valid     <= ex_mem_valid;
        mem_wb_reg_write <= ex_mem_reg_write;
        mem_wb_rd_addr   <= ex_mem_rd_addr;
        if (ex_mem_mem_sc) begin
          mem_wb_write_data <= {31'b0, mem_sc_result};
        end else if (ex_mem_mem_read || ex_mem_mem_lr || ex_mem_mem_amo) begin
          mem_wb_write_data <= mem_rdata;
        end else begin
          mem_wb_write_data <= ex_mem_result;
        end

        // Give the shared bus one cycle with mem_req deasserted before
        // a possible next transaction from the same core.
        ex_mem_valid <= 1'b0;
      end else begin
        mem_wb_valid      <= ex_mem_valid;
        mem_wb_reg_write  <= ex_mem_reg_write;
        mem_wb_rd_addr    <= ex_mem_rd_addr;
        mem_wb_write_data <= ex_mem_result;

        ex_mem_valid      <= id_ex_valid;
        ex_mem_result     <= ex_stage_result;
        ex_mem_store_data <= fwd_rs2_data;
        ex_mem_rd_addr    <= id_ex_rd_addr;
        ex_mem_reg_write  <= id_ex_reg_write;
        ex_mem_mem_read   <= id_ex_mem_read;
        ex_mem_mem_write  <= id_ex_mem_write;
        ex_mem_mem_to_reg <= id_ex_mem_to_reg;
        ex_mem_mem_lr     <= id_ex_mem_lr;
        ex_mem_mem_sc     <= id_ex_mem_sc;
        ex_mem_mem_amo    <= id_ex_mem_amo;
        ex_mem_amo_op     <= id_ex_amo_op;

        if (redirect_taken) begin
          pc               <= redirect_target;
          if_id_valid      <= 1'b0;
          if_id_pc         <= 32'd0;
          if_id_instr      <= 32'd0;

          id_ex_valid      <= 1'b0;
          id_ex_reg_write  <= 1'b0;
          id_ex_mem_read   <= 1'b0;
          id_ex_mem_write  <= 1'b0;
          id_ex_mem_to_reg <= 1'b0;
          id_ex_branch     <= 1'b0;
          id_ex_jump       <= 1'b0;
          id_ex_mem_lr     <= 1'b0;
          id_ex_mem_sc     <= 1'b0;
          id_ex_mem_amo    <= 1'b0;
          flush_count      <= flush_count + 32'd1;
        end else if (load_use_stall) begin
          id_ex_valid          <= 1'b0;
          id_ex_reg_write      <= 1'b0;
          id_ex_mem_read       <= 1'b0;
          id_ex_mem_write      <= 1'b0;
          id_ex_mem_to_reg     <= 1'b0;
          id_ex_branch         <= 1'b0;
          id_ex_jump           <= 1'b0;
          id_ex_mem_lr         <= 1'b0;
          id_ex_mem_sc         <= 1'b0;
          id_ex_mem_amo        <= 1'b0;
          load_use_stall_count <= load_use_stall_count + 32'd1;
        end else begin
          if_id_valid       <= 1'b1;
          if_id_pc          <= pc;
          if_id_instr       <= instr_from_mem;
          pc                <= pc + 32'd4;

          id_ex_valid       <= if_id_valid;
          id_ex_pc          <= if_id_pc;
          id_ex_rs1_data    <= rs1_data;
          id_ex_rs2_data    <= rs2_data;
          id_ex_imm         <= cu_imm;
          id_ex_rs1_addr    <= cu_rs1_addr;
          id_ex_rs2_addr    <= cu_rs2_addr;
          id_ex_rd_addr     <= cu_rd_addr;
          id_ex_reg_write   <= if_id_valid ? cu_reg_write : 1'b0;
          id_ex_alu_src     <= if_id_valid ? cu_alu_src : 1'b0;
          id_ex_alu_control <= if_id_valid ? cu_alu_control : 4'd0;
          id_ex_mem_read    <= if_id_valid ? cu_mem_read : 1'b0;
          id_ex_mem_write   <= if_id_valid ? cu_mem_write : 1'b0;
          id_ex_mem_to_reg  <= if_id_valid ? cu_mem_to_reg : 1'b0;
          id_ex_branch      <= if_id_valid ? cu_branch : 1'b0;
          id_ex_branch_type <= if_id_valid ? cu_branch_type : 3'd0;
          id_ex_jump        <= if_id_valid ? cu_jump : 1'b0;
          id_ex_jalr        <= if_id_valid ? cu_jalr : 1'b0;
          id_ex_lui         <= if_id_valid ? cu_lui : 1'b0;
          id_ex_auipc       <= if_id_valid ? cu_auipc : 1'b0;
          id_ex_mem_lr      <= if_id_valid ? cu_mem_lr : 1'b0;
          id_ex_mem_sc      <= if_id_valid ? cu_mem_sc : 1'b0;
          id_ex_mem_amo     <= if_id_valid ? cu_mem_amo : 1'b0;
          id_ex_amo_op      <= if_id_valid ? cu_amo_op : 4'd0;
        end
      end
    end
  end

endmodule

// =============================================================================
// risc_core.v - Lõi CPU RISC-V hoàn chỉnh (Multi-Cycle, 3-State FSM)
//
// Gom: pc_logic + instr_mem + control_unit + alu + reg_file
//
// FSM:
//   FETCH   -> Đọc lệnh từ instr_mem[PC], lưu vào instr_reg
//   EXECUTE -> Giải mã + ALU + branch/jump. 
//              R/I/LUI/AUIPC/JAL/JALR: ghi rd, cập nhật PC, -> FETCH
//              Branch: xét điều kiện, cập nhật PC, -> FETCH
//              LW/SW: -> MEMORY
//   MEMORY  -> Gửi mem_req tới bus, stall cho đến mem_ready=1, -> FETCH
//
// Parameter: CORE_ID (0-7), INIT_FILE (hex file cho instr_mem)
// =============================================================================
`timescale 1ns / 1ps

module risc_core #(
    parameter CORE_ID   = 0,
    parameter INIT_FILE = "program.hex"
)(
    input  wire        clk,
    input  wire        reset,

    // --- Giao diện với Bus Controller ---
    output reg         mem_req,       // Yêu cầu truy cập memory
    output reg  [31:0] mem_addr,      // Địa chỉ
    output reg  [31:0] mem_wdata,     // Dữ liệu ghi (SW)
    output reg         mem_we,        // Write enable
    output reg         mem_re,        // Read enable

    input  wire [31:0] mem_rdata,     // Dữ liệu đọc từ bus
    input  wire        mem_ready      // Giao dịch hoàn thành
);

    // =========================================================================
    // FSM States
    // =========================================================================
    localparam S_FETCH   = 2'd0;
    localparam S_EXECUTE = 2'd1;
    localparam S_MEMORY  = 2'd2;

    reg [1:0] state;

    // =========================================================================
    // Internal wires: PC
    // =========================================================================
    wire [31:0] pc;
    reg         pc_stall;
    reg         pc_branch_taken;
    reg  [31:0] pc_branch_target;
    reg         pc_jump;
    reg  [31:0] pc_jump_target;

    // =========================================================================
    // Internal wires: Instruction
    // =========================================================================
    wire [31:0] instr_from_mem;   // Lệnh đọc từ instr_mem
    reg  [31:0] instr_reg;        // Lệnh đã latch (dùng trong EXECUTE/MEMORY)

    // =========================================================================
    // Internal wires: Control Unit
    // =========================================================================
    wire        cu_reg_write;
    wire        cu_alu_src;
    wire [3:0]  cu_alu_control;
    wire        cu_mem_read;
    wire        cu_mem_write;
    wire        cu_mem_to_reg;
    wire        cu_branch;
    wire [2:0]  cu_branch_type;
    wire        cu_jump;
    wire        cu_jalr;
    wire        cu_lui;
    wire        cu_auipc;
    wire [31:0] cu_imm;
    wire [4:0]  cu_rs1_addr;
    wire [4:0]  cu_rs2_addr;
    wire [4:0]  cu_rd_addr;

    // =========================================================================
    // Internal wires: Register File
    // =========================================================================
    wire [31:0] rs1_data;
    wire [31:0] rs2_data;
    reg         rf_write_en;
    reg  [31:0] rf_write_data;
    reg  [4:0]  rf_rd_addr;

    // =========================================================================
    // Internal wires: ALU
    // =========================================================================
    wire [31:0] alu_result;
    wire        alu_zero;
    reg  [31:0] alu_input_a;
    reg  [31:0] alu_input_b;

    // =========================================================================
    // Saved ALU result (for MEMORY state)
    // =========================================================================
    reg  [31:0] saved_alu_result;
    reg  [4:0]  saved_rd_addr;
    reg         saved_mem_to_reg;
    reg         saved_reg_write;

    // =========================================================================
    // Sub-module instantiation
    // =========================================================================

    // --- PC Logic ---
    pc_logic u_pc (
        .clk          (clk),
        .reset        (reset),
        .stall        (pc_stall),
        .branch_taken (pc_branch_taken),
        .branch_target(pc_branch_target),
        .jump         (pc_jump),
        .jump_target  (pc_jump_target),
        .pc           (pc)
    );

    // --- Instruction Memory (ROM riêng cho core này) ---
    instr_mem #(.INIT_FILE(INIT_FILE)) u_instr_mem (
        .addr        (pc),
        .instruction (instr_from_mem)
    );

    // --- Control Unit ---
    control_unit u_cu (
        .instruction (instr_reg),
        .reg_write   (cu_reg_write),
        .alu_src     (cu_alu_src),
        .alu_control (cu_alu_control),
        .mem_read    (cu_mem_read),
        .mem_write   (cu_mem_write),
        .mem_to_reg  (cu_mem_to_reg),
        .branch      (cu_branch),
        .branch_type (cu_branch_type),
        .jump        (cu_jump),
        .jalr        (cu_jalr),
        .lui         (cu_lui),
        .auipc       (cu_auipc),
        .imm         (cu_imm),
        .rs1_addr    (cu_rs1_addr),
        .rs2_addr    (cu_rs2_addr),
        .rd_addr     (cu_rd_addr)
    );

    // --- Register File ---
    reg_file u_rf (
        .clk        (clk),
        .reset      (reset),
        .rs1_addr   (cu_rs1_addr),
        .rs2_addr   (cu_rs2_addr),
        .rd_addr    (rf_rd_addr),
        .write_data (rf_write_data),
        .reg_write  (rf_write_en),
        .rs1_data   (rs1_data),
        .rs2_data   (rs2_data)
    );

    // --- ALU ---
    alu u_alu (
        .a           (alu_input_a),
        .b           (alu_input_b),
        .alu_control (cu_alu_control),
        .result      (alu_result),
        .zero        (alu_zero)
    );

    // =========================================================================
    // ALU Input MUX (combinational)
    // =========================================================================
    always @(*) begin
        alu_input_a = rs1_data;
        alu_input_b = cu_alu_src ? cu_imm : rs2_data;
    end

    // =========================================================================
    // Branch condition evaluation (combinational)
    // =========================================================================
    reg branch_condition_met;

    always @(*) begin
        branch_condition_met = 1'b0;
        if (cu_branch) begin
            case (cu_branch_type)
                3'b000: branch_condition_met =  alu_zero;                              // BEQ
                3'b001: branch_condition_met = ~alu_zero;                              // BNE
                3'b100: branch_condition_met = (alu_result[31] == 1'b1);               // BLT (signed)
                3'b101: branch_condition_met = (alu_result[31] == 1'b0) || alu_zero;   // BGE (signed)
                default: branch_condition_met = 1'b0;
            endcase
        end
    end

    // =========================================================================
    // Saved PC for JAL/JALR (PC+4 → rd)
    // =========================================================================
    reg [31:0] saved_pc;

    // =========================================================================
    // Main FSM
    // =========================================================================
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state            <= S_FETCH;
            instr_reg        <= 32'd0;
            pc_stall         <= 1'b0;
            pc_branch_taken  <= 1'b0;
            pc_branch_target <= 32'd0;
            pc_jump          <= 1'b0;
            pc_jump_target   <= 32'd0;
            rf_write_en      <= 1'b0;
            rf_write_data    <= 32'd0;
            rf_rd_addr       <= 5'd0;
            mem_req          <= 1'b0;
            mem_addr         <= 32'd0;
            mem_wdata        <= 32'd0;
            mem_we           <= 1'b0;
            mem_re           <= 1'b0;
            saved_alu_result <= 32'd0;
            saved_rd_addr    <= 5'd0;
            saved_mem_to_reg <= 1'b0;
            saved_reg_write  <= 1'b0;
            saved_pc         <= 32'd0;
        end
        else begin
            // Clear one-shot signals mỗi cycle
            pc_branch_taken <= 1'b0;
            pc_jump         <= 1'b0;
            rf_write_en     <= 1'b0;

            case (state)
                // =============================================================
                // FETCH: Đọc lệnh từ instr_mem, latch vào instr_reg
                // =============================================================
                S_FETCH: begin
                    instr_reg <= instr_from_mem;   // Latch instruction
                    saved_pc  <= pc;               // Lưu PC hiện tại (cho JAL/JALR)
                    pc_stall  <= 1'b1;             // Stall PC trong EXECUTE
                    state     <= S_EXECUTE;
                end

                // =============================================================
                // EXECUTE: Giải mã + ALU + quyết định
                // =============================================================
                S_EXECUTE: begin
                    // --- Trường hợp 1: Load (LW) ---
                    if (cu_mem_read) begin
                        // Cần truy cập bus → chuyển MEMORY
                        saved_alu_result <= alu_result;  // Địa chỉ = rs1 + imm
                        saved_rd_addr    <= cu_rd_addr;
                        saved_mem_to_reg <= 1'b1;
                        saved_reg_write  <= 1'b1;
                        mem_req  <= 1'b1;
                        mem_re   <= 1'b1;
                        mem_we   <= 1'b0;
                        mem_addr <= alu_result;          // rs1 + imm
                        state    <= S_MEMORY;
                    end

                    // --- Trường hợp 2: Store (SW) ---
                    else if (cu_mem_write) begin
                        saved_alu_result <= alu_result;
                        saved_rd_addr    <= 5'd0;
                        saved_mem_to_reg <= 1'b0;
                        saved_reg_write  <= 1'b0;
                        mem_req  <= 1'b1;
                        mem_we   <= 1'b1;
                        mem_re   <= 1'b0;
                        mem_addr <= alu_result;          // rs1 + imm
                        mem_wdata <= rs2_data;           // Dữ liệu từ rs2
                        state    <= S_MEMORY;
                    end

                    // --- Trường hợp 3: Branch ---
                    else if (cu_branch) begin
                        if (branch_condition_met) begin
                            pc_branch_taken  <= 1'b1;
                            pc_branch_target <= saved_pc + cu_imm;
                        end
                        pc_stall <= 1'b0;    // Unstall PC
                        state    <= S_FETCH;
                    end

                    // --- Trường hợp 4: JAL ---
                    else if (cu_jump && !cu_jalr) begin
                        // rd = PC + 4 (return address)
                        rf_write_en   <= 1'b1;
                        rf_rd_addr    <= cu_rd_addr;
                        rf_write_data <= saved_pc + 32'd4;
                        // Jump to PC + imm
                        pc_jump        <= 1'b1;
                        pc_jump_target <= saved_pc + cu_imm;
                        pc_stall       <= 1'b0;
                        state          <= S_FETCH;
                    end

                    // --- Trường hợp 5: JALR ---
                    else if (cu_jump && cu_jalr) begin
                        rf_write_en   <= 1'b1;
                        rf_rd_addr    <= cu_rd_addr;
                        rf_write_data <= saved_pc + 32'd4;
                        pc_jump        <= 1'b1;
                        pc_jump_target <= (alu_result) & 32'hFFFFFFFE; // rs1+imm, bit[0]=0
                        pc_stall       <= 1'b0;
                        state          <= S_FETCH;
                    end

                    // --- Trường hợp 6: LUI ---
                    else if (cu_lui) begin
                        rf_write_en   <= 1'b1;
                        rf_rd_addr    <= cu_rd_addr;
                        rf_write_data <= cu_imm;  // Immediate đã shift 12 bit
                        pc_stall      <= 1'b0;
                        state         <= S_FETCH;
                    end

                    // --- Trường hợp 7: AUIPC ---
                    else if (cu_auipc) begin
                        rf_write_en   <= 1'b1;
                        rf_rd_addr    <= cu_rd_addr;
                        rf_write_data <= saved_pc + cu_imm;
                        pc_stall      <= 1'b0;
                        state         <= S_FETCH;
                    end

                    // --- Trường hợp 8: R-type / I-type ALU ---
                    else begin
                        if (cu_reg_write) begin
                            rf_write_en   <= 1'b1;
                            rf_rd_addr    <= cu_rd_addr;
                            rf_write_data <= alu_result;
                        end
                        pc_stall <= 1'b0;    // Unstall → PC += 4
                        state    <= S_FETCH;
                    end
                end

                // =============================================================
                // MEMORY: Chờ bus_ctrl trả mem_ready
                // =============================================================
                S_MEMORY: begin
                    if (mem_ready) begin
                        // Giao dịch hoàn thành
                        mem_req <= 1'b0;
                        mem_we  <= 1'b0;
                        mem_re  <= 1'b0;

                        // Load: ghi mem_rdata vào rd
                        if (saved_reg_write) begin
                            rf_write_en   <= 1'b1;
                            rf_rd_addr    <= saved_rd_addr;
                            rf_write_data <= saved_mem_to_reg ? mem_rdata : saved_alu_result;
                        end

                        pc_stall <= 1'b0;    // Unstall PC → PC += 4
                        state    <= S_FETCH;
                    end
                    // Else: giữ nguyên, tiếp tục chờ (stall)
                end

                default: state <= S_FETCH;
            endcase
        end
    end

endmodule

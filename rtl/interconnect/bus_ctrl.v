// =============================================================================
// bus_ctrl.v - Bộ điều khiển Bus hệ thống cho 8 lõi RISC-V
//
// Chuyển đổi từ logic C++ (SystemBus.cpp + SyncManager.cpp) sang Verilog RTL.
//
// Thiết kế FSM 2 phase:
//   IDLE    -> Nhận grant từ arbiter, gửi tín hiệu tới mem, chuyển sang DONE
//   DONE    -> Lấy kết quả từ mem, trả về cho core, quay lại IDLE
//   AMO_CALC -> Tính toán AMO, ghi kết quả, chuyển sang AMO_DONE
//   AMO_DONE -> Trả kết quả AMO cho core
//
// Tín hiệu tới memory (dm_addr, dm_we, dm_re) là COMBINATIONAL
// để data_mem async read hoạt động đúng trong cùng cycle.
// =============================================================================
`timescale 1ns / 1ps

module bus_ctrl (
    input  wire        clk,
    input  wire        reset,

    // =========================================================================
    // Giao diện với Arbiter
    // =========================================================================
    output wire [7:0]  bus_request,
    input  wire [7:0]  bus_grant,
    input  wire        bus_grant_valid,
    input  wire [2:0]  bus_grant_id,

    // =========================================================================
    // Giao diện với 8 Core
    // =========================================================================
    input  wire [7:0]  core_mem_req,
    input  wire [31:0] core_addr   [0:7],
    input  wire [31:0] core_wdata  [0:7],
    input  wire [7:0]  core_we,
    input  wire [7:0]  core_re,

    // Atomic signals
    input  wire [7:0]  core_lr,
    input  wire [7:0]  core_sc,
    input  wire [7:0]  core_amo,
    input  wire [3:0]  core_amo_op [0:7],

    // Phản hồi
    output reg  [31:0] core_rdata  [0:7],
    output reg  [7:0]  core_ready,
    output reg  [7:0]  core_sc_result,

    // =========================================================================
    // Giao diện với Data Memory (COMBINATIONAL outputs)
    // =========================================================================
    output reg  [31:0] dm_addr,
    output reg  [31:0] dm_wdata,
    input  wire [31:0] dm_rdata,
    output reg         dm_we,
    output reg         dm_re
);

    // =========================================================================
    // AMO Operation codes
    // =========================================================================
    localparam AMO_SWAP = 4'd0;
    localparam AMO_ADD  = 4'd1;
    localparam AMO_AND  = 4'd2;
    localparam AMO_OR   = 4'd3;
    localparam AMO_XOR  = 4'd4;
    localparam AMO_MAX  = 4'd5;
    localparam AMO_MAXU = 4'd6;
    localparam AMO_MIN  = 4'd7;
    localparam AMO_MINU = 4'd8;

    // =========================================================================
    // FSM States
    // =========================================================================
    localparam S_IDLE     = 3'd0;  // Chờ grant
    localparam S_READ     = 3'd1;  // Đọc dữ liệu từ mem (1 cycle để mem trả data)
    localparam S_WRITE    = 3'd1;  // Ghi dữ liệu (alias, xử lý cùng 1 cycle)
    localparam S_LR       = 3'd1;  // Load Reserved
    localparam S_SC       = 3'd1;  // Store Conditional
    localparam S_AMO_READ = 3'd2;  // AMO phase 1: đọc giá trị cũ
    localparam S_AMO_CALC = 3'd3;  // AMO phase 2: tính toán + ghi

    reg [2:0] state;

    // =========================================================================
    // Transaction register (lưu thông tin giao dịch đang xử lý)
    // =========================================================================
    reg [2:0]  active_core;       // Core đang được phục vụ
    reg [31:0] active_addr;       // Địa chỉ giao dịch
    reg [31:0] active_wdata;      // Dữ liệu ghi
    reg        active_is_write;   // Là giao dịch ghi?
    reg        active_is_read;    // Là giao dịch đọc?
    reg        active_is_lr;      // Load Reserved?
    reg        active_is_sc;      // Store Conditional?
    reg        active_is_amo;     // AMO?
    reg [3:0]  active_amo_op;     // Loại AMO

    // =========================================================================
    // Reservation Station (LR/SC)
    // =========================================================================
    reg        reservation_valid [0:7];
    reg [31:0] reservation_addr  [0:7];

    // =========================================================================
    // AMO registers
    // =========================================================================
    reg [31:0] amo_old_val;
    reg [31:0] amo_result;

    // =========================================================================
    // Bus request = core memory requests
    // =========================================================================
    assign bus_request = core_mem_req;

    // =========================================================================
    // AMO tính toán (combinational)
    // =========================================================================
    reg [31:0] amo_computed;
    always @(*) begin
        case (active_amo_op)
            AMO_SWAP: amo_computed = active_wdata;
            AMO_ADD:  amo_computed = amo_old_val + active_wdata;
            AMO_AND:  amo_computed = amo_old_val & active_wdata;
            AMO_OR:   amo_computed = amo_old_val | active_wdata;
            AMO_XOR:  amo_computed = amo_old_val ^ active_wdata;
            AMO_MAX:  amo_computed = ($signed(amo_old_val) > $signed(active_wdata))
                                     ? amo_old_val : active_wdata;
            AMO_MAXU: amo_computed = (amo_old_val > active_wdata)
                                     ? amo_old_val : active_wdata;
            AMO_MIN:  amo_computed = ($signed(amo_old_val) < $signed(active_wdata))
                                     ? amo_old_val : active_wdata;
            AMO_MINU: amo_computed = (amo_old_val < active_wdata)
                                     ? amo_old_val : active_wdata;
            default:  amo_computed = amo_old_val;
        endcase
    end

    // =========================================================================
    // Combinational Memory Interface
    // Tín hiệu dm_addr, dm_re, dm_we, dm_wdata phải là combinational
    // để data_mem async read có thể trả dm_rdata trong CÙNG cycle.
    // =========================================================================
    always @(*) begin
        // Defaults
        dm_addr  = 32'd0;
        dm_wdata = 32'd0;
        dm_we    = 1'b0;
        dm_re    = 1'b0;

        case (state)
            S_IDLE: begin
                if (bus_grant_valid) begin
                    dm_addr = core_addr[bus_grant_id];
                    // READ hoặc LR: kích hoạt đọc
                    if (core_re[bus_grant_id] || core_lr[bus_grant_id]) begin
                        dm_re = 1'b1;
                    end
                    // WRITE thường: kích hoạt ghi
                    if (core_we[bus_grant_id] && !core_sc[bus_grant_id]) begin
                        dm_we    = 1'b1;
                        dm_wdata = core_wdata[bus_grant_id];
                    end
                    // SC: chỉ ghi nếu reservation valid
                    if (core_sc[bus_grant_id]) begin
                        if (reservation_valid[bus_grant_id] &&
                            reservation_addr[bus_grant_id] == core_addr[bus_grant_id]) begin
                            dm_we    = 1'b1;
                            dm_wdata = core_wdata[bus_grant_id];
                        end
                    end
                    // AMO: bắt đầu đọc
                    if (core_amo[bus_grant_id]) begin
                        dm_re = 1'b1;
                    end
                end
            end

            S_AMO_READ: begin
                // AMO phase 1: giữ đọc để lấy old value
                dm_addr = active_addr;
                dm_re   = 1'b1;
            end

            S_AMO_CALC: begin
                // AMO phase 2: ghi kết quả
                dm_addr  = active_addr;
                dm_we    = 1'b1;
                dm_wdata = amo_computed;
            end

            default: ;
        endcase
    end

    // =========================================================================
    // Sequential Logic: FSM + Reservation + Output
    // =========================================================================
    integer j;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state          <= S_IDLE;
            core_ready     <= 8'b0;
            core_sc_result <= 8'b0;
            active_core    <= 3'd0;
            active_addr    <= 32'd0;
            active_wdata   <= 32'd0;
            active_is_write <= 1'b0;
            active_is_read  <= 1'b0;
            active_is_lr    <= 1'b0;
            active_is_sc    <= 1'b0;
            active_is_amo   <= 1'b0;
            active_amo_op   <= 4'd0;
            amo_old_val     <= 32'd0;

            for (j = 0; j < 8; j = j + 1) begin
                reservation_valid[j] <= 1'b0;
                reservation_addr[j]  <= 32'd0;
                core_rdata[j]        <= 32'd0;
            end
        end
        else begin
            // Mặc định: clear transient signals
            core_ready <= 8'b0;

            case (state)
                // =============================================================
                // IDLE: Nhận grant, ghi nhận giao dịch, xử lý 1-cycle ops
                // =============================================================
                S_IDLE: begin
                    if (bus_grant_valid) begin
                        // Lưu thông tin giao dịch
                        active_core    <= bus_grant_id;
                        active_addr    <= core_addr[bus_grant_id];
                        active_wdata   <= core_wdata[bus_grant_id];
                        active_is_write <= core_we[bus_grant_id] && !core_sc[bus_grant_id];
                        active_is_read  <= core_re[bus_grant_id] && !core_lr[bus_grant_id];
                        active_is_lr    <= core_lr[bus_grant_id];
                        active_is_sc    <= core_sc[bus_grant_id];
                        active_is_amo   <= core_amo[bus_grant_id];
                        active_amo_op   <= core_amo_op[bus_grant_id];

                        // =====================================================
                        // AMO: chuyển sang FSM riêng
                        // =====================================================
                        if (core_amo[bus_grant_id]) begin
                            state <= S_AMO_READ;
                            // Invalidate reservations tại addr
                            for (j = 0; j < 8; j = j + 1) begin
                                if (reservation_valid[j] &&
                                    reservation_addr[j] == core_addr[bus_grant_id]) begin
                                    reservation_valid[j] <= 1'b0;
                                end
                            end
                        end
                        // =====================================================
                        // READ thường: dm_re đã set ở combinational block,
                        // dm_rdata có sẵn ngay -> lấy kết quả ngay cycle này
                        // =====================================================
                        else if (core_re[bus_grant_id] && !core_lr[bus_grant_id]) begin
                            core_rdata[bus_grant_id] <= dm_rdata;
                            core_ready[bus_grant_id] <= 1'b1;
                            // Giữ ở IDLE (1-cycle completion)
                        end
                        // =====================================================
                        // WRITE thường: dm_we đã set ở combinational -> ghi ngay
                        // =====================================================
                        else if (core_we[bus_grant_id] && !core_sc[bus_grant_id]) begin
                            core_ready[bus_grant_id] <= 1'b1;
                            // Snooping invalidation
                            for (j = 0; j < 8; j = j + 1) begin
                                if (j[2:0] != bus_grant_id &&
                                    reservation_valid[j] &&
                                    reservation_addr[j] == core_addr[bus_grant_id]) begin
                                    reservation_valid[j] <= 1'b0;
                                end
                            end
                        end
                        // =====================================================
                        // Load-Reserved (LR)
                        // =====================================================
                        else if (core_lr[bus_grant_id]) begin
                            core_rdata[bus_grant_id] <= dm_rdata;
                            core_ready[bus_grant_id] <= 1'b1;
                            // Đặt reservation
                            reservation_valid[bus_grant_id] <= 1'b1;
                            reservation_addr[bus_grant_id]  <= core_addr[bus_grant_id];
                        end
                        // =====================================================
                        // Store-Conditional (SC)
                        // =====================================================
                        else if (core_sc[bus_grant_id]) begin
                            if (reservation_valid[bus_grant_id] &&
                                reservation_addr[bus_grant_id] == core_addr[bus_grant_id]) begin
                                // SC SUCCESS
                                core_sc_result[bus_grant_id] <= 1'b0;
                                core_ready[bus_grant_id]     <= 1'b1;
                                reservation_valid[bus_grant_id] <= 1'b0;
                                // Snooping
                                for (j = 0; j < 8; j = j + 1) begin
                                    if (j[2:0] != bus_grant_id &&
                                        reservation_valid[j] &&
                                        reservation_addr[j] == core_addr[bus_grant_id]) begin
                                        reservation_valid[j] <= 1'b0;
                                    end
                                end
                            end
                            else begin
                                // SC FAILURE
                                core_sc_result[bus_grant_id] <= 1'b1;
                                core_ready[bus_grant_id]     <= 1'b1;
                                reservation_valid[bus_grant_id] <= 1'b0;
                            end
                        end
                    end
                end

                // =============================================================
                // AMO Phase 1: Đọc old value (dm_rdata có sẵn do async read)
                // =============================================================
                S_AMO_READ: begin
                    amo_old_val <= dm_rdata;
                    state       <= S_AMO_CALC;
                end

                // =============================================================
                // AMO Phase 2: Ghi kết quả + trả old value cho core
                // =============================================================
                S_AMO_CALC: begin
                    // dm_we + dm_wdata đã set ở combinational block
                    core_rdata[active_core] <= amo_old_val;
                    core_ready[active_core] <= 1'b1;
                    state                   <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule

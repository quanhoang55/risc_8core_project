// =============================================================================
// top_8core.v - Hệ thống CPU RISC-V 8 lõi
//
// Instantiate:
//   - 8 x risc_core (mỗi core có instr_mem riêng, cùng chương trình)
//   - 1 x arbiter (Round-Robin)
//   - 1 x bus_ctrl (LR/SC + AMO routing)
//   - 1 x data_mem (Shared RAM 4KB)
//
// Nối: 8 core ↔ bus_ctrl ↔ arbiter ↔ data_mem
// =============================================================================
`timescale 1ns / 1ps

module top_8core #(
    parameter PROGRAM_FILE = "program.hex"  // Chương trình cho tất cả core
)(
    input  wire clk,
    input  wire reset
);

    // =========================================================================
    // Wires giữa 8 core và bus_ctrl
    // =========================================================================
    wire [7:0]  core_mem_req;         // mem_req từ mỗi core
    wire [31:0] core_addr   [0:7];    // mem_addr từ mỗi core
    wire [31:0] core_wdata  [0:7];    // mem_wdata từ mỗi core
    wire [7:0]  core_we;              // mem_we từ mỗi core
    wire [7:0]  core_re;              // mem_re từ mỗi core

    wire [31:0] core_rdata  [0:7];    // rdata trả về mỗi core (từ bus_ctrl)
    wire [7:0]  core_ready;           // ready trả về mỗi core

    // Atomic signals (chưa dùng trong test cơ bản, nhưng kết nối sẵn)
    wire [7:0]  core_lr;              // Load-Reserved
    wire [7:0]  core_sc;              // Store-Conditional
    wire [7:0]  core_amo;             // AMO request
    wire [3:0]  core_amo_op [0:7];    // AMO operation type
    wire [7:0]  core_sc_result;       // SC result

    // =========================================================================
    // Arbiter ↔ Bus Controller wires
    // =========================================================================
    wire [7:0]  arb_request;
    wire [7:0]  arb_grant;
    wire        arb_grant_valid;
    wire [2:0]  arb_grant_id;

    // =========================================================================
    // Bus Controller ↔ Data Memory wires
    // =========================================================================
    wire [31:0] dm_addr;
    wire [31:0] dm_wdata;
    wire [31:0] dm_rdata;
    wire        dm_we;
    wire        dm_re;

    // =========================================================================
    // Generate 8 cores
    // =========================================================================
    genvar gi;
    generate
        for (gi = 0; gi < 8; gi = gi + 1) begin : gen_core
            risc_core #(
                .CORE_ID   (gi),
                .INIT_FILE (PROGRAM_FILE)
            ) u_core (
                .clk       (clk),
                .reset     (reset),
                // Bus interface
                .mem_req   (core_mem_req[gi]),
                .mem_addr  (core_addr[gi]),
                .mem_wdata (core_wdata[gi]),
                .mem_we    (core_we[gi]),
                .mem_re    (core_re[gi]),
                .mem_lr    (core_lr[gi]),
                .mem_sc    (core_sc[gi]),
                .mem_amo   (core_amo[gi]),
                .mem_amo_op(core_amo_op[gi]),
                .mem_rdata (core_rdata[gi]),
                .mem_ready (core_ready[gi]),
                .mem_sc_result(core_sc_result[gi])
            );
        end
    endgenerate

    // =========================================================================
    // Arbiter
    // =========================================================================
    arbiter u_arbiter (
        .clk         (clk),
        .reset       (reset),
        .request     (arb_request),
        .grant       (arb_grant),
        .grant_valid (arb_grant_valid),
        .grant_id    (arb_grant_id)
    );

    // =========================================================================
    // Bus Controller
    // =========================================================================
    bus_ctrl u_bus_ctrl (
        .clk             (clk),
        .reset           (reset),
        // Arbiter interface
        .bus_request     (arb_request),
        .bus_grant       (arb_grant),
        .bus_grant_valid (arb_grant_valid),
        .bus_grant_id    (arb_grant_id),
        // Core interface
        .core_mem_req    (core_mem_req),
        .core_addr       (core_addr),
        .core_wdata      (core_wdata),
        .core_we         (core_we),
        .core_re         (core_re),
        .core_lr         (core_lr),
        .core_sc         (core_sc),
        .core_amo        (core_amo),
        .core_amo_op     (core_amo_op),
        .core_rdata      (core_rdata),
        .core_ready      (core_ready),
        .core_sc_result  (core_sc_result),
        // Memory interface
        .dm_addr         (dm_addr),
        .dm_wdata        (dm_wdata),
        .dm_rdata        (dm_rdata),
        .dm_we           (dm_we),
        .dm_re           (dm_re)
    );

    // =========================================================================
    // Data Memory (Shared)
    // =========================================================================
    data_mem u_data_mem (
        .clk   (clk),
        .reset (reset),
        .addr  (dm_addr),
        .wdata (dm_wdata),
        .we    (dm_we),
        .re    (dm_re),
        .rdata (dm_rdata)
    );

endmodule

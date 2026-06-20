// =============================================================================
// top_8core.v - 8-core pipelined RISC-V system
//
// Instantiates:
//   - 8 x risc_core 5-stage pipeline cores
//   - 1 x arbiter (Round-Robin)
//   - 1 x bus_ctrl (LR/SC + AMO routing)
//   - 1 x data_mem (Shared RAM 4KB)
// =============================================================================
`timescale 1ns / 1ps

module top_8core #(
    parameter PROGRAM_FILE = "program.hex",
    parameter PROGRAM_WORDS = 256
)(
    input  wire clk,
    input  wire reset
);

    wire [7:0]  core_mem_req;
    wire [31:0] core_addr   [0:7];
    wire [31:0] core_wdata  [0:7];
    wire [7:0]  core_we;
    wire [7:0]  core_re;
    wire [31:0] core_rdata  [0:7];
    wire [7:0]  core_ready;

    wire [7:0]  core_lr;
    wire [7:0]  core_sc;
    wire [7:0]  core_amo;
    wire [3:0]  core_amo_op [0:7];
    wire [7:0]  core_sc_result;

    wire [7:0]  arb_request;
    wire [7:0]  arb_grant;
    wire        arb_grant_valid;
    wire [2:0]  arb_grant_id;

    wire [31:0] dm_addr;
    wire [31:0] dm_wdata;
    wire [31:0] dm_rdata;
    wire        dm_we;
    wire        dm_re;

    genvar gi;
    generate
        for (gi = 0; gi < 8; gi = gi + 1) begin : gen_core
            risc_core #(
                .CORE_ID      (gi),
                .INIT_FILE    (PROGRAM_FILE),
                .PROGRAM_WORDS(PROGRAM_WORDS)
            ) u_core (
                .clk          (clk),
                .reset        (reset),
                .mem_req      (core_mem_req[gi]),
                .mem_addr     (core_addr[gi]),
                .mem_wdata    (core_wdata[gi]),
                .mem_we       (core_we[gi]),
                .mem_re       (core_re[gi]),
                .mem_lr       (core_lr[gi]),
                .mem_sc       (core_sc[gi]),
                .mem_amo      (core_amo[gi]),
                .mem_amo_op   (core_amo_op[gi]),
                .mem_rdata    (core_rdata[gi]),
                .mem_ready    (core_ready[gi]),
                .mem_sc_result(core_sc_result[gi])
            );
        end
    endgenerate

    arbiter u_arbiter (
        .clk         (clk),
        .reset       (reset),
        .request     (arb_request),
        .grant       (arb_grant),
        .grant_valid (arb_grant_valid),
        .grant_id    (arb_grant_id)
    );

    bus_ctrl u_bus_ctrl (
        .clk             (clk),
        .reset           (reset),
        .bus_request     (arb_request),
        .bus_grant       (arb_grant),
        .bus_grant_valid (arb_grant_valid),
        .bus_grant_id    (arb_grant_id),
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
        .dm_addr         (dm_addr),
        .dm_wdata        (dm_wdata),
        .dm_rdata        (dm_rdata),
        .dm_we           (dm_we),
        .dm_re           (dm_re)
    );

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
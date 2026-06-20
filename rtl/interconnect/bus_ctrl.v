// =============================================================================
// bus_ctrl.v - System Bus Controller for 8-core RISC-V
//
// Converted from C++ logic (SystemBus.cpp + SyncManager.cpp) to Verilog RTL.
//
// 2-phase FSM Design:
//   IDLE     -> Receives grant from arbiter, sends signals to mem, transitions to DONE
//   DONE     -> Fetches result from mem, returns it to core, returns to IDLE
//   AMO_CALC -> Computes AMO, writes result, transitions to AMO_DONE
//   AMO_DONE -> Returns AMO result to core
//
// Signals to memory (dm_addr, dm_we, dm_re) are COMBINATIONAL
// to ensure async read of data_mem operates correctly within the same cycle.
// =============================================================================
`timescale 1ns / 1ps

module bus_ctrl (
    input  wire        clk,
    input  wire        reset,

    // =========================================================================
    // Arbiter
    // =========================================================================
    output wire [7:0]  bus_request,
    input  wire [7:0]  bus_grant,
    input  wire        bus_grant_valid,
    input  wire [2:0]  bus_grant_id,

    // =========================================================================
    // 8 Core
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

    output reg  [31:0] core_rdata  [0:7],
    output reg  [7:0]  core_ready,
    output reg  [7:0]  core_sc_result,

    // =========================================================================
    // Data Memory (COMBINATIONAL outputs)
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
    localparam S_IDLE     = 3'd0;
    localparam S_READ     = 3'd1;
    localparam S_WRITE    = 3'd1;
    localparam S_LR       = 3'd1;
    localparam S_SC       = 3'd1;
    localparam S_AMO_READ = 3'd2;
    localparam S_AMO_CALC = 3'd3;

    reg [2:0] state;

    // =========================================================================
    // Transaction register
    // =========================================================================
    reg [2:0]  active_core;
    reg [31:0] active_addr;
    reg [31:0] active_wdata;
    reg        active_is_write;
    reg        active_is_read;
    reg        active_is_lr;      // Load Reserved?
    reg        active_is_sc;      // Store Conditional?
    reg        active_is_amo;     // AMO?
    reg [3:0]  active_amo_op;     // AMO type

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
    // AMO combinational
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
    // Signals dm_addr, dm_re, dm_we, and dm_wdata must be combinational
    // to allow data_mem async read to return dm_rdata within the SAME cycle.
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
                    // READ or LR
                    if (core_re[bus_grant_id] || core_lr[bus_grant_id]) begin
                        dm_re = 1'b1;
                    end
                    // WRITE
                    if (core_we[bus_grant_id] && !core_sc[bus_grant_id]) begin
                        dm_we    = 1'b1;
                        dm_wdata = core_wdata[bus_grant_id];
                    end
                    // SC
                    if (core_sc[bus_grant_id]) begin
                        if (reservation_valid[bus_grant_id] &&
                            reservation_addr[bus_grant_id] == core_addr[bus_grant_id]) begin
                            dm_we    = 1'b1;
                            dm_wdata = core_wdata[bus_grant_id];
                        end
                    end
                    // AMO
                    if (core_amo[bus_grant_id]) begin
                        dm_re = 1'b1;
                    end
                end
            end

            S_AMO_READ: begin
                // AMO phase 1
                dm_addr = active_addr;
                dm_re   = 1'b1;
            end

            S_AMO_CALC: begin
                // AMO phase 2
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
            // Default: clear transient signals
            core_ready <= 8'b0;

            case (state)
                // =============================================================
                // IDLE
                // =============================================================
                S_IDLE: begin
                    if (bus_grant_valid) begin
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
                        // AMO
                        // =====================================================
                        if (core_amo[bus_grant_id]) begin
                            state <= S_AMO_READ;
                            // Invalidate reservations at addr
                            for (j = 0; j < 8; j = j + 1) begin
                                if (reservation_valid[j] &&
                                    reservation_addr[j] == core_addr[bus_grant_id]) begin
                                    reservation_valid[j] <= 1'b0;
                                end
                            end
                        end
                        // =====================================================
                        // READ: dm_re is already set in the combinational block,
                        // dm_rdata is available immediately -> fetch the result in this same cycle
                        // =====================================================
                        else if (core_re[bus_grant_id] && !core_lr[bus_grant_id]) begin
                            core_rdata[bus_grant_id] <= dm_rdata;
                            core_ready[bus_grant_id] <= 1'b1;
                            // Giu o IDLE (1-cycle completion)
                        end
                        // =====================================================
                        // WRITE: dm_we is set in combinational -> write
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
                            // Set reservation
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
                // AMO Phase 1: Read old value
                // =============================================================
                S_AMO_READ: begin
                    amo_old_val <= dm_rdata;
                    state       <= S_AMO_CALC;
                end

                // =============================================================
                // AMO Phase 2
                // =============================================================
                S_AMO_CALC: begin
                    // dm_we + dm_wdata is set in combinational block
                    core_rdata[active_core] <= amo_old_val;
                    core_ready[active_core] <= 1'b1;
                    state                   <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule

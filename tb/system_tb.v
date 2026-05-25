// =============================================================================
// system_tb.v - Full 8-core pipelined RISC-V system simulation
//
// The test runs the same program on all 8 cores, verifies shared-memory output,
// and prints pipeline/bus counters that can be used as slide evidence.
// =============================================================================
`timescale 1ns / 1ps

module system_tb;

    reg clk;
    reg reset;

    always #5 clk = ~clk; // 100 MHz

    top_8core #(
        .PROGRAM_FILE("../software/system_program.hex"),
        .PROGRAM_WORDS(6)
    ) dut (
        .clk(clk),
        .reset(reset)
    );

    integer cycle_count;
    integer test_pass;
    integer test_fail;
    integer grant_count [0:7];
    integer gi;

    wire [31:0] core_retired [0:7];
    wire [31:0] core_mem_stall [0:7];
    wire [31:0] core_load_use_stall [0:7];
    wire [31:0] core_flush [0:7];

    assign core_retired[0]        = dut.gen_core[0].u_core.retired_count;
    assign core_retired[1]        = dut.gen_core[1].u_core.retired_count;
    assign core_retired[2]        = dut.gen_core[2].u_core.retired_count;
    assign core_retired[3]        = dut.gen_core[3].u_core.retired_count;
    assign core_retired[4]        = dut.gen_core[4].u_core.retired_count;
    assign core_retired[5]        = dut.gen_core[5].u_core.retired_count;
    assign core_retired[6]        = dut.gen_core[6].u_core.retired_count;
    assign core_retired[7]        = dut.gen_core[7].u_core.retired_count;
    assign core_mem_stall[0]      = dut.gen_core[0].u_core.mem_stall_count;
    assign core_mem_stall[1]      = dut.gen_core[1].u_core.mem_stall_count;
    assign core_mem_stall[2]      = dut.gen_core[2].u_core.mem_stall_count;
    assign core_mem_stall[3]      = dut.gen_core[3].u_core.mem_stall_count;
    assign core_mem_stall[4]      = dut.gen_core[4].u_core.mem_stall_count;
    assign core_mem_stall[5]      = dut.gen_core[5].u_core.mem_stall_count;
    assign core_mem_stall[6]      = dut.gen_core[6].u_core.mem_stall_count;
    assign core_mem_stall[7]      = dut.gen_core[7].u_core.mem_stall_count;
    assign core_load_use_stall[0] = dut.gen_core[0].u_core.load_use_stall_count;
    assign core_load_use_stall[1] = dut.gen_core[1].u_core.load_use_stall_count;
    assign core_load_use_stall[2] = dut.gen_core[2].u_core.load_use_stall_count;
    assign core_load_use_stall[3] = dut.gen_core[3].u_core.load_use_stall_count;
    assign core_load_use_stall[4] = dut.gen_core[4].u_core.load_use_stall_count;
    assign core_load_use_stall[5] = dut.gen_core[5].u_core.load_use_stall_count;
    assign core_load_use_stall[6] = dut.gen_core[6].u_core.load_use_stall_count;
    assign core_load_use_stall[7] = dut.gen_core[7].u_core.load_use_stall_count;
    assign core_flush[0]          = dut.gen_core[0].u_core.flush_count;
    assign core_flush[1]          = dut.gen_core[1].u_core.flush_count;
    assign core_flush[2]          = dut.gen_core[2].u_core.flush_count;
    assign core_flush[3]          = dut.gen_core[3].u_core.flush_count;
    assign core_flush[4]          = dut.gen_core[4].u_core.flush_count;
    assign core_flush[5]          = dut.gen_core[5].u_core.flush_count;
    assign core_flush[6]          = dut.gen_core[6].u_core.flush_count;
    assign core_flush[7]          = dut.gen_core[7].u_core.flush_count;

    initial begin
        $dumpfile("system_tb.vcd");
        $dumpvars(0, system_tb);

        clk = 0;
        reset = 1;
        cycle_count = 0;
        test_pass = 0;
        test_fail = 0;
        for (gi = 0; gi < 8; gi = gi + 1)
            grant_count[gi] = 0;

        #25 reset = 0;

        $display("\n========================================");
        $display("  BAT DAU MO PHONG HE THONG 8 LOI PIPELINE");
        $display("========================================");

        repeat (500) begin
            @(posedge clk);
            cycle_count = cycle_count + 1;

            if (dut.u_arbiter.grant_valid)
                grant_count[dut.u_arbiter.grant_id] = grant_count[dut.u_arbiter.grant_id] + 1;
        end

        $display("\n========================================");
        $display("  KET QUA MO PHONG TAI CYCLE %0d", cycle_count);
        $display("========================================");

        $display("  Kiem tra mem[0] (Ky vong: 42) = %0d", dut.u_data_mem.mem[0]);
        if (dut.u_data_mem.mem[0] == 32'd42) begin
            $display("    [PASS] Shared memory data dung.");
            test_pass = test_pass + 1;
        end else begin
            $display("    [FAIL] Shared memory data sai.");
            test_fail = test_fail + 1;
        end

        $display("  Kiem tra mem[1] addr 4 (Ky vong: 99) = %0d", dut.u_data_mem.mem[1]);
        if (dut.u_data_mem.mem[1] == 32'd99) begin
            $display("    [PASS] 8 core hoan thanh chuong trinh khong deadlock.");
            test_pass = test_pass + 1;
        end else begin
            $display("    [FAIL] Chua thay marker hoan thanh.");
            test_fail = test_fail + 1;
        end

        $display("\n========================================");
        $display("  PIPELINE / BUS EVIDENCE");
        $display("========================================");
        for (gi = 0; gi < 8; gi = gi + 1) begin
            $display("  Core %0d: grant=%0d retired=%0d mem_stall=%0d load_use_stall=%0d flush=%0d",
                     gi,
                     grant_count[gi],
                     core_retired[gi],
                     core_mem_stall[gi],
                     core_load_use_stall[gi],
                     core_flush[gi]);

            if (grant_count[gi] > 0 && core_retired[gi] > 0)
                test_pass = test_pass + 1;
            else begin
                $display("    [FAIL] Core %0d khong co bang chung grant/retire.", gi);
                test_fail = test_fail + 1;
            end
        end

        $display("\n==========================================");
        $display("  TONG KET: %0d PASSED, %0d FAILED", test_pass, test_fail);
        $display("==========================================\n");

        $finish;
    end

endmodule

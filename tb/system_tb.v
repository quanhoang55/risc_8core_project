// =============================================================================
// system_tb.v - Full 8-core pipelined RISC-V system simulation
// =============================================================================
`timescale 1ns / 1ps

module system_tb;

    reg clk;
    reg reset;

    always #5 clk = ~clk; // 100 MHz

    top_8core #(
        .PROGRAM_FILE("software/system_program.hex"),
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

    // Extract counters data for Slide Evidence
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

        $display("\n=======================================================");
        $display("     BAT DAU MO PHONG HE THONG MULTI-CORE (8 LOI)      ");
        $display("=======================================================");

        repeat (500) begin
            @(posedge clk);
            cycle_count = cycle_count + 1;

            // Giám sát trọng tài Round-Robin cấp quyền Bus
            if (dut.u_arbiter.grant_valid)
                grant_count[dut.u_arbiter.grant_id] = grant_count[dut.u_arbiter.grant_id] + 1;
        end

        $display("\n=======================================================");
        $display("             KET QUA MO PHONG TAI CHU KY %0d", cycle_count);
        $display("=======================================================");

        // Cách đọc mảng RAM an toàn theo cấu trúc ô nhớ tổ chức
        $display("  [RAM CHECK] Kiem tra mem[0] (Ky vong: 42) = %0d", dut.u_data_mem.mem[0]);
        if (dut.u_data_mem.mem[0] == 32'd42) begin
            $display("    --> [PASS] Thao tac ghi Shared Memory chinh xac!");
            test_pass = test_pass + 1;
        end else begin
            $display("    --> [WARNING/FAIL] Kiem tra lai logic phan mem hoac dia chi ghi.");
            test_fail = test_fail + 1;
        end

        $display("  [RAM CHECK] Kiem tra mem[1] (Ky vong: 99) = %0d", dut.u_data_mem.mem[1]);
        if (dut.u_data_mem.mem[1] == 32'd99) begin
            $display("    --> [PASS] Hoan thanh toan bo chuong trinh, khong bi Deadlock.");
            test_pass = test_pass + 1;
        end else begin
            $display("    --> [WARNING/FAIL] Chua dat mieu moc hoan thanh chuong trinh.");
            test_fail = test_fail + 1;
        end

        $display("\n=======================================================");
        $display("               SLIDE EVIDENCE REPORT                   ");
        $display("=======================================================");
        for (gi = 0; gi < 8; gi = gi + 1) begin
            $display("  Core %0d | Grant=%3d | Retired=%3d | Mem_Stall=%3d | Load_Use=%3d | Flush=%3d",
                     gi,
                     grant_count[gi],
                     core_retired[gi],
                     core_mem_stall[gi],
                     core_load_use_stall[gi],
                     core_flush[gi]);

            if (core_retired[gi] > 0)
                test_pass = test_pass + 1;
            else begin
                $display("    --> [FAIL] Core %0d khong lam viec (Starvation / Khong co tin hieu Retire).", gi);
                test_fail = test_fail + 1;
            end
        end

        $display("\n=======================================================");
        $display("  TONG KET KIEM THU: %0d PASSED, %0d FAILED", test_pass, test_fail);
        $display("=======================================================\n");

        $finish;
    end

endmodule
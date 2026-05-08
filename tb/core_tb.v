// =============================================================================
// core_tb.v - Testbench cho 1 core RISC-V (risc_core)
//
// Chạy chương trình từ program.hex:
//   ADDI x1, x0, 10    → x1 = 10
//   ADDI x2, x0, 20    → x2 = 20
//   ADD  x3, x1, x2    → x3 = 30
//   SW   x3, 0(x0)     → mem[0] = 30
//   LW   x4, 0(x0)     → x4 = 30
//   BEQ  x3, x4, +4    → branch taken (skip FAIL)
//   ADDI x5, x0, 1     → x5 = 1 (PASS marker)
//
// Core giao tiếp trực tiếp với data_mem (không qua bus, vì chỉ test 1 core).
// =============================================================================
`timescale 1ns / 1ps

module core_tb;

    reg clk, reset;
    always #5 clk = ~clk;

    // Core ↔ Memory signals
    wire        mem_req;
    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire        mem_we;
    wire        mem_re;
    wire [31:0] mem_rdata;
    reg         mem_ready;

    // Data Memory signals
    reg         dm_we;
    reg         dm_re;
    reg  [31:0] dm_addr;
    reg  [31:0] dm_wdata;
    wire [31:0] dm_rdata;

    // =========================================================================
    // DUT: 1 core
    // =========================================================================
    risc_core #(
        .CORE_ID(0),
        .INIT_FILE("program.hex")
    ) u_core (
        .clk       (clk),
        .reset     (reset),
        .mem_req   (mem_req),
        .mem_addr  (mem_addr),
        .mem_wdata (mem_wdata),
        .mem_we    (mem_we),
        .mem_re    (mem_re),
        .mem_rdata (mem_rdata),
        .mem_ready (mem_ready)
    );

    // =========================================================================
    // Data Memory (trực tiếp, không qua bus)
    // =========================================================================
    data_mem u_dmem (
        .clk   (clk),
        .reset (reset),
        .addr  (dm_addr),
        .wdata (dm_wdata),
        .we    (dm_we),
        .re    (dm_re),
        .rdata (dm_rdata)
    );

    // =========================================================================
    // Kết nối core ↔ data_mem đơn giản (bypass bus)
    // Khi core gửi mem_req, chuyển tiếp tới data_mem, trả mem_ready sau 1 cycle
    // =========================================================================
    assign mem_rdata = dm_rdata;

    reg mem_req_prev;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            dm_we        <= 1'b0;
            dm_re        <= 1'b0;
            dm_addr      <= 32'd0;
            dm_wdata     <= 32'd0;
            mem_ready    <= 1'b0;
            mem_req_prev <= 1'b0;
        end
        else begin
            mem_req_prev <= mem_req;
            mem_ready    <= 1'b0;

            if (mem_req && !mem_req_prev) begin
                // Bắt đầu giao dịch: chuyển tiếp tới data_mem
                dm_addr  <= mem_addr;
                dm_wdata <= mem_wdata;
                dm_we    <= mem_we;
                dm_re    <= mem_re;
            end
            else if (mem_req && mem_req_prev) begin
                // Cycle sau: giao dịch hoàn thành
                mem_ready <= 1'b1;
                dm_we     <= 1'b0;
                // Giữ dm_re=1 để data_mem async read vẫn trả dữ liệu hợp lệ
                // khi core đọc mem_rdata ở cycle mem_ready=1
            end
            else begin
                dm_we <= 1'b0;
                dm_re <= 1'b0;
            end
        end
    end

    // =========================================================================
    // Monitor + Timeout
    // =========================================================================
    integer cycle_count;
    integer test_pass, test_fail;

    initial begin
        $dumpfile("core_tb.vcd");
        $dumpvars(0, core_tb);

        clk = 0; reset = 1;
        cycle_count = 0;
        test_pass = 0; test_fail = 0;

        #25 reset = 0;

        // Chạy tối đa 200 cycle
        repeat (200) begin
            @(posedge clk);
            cycle_count = cycle_count + 1;

            // Kiểm tra khi core halt (PC không đổi trong 4 cycle liên tiếp ở FETCH)
            // Hoặc khi x5 = 1 (PASS marker)
        end

        // === Kiểm tra kết quả ===
        $display("");
        $display("========================================");
        $display("  CORE TEST RESULTS (after %0d cycles)", cycle_count);
        $display("========================================");

        // Kiểm tra Register File thông qua internal path
        $display("  x1 (expect 10) = %0d", u_core.u_rf.registers[1]);
        if (u_core.u_rf.registers[1] == 32'd10) begin
            $display("    [PASS]"); test_pass = test_pass + 1;
        end else begin
            $display("    [FAIL]"); test_fail = test_fail + 1;
        end

        $display("  x2 (expect 20) = %0d", u_core.u_rf.registers[2]);
        if (u_core.u_rf.registers[2] == 32'd20) begin
            $display("    [PASS]"); test_pass = test_pass + 1;
        end else begin
            $display("    [FAIL]"); test_fail = test_fail + 1;
        end

        $display("  x3 (expect 30) = %0d", u_core.u_rf.registers[3]);
        if (u_core.u_rf.registers[3] == 32'd30) begin
            $display("    [PASS]"); test_pass = test_pass + 1;
        end else begin
            $display("    [FAIL]"); test_fail = test_fail + 1;
        end

        $display("  x4 (expect 30) = %0d", u_core.u_rf.registers[4]);
        if (u_core.u_rf.registers[4] == 32'd30) begin
            $display("    [PASS]"); test_pass = test_pass + 1;
        end else begin
            $display("    [FAIL]"); test_fail = test_fail + 1;
        end

        $display("  x5 (expect 1)  = %0d", u_core.u_rf.registers[5]);
        if (u_core.u_rf.registers[5] == 32'd1) begin
            $display("    [PASS] BRANCH worked!"); test_pass = test_pass + 1;
        end else begin
            $display("    [FAIL] Branch may have failed"); test_fail = test_fail + 1;
        end

        // Kiểm tra Data Memory
        $display("  mem[0] (expect 30) = %0d", u_dmem.mem[0]);
        if (u_dmem.mem[0] == 32'd30) begin
            $display("    [PASS]"); test_pass = test_pass + 1;
        end else begin
            $display("    [FAIL]"); test_fail = test_fail + 1;
        end

        $display("");
        $display("==========================================");
        $display("  SUMMARY: %0d PASSED, %0d FAILED", test_pass, test_fail);
        $display("==========================================");

        $finish;
    end

endmodule

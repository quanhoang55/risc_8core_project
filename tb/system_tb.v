// =============================================================================
// system_tb.v - Testbench mô phỏng toàn bộ hệ thống 8 lõi
//
// Khởi tạo top_8core, nạp system_program.hex cho tất cả các lõi.
// Đợi các lõi thực thi xong (khoảng vài trăm cycle).
// Kiểm tra nội dung của Data Memory để xác nhận thành công.
// =============================================================================
`timescale 1ns / 1ps

module system_tb;

    reg clk;
    reg reset;

    // Tạo clock (100MHz -> 10ns period)
    always #5 clk = ~clk;

    // =========================================================================
    // Khởi tạo Top Level (8 cores + Interconnect + Memory)
    // =========================================================================
    top_8core #(
        .PROGRAM_FILE("../software/system_program.hex")
    ) dut (
        .clk(clk),
        .reset(reset)
    );

    // =========================================================================
    // Monitor & Timeout
    // =========================================================================
    integer cycle_count;
    integer test_pass;
    integer test_fail;

    initial begin
        // Tạo file VCD để xem dạng sóng trên GTKWave
        $dumpfile("system_tb.vcd");
        $dumpvars(0, system_tb);

        clk = 0;
        reset = 1;
        cycle_count = 0;
        test_pass = 0;
        test_fail = 0;

        // Giữ reset trong vài cycle
        #25 reset = 0;

        $display("\n========================================");
        $display("  BAT DAU MO PHONG HE THONG 8 LOI");
        $display("========================================");

        // Chạy tối đa 500 cycles (đủ cho chương trình ngắn)
        repeat (500) begin
            @(posedge clk);
            cycle_count = cycle_count + 1;
            
            // Tùy chọn in ra thông báo nếu cần debug
            // if (cycle_count % 100 == 0)
            //    $display("  ... running cycle %0d", cycle_count);
        end

        // =====================================================================
        // Kiểm tra kết quả trong Data Memory
        // =====================================================================
        $display("\n========================================");
        $display("  KET QUA MO PHONG TAI CYCLE %0d", cycle_count);
        $display("========================================");

        // Theo system_program.hex:
        // mem[0] phải bằng 42
        // mem[4] (word_addr 1) phải bằng 99 (marker chạy xong)
        
        $display("  Kiem tra mem[0] (Ky vong: 42) = %0d", dut.u_data_mem.mem[0]);
        if (dut.u_data_mem.mem[0] == 32'd42) begin
            $display("    [PASS] Tat ca core da ghi gia tri chinh xac.");
            test_pass = test_pass + 1;
        end else begin
            $display("    [FAIL] Du lieu sai.");
            test_fail = test_fail + 1;
        end

        $display("  Kiem tra mem[1] addr 4 (Ky vong: 99) = %0d", dut.u_data_mem.mem[1]);
        if (dut.u_data_mem.mem[1] == 32'd99) begin
            $display("    [PASS] He thong hoan thanh ma khong bi deadlock.");
            test_pass = test_pass + 1;
        end else begin
            $display("    [FAIL] Cac core chua chay den lenh ghi marker.");
            test_fail = test_fail + 1;
        end

        $display("\n==========================================");
        $display("  TONG KET: %0d PASSED, %0d FAILED", test_pass, test_fail);
        $display("==========================================\n");

        $finish;
    end

endmodule

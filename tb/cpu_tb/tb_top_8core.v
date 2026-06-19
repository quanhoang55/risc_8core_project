`timescale 1ns / 1ps

module tb_top_8core;

    // --- Tham số mô phỏng ---
    parameter PROGRAM_FILE  = "program.hex";
    parameter PROGRAM_WORDS = 64;
    parameter CLK_PERIOD    = 10; // Xung clock 10ns (100MHz)

    // --- Các tín hiệu kết nối vào hệ thống ---
    reg clk;
    reg reset;

    // --- Khởi tạo hệ thống 8-Core ---
    top_8core #(
        .PROGRAM_FILE(PROGRAM_FILE),
        .PROGRAM_WORDS(PROGRAM_WORDS)
    ) uut (
        .clk(clk),
        .reset(reset)
    );

    // --- Tạo xung Clock ---
    always #(CLK_PERIOD/2) clk = ~clk;

    // --- Kịch bản Test chính ---
    initial begin
        // 1. Khởi tạo trạng thái ban đầu
        clk = 0;
        reset = 1;
        
        $display("=========================================================");
        $display("   BAT DAU KIEM THU HÊ THONG MULTI-CORE (8-CORE RISC-V)   ");
        $display("=========================================================");
        
        // 2. Kích hoạt Reset hệ thống trong 5 chu kỳ
        #(CLK_PERIOD * 5);
        @(posedge clk);
        reset = 0;
        $display("[STATUS] Reset hoan tat. Tat ca 8 Core bat dau thuc thi...");

        // 3. Giám sát trạng thái Bus / Tranh chấp (Arbitration Monitoring)
        // Log lại mỗi khi một core được cấp quyền truy cập bus dữ liệu chung
        fork
            begin
                forever begin
                    @(posedge clk);
                    if (uut.arb_grant_valid) begin
                        $display("[BUS_ARBITER] Thoi gian: %0t ps | Core %0d duoc cap quyen truy cap Bus.", 
                                 $time, uut.arb_grant_id);
                    end
                end
            end
            
            // Giám sát các thao tác ghi đặc biệt (LR/SC / AMO) vào Shared RAM
            begin
                forever begin
                    @(posedge clk);
                    if (uut.dm_we) begin
                        $display("[SHARED_RAM] Core dang chiem quyen ghi vao RAM | Dia chi: 0x%h | Du lieu ghi: 0x%h", 
                                 uut.dm_addr, uut.dm_wdata);
                    end
                end
            end
        join_none

        // 4. Khống chế thời gian mô phỏng (Timeout)
        // Chờ 150 chu kỳ để các core hoàn thành việc tranh chấp và xử lý thuật toán
        #(CLK_PERIOD * 150);

        // 5. Kết thúc mô phỏng và in báo cáo hiệu năng các Core
        $display("=========================================================");
        $display("          BAO CAO TONG HOP HIÊU NANG SYSTEM              ");
        $display("=========================================================");
        $display(" Thoi gian mo phong ket thuc tai: %0t ps", $time);
        
        // In so luong lenh hoan thanh cua tung Core để check xem co core nao bi "bo doi" (Starvation) khong
        $display(" Core 0 Retired Instructions: %0d", uut.gen_core[0].u_core.retired_count);
        $display(" Core 1 Retired Instructions: %0d", uut.gen_core[1].u_core.retired_count);
        $display(" Core 2 Retired Instructions: %0d", uut.gen_core[2].u_core.retired_count);
        $display(" Core 3 Retired Instructions: %0d", uut.gen_core[3].u_core.retired_count);
        $display(" Core 4 Retired Instructions: %0d", uut.gen_core[4].u_core.retired_count);
        $display(" Core 5 Retired Instructions: %0d", uut.gen_core[5].u_core.retired_count);
        $display(" Core 6 Retired Instructions: %0d", uut.gen_core[6].u_core.retired_count);
        $display(" Core 7 Retired Instructions: %0d", uut.gen_core[7].u_core.retired_count);
        $display("=========================================================");

        $finish;
    end

    // --- Ghi file Waveform de soi GTKWave ---
    initial begin
        $dumpfile("multicore_system_waveform.vcd");
        // Dump muc 0 de xem tat ca cac bien tu top xuong tan loi con
        $dumpvars(0, tb_top_8core);
    end

endmodule
`timescale 1ns / 1ps

module tb_hazard_controller;

    // --- Inputs ---
    logic        ex_valid; logic ex_reg_write;
    logic [4:0]  ex_rs1_addr; logic [4:0] ex_rs2_addr;
    logic        mem_can_forward; logic [4:0] mem_rd_addr;
    logic        wb_can_forward; logic [4:0] wb_rd_addr;
    logic        id_valid;
    logic [4:0]  cu_rs1_addr; logic [4:0] cu_rs2_addr;
    logic        ex_load_like; logic [4:0] ex_rd_addr;
    logic        mem_wait; logic        redirect_taken;

    // --- Outputs ---
    wire [1:0]   forward_a; wire [1:0] forward_b;
    wire         load_use_stall;
    wire         if_id_hold; wire if_id_clear;
    wire         id_ex_hold; wire id_ex_clear;
    wire         ex_mem_hold; wire mem_wb_hold;

    // --- Instantiate DUT ---
    hazard_controller uut (.*);

    // --- GTKWave Dump ---
    initial begin
        $dumpfile("hazard_waveform.vcd");
        $dumpvars(0, tb_hazard_controller);
    end

    // --- Test Stimulus ---
    initial begin
        // Khởi tạo hệ thống chạy bình thường
        ex_valid = 1; id_valid = 1; ex_reg_write = 0;
        ex_rs1_addr = 5'd0; ex_rs2_addr = 5'd0;
        mem_can_forward = 0; mem_rd_addr = 5'd0;
        wb_can_forward = 0; wb_rd_addr = 5'd0;
        cu_rs1_addr = 5'd0; cu_rs2_addr = 5'd0;
        ex_load_like = 0; ex_rd_addr = 5'd0;
        mem_wait = 0; redirect_taken = 0;

        $display("--- BAT DAU UNIT TESTING HAZARD CONTROLLER ---");
        #10;

        // TIMELINE 1: Test mạch Forwarding toán hạng B (Kiểm tra lỗi ex_rs2_addr)
        $display("[TEST 1] Kích hoạt Forwarding tầng EX/MEM cho toán hạng B");
        ex_rs2_addr = 5'd12; // Đường RS2 cần thanh ghi x12
        mem_can_forward = 1; 
        mem_rd_addr = 5'd12; // Tầng trước cũng chuẩn bị ghi vào x12
        #10;
        if (forward_b == 2'b10) $display("-> TEST 1 PASSED: Mạch Forwarding B nhận diện chính xác.");
        else                    $error("-> TEST 1 FAILED: Chưa sửa lỗi rs1_addr/rs2_addr ở vế B!");

        // Reset trạng thái
        mem_can_forward = 0; ex_rs2_addr = 5'd0; mem_rd_addr = 5'd0;
        #10;

        // TIMELINE 2: Test kịch bản xung đột phức hợp (Rẽ nhánh + Kẹt bộ nhớ đồng thời)
        $display("[TEST 2] Giả lập Memory Stall (mem_wait=1) trùng với Rẽ nhánh (redirect_taken=1)");
        redirect_taken = 1;
        mem_wait = 1; // Bus bộ nhớ bận
        #10;
        
        if (if_id_hold == 1 && id_ex_hold == 1 && ex_mem_hold == 1 && mem_wb_hold == 1) begin
            $display("-> Kịch bản khóa: Toàn bộ hệ thống vách ngăn đã được đóng băng thành công.");
        end else begin
            $error("-> TEST 2 FAILED: Hệ thống không thể đóng băng đồng bộ!");
        end

        // KIỂM TRA LỖI SẬP HẦM (Xóa nhầm dữ liệu khi đang bận RAM)
        if (if_id_clear == 0 && id_ex_clear == 0) begin
            $display("-> TEST 2 PASSED: Cờ Clear đã bị chặn an toàn. Dữ liệu lệnh không bị xóa mất.");
        end else begin
            $error("-> CRITICAL BUG FAILED: Lệnh đang chờ bộ nhớ bị xóa sạch do clear=1! CPU sẽ bị treo!");
        end

        // Kết thúc test
        #10;
        mem_wait = 0;
        redirect_taken = 0;
        #10;
        $display("--- KẾT THÚC MÔ PHỎNG VÀ XUẤT FILE SÓNG VCD ---");
        $finish;
    end

endmodule
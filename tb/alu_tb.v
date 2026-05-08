`timescale 1ns / 1ps

module alu_tb();

    // 1. Khai báo các biến kết nối với ALU
    reg  [31:0] a;
    reg  [31:0] b;
    reg  [3:0]  alu_control;
    wire [31:0] result;
    wire        zero;

    // 2. Khởi tạo module ALU (DUT - Device Under Test)
    alu dut (
        .a(a),
        .b(b),
        .alu_control(alu_control),
        .result(result),
        .zero(zero)
    );

    // Định nghĩa lại các mã lệnh để dễ đọc trong testbench
    localparam AND  = 4'b0000;
    localparam OR   = 4'b0001;
    localparam ADD  = 4'b0010;
    localparam SUB  = 4'b0110;
    localparam SLT  = 4'b0111;

    // 3. Quy trình kiểm thử
    initial begin
        // Hiển thị tiêu đề bảng kết quả
        $display("Time | A | B | Control | Result | Zero");
        $display("----------------------------------------------");

        // Test Case 1: Phép cộng (ADD)
        a = 32'd10; b = 32'd20; alu_control = ADD;
        #10; // Đợi 10 đơn vị thời gian
        $display("%4t | %d | %d |  ADD    | %d | %b", $time, a, b, result, zero);

        // Test Case 2: Phép trừ (SUB) dẫn đến kết quả bằng 0
        a = 32'd50; b = 32'd50; alu_control = SUB;
        #10;
        $display("%4t | %d | %d |  SUB    | %d | %b", $time, a, b, result, zero);

        // Test Case 3: Phép toán logic AND
        a = 32'hAAAA_AAAA; b = 32'h5555_5555; alu_control = AND;
        #10;
        $display("%4t | %h | %h |  AND    | %h | %b", $time, a, b, result, zero);

        // Test Case 4: So sánh nhỏ hơn (SLT) - Số dương
        a = 32'd15; b = 32'd25; alu_control = SLT;
        #10;
        $display("%4t | %d | %d |  SLT    | %d | %b", $time, a, b, result, zero);

        // Test Case 5: So sánh nhỏ hơn (SLT) - Số âm (Kiểm tra tính đúng đắn của $signed)
        a = -32'd10; b = 32'd5; alu_control = SLT;
        #10;
        $display("%4t | %d | %d |  SLT    | %d | %b", $time, a, b, result, zero);

        $display("----------------------------------------------");
        $display("Kiem tra ket thuc.");
        $finish; // Dừng mô phỏng
    end

endmodule
module alu (
    input  [31:0] a,           // Toán hạng thứ nhất
    input  [31:0] b,           // Toán hạng thứ hai
    input  [3:0]  alu_control, // Tín hiệu điều khiển từ Control Unit
    output reg [31:0] result,  // Kết quả tính toán
    output        zero         // Cờ báo kết quả bằng 0
);

    // Định nghĩa các mã điều khiển (Dựa trên chuẩn thông dụng cho RV32I)
    localparam AND  = 4'b0000;
    localparam OR   = 4'b0001;
    localparam ADD  = 4'b0010;
    localparam SUB  = 4'b0110;
    localparam XOR  = 4'b0100;
    localparam SRL  = 4'b0101; // Shift Right Logical
    localparam SLL  = 4'b0011; // Shift Left Logical
    localparam SLT  = 4'b0111; // Set Less Than (có dấu)

    always @(*) begin
        case (alu_control)
            ADD:  result = a + b;
            SUB:  result = a - b;
            AND:  result = a & b;
            OR:   result = a | b;
            XOR:  result = a ^ b;
            SLL:  result = a << b[4:0];  // Chỉ lấy 5 bit thấp của b để dịch
            SRL:  result = a >> b[4:0];
            SLT:  result = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;
            default: result = 32'b0;
        endcase
    end

    // Cờ Zero: bật lên 1 nếu kết quả bằng 0 (phục vụ lệnh BEQ, BNE...)
    assign zero = (result == 32'b0);

endmodule
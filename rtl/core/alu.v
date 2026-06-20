module alu (
    input      [31:0] a,
    input      [31:0] b,
    input      [ 3:0] alu_control,
    output reg [31:0] result,
    output            zero
);

  // Dinh nghia cac ma dieu khien (Dua tren chuan thong dung cho RV32I)
  localparam AND = 4'b0000;
  localparam OR = 4'b0001;
  localparam ADD = 4'b0010;
  localparam SUB = 4'b0110;
  localparam XOR = 4'b0100;
  localparam SRL = 4'b0101;  // Shift Right Logical
  localparam SLL = 4'b0011;  // Shift Left Logical
  localparam SLT = 4'b0111;  // Set Less Than (co dau)

  always @(*) begin
    case (alu_control)
      ADD: result = a + b;
      SUB: result = a - b;
      AND: result = a & b;
      OR: result = a | b;
      XOR: result = a ^ b;
      SLL: result = a << b[4:0];  // Chi lay 5 bit thap cua b de dich
      SRL: result = a >> b[4:0];
      SLT: result = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;
      default: result = 32'b0;
    endcase
  end

  // Co Zero: bat len 1 neu ket qua bang 0 (phuc vu lenh BEQ, BNE...)
  assign zero = (result == 32'b0);

endmodule


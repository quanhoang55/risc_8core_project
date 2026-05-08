// =============================================================================
// arbiter.v - Bộ phân xử Bus Round-Robin cho hệ thống 8 lõi RISC-V
//
// Thuật toán Round-Robin:
//   - Quét 8 core bắt đầu từ priority_ptr, grant cho core đầu tiên có request.
//   - Grant chỉ active 1 CYCLE (pulse), sau đó tự xóa.
//   - Sau khi grant, priority_ptr = (granted_core + 1) % 8.
//   - Một core phải deassert request và re-assert để được grant lần nữa.
// =============================================================================
`timescale 1ns / 1ps

module arbiter (
    input  wire        clk,
    input  wire        reset,
    input  wire [7:0]  request,
    output reg  [7:0]  grant,
    output reg         grant_valid,
    output reg  [2:0]  grant_id
);

    reg [2:0] priority_ptr;

    // Đã grant cho core nào ở cycle trước? Dùng để tránh grant lại cùng request.
    reg [7:0] last_granted;  // Bit mask: core nào đã được grant gần nhất

    // Round-Robin scan (combinational)
    reg [2:0] winner;
    reg       found;
    integer   i;
    reg [2:0] candidate;

    // Tạo masked request: chỉ xét request MỚI (chưa được grant)
    wire [7:0] new_request = request & ~last_granted;

    always @(*) begin
        found  = 1'b0;
        winner = 3'd0;
        for (i = 0; i < 8; i = i + 1) begin
            candidate = priority_ptr + i[2:0];
            if (!found && new_request[candidate]) begin
                winner = candidate;
                found  = 1'b1;
            end
        end
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            grant        <= 8'b0;
            grant_valid  <= 1'b0;
            grant_id     <= 3'd0;
            priority_ptr <= 3'd0;
            last_granted <= 8'b0;
        end
        else begin
            if (found) begin
                grant        <= (8'b0000_0001 << winner);
                grant_valid  <= 1'b1;
                grant_id     <= winner;
                priority_ptr <= winner + 3'd1;
                last_granted <= (8'b0000_0001 << winner);
            end
            else begin
                grant        <= 8'b0;
                grant_valid  <= 1'b0;
                grant_id     <= 3'd0;
                // Clear last_granted khi không còn request pending
                // Cho phép core request lại
                last_granted <= last_granted & request;
            end
        end
    end

endmodule

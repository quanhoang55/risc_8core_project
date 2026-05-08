// =============================================================================
// data_mem.v - Bộ nhớ dữ liệu dùng chung (Shared Data RAM)
//
// RAM đồng bộ 1-port, 32-bit word-addressable.
// Được truy cập bởi 8 core thông qua bus_ctrl.
//
// Kích thước: 1024 words = 4 KB
// Địa chỉ: word-aligned (addr[11:2] chọn word, bỏ 2 bit thấp)
// =============================================================================
`timescale 1ns / 1ps

module data_mem (
    input  wire        clk,
    input  wire        reset,
    input  wire [31:0] addr,       // Địa chỉ byte (word-aligned)
    input  wire [31:0] wdata,      // Dữ liệu ghi
    input  wire        we,         // Write enable
    input  wire        re,         // Read enable
    output reg  [31:0] rdata       // Dữ liệu đọc
);

    // 1024 words x 32 bits = 4 KB RAM
    reg [31:0] mem [0:1023];

    // Word index từ byte address (chia 4 = bỏ 2 bit thấp)
    wire [9:0] word_addr = addr[11:2];

    // Đọc bất đồng bộ (combinational read) - để bus_ctrl có thể đọc ngay
    always @(*) begin
        if (re)
            rdata = mem[word_addr];
        else
            rdata = 32'd0;
    end

    // Ghi đồng bộ
    integer i;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            for (i = 0; i < 1024; i = i + 1)
                mem[i] <= 32'd0;
        end
        else if (we) begin
            mem[word_addr] <= wdata;
        end
    end

endmodule

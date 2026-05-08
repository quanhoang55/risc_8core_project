// =============================================================================
// instr_mem.v - Bộ nhớ lệnh (Instruction ROM)
//
// ROM chỉ đọc, 256 words = 1KB.
// Mỗi core có 1 bản sao riêng (instantiated bên trong risc_core).
// Nạp chương trình từ file .hex bằng $readmemh.
//
// Đọc bất đồng bộ (combinational) - trả instruction trong cùng cycle.
// =============================================================================
`timescale 1ns / 1ps

module instr_mem #(
    parameter INIT_FILE = "program.hex"  // File hex nạp chương trình
)(
    input  wire [31:0] addr,        // Địa chỉ byte (từ PC, word-aligned)
    output wire [31:0] instruction  // Lệnh 32-bit
);

    // 256 words × 32 bits = 1 KB ROM
    reg [31:0] mem [0:255];

    // Word index từ byte address
    wire [7:0] word_addr = addr[9:2];

    // Đọc bất đồng bộ
    assign instruction = mem[word_addr];

    // Nạp chương trình khi khởi tạo
    initial begin
        $readmemh(INIT_FILE, mem);
    end

endmodule

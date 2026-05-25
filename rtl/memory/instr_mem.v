// =============================================================================
// instr_mem.v - Instruction ROM
//
// Read-only 256-word instruction memory. Each core instantiates its own copy.
// PROGRAM_WORDS lets short demo programs load without noisy readmemh warnings.
// =============================================================================
`timescale 1ns / 1ps

module instr_mem #(
    parameter INIT_FILE = "program.hex",
    parameter PROGRAM_WORDS = 256
)(
    input  wire [31:0] addr,
    output wire [31:0] instruction
);

    reg [31:0] mem [0:255];
    wire [7:0] word_addr = addr[9:2];

    assign instruction = mem[word_addr];

    integer i;
    initial begin
        for (i = 0; i < 256; i = i + 1)
            mem[i] = 32'h0000_0013; // ADDI x0, x0, 0 (NOP)
        $readmemh(INIT_FILE, mem, 0, PROGRAM_WORDS - 1);
    end

endmodule

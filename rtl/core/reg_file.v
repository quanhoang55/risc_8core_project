// 32-bit Register File (RV32I compatible)
// Part 1: Single-Core Engine & ISA

module reg_file (
    input  wire        clk,           // Clock signal
    input  wire        reset,         // Reset signal (matches pc_logic.v)
    
    // Addresses (5 bits to address 32 registers)
    input  wire [4:0]  rs1_addr,      // Source Register 1
    input  wire [4:0]  rs2_addr,      // Source Register 2
    input  wire [4:0]  rd_addr,       // Destination Register
    
    // Write Data and Control
    input  wire [31:0] write_data,    // Data to be written to rd
    input  wire        reg_write,     // Write enable from Control Unit
    
    // Data Outputs
    output wire [31:0] rs1_data,      // Data out from rs1
    output wire [31:0] rs2_data       // Data out from rs2
);

    // Internal memory array: 32 registers, 32 bits each
    reg [31:0] registers [0:31];

    // Asynchronous Read: Data is available immediately when addresses change
    // Note: Register x0 is hardwired to 0 in RISC-V
    assign rs1_data = (rs1_addr == 5'd0) ? 32'd0 : registers[rs1_addr];
    assign rs2_data = (rs2_addr == 5'd0) ? 32'd0 : registers[rs2_addr];

    // Synchronous Write: Updates happen on the rising edge of the clock
    integer i;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            // Initialize all registers to 0 on reset[cite: 1]
            for (i = 0; i < 32; i = i + 1) begin
                registers[i] <= 32'd0;
            end
        end 
        else if (reg_write && (rd_addr != 5'd0)) begin
            // Write data to rd if enable is high and rd is not register 0[cite: 1]
            registers[rd_addr] <= write_data;
        end
    end

endmodule

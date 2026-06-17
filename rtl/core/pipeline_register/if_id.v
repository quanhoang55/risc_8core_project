`timescale 1ns / 1ps
module if_id (
    input wire clk,
    input wire reset,
    input wire clear, // Flush khi rẽ nhánh sai
    input wire hold,  // Stall khi gặp Load-Use
    input wire [31:0] if_pc,
    input wire [31:0] if_instr,
    output reg        id_valid,
    output reg [31:0] id_pc,
    output reg [31:0] id_instr
);
    always @(posedge clk or posedge reset) begin
        if (reset || clear) begin
            id_valid <= 1'b0;
            id_pc    <= 32'd0;
            id_instr <= 32'd0;
        end else if (!hold) begin
            id_valid <= 1'b1;
            id_pc    <= if_pc;
            id_instr <= if_instr;
        end
    end
endmodule
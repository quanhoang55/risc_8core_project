// =============================================================================
// arbiter.v
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

    reg [7:0] last_granted;  // Bit mask

    // Round-Robin scan (combinational)
    reg [2:0] winner;
    reg       found;
    integer   i;
    reg [2:0] candidate;

    // Create masked request
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
                // Clear last_granted when it's not having request pending
                // Allow core request 
                last_granted <= last_granted & request;
            end
        end
    end

endmodule

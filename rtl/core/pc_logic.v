module pc_logic (
    input  wire        clk,
    input  wire        reset,
    input  wire        stall,

    input  wire        branch_taken,
    input  wire [31:0] branch_target,

    input  wire        jump,
    input  wire [31:0] jump_target,

    output reg  [31:0] pc
);

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            pc <= 32'd0;
        end
        else if (stall) begin
            pc <= pc;
        end
        else if (jump) begin
            pc <= jump_target;
        end
        else if (branch_taken) begin
            pc <= branch_target;
        end
        else begin
            pc <= pc + 32'd4;
        end
    end

endmodule
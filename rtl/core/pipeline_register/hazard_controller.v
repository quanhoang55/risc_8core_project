`timescale 1ns / 1ps
module hazard_controller (
    // Inputs For Forwarding
    input wire        ex_valid,
    input wire        ex_reg_write,
    input wire [ 4:0] ex_rs1_addr,
    input wire [ 4:0] ex_rs2_addr,
    input wire        mem_can_forward,
    input wire [ 4:0] mem_rd_addr,
    input wire        wb_can_forward,
    input wire [ 4:0] wb_rd_addr,

    // Inputs For Load-Use Stall
    input wire        id_valid,
    input wire [ 4:0] cu_rs1_addr,
    input wire [ 4:0] cu_rs2_addr,
    input wire        ex_load_like,
    input wire [ 4:0] ex_rd_addr,

    // Inputs For Memory Stall & Control Flush
    input wire        mem_wait,
    input wire        redirect_taken,

    // Outputs
    output reg [ 1:0] forward_a,
    output reg [ 1:0] forward_b,
    output wire       load_use_stall,
    output wire       if_id_hold,
    output wire       if_id_clear,
    output wire       id_ex_hold,
    output wire       id_ex_clear,
    output wire       ex_mem_hold,
    output wire       mem_wb_hold
);

    // =========================================================================
    // 1. Mạch Forwarding
    // =========================================================================
    always @* begin
        forward_a = 2'b00; 
        forward_b = 2'b00;

        // A
        if (mem_can_forward && (mem_rd_addr != 5'd0) && (mem_rd_addr == ex_rs1_addr)) begin
            forward_a = 2'b10; 
        end 
        else if (wb_can_forward && (wb_rd_addr != 5'd0) && (wb_rd_addr == ex_rs1_addr)) begin
            forward_a = 2'b01; 
        end

        // Forwarding For B
        if (mem_can_forward && (mem_rd_addr != 5'd0) && (mem_rd_addr == ex_rs2_addr)) begin
            forward_b = 2'b10; 
        end 
        else if (wb_can_forward && (wb_rd_addr != 5'd0) && (wb_rd_addr == ex_rs2_addr)) begin
            forward_b = 2'b01; 
        end
    end

    // =========================================================================
    // Load-Use Stall
    // =========================================================================
    assign load_use_stall = id_valid && ex_load_like && (ex_rd_addr != 5'd0) &&
                            ((ex_rd_addr == cu_rs1_addr) || (ex_rd_addr == cu_rs2_addr));

    // =========================================================================
    // Hold / Clear
    // =========================================================================
    assign if_id_hold   = load_use_stall || mem_wait;
    assign if_id_clear  = redirect_taken && !mem_wait; 
    
    assign id_ex_hold   = mem_wait;
    assign id_ex_clear  = (redirect_taken || load_use_stall) && !mem_wait; 

    assign ex_mem_hold  = mem_wait;
    assign mem_wb_hold  = mem_wait; 

endmodule
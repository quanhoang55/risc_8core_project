`timescale 1ns / 1ps
module hazard_controller (
    // Inputs phục vụ Forwarding
    input wire        ex_valid,
    input wire        ex_reg_write,
    input wire [ 4:0] ex_rs1_addr,
    input wire [ 4:0] ex_rs2_addr,
    input wire        mem_can_forward,
    input wire [ 4:0] mem_rd_addr,
    input wire        wb_can_forward,
    input wire [ 4:0] wb_rd_addr,

    // Inputs phục vụ Load-Use Stall
    input wire        id_valid,
    input wire [ 4:0] cu_rs1_addr,
    input wire [ 4:0] cu_rs2_addr,
    input wire        ex_load_like,
    input wire [ 4:0] ex_rd_addr,

    // Inputs phục vụ Memory Stall & Control Flush
    input wire        mem_wait,
    input wire        redirect_taken,

    // Outputs điều khiển luồng dữ liệu & vách ngăn
    output reg [ 1:0] forward_a,
    output reg [ 1:0] forward_b,
    output wire       load_use_stall,
    output wire       if_id_hold,
    output wire       if_id_clear,
    output wire       id_ex_hold,
    output wire       id_ex_clear,
    output wire       ex_mem_hold,
    output wire       mem_wb_hold  // Thay thế mem_wb_clear thành hold để đồng bộ đóng băng
);

    // =========================================================================
    // 1. Mạch Forwarding - Đã vá lỗi kiểm tra thanh ghi x0
    // =========================================================================
    always_comb begin
        forward_a = 2'b00; // Mặc định dùng dữ liệu gốc từ Register File
        forward_b = 2'b00;

        // Ưu tiên 1: Forward từ tầng EX/MEM (Lệnh ngay trước)
        if (mem_can_forward && (mem_rd_addr != 5'd0) && (mem_rd_addr == ex_rs1_addr)) begin
            forward_a = 2'b10; 
        end 
        // Ưu tiên 2: Forward từ tầng MEM/WB (Lệnh trước đó nữa)
        else if (wb_can_forward && (wb_rd_addr != 5'd0) && (wb_rd_addr == ex_rs1_addr)) begin
            forward_a = 2'b01; 
        end

        // Tương tự cho toán hạng B
        if (mem_can_forward && (mem_rd_addr != 5'd0) && (mem_rd_addr == ex_rs2_addr)) begin
            forward_b = 2'b10; 
        end 
        else if (wb_can_forward && (wb_rd_addr != 5'd0) && (wb_rd_addr == ex_rs2_addr)) begin
            forward_b = 2'b01; 
        end
    end

    // =========================================================================
    // 2. Mạch Load-Use Stall (Giữ nguyên vì đã check x0 sẵn ở ex_rd_addr != 0)
    // =========================================================================
    assign load_use_stall = id_valid && ex_load_like && (ex_rd_addr != 5'd0) &&
                            ((ex_rd_addr == cu_rs1_addr) || (ex_rd_addr == cu_rs2_addr));

    // =========================================================================
    // 3. Quản lý các chốt chặn (Hold / Clear) - Đã sửa lỗi sập hầm Memory Stall
    // =========================================================================
    
    // Khi bị Load-Use Stall HOẶC chờ Bus bộ nhớ bên ngoài -> Đóng băng tầng IF/ID
    assign if_id_hold   = load_use_stall || mem_wait;
    // Khi rẽ nhánh thực hiện (Jump/Branch taken) -> Xóa lệnh rác ở tầng IF/ID
    assign if_id_clear  = redirect_taken && !mem_wait; // Không flush khi đang stall bộ nhớ
    
    // Tầng ID/EX đóng băng khi chờ bộ nhớ
    assign id_ex_hold   = mem_wait;
    // Tầng ID/EX bị xóa khi rẽ nhánh SAI, HOẶC chủ động chèn Bong bóng (Bubble NOP) do Load-Use Stall
    assign id_ex_clear  = (redirect_taken || load_use_stall) && !mem_wait;

    // Khi gặp Memory Stall, đóng băng toàn bộ các tầng phía sau để giữ nguyên trạng thái dữ liệu
    assign ex_mem_hold  = mem_wait;
    assign mem_wb_hold  = mem_wait; 

endmodule
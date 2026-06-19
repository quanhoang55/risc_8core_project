`timescale 1ns / 1ps

module tb_risc_core;

    // --- Khai báo các tín hiệu Testbench ---
    reg clk;
    reg reset;

    wire        mem_req;
    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire        mem_we;
    wire        mem_re;
    wire        mem_lr;
    wire        mem_sc;
    wire        mem_amo;
    wire [ 3:0] mem_amo_op;

    reg  [31:0] mem_rdata;
    reg         mem_ready;
    reg         mem_sc_result;

    // --- Khởi tạo khối UUT (Unit Under Test) ---
    risc_core #(
        .CORE_ID(0),
        .INIT_FILE("program.hex"),
        .PROGRAM_WORDS(64)
    ) uut (
        .clk(clk),
        .reset(reset),
        .mem_req(mem_req),
        .mem_addr(mem_addr),
        .mem_wdata(mem_wdata),
        .mem_we(mem_we),
        .mem_re(mem_re),
        .mem_lr(mem_lr),
        .mem_sc(mem_sc),
        .mem_amo(mem_amo),
        .mem_amo_op(mem_amo_op),
        .mem_rdata(mem_rdata),
        .mem_ready(mem_ready),
        .mem_sc_result(mem_sc_result)
    );

    // --- 1. Tạo xung Clock (Chu kỳ 10ns -> Freq = 100MHz) ---
    always #5 clk = ~clk;

    // --- 2. Cấu trúc xuất file sóng cho GTKWave ---
    initial begin
        $dumpfile("risc_core_waveform.vcd");
        $dumpvars(0, tb_risc_core);
    end

    // --- 3. Mạch giả lập RAM ngoài (Data Memory Behavior) ---
    // RAM phản hồi sau 1 chu kỳ trễ để ép mạch Core xử lý mem_wait Stall
    reg [1:0] stall_counter;
    
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            mem_ready     <= 1'b0;
            mem_rdata     <= 32'd0;
            mem_sc_result <= 1'b0;
            stall_counter <= 2'd0;
        end else begin
            if (mem_req && !mem_ready) begin
                if (stall_counter == 2'd1) begin // Giả lập trễ Bus 1 chu kỳ clock
                    mem_ready     <= 1'b1;
                    stall_counter <= 2'd0;
                    
                    // Giả lập dữ liệu trả về khi có lệnh Đọc (Load / LR)
                    if (mem_re) begin
                        if (mem_addr == 32'h000000A0)
                            mem_rdata <= 32'hDEADC0DE; // Trả về dữ liệu test mẫu
                        else
                            mem_rdata <= 32'h0000002A; // Số 42 mặc định
                    end
                    
                    // Giả lập kết quả lệnh Store-Conditional (1 = Thành công)
                    if (mem_sc) begin
                        mem_sc_result <= 1'b1; 
                    end
                end else begin
                    stall_counter <= stall_counter + 2'd1;
                    mem_ready     <= 1'b0;
                end
            end else begin
                mem_ready <= 1'b0;
            end
        end
    end

    // --- 4. Tiến trình kích hoạt các kịch bản Test ---
    initial begin
        // Khởi tạo trạng thái ban đầu
        clk   = 0;
        reset = 1;
        
        $display("=========================================================");
        $display("   BAT DAU KIEM THU LOI SYSTEM-LEVEL: RISC_CORE.V");
        $display("=========================================================");
        
        // Kích hoạt Reset hệ thống trong 2 chu kỳ để xóa sạch Pipeline
        #20;
        reset = 0;
        $display("[STATUS] Reset completed. Pipeline started fetching...");

        // Cho Core chạy tự do trong 400ns để thực thi luồng chương trình
        // Trong quá trình này, các bộ đếm nội bộ của Core sẽ tự chạy
        #400;

        // --- 5. Báo cáo kết quả giám sát hiệu năng Core ---
        $display("\n=========================================================");
        $display("          BAO CAO HOAT DONG CUA CORE (COUNTERS)");
        $display("=========================================================");
        $display(" Tổng số chu kỳ xung bock chạy qua: %d", uut.pipeline_cycle_count);
        $display(" Số lệnh hoàn thành (Retired):      %d", uut.retired_count);
        $display(" Số chu kỳ kẹt bộ nhớ (Mem Stall):  %d", uut.mem_stall_count);
        $display(" Số chu kỳ kẹt Load-Use Stall:      %d", uut.load_use_stall_count);
        $display(" Số lần xóa lệnh rác (Flush Count): %d", uut.flush_count);
        $display("=========================================================");

        $finish;
    end

endmodule
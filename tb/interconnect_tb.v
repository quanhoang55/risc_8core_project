// =============================================================================
// interconnect_tb.v - Testbench cho arbiter + bus_ctrl + data_mem
// Test 1: Round-Robin Write/Read (4 cores)
// Test 2: LR/SC (success + snooping failure)
// Test 3: AMO Atomic Add
// =============================================================================
`timescale 1ns / 1ps

module interconnect_tb;
    reg clk, reset;
    always #5 clk = ~clk;

    wire [7:0] arb_request, arb_grant;
    wire arb_grant_valid;
    wire [2:0] arb_grant_id;

    reg  [7:0]  core_mem_req;
    reg  [31:0] core_addr   [0:7];
    reg  [31:0] core_wdata  [0:7];
    reg  [7:0]  core_we, core_re, core_lr, core_sc, core_amo;
    reg  [3:0]  core_amo_op [0:7];
    wire [31:0] core_rdata  [0:7];
    wire [7:0]  core_ready, core_sc_result;
    wire [31:0] dm_addr, dm_wdata, dm_rdata;
    wire        dm_we, dm_re;

    arbiter u_arbiter (.clk(clk),.reset(reset),.request(arb_request),
        .grant(arb_grant),.grant_valid(arb_grant_valid),.grant_id(arb_grant_id));
    bus_ctrl u_bus_ctrl (.clk(clk),.reset(reset),
        .bus_request(arb_request),.bus_grant(arb_grant),
        .bus_grant_valid(arb_grant_valid),.bus_grant_id(arb_grant_id),
        .core_mem_req(core_mem_req),
        .core_addr(core_addr),.core_wdata(core_wdata),
        .core_we(core_we),.core_re(core_re),
        .core_lr(core_lr),.core_sc(core_sc),
        .core_amo(core_amo),.core_amo_op(core_amo_op),
        .core_rdata(core_rdata),.core_ready(core_ready),
        .core_sc_result(core_sc_result),
        .dm_addr(dm_addr),.dm_wdata(dm_wdata),
        .dm_rdata(dm_rdata),.dm_we(dm_we),.dm_re(dm_re));
    data_mem u_data_mem (.clk(clk),.reset(reset),
        .addr(dm_addr),.wdata(dm_wdata),.we(dm_we),.re(dm_re),.rdata(dm_rdata));

    integer test_pass, test_fail;

    task clear_all;
        integer k;
        begin
            core_mem_req=8'b0; core_we=8'b0; core_re=8'b0;
            core_lr=8'b0; core_sc=8'b0; core_amo=8'b0;
            for(k=0;k<8;k=k+1) begin core_addr[k]=0; core_wdata[k]=0; core_amo_op[k]=0; end
        end
    endtask

    // WRITE: set signals -> wait for grant -> wait for mem write -> clear
    task do_write;
        input [2:0] cid;
        input [31:0] addr;
        input [31:0] data;
        begin
            clear_all;
            core_mem_req[cid]=1; core_we[cid]=1;
            core_addr[cid]=addr; core_wdata[cid]=data;
            // Wait until core_ready asserts
            @(posedge clk); // arbiter sees request
            @(posedge clk); // arbiter grants, bus_ctrl processes, dm_we goes high
            @(posedge clk); // data_mem writes
            clear_all;
            @(posedge clk); // settle + allow arbiter to clear last_granted
        end
    endtask

    // READ: set -> grant -> bus_ctrl reads async -> registered
    task do_read;
        input [2:0] cid;
        input [31:0] addr;
        output [31:0] data;
        begin
            clear_all;
            core_mem_req[cid]=1; core_re[cid]=1; core_addr[cid]=addr;
            @(posedge clk); // arbiter sees
            @(posedge clk); // grant + bus_ctrl registers rdata
            @(posedge clk); // rdata stable
            data = core_rdata[cid];
            clear_all;
            @(posedge clk);
        end
    endtask

    // LR
    task do_lr;
        input [2:0] cid;
        input [31:0] addr;
        output [31:0] data;
        begin
            clear_all;
            core_mem_req[cid]=1; core_lr[cid]=1; core_addr[cid]=addr;
            @(posedge clk); // arbiter sees
            @(posedge clk); // grant + bus_ctrl processes LR, sets reservation
            @(posedge clk); // rdata stable
            data = core_rdata[cid];
            clear_all;
            @(posedge clk); // settle
        end
    endtask

    // SC
    task do_sc;
        input [2:0] cid;
        input [31:0] addr;
        input [31:0] data;
        output success;
        begin
            clear_all;
            core_mem_req[cid]=1; core_sc[cid]=1;
            core_addr[cid]=addr; core_wdata[cid]=data;
            @(posedge clk); // arbiter sees
            @(posedge clk); // grant + bus_ctrl processes SC
            @(posedge clk); // result stable, mem written (if success)
            success = ~core_sc_result[cid];
            clear_all;
            @(posedge clk);
        end
    endtask

    // AMO
    task do_amo;
        input [2:0] cid;
        input [3:0] op;
        input [31:0] addr;
        input [31:0] operand;
        output [31:0] old_val;
        begin
            clear_all;
            core_mem_req[cid]=1; core_amo[cid]=1;
            core_addr[cid]=addr; core_wdata[cid]=operand; core_amo_op[cid]=op;
            @(posedge clk); // arbiter sees
            @(posedge clk); // grant -> bus_ctrl enters AMO_READ
            @(posedge clk); // AMO_READ -> AMO_CALC
            @(posedge clk); // AMO_CALC -> writes, core_rdata registered
            @(posedge clk); // stable
            old_val = core_rdata[cid];
            clear_all;
            @(posedge clk);
        end
    endtask

    reg [31:0] rv;
    reg sc_ok;

    initial begin
        $dumpfile("interconnect_tb.vcd");
        $dumpvars(0, interconnect_tb);
        clk=0; reset=1; test_pass=0; test_fail=0;
        clear_all;
        #25 reset=0;
        @(posedge clk); @(posedge clk);

        // === TEST 1 ===
        $display("");
        $display("========================================");
        $display("  TEST 1: Round-Robin Write/Read");
        $display("========================================");

        do_write(3'd0, 32'h0000, 32'hAAAA_0000);
        do_write(3'd1, 32'h0004, 32'hBBBB_0001);
        do_write(3'd2, 32'h0008, 32'hCCCC_0002);
        do_write(3'd3, 32'h000C, 32'hDDDD_0003);

        do_read(3'd0, 32'h0000, rv);
        if(rv==32'hAAAA_0000) begin $display("  [PASS] C0:0x%h",rv); test_pass=test_pass+1; end
        else begin $display("  [FAIL] C0:0x%h exp 0xAAAA0000",rv); test_fail=test_fail+1; end

        do_read(3'd1, 32'h0004, rv);
        if(rv==32'hBBBB_0001) begin $display("  [PASS] C1:0x%h",rv); test_pass=test_pass+1; end
        else begin $display("  [FAIL] C1:0x%h exp 0xBBBB0001",rv); test_fail=test_fail+1; end

        do_read(3'd2, 32'h0008, rv);
        if(rv==32'hCCCC_0002) begin $display("  [PASS] C2:0x%h",rv); test_pass=test_pass+1; end
        else begin $display("  [FAIL] C2:0x%h exp 0xCCCC0002",rv); test_fail=test_fail+1; end

        do_read(3'd3, 32'h000C, rv);
        if(rv==32'hDDDD_0003) begin $display("  [PASS] C3:0x%h",rv); test_pass=test_pass+1; end
        else begin $display("  [FAIL] C3:0x%h exp 0xDDDD0003",rv); test_fail=test_fail+1; end

        // === TEST 2 ===
        $display("");
        $display("========================================");
        $display("  TEST 2: LR/SC Atomic Operations");
        $display("========================================");

        do_write(3'd0, 32'h0100, 32'd100);

        // 2a: LR -> SC (no interference) -> SUCCESS
        do_lr(3'd0, 32'h0100, rv);
        $display("  C0 LR: %0d", rv);
        do_sc(3'd0, 32'h0100, 32'd200, sc_ok);
        if(sc_ok) begin $display("  [PASS] SC SUCCESS"); test_pass=test_pass+1; end
        else begin $display("  [FAIL] SC should succeed"); test_fail=test_fail+1; end
        do_read(3'd0, 32'h0100, rv);
        if(rv==32'd200) begin $display("  [PASS] Mem=%0d",rv); test_pass=test_pass+1; end
        else begin $display("  [FAIL] Mem=%0d exp 200",rv); test_fail=test_fail+1; end

        // 2b: LR -> other WRITE -> SC -> FAIL
        do_lr(3'd0, 32'h0100, rv);
        $display("  C0 LR: %0d", rv);
        do_write(3'd1, 32'h0100, 32'd999);
        $display("  C1 writes 999 (invalidates C0)");
        do_sc(3'd0, 32'h0100, 32'd300, sc_ok);
        if(!sc_ok) begin $display("  [PASS] SC FAILED (expected)"); test_pass=test_pass+1; end
        else begin $display("  [FAIL] SC should fail"); test_fail=test_fail+1; end
        do_read(3'd0, 32'h0100, rv);
        if(rv==32'd999) begin $display("  [PASS] Mem=%0d",rv); test_pass=test_pass+1; end
        else begin $display("  [FAIL] Mem=%0d exp 999",rv); test_fail=test_fail+1; end

        // === TEST 3 ===
        $display("");
        $display("========================================");
        $display("  TEST 3: AMO Atomic Add");
        $display("========================================");

        do_write(3'd0, 32'h0200, 32'd0);
        do_amo(3'd2, 4'd1, 32'h0200, 32'd42, rv);
        $display("  AMOADD +42: old=%0d", rv);
        do_read(3'd0, 32'h0200, rv);
        if(rv==32'd42) begin $display("  [PASS] Mem=%0d",rv); test_pass=test_pass+1; end
        else begin $display("  [FAIL] Mem=%0d exp 42",rv); test_fail=test_fail+1; end

        do_amo(3'd3, 4'd1, 32'h0200, 32'd58, rv);
        $display("  AMOADD +58: old=%0d", rv);
        do_read(3'd0, 32'h0200, rv);
        if(rv==32'd100) begin $display("  [PASS] Mem=%0d",rv); test_pass=test_pass+1; end
        else begin $display("  [FAIL] Mem=%0d exp 100",rv); test_fail=test_fail+1; end

        // === SUMMARY ===
        $display("");
        $display("==========================================");
        $display("  SUMMARY: %0d PASSED, %0d FAILED", test_pass, test_fail);
        $display("==========================================");
        #20 $finish;
    end
endmodule

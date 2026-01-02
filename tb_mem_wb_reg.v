// ============================================================================
// Testbench for MEM/WB Pipeline Register
// Tests memory results and control signal propagation
// Verifies proper data storage for writeback stage
// Self-checking with comprehensive test cases
// ============================================================================

`timescale 1ns / 1ps

module tb_mem_wb_reg;

    // ========================================================================
    // Clock and Reset
    // ========================================================================

    reg clk;
    reg rst_n;

    // ========================================================================
    // DUT Signals
    // ========================================================================

    // Data inputs
    reg [31:0] alu_result_mem;
    reg [31:0] mem_rdata_mem;
    reg [31:0] fpu_result_mem;
    reg [4:0]  rd_mem;

    // Control inputs
    reg        reg_write_mem;
    reg        mem_to_reg_mem;
    reg        fp_op_mem;
    reg        fp_reg_write_mem;

    // Data outputs
    wire [31:0] alu_result_wb;
    wire [31:0] mem_rdata_wb;
    wire [31:0] fpu_result_wb;
    wire [4:0]  rd_wb;

    // Control outputs
    wire        reg_write_wb;
    wire        mem_to_reg_wb;
    wire        fp_op_wb;
    wire        fp_reg_write_wb;

    // ========================================================================
    // DUT Instantiation
    // ========================================================================

    mem_wb_reg dut (
        .clk(clk),
        .rst_n(rst_n),
        .alu_result_mem(alu_result_mem),
        .mem_rdata_mem(mem_rdata_mem),
        .fpu_result_mem(fpu_result_mem),
        .rd_mem(rd_mem),
        .reg_write_mem(reg_write_mem),
        .mem_to_reg_mem(mem_to_reg_mem),
        .fp_op_mem(fp_op_mem),
        .fp_reg_write_mem(fp_reg_write_mem),
        .alu_result_wb(alu_result_wb),
        .mem_rdata_wb(mem_rdata_wb),
        .fpu_result_wb(fpu_result_wb),
        .rd_wb(rd_wb),
        .reg_write_wb(reg_write_wb),
        .mem_to_reg_wb(mem_to_reg_wb),
        .fp_op_wb(fp_op_wb),
        .fp_reg_write_wb(fp_reg_write_wb)
    );

    // ========================================================================
    // Clock Generation
    // ========================================================================

    initial clk = 0;
    always #5 clk = ~clk;

    // ========================================================================
    // Test Infrastructure
    // ========================================================================

    integer test_count = 0;
    integer pass_count = 0;
    integer fail_count = 0;

    // ========================================================================
    // Test Tasks
    // ========================================================================

    task reset_inputs;
        begin
            alu_result_mem = 32'd0;
            mem_rdata_mem = 32'd0;
            fpu_result_mem = 32'd0;
            rd_mem = 5'd0;
            reg_write_mem = 1'b0;
            mem_to_reg_mem = 1'b0;
            fp_op_mem = 1'b0;
            fp_reg_write_mem = 1'b0;
        end
    endtask

    task check_all_zero;
        input [200:0] description;
        begin
            test_count = test_count + 1;
            #1;

            if (alu_result_wb === 32'd0 && mem_rdata_wb === 32'd0 &&
                fpu_result_wb === 32'd0 && rd_wb === 5'd0 &&
                reg_write_wb === 1'b0 && mem_to_reg_wb === 1'b0 &&
                fp_op_wb === 1'b0 && fp_reg_write_wb === 1'b0) begin
                $display("[PASS] Test %0d: %s", test_count, description);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] Test %0d: %s", test_count, description);
                $display("       Some outputs are not zero");
                fail_count = fail_count + 1;
            end
        end
    endtask

    task check_propagation;
        input [200:0] description;
        begin
            test_count = test_count + 1;
            #1;

            if (alu_result_wb === alu_result_mem && mem_rdata_wb === mem_rdata_mem &&
                fpu_result_wb === fpu_result_mem && rd_wb === rd_mem &&
                reg_write_wb === reg_write_mem && mem_to_reg_wb === mem_to_reg_mem &&
                fp_op_wb === fp_op_mem && fp_reg_write_wb === fp_reg_write_mem) begin
                $display("[PASS] Test %0d: %s", test_count, description);
                $display("       ALU=0x%h, MEM=0x%h, FPU=0x%h, rd=%0d",
                         alu_result_wb, mem_rdata_wb, fpu_result_wb, rd_wb);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] Test %0d: %s", test_count, description);
                $display("       Some signals did not propagate correctly");
                fail_count = fail_count + 1;
            end
        end
    endtask

    task wait_cycle;
        begin
            @(posedge clk);
        end
    endtask

    // ========================================================================
    // Test Stimulus
    // ========================================================================

    initial begin
        $display("\n========================================");
        $display("MEM/WB Pipeline Register Testbench");
        $display("========================================\n");

        // Initialize
        rst_n = 0;
        reset_inputs();

        repeat(3) @(posedge clk);
        rst_n = 1;
        @(posedge clk);

        // ====================================================================
        // Test Category 1: Reset Behavior
        // ====================================================================
        $display("\n--- Test Category 1: Reset Behavior ---");

        check_all_zero("Reset: All outputs are zero");

        // ====================================================================
        // Test Category 2: ALU Result Propagation
        // ====================================================================
        $display("\n--- Test Category 2: ALU Result Propagation ---");

        alu_result_mem = 32'h12345678;
        rd_mem = 5'd10;
        reg_write_mem = 1'b1;
        wait_cycle();
        check_propagation("ALU result: ADD operation");

        alu_result_mem = 32'hABCDEF01;
        rd_mem = 5'd15;
        wait_cycle();
        check_propagation("ALU result: SUB operation");

        alu_result_mem = 32'hFFFFFFFF;
        rd_mem = 5'd20;
        wait_cycle();
        check_propagation("ALU result: All 1s");

        alu_result_mem = 32'h00000000;
        rd_mem = 5'd0;
        wait_cycle();
        check_propagation("ALU result: Zero");

        // ====================================================================
        // Test Category 3: Memory Read Data Propagation
        // ====================================================================
        $display("\n--- Test Category 3: Memory Read Data ---");

        reset_inputs();
        mem_rdata_mem = 32'hDEADBEEF;
        rd_mem = 5'd8;
        reg_write_mem = 1'b1;
        mem_to_reg_mem = 1'b1;
        wait_cycle();
        check_propagation("Load word: Memory data");

        mem_rdata_mem = 32'hCAFEBABE;
        rd_mem = 5'd9;
        wait_cycle();
        check_propagation("Load word: Different data");

        mem_rdata_mem = 32'h00000042;
        rd_mem = 5'd11;
        wait_cycle();
        check_propagation("Load word: Small value");

        mem_rdata_mem = 32'hFFFFFFFF;
        rd_mem = 5'd12;
        wait_cycle();
        check_propagation("Load word: All 1s (signed -1)");

        // ====================================================================
        // Test Category 4: Sign-Extended Load Results
        // ====================================================================
        $display("\n--- Test Category 4: Sign-Extended Loads ---");

        reset_inputs();
        mem_rdata_mem = 32'hFFFFFF80;  // LB sign-extended negative
        rd_mem = 5'd5;
        reg_write_mem = 1'b1;
        mem_to_reg_mem = 1'b1;
        wait_cycle();
        check_propagation("Load byte: Sign-extended negative");

        mem_rdata_mem = 32'h0000007F;  // LB sign-extended positive
        rd_mem = 5'd6;
        wait_cycle();
        check_propagation("Load byte: Sign-extended positive");

        mem_rdata_mem = 32'hFFFF8000;  // LH sign-extended negative
        rd_mem = 5'd7;
        wait_cycle();
        check_propagation("Load halfword: Sign-extended negative");

        mem_rdata_mem = 32'h00007FFF;  // LH sign-extended positive
        rd_mem = 5'd8;
        wait_cycle();
        check_propagation("Load halfword: Sign-extended positive");

        // ====================================================================
        // Test Category 5: Zero-Extended Load Results
        // ====================================================================
        $display("\n--- Test Category 5: Zero-Extended Loads ---");

        reset_inputs();
        mem_rdata_mem = 32'h000000FF;  // LBU
        rd_mem = 5'd9;
        reg_write_mem = 1'b1;
        mem_to_reg_mem = 1'b1;
        wait_cycle();
        check_propagation("Load byte unsigned: 0xFF");

        mem_rdata_mem = 32'h0000FFFF;  // LHU
        rd_mem = 5'd10;
        wait_cycle();
        check_propagation("Load halfword unsigned: 0xFFFF");

        // ====================================================================
        // Test Category 6: FPU Result Propagation
        // ====================================================================
        $display("\n--- Test Category 6: FPU Result Propagation ---");

        reset_inputs();
        fpu_result_mem = 32'h3F800000;  // 1.0
        rd_mem = 5'd11;
        reg_write_mem = 1'b1;
        fp_op_mem = 1'b1;
        fp_reg_write_mem = 1'b1;
        wait_cycle();
        check_propagation("FPU result: 1.0");

        fpu_result_mem = 32'h40000000;  // 2.0
        rd_mem = 5'd12;
        wait_cycle();
        check_propagation("FPU result: 2.0");

        fpu_result_mem = 32'h40400000;  // 3.0
        rd_mem = 5'd13;
        wait_cycle();
        check_propagation("FPU result: 3.0");

        fpu_result_mem = 32'h7F800000;  // +Infinity
        rd_mem = 5'd14;
        wait_cycle();
        check_propagation("FPU result: +Inf");

        fpu_result_mem = 32'hFF800000;  // -Infinity
        rd_mem = 5'd15;
        wait_cycle();
        check_propagation("FPU result: -Inf");

        fpu_result_mem = 32'h00000000;  // +0.0
        rd_mem = 5'd16;
        wait_cycle();
        check_propagation("FPU result: +0.0");

        fpu_result_mem = 32'h80000000;  // -0.0
        rd_mem = 5'd17;
        wait_cycle();
        check_propagation("FPU result: -0.0");

        // ====================================================================
        // Test Category 7: Combined Data (All Three Sources)
        // ====================================================================
        $display("\n--- Test Category 7: Combined Data Sources ---");

        reset_inputs();
        alu_result_mem = 32'h11111111;
        mem_rdata_mem = 32'h22222222;
        fpu_result_mem = 32'h33333333;
        rd_mem = 5'd18;
        reg_write_mem = 1'b1;
        mem_to_reg_mem = 1'b1;
        fp_op_mem = 1'b1;
        fp_reg_write_mem = 1'b1;
        wait_cycle();
        check_propagation("All sources: ALU + MEM + FPU");

        alu_result_mem = 32'hAAAAAAAA;
        mem_rdata_mem = 32'hBBBBBBBB;
        fpu_result_mem = 32'hCCCCCCCC;
        rd_mem = 5'd19;
        wait_cycle();
        check_propagation("All sources: Different pattern");

        // ====================================================================
        // Test Category 8: Register Destination Tests
        // ====================================================================
        $display("\n--- Test Category 8: Register Destinations ---");

        reset_inputs();
        alu_result_mem = 32'h00000100;
        rd_mem = 5'd0;  // x0 (zero register)
        reg_write_mem = 1'b1;
        wait_cycle();
        check_propagation("Destination: x0 (zero register)");

        rd_mem = 5'd1;  // x1 (return address)
        wait_cycle();
        check_propagation("Destination: x1 (ra)");

        rd_mem = 5'd2;  // x2 (stack pointer)
        wait_cycle();
        check_propagation("Destination: x2 (sp)");

        rd_mem = 5'd31;  // x31
        wait_cycle();
        check_propagation("Destination: x31 (last register)");

        // ====================================================================
        // Test Category 9: Control Signal Combinations
        // ====================================================================
        $display("\n--- Test Category 9: Control Combinations ---");

        reset_inputs();
        alu_result_mem = 32'h12340000;
        rd_mem = 5'd20;
        reg_write_mem = 1'b1;
        mem_to_reg_mem = 1'b0;
        fp_op_mem = 1'b0;
        wait_cycle();
        check_propagation("Control: ALU only (reg_write=1)");

        reset_inputs();
        mem_rdata_mem = 32'h56780000;
        rd_mem = 5'd21;
        reg_write_mem = 1'b1;
        mem_to_reg_mem = 1'b1;
        wait_cycle();
        check_propagation("Control: Memory (mem_to_reg=1)");

        reset_inputs();
        fpu_result_mem = 32'h3F000000;  // 0.5
        rd_mem = 5'd22;
        reg_write_mem = 1'b1;
        fp_op_mem = 1'b1;
        fp_reg_write_mem = 1'b1;
        wait_cycle();
        check_propagation("Control: FPU (fp_op=1)");

        reset_inputs();
        alu_result_mem = 32'hABCD0000;
        rd_mem = 5'd23;
        reg_write_mem = 1'b0;  // No write
        wait_cycle();
        check_propagation("Control: No writeback (reg_write=0)");

        // ====================================================================
        // Test Category 10: Reset During Operation
        // ====================================================================
        $display("\n--- Test Category 10: Reset During Operation ---");

        reset_inputs();
        alu_result_mem = 32'hFFFF0000;
        mem_rdata_mem = 32'h0000FFFF;
        fpu_result_mem = 32'hF0F0F0F0;
        reg_write_mem = 1'b1;
        wait_cycle();

        rst_n = 0;
        @(posedge clk);
        check_all_zero("During reset: All cleared");

        rst_n = 1;
        @(posedge clk);
        check_all_zero("After reset release: Still cleared");

        alu_result_mem = 32'hDEADBEEF;
        wait_cycle();
        check_propagation("After reset: Normal operation");

        // ====================================================================
        // Test Category 11: Edge Cases
        // ====================================================================
        $display("\n--- Test Category 11: Edge Cases ---");

        reset_inputs();
        alu_result_mem = 32'h80000000;  // Min signed int
        mem_rdata_mem = 32'h7FFFFFFF;   // Max signed int
        fpu_result_mem = 32'h7F7FFFFF;  // Max FP (before Inf)
        rd_mem = 5'd24;
        wait_cycle();
        check_propagation("Edge: Boundary values");

        alu_result_mem = 32'hFFFFFFFE;  // -2
        mem_rdata_mem = 32'h00000001;   // 1
        fpu_result_mem = 32'h80800000;  // Min normalized FP
        rd_mem = 5'd25;
        wait_cycle();
        check_propagation("Edge: Near boundary values");

        // ====================================================================
        // Test Category 12: Data Pattern Tests
        // ====================================================================
        $display("\n--- Test Category 12: Data Patterns ---");

        reset_inputs();
        alu_result_mem = 32'hA5A5A5A5;
        mem_rdata_mem = 32'h5A5A5A5A;
        fpu_result_mem = 32'hF0F0F0F0;
        wait_cycle();
        check_propagation("Pattern: Alternating bits");

        alu_result_mem = 32'h00FF00FF;
        mem_rdata_mem = 32'hFF00FF00;
        fpu_result_mem = 32'h0F0F0F0F;
        wait_cycle();
        check_propagation("Pattern: Byte patterns");

        alu_result_mem = 32'hAAAAAAAA;
        mem_rdata_mem = 32'h55555555;
        fpu_result_mem = 32'hCCCCCCCC;
        wait_cycle();
        check_propagation("Pattern: Bit patterns");

        // ====================================================================
        // Test Category 13: Sequential Operations
        // ====================================================================
        $display("\n--- Test Category 13: Sequential Operations ---");

        integer i;
        for (i = 0; i < 5; i = i + 1) begin
            reset_inputs();
            alu_result_mem = 32'h10000000 + (i * 256);
            mem_rdata_mem = 32'h20000000 + (i * 512);
            fpu_result_mem = 32'h30000000 + i;
            rd_mem = 5'd8 + i;
            reg_write_mem = 1'b1;
            wait_cycle();

            test_count = test_count + 1;
            if (alu_result_wb === (32'h10000000 + (i * 256)) &&
                mem_rdata_wb === (32'h20000000 + (i * 512)) &&
                fpu_result_wb === (32'h30000000 + i) &&
                rd_wb === (5'd8 + i)) begin
                $display("[PASS] Test %0d: Sequential [%0d] ALU=0x%h, MEM=0x%h",
                         test_count, i, alu_result_wb, mem_rdata_wb);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] Test %0d: Sequential [%0d]", test_count, i);
                fail_count = fail_count + 1;
            end
        end

        // ====================================================================
        // Test Category 14: Realistic Writeback Scenarios
        // ====================================================================
        $display("\n--- Test Category 14: Realistic Scenarios ---");

        // Integer ALU result writeback
        reset_inputs();
        alu_result_mem = 32'h00001234;
        rd_mem = 5'd10;
        reg_write_mem = 1'b1;
        wait_cycle();
        check_propagation("Realistic: Integer ADD result");

        // Load from memory
        reset_inputs();
        mem_rdata_mem = 32'h0000CAFE;
        rd_mem = 5'd11;
        reg_write_mem = 1'b1;
        mem_to_reg_mem = 1'b1;
        wait_cycle();
        check_propagation("Realistic: Load from array");

        // FPU computation result
        reset_inputs();
        fpu_result_mem = 32'h40490FDB;  // Pi
        rd_mem = 5'd12;
        reg_write_mem = 1'b1;
        fp_op_mem = 1'b1;
        fp_reg_write_mem = 1'b1;
        wait_cycle();
        check_propagation("Realistic: FP computation (Pi)");

        // NOP (no writeback)
        reset_inputs();
        wait_cycle();
        check_propagation("Realistic: NOP (no writeback)");

        // ====================================================================
        // Test Summary
        // ====================================================================
        @(posedge clk);
        $display("\n========================================");
        $display("Test Summary");
        $display("========================================");
        $display("Total Tests: %0d", test_count);
        $display("Passed:      %0d", pass_count);
        $display("Failed:      %0d", fail_count);

        if (fail_count == 0) begin
            $display("\n*** ALL TESTS PASSED ***\n");
        end else begin
            $display("\n*** SOME TESTS FAILED ***\n");
        end

        $finish;
    end

endmodule

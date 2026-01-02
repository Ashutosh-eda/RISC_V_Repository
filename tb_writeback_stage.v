// ============================================================================
// Testbench for Writeback Stage
// Tests data multiplexing between ALU, memory, and FPU results
// Verifies proper priority handling
// Self-checking with comprehensive test cases
// ============================================================================

`timescale 1ns / 1ps

module tb_writeback_stage;

    // ========================================================================
    // DUT Signals
    // ========================================================================

    reg  [31:0] alu_result_wb;
    reg  [31:0] mem_rdata_wb;
    reg  [31:0] fpu_result_wb;
    reg         mem_to_reg_wb;
    reg         fp_op_wb;

    wire [31:0] wb_data;

    // ========================================================================
    // DUT Instantiation
    // ========================================================================

    writeback_stage dut (
        .alu_result_wb(alu_result_wb),
        .mem_rdata_wb(mem_rdata_wb),
        .fpu_result_wb(fpu_result_wb),
        .mem_to_reg_wb(mem_to_reg_wb),
        .fp_op_wb(fp_op_wb),
        .wb_data(wb_data)
    );

    // ========================================================================
    // Test Infrastructure
    // ========================================================================

    integer test_count = 0;
    integer pass_count = 0;
    integer fail_count = 0;

    // ========================================================================
    // Test Task
    // ========================================================================

    task check_wb;
        input [31:0] test_alu;
        input [31:0] test_mem;
        input [31:0] test_fpu;
        input        test_mem_to_reg;
        input        test_fp_op;
        input [31:0] exp_wb_data;
        input [200:0] description;
        begin
            test_count = test_count + 1;

            alu_result_wb = test_alu;
            mem_rdata_wb = test_mem;
            fpu_result_wb = test_fpu;
            mem_to_reg_wb = test_mem_to_reg;
            fp_op_wb = test_fp_op;

            #10;

            if (wb_data === exp_wb_data) begin
                $display("[PASS] Test %0d: %s", test_count, description);
                $display("       wb_data = 0x%h", wb_data);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] Test %0d: %s", test_count, description);
                $display("       Expected: 0x%h", exp_wb_data);
                $display("       Got:      0x%h", wb_data);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // ========================================================================
    // Test Stimulus
    // ========================================================================

    initial begin
        $display("\n========================================");
        $display("Writeback Stage Testbench");
        $display("========================================\n");

        // Initialize
        alu_result_wb = 32'd0;
        mem_rdata_wb = 32'd0;
        fpu_result_wb = 32'd0;
        mem_to_reg_wb = 1'b0;
        fp_op_wb = 1'b0;

        #20;

        // ====================================================================
        // Test Category 1: ALU Result Selection
        // ====================================================================
        $display("\n--- Test Category 1: ALU Result Selection ---");

        check_wb(
            32'h12345678, 32'h00000000, 32'h00000000,
            1'b0, 1'b0,
            32'h12345678,
            "ALU result selected (mem_to_reg=0, fp_op=0)"
        );

        check_wb(
            32'hABCDEF01, 32'h99999999, 32'h88888888,
            1'b0, 1'b0,
            32'hABCDEF01,
            "ALU result priority (other data ignored)"
        );

        check_wb(
            32'hFFFFFFFF, 32'h00000000, 32'h00000000,
            1'b0, 1'b0,
            32'hFFFFFFFF,
            "ALU result = -1 (all 1s)"
        );

        check_wb(
            32'h00000000, 32'hDEADBEEF, 32'hCAFEBABE,
            1'b0, 1'b0,
            32'h00000000,
            "ALU result = 0 (other data ignored)"
        );

        // ====================================================================
        // Test Category 2: FPU Result Selection
        // ====================================================================
        $display("\n--- Test Category 2: FPU Result Selection ---");

        check_wb(
            32'h11111111, 32'h22222222, 32'h3F800000,
            1'b0, 1'b1,
            32'h3F800000,
            "FPU result selected (fp_op=1, mem_to_reg=0)"
        );

        check_wb(
            32'hAAAAAAAA, 32'hBBBBBBBB, 32'h40000000,
            1'b0, 1'b1,
            32'h40000000,
            "FPU result = 2.0 (IEEE 754)"
        );

        check_wb(
            32'h00000000, 32'h00000000, 32'h7F800000,
            1'b0, 1'b1,
            32'h7F800000,
            "FPU result = +Infinity"
        );

        check_wb(
            32'h12345678, 32'hABCDEF01, 32'h00000000,
            1'b0, 1'b1,
            32'h00000000,
            "FPU result = +0.0"
        );

        // ====================================================================
        // Test Category 3: Memory Data Selection (Highest Priority)
        // ====================================================================
        $display("\n--- Test Category 3: Memory Data Selection (Highest Priority) ---");

        check_wb(
            32'h11111111, 32'hDEADBEEF, 32'h33333333,
            1'b1, 1'b0,
            32'hDEADBEEF,
            "Memory data selected (mem_to_reg=1)"
        );

        check_wb(
            32'hAAAAAAAA, 32'h12345678, 32'hBBBBBBBB,
            1'b1, 1'b0,
            32'h12345678,
            "Memory data has highest priority"
        );

        check_wb(
            32'hFFFFFFFF, 32'h00000000, 32'hFFFFFFFF,
            1'b1, 1'b0,
            32'h00000000,
            "Memory data = 0 (load zero)"
        );

        check_wb(
            32'h00000000, 32'hFFFFFFFF, 32'h00000000,
            1'b1, 1'b0,
            32'hFFFFFFFF,
            "Memory data = -1 (load all 1s)"
        );

        // ====================================================================
        // Test Category 4: Priority Resolution (Memory > FPU)
        // ====================================================================
        $display("\n--- Test Category 4: Priority (Memory > FPU) ---");

        check_wb(
            32'h11111111, 32'h22222222, 32'h33333333,
            1'b1, 1'b1,
            32'h22222222,
            "Memory overrides FPU (mem_to_reg=1, fp_op=1)"
        );

        check_wb(
            32'hAAAAAAAA, 32'hBBBBBBBB, 32'hCCCCCCCC,
            1'b1, 1'b1,
            32'hBBBBBBBB,
            "Memory has highest priority over all"
        );

        // ====================================================================
        // Test Category 5: All Control Signals Off
        // ====================================================================
        $display("\n--- Test Category 5: Default Case (ALU) ---");

        check_wb(
            32'h55555555, 32'h66666666, 32'h77777777,
            1'b0, 1'b0,
            32'h55555555,
            "Default: ALU selected (both control=0)"
        );

        // ====================================================================
        // Test Category 6: Data Pattern Tests
        // ====================================================================
        $display("\n--- Test Category 6: Various Data Patterns ---");

        check_wb(
            32'hA5A5A5A5, 32'h00000000, 32'h00000000,
            1'b0, 1'b0,
            32'hA5A5A5A5,
            "ALU: Alternating pattern 0xA5"
        );

        check_wb(
            32'h00000000, 32'h5A5A5A5A, 32'h00000000,
            1'b1, 1'b0,
            32'h5A5A5A5A,
            "Memory: Alternating pattern 0x5A"
        );

        check_wb(
            32'h00000000, 32'h00000000, 32'hF0F0F0F0,
            1'b0, 1'b1,
            32'hF0F0F0F0,
            "FPU: Pattern 0xF0"
        );

        // ====================================================================
        // Test Category 7: Realistic Pipeline Scenarios
        // ====================================================================
        $display("\n--- Test Category 7: Realistic Scenarios ---");

        check_wb(
            32'h00001000, 32'h00000000, 32'h00000000,
            1'b0, 1'b0,
            32'h00001000,
            "ADD result (address calculation)"
        );

        check_wb(
            32'h00000000, 32'hCAFEBABE, 32'h00000000,
            1'b1, 1'b0,
            32'hCAFEBABE,
            "Load word from memory"
        );

        check_wb(
            32'h00000000, 32'h00000000, 32'h3F000000,
            1'b0, 1'b1,
            32'h3F000000,
            "FPU add result (0.5)"
        );

        check_wb(
            32'h00000000, 32'hFFFFFFF0, 32'h00000000,
            1'b1, 1'b0,
            32'hFFFFFFF0,
            "Load byte (sign-extended negative)"
        );

        // ====================================================================
        // Test Category 8: Sequential Operations
        // ====================================================================
        $display("\n--- Test Category 8: Sequential Operations ---");

        integer i;
        for (i = 0; i < 4; i = i + 1) begin
            alu_result_wb = 32'h10000000 + i;
            mem_rdata_wb = 32'h20000000 + i;
            fpu_result_wb = 32'h30000000 + i;

            // ALU operation
            mem_to_reg_wb = 1'b0;
            fp_op_wb = 1'b0;
            #10;

            test_count = test_count + 1;
            if (wb_data === (32'h10000000 + i)) begin
                $display("[PASS] Test %0d: Sequential ALU [%0d] = 0x%h",
                         test_count, i, wb_data);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] Test %0d: Sequential ALU [%0d]", test_count, i);
                fail_count = fail_count + 1;
            end

            // Memory operation
            mem_to_reg_wb = 1'b1;
            fp_op_wb = 1'b0;
            #10;

            test_count = test_count + 1;
            if (wb_data === (32'h20000000 + i)) begin
                $display("[PASS] Test %0d: Sequential MEM [%0d] = 0x%h",
                         test_count, i, wb_data);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] Test %0d: Sequential MEM [%0d]", test_count, i);
                fail_count = fail_count + 1;
            end

            // FPU operation
            mem_to_reg_wb = 1'b0;
            fp_op_wb = 1'b1;
            #10;

            test_count = test_count + 1;
            if (wb_data === (32'h30000000 + i)) begin
                $display("[PASS] Test %0d: Sequential FPU [%0d] = 0x%h",
                         test_count, i, wb_data);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] Test %0d: Sequential FPU [%0d]", test_count, i);
                fail_count = fail_count + 1;
            end
        end

        // ====================================================================
        // Test Summary
        // ====================================================================
        #10;
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

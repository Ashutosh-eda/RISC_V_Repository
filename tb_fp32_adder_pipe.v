// ============================================================================
// Testbench for IEEE 754 Single-Precision FP Adder (4-Stage Pipeline)
// Tests floating-point addition and subtraction with special cases
// Pipeline latency: 4 cycles
// Self-checking with comprehensive test cases
// ============================================================================

`timescale 1ns / 1ps

module tb_fp32_adder_pipe;

    // ========================================================================
    // Clock and Reset
    // ========================================================================

    reg clk;
    reg rst_n;

    // ========================================================================
    // DUT Signals
    // ========================================================================

    reg  [31:0] x, y;
    reg         sub;
    reg  [2:0]  rm;

    wire [31:0] sum;
    wire [4:0]  flags;  // {NV, DZ, OF, UF, NX}

    // ========================================================================
    // DUT Instantiation
    // ========================================================================

    fp32_adder_pipe dut (
        .clk(clk),
        .rst_n(rst_n),
        .x(x),
        .y(y),
        .sub(sub),
        .rm(rm),
        .sum(sum),
        .flags(flags)
    );

    // ========================================================================
    // Clock Generation
    // ========================================================================

    initial clk = 0;
    always #5 clk = ~clk;  // 10ns period

    // ========================================================================
    // Test Infrastructure
    // ========================================================================

    integer test_count = 0;
    integer pass_count = 0;
    integer fail_count = 0;

    // Pipeline queue (4-cycle latency)
    reg [31:0] expected_queue [0:15];
    reg [200:0] description_queue [0:15];
    integer queue_head = 0;
    integer queue_tail = 0;
    integer pending_tests = 0;

    // Rounding modes
    localparam RNE = 3'b000;  // Round to Nearest, ties to Even
    localparam RTZ = 3'b001;  // Round Toward Zero
    localparam RDN = 3'b010;  // Round Down
    localparam RUP = 3'b011;  // Round Up
    localparam RMM = 3'b100;  // Round to Max Magnitude

    // IEEE 754 Constants
    localparam POS_ZERO = 32'h00000000;
    localparam NEG_ZERO = 32'h80000000;
    localparam POS_INF  = 32'h7F800000;
    localparam NEG_INF  = 32'hFF800000;
    localparam QNAN     = 32'h7FC00000;

    // ========================================================================
    // Helper Functions
    // ========================================================================

    function [31:0] real_to_fp32;
        input real value;
        begin
            real_to_fp32 = $shortrealtobits(value);
        end
    endfunction

    function real fp32_to_real;
        input [31:0] fp;
        begin
            fp32_to_real = $bitstoreal(fp);
        end
    endfunction

    function is_nan;
        input [31:0] fp;
        begin
            is_nan = (fp[30:23] == 8'hFF) && (fp[22:0] != 23'd0);
        end
    endfunction

    function is_close;
        input [31:0] a, b;
        input real tolerance;
        real diff;
        begin
            if (is_nan(a) && is_nan(b))
                is_close = 1;
            else if (a == b)
                is_close = 1;
            else begin
                diff = fp32_to_real(a) - fp32_to_real(b);
                if (diff < 0) diff = -diff;
                is_close = (diff < tolerance);
            end
        end
    endfunction

    // ========================================================================
    // Test Task
    // ========================================================================

    task test_fp_op;
        input [31:0] test_x, test_y;
        input        test_sub;
        input [2:0]  test_rm;
        input [31:0] expected;
        input [200:0] description;

        begin
            // Enqueue test
            expected_queue[queue_tail] = expected;
            description_queue[queue_tail] = description;
            queue_tail = (queue_tail + 1) % 16;
            pending_tests = pending_tests + 1;

            // Apply inputs
            x = test_x;
            y = test_y;
            sub = test_sub;
            rm = test_rm;

            @(posedge clk);
        end
    endtask

    // ========================================================================
    // Result Checker (runs every cycle)
    // ========================================================================

    always @(posedge clk) begin
        if (rst_n && pending_tests > 0) begin
            // Wait for pipeline latency (4 cycles)
            if (test_count >= 4) begin
                test_count = test_count + 1;

                if (is_close(sum, expected_queue[queue_head], 1e-5)) begin
                    $display("[PASS] Test %0d: %s", test_count - 4, description_queue[queue_head]);
                    $display("       Result: %h (%.6f)", sum, fp32_to_real(sum));
                    pass_count = pass_count + 1;
                end else begin
                    $display("[FAIL] Test %0d: %s", test_count - 4, description_queue[queue_head]);
                    $display("       Expected: %h (%.6f)", expected_queue[queue_head],
                             fp32_to_real(expected_queue[queue_head]));
                    $display("       Got:      %h (%.6f)", sum, fp32_to_real(sum));
                    fail_count = fail_count + 1;
                end

                queue_head = (queue_head + 1) % 16;
                pending_tests = pending_tests - 1;
            end else begin
                test_count = test_count + 1;
            end
        end
    end

    // ========================================================================
    // Test Stimulus
    // ========================================================================

    initial begin
        $display("\n========================================");
        $display("FP32 Pipelined Adder Testbench");
        $display("========================================\n");

        // Initialize
        rst_n = 0;
        x = 32'd0;
        y = 32'd0;
        sub = 1'b0;
        rm = RNE;

        repeat(3) @(posedge clk);
        rst_n = 1;
        @(posedge clk);

        // ====================================================================
        // Test Category 1: Simple Addition
        // ====================================================================
        $display("\n--- Test Category 1: Simple Addition ---");

        test_fp_op(
            real_to_fp32(1.0), real_to_fp32(1.0),
            1'b0, RNE,
            real_to_fp32(2.0),
            "Addition: 1.0 + 1.0 = 2.0"
        );

        test_fp_op(
            real_to_fp32(2.5), real_to_fp32(3.5),
            1'b0, RNE,
            real_to_fp32(6.0),
            "Addition: 2.5 + 3.5 = 6.0"
        );

        test_fp_op(
            real_to_fp32(0.5), real_to_fp32(0.25),
            1'b0, RNE,
            real_to_fp32(0.75),
            "Addition: 0.5 + 0.25 = 0.75"
        );

        // ====================================================================
        // Test Category 2: Simple Subtraction
        // ====================================================================
        $display("\n--- Test Category 2: Simple Subtraction ---");

        test_fp_op(
            real_to_fp32(5.0), real_to_fp32(3.0),
            1'b1, RNE,
            real_to_fp32(2.0),
            "Subtraction: 5.0 - 3.0 = 2.0"
        );

        test_fp_op(
            real_to_fp32(10.0), real_to_fp32(2.5),
            1'b1, RNE,
            real_to_fp32(7.5),
            "Subtraction: 10.0 - 2.5 = 7.5"
        );

        test_fp_op(
            real_to_fp32(1.0), real_to_fp32(1.0),
            1'b1, RNE,
            POS_ZERO,
            "Subtraction: 1.0 - 1.0 = 0.0"
        );

        // ====================================================================
        // Test Category 3: Negative Operands
        // ====================================================================
        $display("\n--- Test Category 3: Negative Operands ---");

        test_fp_op(
            real_to_fp32(-2.0), real_to_fp32(-3.0),
            1'b0, RNE,
            real_to_fp32(-5.0),
            "Addition: -2.0 + (-3.0) = -5.0"
        );

        test_fp_op(
            real_to_fp32(-5.0), real_to_fp32(3.0),
            1'b0, RNE,
            real_to_fp32(-2.0),
            "Addition: -5.0 + 3.0 = -2.0"
        );

        test_fp_op(
            real_to_fp32(5.0), real_to_fp32(-3.0),
            1'b0, RNE,
            real_to_fp32(2.0),
            "Addition: 5.0 + (-3.0) = 2.0"
        );

        test_fp_op(
            real_to_fp32(-5.0), real_to_fp32(-3.0),
            1'b1, RNE,
            real_to_fp32(-2.0),
            "Subtraction: -5.0 - (-3.0) = -2.0"
        );

        // ====================================================================
        // Test Category 4: Special Values - Zero
        // ====================================================================
        $display("\n--- Test Category 4: Special Values - Zero ---");

        test_fp_op(
            POS_ZERO, POS_ZERO,
            1'b0, RNE,
            POS_ZERO,
            "Zero: +0 + (+0) = +0"
        );

        test_fp_op(
            POS_ZERO, NEG_ZERO,
            1'b0, RNE,
            POS_ZERO,
            "Zero: +0 + (-0) = +0"
        );

        test_fp_op(
            real_to_fp32(5.0), POS_ZERO,
            1'b0, RNE,
            real_to_fp32(5.0),
            "Zero: 5.0 + 0 = 5.0"
        );

        test_fp_op(
            POS_ZERO, real_to_fp32(3.5),
            1'b0, RNE,
            real_to_fp32(3.5),
            "Zero: 0 + 3.5 = 3.5"
        );

        // ====================================================================
        // Test Category 5: Special Values - Infinity
        // ====================================================================
        $display("\n--- Test Category 5: Special Values - Infinity ---");

        test_fp_op(
            POS_INF, real_to_fp32(5.0),
            1'b0, RNE,
            POS_INF,
            "Infinity: +Inf + 5.0 = +Inf"
        );

        test_fp_op(
            NEG_INF, real_to_fp32(5.0),
            1'b0, RNE,
            NEG_INF,
            "Infinity: -Inf + 5.0 = -Inf"
        );

        test_fp_op(
            POS_INF, POS_INF,
            1'b0, RNE,
            POS_INF,
            "Infinity: +Inf + (+Inf) = +Inf"
        );

        test_fp_op(
            POS_INF, NEG_INF,
            1'b0, RNE,
            QNAN,
            "Infinity: +Inf + (-Inf) = NaN"
        );

        test_fp_op(
            POS_INF, POS_INF,
            1'b1, RNE,
            QNAN,
            "Infinity: +Inf - (+Inf) = NaN"
        );

        // ====================================================================
        // Test Category 6: Special Values - NaN
        // ====================================================================
        $display("\n--- Test Category 6: Special Values - NaN ---");

        test_fp_op(
            QNAN, real_to_fp32(5.0),
            1'b0, RNE,
            QNAN,
            "NaN: NaN + 5.0 = NaN"
        );

        test_fp_op(
            real_to_fp32(5.0), QNAN,
            1'b0, RNE,
            QNAN,
            "NaN: 5.0 + NaN = NaN"
        );

        test_fp_op(
            QNAN, QNAN,
            1'b0, RNE,
            QNAN,
            "NaN: NaN + NaN = NaN"
        );

        // ====================================================================
        // Test Category 7: Large and Small Numbers
        // ====================================================================
        $display("\n--- Test Category 7: Large and Small Numbers ---");

        test_fp_op(
            real_to_fp32(1e20), real_to_fp32(1e20),
            1'b0, RNE,
            real_to_fp32(2e20),
            "Large: 1e20 + 1e20 = 2e20"
        );

        test_fp_op(
            real_to_fp32(1e-20), real_to_fp32(1e-20),
            1'b0, RNE,
            real_to_fp32(2e-20),
            "Small: 1e-20 + 1e-20 = 2e-20"
        );

        test_fp_op(
            real_to_fp32(1e30), real_to_fp32(1e-30),
            1'b0, RNE,
            real_to_fp32(1e30),
            "Mixed: 1e30 + 1e-30 ≈ 1e30"
        );

        // ====================================================================
        // Test Category 8: Cancellation
        // ====================================================================
        $display("\n--- Test Category 8: Cancellation ---");

        test_fp_op(
            real_to_fp32(1.000001), real_to_fp32(-1.0),
            1'b0, RNE,
            real_to_fp32(0.000001),
            "Cancellation: 1.000001 - 1.0"
        );

        test_fp_op(
            real_to_fp32(100.5), real_to_fp32(100.0),
            1'b1, RNE,
            real_to_fp32(0.5),
            "Cancellation: 100.5 - 100.0 = 0.5"
        );

        // ====================================================================
        // Test Category 9: Rounding Modes
        // ====================================================================
        $display("\n--- Test Category 9: Rounding Modes ---");

        // RNE (default tested above)
        test_fp_op(
            real_to_fp32(1.5), real_to_fp32(0.5),
            1'b0, RNE,
            real_to_fp32(2.0),
            "RNE: 1.5 + 0.5 = 2.0"
        );

        // RTZ (toward zero)
        test_fp_op(
            real_to_fp32(1.5), real_to_fp32(0.5),
            1'b0, RTZ,
            real_to_fp32(2.0),
            "RTZ: 1.5 + 0.5 = 2.0"
        );

        // RDN (toward -inf)
        test_fp_op(
            real_to_fp32(1.5), real_to_fp32(0.5),
            1'b0, RDN,
            real_to_fp32(2.0),
            "RDN: 1.5 + 0.5 = 2.0"
        );

        // RUP (toward +inf)
        test_fp_op(
            real_to_fp32(1.5), real_to_fp32(0.5),
            1'b0, RUP,
            real_to_fp32(2.0),
            "RUP: 1.5 + 0.5 = 2.0"
        );

        // ====================================================================
        // Test Category 10: Stress Tests
        // ====================================================================
        $display("\n--- Test Category 10: Stress Tests ---");

        test_fp_op(
            32'h7F7FFFFF, 32'h7F7FFFFF,  // Max normal + Max normal
            1'b0, RNE,
            POS_INF,
            "Overflow: Max + Max = +Inf"
        );

        test_fp_op(
            32'h00800000, 32'h00800001,  // Min normal + near min
            1'b1, RNE,
            32'h00000001,  // Result near zero
            "Underflow: MinNorm - MinNorm ≈ 0"
        );

        // Wait for pipeline to drain
        repeat(5) @(posedge clk);

        // ====================================================================
        // Test Summary
        // ====================================================================
        $display("\n========================================");
        $display("Test Summary");
        $display("========================================");
        $display("Total Tests: %0d", pass_count + fail_count);
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

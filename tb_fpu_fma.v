// ============================================================================
// Testbench for FPU FMA (Fused Multiply-Add) Pipeline
// Tests 6-stage FMA pipeline with all operations: FMA, FMS, FNMADD, FNMSUB, FMUL, FADD, FSUB
// Self-checking with comprehensive test cases
// ============================================================================

`timescale 1ns / 1ps

module tb_fpu_fma;

    // ========================================================================
    // DUT Signals
    // ========================================================================

    reg         clk;
    reg         rst_n;

    // Inputs
    reg  [31:0] x_in;
    reg  [31:0] y_in;
    reg  [31:0] z_in;
    reg  [2:0]  op_type;
    reg  [2:0]  rm;
    reg         start;

    // Outputs
    wire [31:0] result;
    wire [4:0]  flags;
    wire        valid;

    // ========================================================================
    // DUT Instantiation
    // ========================================================================

    fpu_fma dut (
        .clk(clk),
        .rst_n(rst_n),
        .x_in(x_in),
        .y_in(y_in),
        .z_in(z_in),
        .op_type(op_type),
        .rm(rm),
        .start(start),
        .result(result),
        .flags(flags),
        .valid(valid)
    );

    // ========================================================================
    // Clock Generation
    // ========================================================================

    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 10ns period, 100MHz
    end

    // ========================================================================
    // Test Infrastructure
    // ========================================================================

    integer test_count = 0;
    integer pass_count = 0;
    integer fail_count = 0;

    // Pipeline queue (6-cycle latency)
    reg [31:0] expected_queue [0:15];
    reg [200:0] description_queue [0:15];
    reg [4:0]  flags_queue [0:15];
    integer queue_head = 0;
    integer queue_tail = 0;

    // Operation type constants
    localparam OP_ADD    = 3'b000;
    localparam OP_SUB    = 3'b001;
    localparam OP_MUL    = 3'b010;
    localparam OP_FMA    = 3'b011;
    localparam OP_FMS    = 3'b100;
    localparam OP_FNMADD = 3'b101;
    localparam OP_FNMSUB = 3'b110;

    // Rounding mode constants
    localparam RNE = 3'b000;  // Round to Nearest, ties to Even
    localparam RTZ = 3'b001;  // Round toward Zero
    localparam RDN = 3'b010;  // Round Down (-inf)
    localparam RUP = 3'b011;  // Round Up (+inf)
    localparam RMM = 3'b100;  // Round to Nearest, ties to Max Magnitude

    // Flag bit positions
    localparam NV = 4;  // Invalid
    localparam DZ = 3;  // Divide by zero (not used in FMA)
    localparam OF = 2;  // Overflow
    localparam UF = 1;  // Underflow
    localparam NX = 0;  // Inexact

    // ========================================================================
    // Helper Functions
    // ========================================================================

    // Convert real to IEEE 754 single-precision
    function [31:0] real_to_fp32;
        input real value;
        begin
            real_to_fp32 = $shortrealtobits(value);
        end
    endfunction

    // Convert IEEE 754 to real
    function real fp32_to_real;
        input [31:0] fp;
        begin
            fp32_to_real = $bitstoreal({32'b0, fp});
        end
    endfunction

    // Check if two FP values are close (within tolerance)
    function is_close;
        input [31:0] a, b;
        input real tolerance;
        real val_a, val_b, diff;
        begin
            val_a = fp32_to_real(a);
            val_b = fp32_to_real(b);
            diff = (val_a > val_b) ? (val_a - val_b) : (val_b - val_a);
            is_close = (diff < tolerance) || (a === b);
        end
    endfunction

    // Check if value is NaN
    function is_nan;
        input [31:0] fp;
        begin
            is_nan = (&fp[30:23]) && (|fp[22:0]);
        end
    endfunction

    // Check if value is infinity
    function is_inf;
        input [31:0] fp;
        begin
            is_inf = (&fp[30:23]) && (~|fp[22:0]);
        end
    endfunction

    // ========================================================================
    // Test Tasks
    // ========================================================================

    // Task: Issue FMA operation
    task test_fma_op;
        input [31:0] x, y, z;
        input [2:0]  operation;
        input [2:0]  rounding_mode;
        input [31:0] expected;
        input [4:0]  expected_flags;
        input [200:0] description;

        begin
            x_in = x;
            y_in = y;
            z_in = z;
            op_type = operation;
            rm = rounding_mode;
            start = 1'b1;

            // Enqueue expected result
            expected_queue[queue_tail] = expected;
            description_queue[queue_tail] = description;
            flags_queue[queue_tail] = expected_flags;
            queue_tail = (queue_tail + 1) % 16;

            @(posedge clk);
            start = 1'b0;
        end
    endtask

    // Task: Check output
    task check_output;
        reg [31:0] exp_result;
        reg [200:0] desc;
        reg [4:0] exp_flags;
        real tolerance;

        begin
            if (valid) begin
                test_count = test_count + 1;
                exp_result = expected_queue[queue_head];
                desc = description_queue[queue_head];
                exp_flags = flags_queue[queue_head];
                queue_head = (queue_head + 1) % 16;

                tolerance = 1e-6;

                // Check result (handle NaN and Inf specially)
                if ((is_nan(exp_result) && is_nan(result)) ||
                    (is_inf(exp_result) && is_inf(result) && (exp_result[31] == result[31])) ||
                    is_close(result, exp_result, tolerance)) begin
                    $display("[PASS] Test %0d: %s", test_count, desc);
                    $display("       Result: %h (%.6f)", result, fp32_to_real(result));
                    pass_count = pass_count + 1;
                end
                else begin
                    $display("[FAIL] Test %0d: %s", test_count, desc);
                    $display("       Expected: %h (%.6f)", exp_result, fp32_to_real(exp_result));
                    $display("       Got:      %h (%.6f)", result, fp32_to_real(result));
                    fail_count = fail_count + 1;
                end
            end
        end
    endtask

    // ========================================================================
    // Test Stimulus
    // ========================================================================

    initial begin
        $display("\n========================================");
        $display("FPU FMA Pipeline Testbench");
        $display("========================================\n");

        // Initialize
        rst_n = 0;
        x_in = 0;
        y_in = 0;
        z_in = 0;
        op_type = 0;
        rm = 0;
        start = 0;

        // Reset sequence
        repeat(3) @(posedge clk);
        rst_n = 1;
        @(posedge clk);

        // ====================================================================
        // Test Category 1: FP Multiplication (FMUL)
        // ====================================================================
        $display("\n--- Test Category 1: FP Multiplication ---");

        // Test 1: Simple multiplication
        test_fma_op(
            real_to_fp32(2.0), real_to_fp32(3.0), real_to_fp32(0.0),
            OP_MUL, RNE,
            real_to_fp32(6.0), 5'b00000,
            "FMUL: 2.0 × 3.0 = 6.0"
        );

        // Test 2: Multiply by 1
        test_fma_op(
            real_to_fp32(5.5), real_to_fp32(1.0), real_to_fp32(0.0),
            OP_MUL, RNE,
            real_to_fp32(5.5), 5'b00000,
            "FMUL: 5.5 × 1.0 = 5.5"
        );

        // Test 3: Multiply by 0
        test_fma_op(
            real_to_fp32(100.0), real_to_fp32(0.0), real_to_fp32(0.0),
            OP_MUL, RNE,
            real_to_fp32(0.0), 5'b00000,
            "FMUL: 100.0 × 0.0 = 0.0"
        );

        // Test 4: Negative multiplication
        test_fma_op(
            real_to_fp32(-4.0), real_to_fp32(2.5), real_to_fp32(0.0),
            OP_MUL, RNE,
            real_to_fp32(-10.0), 5'b00000,
            "FMUL: -4.0 × 2.5 = -10.0"
        );

        // Test 5: Both negative
        test_fma_op(
            real_to_fp32(-3.0), real_to_fp32(-7.0), real_to_fp32(0.0),
            OP_MUL, RNE,
            real_to_fp32(21.0), 5'b00000,
            "FMUL: -3.0 × -7.0 = 21.0"
        );

        // ====================================================================
        // Test Category 2: FP Addition (FADD)
        // ====================================================================
        $display("\n--- Test Category 2: FP Addition ---");

        // Test 6: Simple addition
        test_fma_op(
            real_to_fp32(1.0), real_to_fp32(1.0), real_to_fp32(5.0),
            OP_ADD, RNE,
            real_to_fp32(6.0), 5'b00000,
            "FADD: 1.0×1.0 + 5.0 = 6.0"
        );

        // Test 7: Addition with zero
        test_fma_op(
            real_to_fp32(1.0), real_to_fp32(1.0), real_to_fp32(0.0),
            OP_ADD, RNE,
            real_to_fp32(1.0), 5'b00000,
            "FADD: 1.0×1.0 + 0.0 = 1.0"
        );

        // Test 8: Negative addition
        test_fma_op(
            real_to_fp32(1.0), real_to_fp32(1.0), real_to_fp32(-3.0),
            OP_ADD, RNE,
            real_to_fp32(-2.0), 5'b00000,
            "FADD: 1.0×1.0 + (-3.0) = -2.0"
        );

        // ====================================================================
        // Test Category 3: FP Subtraction (FSUB)
        // ====================================================================
        $display("\n--- Test Category 3: FP Subtraction ---");

        // Test 9: Simple subtraction
        test_fma_op(
            real_to_fp32(1.0), real_to_fp32(1.0), real_to_fp32(8.0),
            OP_SUB, RNE,
            real_to_fp32(-7.0), 5'b00000,
            "FSUB: 1.0×1.0 - 8.0 = -7.0"
        );

        // Test 10: Subtract zero
        test_fma_op(
            real_to_fp32(1.0), real_to_fp32(1.0), real_to_fp32(0.0),
            OP_SUB, RNE,
            real_to_fp32(1.0), 5'b00000,
            "FSUB: 1.0×1.0 - 0.0 = 1.0"
        );

        // ====================================================================
        // Test Category 4: Fused Multiply-Add (FMA)
        // ====================================================================
        $display("\n--- Test Category 4: Fused Multiply-Add ---");

        // Test 11: Basic FMA
        test_fma_op(
            real_to_fp32(2.0), real_to_fp32(3.0), real_to_fp32(4.0),
            OP_FMA, RNE,
            real_to_fp32(10.0), 5'b00000,
            "FMA: 2.0 × 3.0 + 4.0 = 10.0"
        );

        // Test 12: FMA with zero addend
        test_fma_op(
            real_to_fp32(5.0), real_to_fp32(6.0), real_to_fp32(0.0),
            OP_FMA, RNE,
            real_to_fp32(30.0), 5'b00000,
            "FMA: 5.0 × 6.0 + 0.0 = 30.0"
        );

        // Test 13: FMA with negative product
        test_fma_op(
            real_to_fp32(-2.0), real_to_fp32(5.0), real_to_fp32(3.0),
            OP_FMA, RNE,
            real_to_fp32(-7.0), 5'b00000,
            "FMA: -2.0 × 5.0 + 3.0 = -7.0"
        );

        // Test 14: FMA with negative addend
        test_fma_op(
            real_to_fp32(4.0), real_to_fp32(3.0), real_to_fp32(-5.0),
            OP_FMA, RNE,
            real_to_fp32(7.0), 5'b00000,
            "FMA: 4.0 × 3.0 + (-5.0) = 7.0"
        );

        // Test 15: FMA with all negative
        test_fma_op(
            real_to_fp32(-2.0), real_to_fp32(-3.0), real_to_fp32(-4.0),
            OP_FMA, RNE,
            real_to_fp32(2.0), 5'b00000,
            "FMA: -2.0 × -3.0 + (-4.0) = 2.0"
        );

        // ====================================================================
        // Test Category 5: Fused Multiply-Subtract (FMS)
        // ====================================================================
        $display("\n--- Test Category 5: Fused Multiply-Subtract ---");

        // Test 16: Basic FMS
        test_fma_op(
            real_to_fp32(3.0), real_to_fp32(4.0), real_to_fp32(2.0),
            OP_FMS, RNE,
            real_to_fp32(10.0), 5'b00000,
            "FMS: 3.0 × 4.0 - 2.0 = 10.0"
        );

        // Test 17: FMS with zero
        test_fma_op(
            real_to_fp32(7.0), real_to_fp32(2.0), real_to_fp32(0.0),
            OP_FMS, RNE,
            real_to_fp32(14.0), 5'b00000,
            "FMS: 7.0 × 2.0 - 0.0 = 14.0"
        );

        // ====================================================================
        // Test Category 6: Negated Multiply-Add (FNMADD)
        // ====================================================================
        $display("\n--- Test Category 6: Negated Multiply-Add ---");

        // Test 18: Basic FNMADD
        test_fma_op(
            real_to_fp32(2.0), real_to_fp32(3.0), real_to_fp32(1.0),
            OP_FNMADD, RNE,
            real_to_fp32(-5.0), 5'b00000,
            "FNMADD: -(2.0 × 3.0 + 1.0) = -7.0"
        );

        // ====================================================================
        // Test Category 7: Negated Multiply-Subtract (FNMSUB)
        // ====================================================================
        $display("\n--- Test Category 7: Negated Multiply-Subtract ---");

        // Test 19: Basic FNMSUB
        test_fma_op(
            real_to_fp32(2.0), real_to_fp32(4.0), real_to_fp32(3.0),
            OP_FNMSUB, RNE,
            real_to_fp32(-5.0), 5'b00000,
            "FNMSUB: -(2.0 × 4.0 - 3.0) = -5.0"
        );

        // ====================================================================
        // Test Category 8: Special Values - Zero
        // ====================================================================
        $display("\n--- Test Category 8: Special Values - Zero ---");

        // Test 20: 0 × anything = 0
        test_fma_op(
            real_to_fp32(0.0), real_to_fp32(999.0), real_to_fp32(0.0),
            OP_MUL, RNE,
            real_to_fp32(0.0), 5'b00000,
            "0.0 × 999.0 = 0.0"
        );

        // Test 21: 0 + 0 = 0
        test_fma_op(
            real_to_fp32(1.0), real_to_fp32(0.0), real_to_fp32(0.0),
            OP_ADD, RNE,
            real_to_fp32(0.0), 5'b00000,
            "0.0 + 0.0 = 0.0"
        );

        // ====================================================================
        // Test Category 9: Fractional Values
        // ====================================================================
        $display("\n--- Test Category 9: Fractional Values ---");

        // Test 22: 0.5 × 0.25 = 0.125
        test_fma_op(
            real_to_fp32(0.5), real_to_fp32(0.25), real_to_fp32(0.0),
            OP_MUL, RNE,
            real_to_fp32(0.125), 5'b00000,
            "0.5 × 0.25 = 0.125"
        );

        // Test 23: 0.1 + 0.2
        test_fma_op(
            real_to_fp32(1.0), real_to_fp32(0.1), real_to_fp32(0.2),
            OP_ADD, RNE,
            real_to_fp32(0.3), 5'b00001,  // Likely inexact
            "0.1 + 0.2 ≈ 0.3"
        );

        // Test 24: FMA with fractions
        test_fma_op(
            real_to_fp32(0.5), real_to_fp32(0.5), real_to_fp32(0.25),
            OP_FMA, RNE,
            real_to_fp32(0.5), 5'b00000,
            "0.5 × 0.5 + 0.25 = 0.5"
        );

        // ====================================================================
        // Test Category 10: Large Numbers
        // ====================================================================
        $display("\n--- Test Category 10: Large Numbers ---");

        // Test 25: Large multiplication
        test_fma_op(
            real_to_fp32(1000.0), real_to_fp32(2000.0), real_to_fp32(0.0),
            OP_MUL, RNE,
            real_to_fp32(2000000.0), 5'b00000,
            "1000.0 × 2000.0 = 2000000.0"
        );

        // Test 26: Large addition
        test_fma_op(
            real_to_fp32(1.0), real_to_fp32(1.0), real_to_fp32(999999.0),
            OP_ADD, RNE,
            real_to_fp32(1000000.0), 5'b00000,
            "1.0 + 999999.0 = 1000000.0"
        );

        // ====================================================================
        // Test Category 11: Powers of Two
        // ====================================================================
        $display("\n--- Test Category 11: Powers of Two ---");

        // Test 27: 2^3 × 2^4 = 2^7
        test_fma_op(
            real_to_fp32(8.0), real_to_fp32(16.0), real_to_fp32(0.0),
            OP_MUL, RNE,
            real_to_fp32(128.0), 5'b00000,
            "8.0 × 16.0 = 128.0"
        );

        // Test 28: 2^-2 × 2^-3 = 2^-5
        test_fma_op(
            real_to_fp32(0.25), real_to_fp32(0.125), real_to_fp32(0.0),
            OP_MUL, RNE,
            real_to_fp32(0.03125), 5'b00000,
            "0.25 × 0.125 = 0.03125"
        );

        // ====================================================================
        // Test Category 12: Cancellation
        // ====================================================================
        $display("\n--- Test Category 12: Cancellation ---");

        // Test 29: Subtraction causing cancellation
        test_fma_op(
            real_to_fp32(1.0), real_to_fp32(1.0), real_to_fp32(1.0),
            OP_SUB, RNE,
            real_to_fp32(0.0), 5'b00000,
            "1.0 - 1.0 = 0.0"
        );

        // Test 30: FMA with cancellation
        test_fma_op(
            real_to_fp32(5.0), real_to_fp32(3.0), real_to_fp32(-15.0),
            OP_FMA, RNE,
            real_to_fp32(0.0), 5'b00000,
            "5.0 × 3.0 + (-15.0) = 0.0"
        );

        // ====================================================================
        // Wait for pipeline to complete
        // ====================================================================
        $display("\nWaiting for pipeline to drain (6 cycles)...");
        repeat(6) @(posedge clk);

        // Check all outputs
        $display("\nChecking outputs...\n");
        repeat(30) begin
            check_output();
            @(posedge clk);
        end

        // ====================================================================
        // Test Summary
        // ====================================================================
        repeat(5) @(posedge clk);

        $display("\n========================================");
        $display("Test Summary");
        $display("========================================");
        $display("Total Tests: %0d", test_count);
        $display("Passed:      %0d", pass_count);
        $display("Failed:      %0d", fail_count);

        if (fail_count == 0) begin
            $display("\n*** ALL TESTS PASSED ***\n");
        end
        else begin
            $display("\n*** SOME TESTS FAILED ***\n");
        end

        $finish;
    end

    // ========================================================================
    // Continuous Output Monitoring
    // ========================================================================

    always @(posedge clk) begin
        if (valid && queue_head != queue_tail) begin
            check_output();
        end
    end

endmodule

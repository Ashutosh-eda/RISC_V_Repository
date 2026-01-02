// ============================================================================
// Testbench for FPU Exception Flags Generator
// Tests IEEE 754 exception flag generation
// Covers: NV (Invalid), DZ (Divide by Zero), OF (Overflow), UF (Underflow), NX (Inexact)
// Tests all special case combinations and operation types
// Self-checking with comprehensive test cases
// ============================================================================

`timescale 1ns / 1ps

module tb_fpu_exception_flags;

    // ========================================================================
    // DUT Signals
    // ========================================================================

    reg        result_overflow;
    reg        result_underflow;
    reg        result_inexact;
    reg        result_invalid;
    reg        x_nan, y_nan, z_nan;
    reg        x_snan, y_snan, z_snan;
    reg        x_inf, y_inf, z_inf;
    reg        x_zero, y_zero, z_zero;
    reg  [2:0] op_type;

    wire [4:0] flags;

    // ========================================================================
    // DUT Instantiation
    // ========================================================================

    fpu_exception_flags dut (
        .result_overflow(result_overflow),
        .result_underflow(result_underflow),
        .result_inexact(result_inexact),
        .result_invalid(result_invalid),
        .x_nan(x_nan),
        .y_nan(y_nan),
        .z_nan(z_nan),
        .x_snan(x_snan),
        .y_snan(y_snan),
        .z_snan(z_snan),
        .x_inf(x_inf),
        .y_inf(y_inf),
        .z_inf(z_inf),
        .x_zero(x_zero),
        .y_zero(y_zero),
        .z_zero(z_zero),
        .op_type(op_type),
        .flags(flags)
    );

    // ========================================================================
    // Operation Types
    // ========================================================================

    localparam OP_ADD = 3'b000;
    localparam OP_SUB = 3'b001;
    localparam OP_MUL = 3'b010;
    localparam OP_FMA = 3'b011;
    localparam OP_FMS = 3'b100;

    // ========================================================================
    // Flag Bit Positions
    // ========================================================================

    localparam NV = 4;  // Invalid Operation
    localparam DZ = 3;  // Divide by Zero (unused)
    localparam OF = 2;  // Overflow
    localparam UF = 1;  // Underflow
    localparam NX = 0;  // Inexact

    // ========================================================================
    // Test Infrastructure
    // ========================================================================

    integer test_count = 0;
    integer pass_count = 0;
    integer fail_count = 0;

    // ========================================================================
    // Test Task
    // ========================================================================

    task check_flags;
        input [4:0] exp_flags;
        input [200:0] description;
        begin
            test_count = test_count + 1;

            #10;

            if (flags === exp_flags) begin
                $display("[PASS] Test %0d: %s", test_count, description);
                $display("       Flags = %b (NV=%b DZ=%b OF=%b UF=%b NX=%b)",
                         flags, flags[NV], flags[DZ], flags[OF], flags[UF], flags[NX]);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] Test %0d: %s", test_count, description);
                $display("       Expected: %b (NV=%b DZ=%b OF=%b UF=%b NX=%b)",
                         exp_flags, exp_flags[NV], exp_flags[DZ], exp_flags[OF], exp_flags[UF], exp_flags[NX]);
                $display("       Got:      %b (NV=%b DZ=%b OF=%b UF=%b NX=%b)",
                         flags, flags[NV], flags[DZ], flags[OF], flags[UF], flags[NX]);
                fail_count = fail_count + 1;
            end
        end
    endtask

    task reset_inputs;
        begin
            result_overflow = 1'b0;
            result_underflow = 1'b0;
            result_inexact = 1'b0;
            result_invalid = 1'b0;
            x_nan = 1'b0;
            y_nan = 1'b0;
            z_nan = 1'b0;
            x_snan = 1'b0;
            y_snan = 1'b0;
            z_snan = 1'b0;
            x_inf = 1'b0;
            y_inf = 1'b0;
            z_inf = 1'b0;
            x_zero = 1'b0;
            y_zero = 1'b0;
            z_zero = 1'b0;
            op_type = OP_ADD;
        end
    endtask

    // ========================================================================
    // Test Stimulus
    // ========================================================================

    initial begin
        $display("\n========================================");
        $display("FPU Exception Flags Testbench");
        $display("========================================\n");

        reset_inputs();
        #20;

        // ====================================================================
        // Test Category 1: No Exceptions (Normal Operation)
        // ====================================================================
        $display("\n--- Test Category 1: No Exceptions ---");

        reset_inputs();
        check_flags(
            5'b00000,
            "Normal operation - no flags"
        );

        reset_inputs();
        op_type = OP_MUL;
        check_flags(
            5'b00000,
            "Multiplication - no flags"
        );

        reset_inputs();
        op_type = OP_FMA;
        check_flags(
            5'b00000,
            "FMA - no flags"
        );

        // ====================================================================
        // Test Category 2: Overflow Flag
        // ====================================================================
        $display("\n--- Test Category 2: Overflow (OF) ---");

        reset_inputs();
        result_overflow = 1'b1;
        check_flags(
            5'b00101,  // OF=1, NX=1 (inexact also set on overflow)
            "Overflow sets OF and NX"
        );

        reset_inputs();
        result_overflow = 1'b1;
        op_type = OP_MUL;
        check_flags(
            5'b00101,
            "Overflow in multiplication"
        );

        reset_inputs();
        result_overflow = 1'b1;
        result_inexact = 1'b1;
        check_flags(
            5'b00101,
            "Overflow with explicit inexact"
        );

        // ====================================================================
        // Test Category 3: Underflow Flag
        // ====================================================================
        $display("\n--- Test Category 3: Underflow (UF) ---");

        reset_inputs();
        result_underflow = 1'b1;
        check_flags(
            5'b00011,  // UF=1, NX=1 (inexact also set on underflow)
            "Underflow sets UF and NX"
        );

        reset_inputs();
        result_underflow = 1'b1;
        op_type = OP_SUB;
        check_flags(
            5'b00011,
            "Underflow in subtraction"
        );

        reset_inputs();
        result_underflow = 1'b1;
        result_inexact = 1'b1;
        check_flags(
            5'b00011,
            "Underflow with explicit inexact"
        );

        // ====================================================================
        // Test Category 4: Inexact Flag Only
        // ====================================================================
        $display("\n--- Test Category 4: Inexact (NX) Only ---");

        reset_inputs();
        result_inexact = 1'b1;
        check_flags(
            5'b00001,
            "Inexact only (rounding occurred)"
        );

        reset_inputs();
        result_inexact = 1'b1;
        op_type = OP_FMA;
        check_flags(
            5'b00001,
            "Inexact in FMA"
        );

        // ====================================================================
        // Test Category 5: Invalid Operation - Signaling NaN
        // ====================================================================
        $display("\n--- Test Category 5: Invalid (NV) - Signaling NaN ---");

        reset_inputs();
        x_snan = 1'b1;
        check_flags(
            5'b10000,
            "X is signaling NaN → NV"
        );

        reset_inputs();
        y_snan = 1'b1;
        check_flags(
            5'b10000,
            "Y is signaling NaN → NV"
        );

        reset_inputs();
        z_snan = 1'b1;
        op_type = OP_FMA;
        check_flags(
            5'b10000,
            "Z is signaling NaN in FMA → NV"
        );

        reset_inputs();
        x_snan = 1'b1;
        y_snan = 1'b1;
        check_flags(
            5'b10000,
            "Multiple signaling NaNs → NV"
        );

        // ====================================================================
        // Test Category 6: Invalid Operation - 0 × Inf
        // ====================================================================
        $display("\n--- Test Category 6: Invalid (NV) - 0 × Inf ---");

        reset_inputs();
        x_zero = 1'b1;
        y_inf = 1'b1;
        op_type = OP_MUL;
        check_flags(
            5'b10000,
            "MUL: 0 × Inf → NV"
        );

        reset_inputs();
        x_inf = 1'b1;
        y_zero = 1'b1;
        op_type = OP_MUL;
        check_flags(
            5'b10000,
            "MUL: Inf × 0 → NV"
        );

        reset_inputs();
        x_zero = 1'b1;
        y_inf = 1'b1;
        op_type = OP_FMA;
        check_flags(
            5'b10000,
            "FMA: 0 × Inf → NV"
        );

        reset_inputs();
        x_inf = 1'b1;
        y_zero = 1'b1;
        op_type = OP_FMS;
        check_flags(
            5'b10000,
            "FMS: Inf × 0 → NV"
        );

        // ====================================================================
        // Test Category 7: Invalid Operation - Inf - Inf
        // ====================================================================
        $display("\n--- Test Category 7: Invalid (NV) - Inf - Inf ---");

        reset_inputs();
        x_inf = 1'b1;
        y_inf = 1'b1;
        op_type = OP_ADD;
        check_flags(
            5'b10000,
            "ADD: Inf + Inf (same sign check) → NV"
        );

        reset_inputs();
        x_inf = 1'b1;
        y_inf = 1'b1;
        op_type = OP_SUB;
        check_flags(
            5'b10000,
            "SUB: Inf - Inf → NV"
        );

        // ====================================================================
        // Test Category 8: Multiple Flags Set
        // ====================================================================
        $display("\n--- Test Category 8: Multiple Flags ---");

        reset_inputs();
        result_overflow = 1'b1;
        result_inexact = 1'b1;
        check_flags(
            5'b00101,
            "OF + NX together"
        );

        reset_inputs();
        result_underflow = 1'b1;
        result_inexact = 1'b1;
        check_flags(
            5'b00011,
            "UF + NX together"
        );

        reset_inputs();
        x_snan = 1'b1;
        result_overflow = 1'b1;
        check_flags(
            5'b10101,
            "NV + OF + NX together"
        );

        reset_inputs();
        x_snan = 1'b1;
        result_underflow = 1'b1;
        check_flags(
            5'b10011,
            "NV + UF + NX together"
        );

        reset_inputs();
        result_invalid = 1'b1;
        result_overflow = 1'b1;
        result_underflow = 1'b1;
        result_inexact = 1'b1;
        check_flags(
            5'b10111,
            "All flags except DZ (NV + OF + UF + NX)"
        );

        // ====================================================================
        // Test Category 9: DZ Always Zero (No Division)
        // ====================================================================
        $display("\n--- Test Category 9: DZ Always Zero ---");

        reset_inputs();
        check_flags(
            5'b00000,
            "DZ bit always 0 (no division)"
        );

        reset_inputs();
        result_overflow = 1'b1;
        result_underflow = 1'b1;
        result_inexact = 1'b1;
        check_flags(
            5'b00111,
            "DZ=0 even with other flags"
        );

        // ====================================================================
        // Test Category 10: Quiet NaN (No Invalid)
        // ====================================================================
        $display("\n--- Test Category 10: Quiet NaN (No Invalid) ---");

        reset_inputs();
        x_nan = 1'b1;  // Quiet NaN
        check_flags(
            5'b00000,
            "Quiet NaN (x_nan=1, x_snan=0) → no NV"
        );

        reset_inputs();
        y_nan = 1'b1;
        check_flags(
            5'b00000,
            "Quiet NaN on Y → no NV"
        );

        reset_inputs();
        x_nan = 1'b1;
        y_nan = 1'b1;
        z_nan = 1'b1;
        check_flags(
            5'b00000,
            "All quiet NaNs → no NV"
        );

        // ====================================================================
        // Test Category 11: Operation Type Variations
        // ====================================================================
        $display("\n--- Test Category 11: Operation Type Variations ---");

        reset_inputs();
        x_zero = 1'b1;
        y_inf = 1'b1;
        op_type = OP_ADD;
        check_flags(
            5'b00000,
            "ADD: 0 + Inf → valid (no NV)"
        );

        reset_inputs();
        x_zero = 1'b1;
        y_inf = 1'b1;
        op_type = OP_MUL;
        check_flags(
            5'b10000,
            "MUL: 0 × Inf → NV"
        );

        reset_inputs();
        x_inf = 1'b1;
        y_inf = 1'b1;
        op_type = OP_MUL;
        check_flags(
            5'b00000,
            "MUL: Inf × Inf → valid (no NV)"
        );

        reset_inputs();
        x_zero = 1'b1;
        y_zero = 1'b1;
        op_type = OP_ADD;
        check_flags(
            5'b00000,
            "ADD: 0 + 0 → valid"
        );

        reset_inputs();
        x_zero = 1'b1;
        y_zero = 1'b1;
        op_type = OP_MUL;
        check_flags(
            5'b00000,
            "MUL: 0 × 0 → valid"
        );

        // ====================================================================
        // Test Category 12: Explicit result_invalid Flag
        // ====================================================================
        $display("\n--- Test Category 12: Explicit result_invalid ---");

        reset_inputs();
        result_invalid = 1'b1;
        check_flags(
            5'b10000,
            "Explicit result_invalid → NV"
        );

        reset_inputs();
        result_invalid = 1'b1;
        result_inexact = 1'b1;
        check_flags(
            5'b10001,
            "Explicit result_invalid + inexact"
        );

        // ====================================================================
        // Test Category 13: Realistic FP Scenarios
        // ====================================================================
        $display("\n--- Test Category 13: Realistic Scenarios ---");

        reset_inputs();
        result_inexact = 1'b1;
        op_type = OP_FMA;
        check_flags(
            5'b00001,
            "FMA with rounding (inexact)"
        );

        reset_inputs();
        result_overflow = 1'b1;
        op_type = OP_MUL;
        check_flags(
            5'b00101,
            "Multiplication overflow"
        );

        reset_inputs();
        result_underflow = 1'b1;
        op_type = OP_ADD;
        check_flags(
            5'b00011,
            "Addition underflow (close cancellation)"
        );

        reset_inputs();
        x_snan = 1'b1;
        result_overflow = 1'b1;
        op_type = OP_FMA;
        check_flags(
            5'b10101,
            "FMA: sNaN input causes NV + overflow"
        );

        // ====================================================================
        // Test Category 14: All Special Value Combinations
        // ====================================================================
        $display("\n--- Test Category 14: Special Value Combinations ---");

        reset_inputs();
        x_inf = 1'b1;
        y_zero = 1'b0;
        z_zero = 1'b1;
        op_type = OP_FMA;
        check_flags(
            5'b00000,
            "FMA: Inf × normal + 0 → valid"
        );

        reset_inputs();
        x_zero = 1'b0;
        y_inf = 1'b1;
        z_inf = 1'b1;
        op_type = OP_FMA;
        check_flags(
            5'b00000,
            "FMA: normal × Inf + Inf → valid"
        );

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

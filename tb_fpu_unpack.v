// ============================================================================
// Self-Checking Testbench for FPU Unpack Module
// Tests: IEEE 754 unpacking into sign, exponent, mantissa
// Coverage: Normal, Zero, Infinity, NaN, Subnormal numbers
// ============================================================================

`timescale 1ns / 1ps

module tb_fpu_unpack;

    // ========================================================================
    // Test Infrastructure
    // ========================================================================
    reg  [31:0] fp_in;
    wire        sign;
    wire [7:0]  exponent;
    wire [23:0] significand;
    wire        is_zero;
    wire        is_inf;
    wire        is_nan;
    wire        is_qnan;
    wire        is_snan;
    wire        is_subnormal;

    // Test statistics
    integer test_count = 0;
    integer pass_count = 0;
    integer fail_count = 0;

    // ========================================================================
    // DUT Instantiation
    // ========================================================================
    fpu_unpack uut (
        .ieee_in     (fp_in),
        .sign        (sign),
        .exponent    (exponent),
        .significand (significand),
        .is_zero     (is_zero),
        .is_inf      (is_inf),
        .is_nan      (is_nan),
        .is_qnan     (is_qnan),
        .is_snan     (is_snan),
        .is_subnormal(is_subnormal)
    );

    // ========================================================================
    // Test Tasks
    // ========================================================================

    // Check unpacking results
    task check_unpack;
        input [31:0] test_value;
        input        exp_sign;
        input [7:0]  exp_exponent;
        input [23:0] exp_significand;
        input        exp_zero;
        input        exp_inf;
        input        exp_nan;
        input        exp_qnan;
        input        exp_snan;
        input        exp_subnormal;
        input [200:0] description;

        begin
            test_count = test_count + 1;
            fp_in = test_value;
            #10; // Wait for combinational logic

            if (sign === exp_sign &&
                exponent === exp_exponent &&
                significand === exp_significand &&
                is_zero === exp_zero &&
                is_inf === exp_inf &&
                is_nan === exp_nan &&
                is_qnan === exp_qnan &&
                is_snan === exp_snan &&
                is_subnormal === exp_subnormal) begin

                $display("[PASS] Test %0d: %s", test_count, description);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] Test %0d: %s", test_count, description);
                $display("  Input:        0x%08h", test_value);
                $display("  Expected:     sign=%b exp=%03d(0x%02h) mant=0x%06h",
                         exp_sign, exp_exponent, exp_exponent, exp_significand);
                $display("  Got:          sign=%b exp=%03d(0x%02h) mant=0x%06h",
                         sign, exponent, exponent, significand);
                $display("  Flags Expected: Z=%b Inf=%b NaN=%b QNaN=%b SNaN=%b Sub=%b",
                         exp_zero, exp_inf, exp_nan, exp_qnan, exp_snan, exp_subnormal);
                $display("  Flags Got:      Z=%b Inf=%b NaN=%b QNaN=%b SNaN=%b Sub=%b",
                         is_zero, is_inf, is_nan, is_qnan, is_snan, is_subnormal);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // ========================================================================
    // Test Vectors
    // ========================================================================
    initial begin
        $display("========================================");
        $display("FPU Unpack Module Self-Checking Tests");
        $display("========================================\n");

        // --------------------------------------------------------------------
        // Category 1: Zero
        // --------------------------------------------------------------------
        $display("--- Testing ZERO ---");

        // Positive zero: 0x00000000 = +0.0
        // Sign=0, Exp=0, Mant=0 → Zero flag set
        check_unpack(
            32'h00000000,      // Input
            1'b0,              // sign
            8'd0,              // exponent
            24'h000000,        // significand
            1'b1,              // is_zero
            1'b0,              // is_inf
            1'b0,              // is_nan
            1'b0,              // is_qnan
            1'b0,              // is_snan
            1'b0,              // is_subnormal
            "Positive Zero (+0.0)"
        );

        // Negative zero: 0x80000000 = -0.0
        check_unpack(
            32'h80000000,
            1'b1,              // sign = 1
            8'd0,
            24'h000000,
            1'b1,              // is_zero
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
            "Negative Zero (-0.0)"
        );

        // --------------------------------------------------------------------
        // Category 2: Normal Numbers
        // --------------------------------------------------------------------
        $display("\n--- Testing NORMAL NUMBERS ---");

        // 1.0 = 0x3F800000
        // Sign=0, Exp=127 (0x7F), Mant=1.0 (implicit 1 + 0x000000)
        check_unpack(
            32'h3F800000,
            1'b0,              // sign
            8'd127,            // exponent (biased)
            24'h800000,        // significand (1.0 with implicit bit)
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
            "1.0"
        );

        // -1.0 = 0xBF800000
        check_unpack(
            32'hBF800000,
            1'b1,              // sign = 1
            8'd127,
            24'h800000,
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
            "-1.0"
        );

        // 2.0 = 0x40000000
        // Exp = 128, Mant = 1.0
        check_unpack(
            32'h40000000,
            1'b0,
            8'd128,
            24'h800000,
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
            "2.0"
        );

        // 0.5 = 0x3F000000
        // Exp = 126, Mant = 1.0
        check_unpack(
            32'h3F000000,
            1'b0,
            8'd126,
            24'h800000,
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
            "0.5"
        );

        // 3.14159 (approx) = 0x40490FDB
        check_unpack(
            32'h40490FDB,
            1'b0,
            8'd128,            // Exp = 128 (unbiased: 1)
            24'hC90FDB,        // Mant with implicit 1
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
            "Pi (approx 3.14159)"
        );

        // --------------------------------------------------------------------
        // Category 3: Infinity
        // --------------------------------------------------------------------
        $display("\n--- Testing INFINITY ---");

        // +Inf = 0x7F800000
        // Sign=0, Exp=255, Mant=0
        check_unpack(
            32'h7F800000,
            1'b0,
            8'd255,
            24'h000000,        // Mant=0 (no implicit bit for Inf)
            1'b0,              // is_zero
            1'b1,              // is_inf
            1'b0, 1'b0, 1'b0, 1'b0,
            "Positive Infinity (+Inf)"
        );

        // -Inf = 0xFF800000
        check_unpack(
            32'hFF800000,
            1'b1,              // sign = 1
            8'd255,
            24'h000000,        // Mant=0 (no implicit bit for Inf)
            1'b0,
            1'b1,              // is_inf
            1'b0, 1'b0, 1'b0, 1'b0,
            "Negative Infinity (-Inf)"
        );

        // --------------------------------------------------------------------
        // Category 4: NaN (Not a Number)
        // --------------------------------------------------------------------
        $display("\n--- Testing NaN ---");

        // Quiet NaN = 0x7FC00000
        // Exp=255, Mant[22]=1 (QNaN bit), rest non-zero
        check_unpack(
            32'h7FC00000,
            1'b0,
            8'd255,
            24'hC00000,        // Mant with QNaN bit
            1'b0, 1'b0,
            1'b1,              // is_nan
            1'b1,              // is_qnan
            1'b0, 1'b0,
            "Quiet NaN (QNaN)"
        );

        // Signaling NaN = 0x7FA00000
        // Exp=255, Mant[22]=0, Mant[21:0] non-zero
        check_unpack(
            32'h7FA00000,
            1'b0,
            8'd255,
            24'hA00000,
            1'b0, 1'b0,
            1'b1,              // is_nan
            1'b0,
            1'b1,              // is_snan
            1'b0,
            "Signaling NaN (SNaN)"
        );

        // Negative QNaN
        check_unpack(
            32'hFFC00000,
            1'b1,              // sign = 1
            8'd255,
            24'hC00000,
            1'b0, 1'b0, 1'b1, 1'b1, 1'b0, 1'b0,
            "Negative Quiet NaN"
        );

        // --------------------------------------------------------------------
        // Category 5: Subnormal (Denormalized) Numbers
        // --------------------------------------------------------------------
        $display("\n--- Testing SUBNORMAL NUMBERS ---");

        // Minimum subnormal = 0x00000001
        // Sign=0, Exp=0, Mant=0x000001
        check_unpack(
            32'h00000001,
            1'b0,
            8'd0,
            24'h000001,        // No implicit bit for subnormal
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
            1'b1,              // is_subnormal
            "Minimum Subnormal (smallest positive)"
        );

        // Maximum subnormal = 0x007FFFFF
        // Sign=0, Exp=0, Mant=0x7FFFFF
        check_unpack(
            32'h007FFFFF,
            1'b0,
            8'd0,
            24'h7FFFFF,
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
            1'b1,              // is_subnormal
            "Maximum Subnormal"
        );

        // Negative subnormal
        check_unpack(
            32'h80000001,
            1'b1,              // sign = 1
            8'd0,
            24'h000001,
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
            1'b1,              // is_subnormal
            "Negative Subnormal"
        );

        // --------------------------------------------------------------------
        // Category 6: Edge Cases
        // --------------------------------------------------------------------
        $display("\n--- Testing EDGE CASES ---");

        // Minimum normal number = 0x00800000
        // Exp=1, Mant=1.0
        check_unpack(
            32'h00800000,
            1'b0,
            8'd1,
            24'h800000,
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
            "Minimum Normal Number"
        );

        // Maximum normal number = 0x7F7FFFFF
        // Exp=254, Mant=0x7FFFFF (all 1s)
        check_unpack(
            32'h7F7FFFFF,
            1'b0,
            8'd254,
            24'hFFFFFF,
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
            "Maximum Normal Number"
        );

        // --------------------------------------------------------------------
        // Test Summary
        // --------------------------------------------------------------------
        $display("\n========================================");
        $display("Test Summary:");
        $display("  Total Tests: %0d", test_count);
        $display("  Passed:      %0d", pass_count);
        $display("  Failed:      %0d", fail_count);
        $display("  Pass Rate:   %.2f%%", (pass_count * 100.0) / test_count);
        $display("========================================\n");

        if (fail_count == 0) begin
            $display("*** ALL TESTS PASSED ***\n");
        end else begin
            $display("*** SOME TESTS FAILED ***\n");
        end

        $finish;
    end

endmodule

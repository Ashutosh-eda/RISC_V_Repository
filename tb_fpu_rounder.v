// ============================================================================
// Testbench for FPU Rounder
// Tests all 5 IEEE 754 rounding modes
// Self-checking with comprehensive test cases
// ============================================================================

`timescale 1ns / 1ps

module tb_fpu_rounder;

    // ========================================================================
    // DUT Signals
    // ========================================================================

    reg  [47:0] mantissa;
    reg  [8:0]  exponent;
    reg         sign;
    reg         guard;
    reg         round;
    reg         sticky;
    reg  [2:0]  rm;

    wire [22:0] mantissa_rounded;
    wire [7:0]  exponent_rounded;
    wire        inexact;
    wire        overflow;

    // ========================================================================
    // DUT Instantiation
    // ========================================================================

    fpu_rounder dut (
        .mantissa(mantissa),
        .exponent(exponent),
        .sign(sign),
        .guard(guard),
        .round(round),
        .sticky(sticky),
        .rm(rm),
        .mantissa_rounded(mantissa_rounded),
        .exponent_rounded(exponent_rounded),
        .inexact(inexact),
        .overflow(overflow)
    );

    // ========================================================================
    // Test Infrastructure
    // ========================================================================

    integer test_count = 0;
    integer pass_count = 0;
    integer fail_count = 0;

    // Rounding modes
    localparam RNE = 3'b000;  // Round to Nearest, ties to Even
    localparam RTZ = 3'b001;  // Round Toward Zero
    localparam RDN = 3'b010;  // Round Down (-Inf)
    localparam RUP = 3'b011;  // Round Up (+Inf)
    localparam RMM = 3'b100;  // Round to Nearest, ties to Max Magnitude

    // ========================================================================
    // Test Task
    // ========================================================================

    task check_rounding;
        input [47:0] test_mantissa;
        input [8:0]  test_exponent;
        input        test_sign;
        input        test_guard;
        input        test_round;
        input        test_sticky;
        input [2:0]  test_rm;
        input [22:0] exp_mantissa;
        input [7:0]  exp_exponent;
        input        exp_inexact;
        input        exp_overflow;
        input [200:0] description;

        begin
            test_count = test_count + 1;

            mantissa = test_mantissa;
            exponent = test_exponent;
            sign = test_sign;
            guard = test_guard;
            round = test_round;
            sticky = test_sticky;
            rm = test_rm;

            #10;

            if (mantissa_rounded === exp_mantissa &&
                exponent_rounded === exp_exponent &&
                inexact === exp_inexact &&
                overflow === exp_overflow) begin
                $display("[PASS] Test %0d: %s", test_count, description);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] Test %0d: %s", test_count, description);
                $display("       Expected: M=%h E=%h Inex=%b OF=%b",
                         exp_mantissa, exp_exponent, exp_inexact, exp_overflow);
                $display("       Got:      M=%h E=%h Inex=%b OF=%b",
                         mantissa_rounded, exponent_rounded, inexact, overflow);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // ========================================================================
    // Test Stimulus
    // ========================================================================

    initial begin
        $display("\n========================================");
        $display("FPU Rounder Testbench");
        $display("========================================\n");

        // ====================================================================
        // Test Category 1: RNE (Round to Nearest, ties to Even)
        // ====================================================================
        $display("\n--- Test Category 1: RNE (Round to Nearest, ties to Even) ---");

        // Test 1: No rounding needed (GRS = 000)
        check_rounding(
            48'h800000_000000, 9'd127, 1'b0,
            1'b0, 1'b0, 1'b0, RNE,
            23'h000000, 8'd127, 1'b0, 1'b0,
            "RNE: GRS=000, no rounding"
        );

        // Test 2: Round down (GRS = 001, G=0)
        check_rounding(
            48'h800000_100000, 9'd127, 1'b0,
            1'b0, 1'b0, 1'b1, RNE,
            23'h000000, 8'd127, 1'b1, 1'b0,
            "RNE: GRS=001, round down"
        );

        // Test 3: Round down (GRS = 100, LSB=0 tie to even)
        check_rounding(
            48'h800000_000000, 9'd127, 1'b0,
            1'b1, 1'b0, 1'b0, RNE,
            23'h000000, 8'd127, 1'b1, 1'b0,
            "RNE: GRS=100 LSB=0, tie to even (down)"
        );

        // Test 4: Round up (GRS = 100, LSB=1 tie to even)
        check_rounding(
            48'h800001_000000, 9'd127, 1'b0,
            1'b1, 1'b0, 1'b0, RNE,
            23'h000002, 8'd127, 1'b1, 1'b0,
            "RNE: GRS=100 LSB=1, tie to even (up)"
        );

        // Test 5: Round up (GRS = 101)
        check_rounding(
            48'h800000_000000, 9'd127, 1'b0,
            1'b1, 1'b0, 1'b1, RNE,
            23'h000001, 8'd127, 1'b1, 1'b0,
            "RNE: GRS=101, round up"
        );

        // Test 6: Round up (GRS = 110)
        check_rounding(
            48'h800000_000000, 9'd127, 1'b0,
            1'b1, 1'b1, 1'b0, RNE,
            23'h000001, 8'd127, 1'b1, 1'b0,
            "RNE: GRS=110, round up"
        );

        // Test 7: Round up (GRS = 111)
        check_rounding(
            48'h800000_000000, 9'd127, 1'b0,
            1'b1, 1'b1, 1'b1, RNE,
            23'h000001, 8'd127, 1'b1, 1'b0,
            "RNE: GRS=111, round up"
        );

        // ====================================================================
        // Test Category 2: RTZ (Round Toward Zero)
        // ====================================================================
        $display("\n--- Test Category 2: RTZ (Round Toward Zero) ---");

        // Test 8: Always truncate (GRS = 111, positive)
        check_rounding(
            48'h800000_FFFFFF, 9'd127, 1'b0,
            1'b1, 1'b1, 1'b1, RTZ,
            23'h000000, 8'd127, 1'b1, 1'b0,
            "RTZ: Always truncate (positive)"
        );

        // Test 9: Always truncate (GRS = 111, negative)
        check_rounding(
            48'h800000_FFFFFF, 9'd127, 1'b1,
            1'b1, 1'b1, 1'b1, RTZ,
            23'h000000, 8'd127, 1'b1, 1'b0,
            "RTZ: Always truncate (negative)"
        );

        // ====================================================================
        // Test Category 3: RDN (Round Down toward -Inf)
        // ====================================================================
        $display("\n--- Test Category 3: RDN (Round Down toward -Inf) ---");

        // Test 10: Positive, round down (truncate)
        check_rounding(
            48'h800000_FFFFFF, 9'd127, 1'b0,
            1'b1, 1'b1, 1'b1, RDN,
            23'h000000, 8'd127, 1'b1, 1'b0,
            "RDN: Positive, truncate"
        );

        // Test 11: Negative, round down (increment magnitude)
        check_rounding(
            48'h800000_000000, 9'd127, 1'b1,
            1'b1, 1'b1, 1'b1, RDN,
            23'h000001, 8'd127, 1'b1, 1'b0,
            "RDN: Negative, increment magnitude"
        );

        // Test 12: Negative, no bits set (no rounding)
        check_rounding(
            48'h800000_000000, 9'd127, 1'b1,
            1'b0, 1'b0, 1'b0, RDN,
            23'h000000, 8'd127, 1'b0, 1'b0,
            "RDN: Negative, GRS=000"
        );

        // ====================================================================
        // Test Category 4: RUP (Round Up toward +Inf)
        // ====================================================================
        $display("\n--- Test Category 4: RUP (Round Up toward +Inf) ---");

        // Test 13: Positive, round up
        check_rounding(
            48'h800000_000000, 9'd127, 1'b0,
            1'b1, 1'b1, 1'b1, RUP,
            23'h000001, 8'd127, 1'b1, 1'b0,
            "RUP: Positive, round up"
        );

        // Test 14: Negative, round up (truncate)
        check_rounding(
            48'h800000_FFFFFF, 9'd127, 1'b1,
            1'b1, 1'b1, 1'b1, RUP,
            23'h000000, 8'd127, 1'b1, 1'b0,
            "RUP: Negative, truncate"
        );

        // Test 15: Positive, no bits set
        check_rounding(
            48'h800000_000000, 9'd127, 1'b0,
            1'b0, 1'b0, 1'b0, RUP,
            23'h000000, 8'd127, 1'b0, 1'b0,
            "RUP: Positive, GRS=000"
        );

        // ====================================================================
        // Test Category 5: RMM (Round to Nearest, ties to Max Magnitude)
        // ====================================================================
        $display("\n--- Test Category 5: RMM (Round to Nearest, ties to Max Magnitude) ---");

        // Test 16: Round up on tie (G=1, R=0, S=0)
        check_rounding(
            48'h800000_000000, 9'd127, 1'b0,
            1'b1, 1'b0, 1'b0, RMM,
            23'h000001, 8'd127, 1'b1, 1'b0,
            "RMM: Tie, round to max magnitude"
        );

        // Test 17: No rounding (G=0)
        check_rounding(
            48'h800000_000000, 9'd127, 1'b0,
            1'b0, 1'b1, 1'b1, RMM,
            23'h000000, 8'd127, 1'b1, 1'b0,
            "RMM: G=0, no rounding"
        );

        // ====================================================================
        // Test Category 6: Mantissa Overflow (Carry into bit 23)
        // ====================================================================
        $display("\n--- Test Category 6: Mantissa Overflow ---");

        // Test 18: Rounding causes mantissa overflow
        check_rounding(
            48'hFFFFFF_000000, 9'd127, 1'b0,
            1'b1, 1'b1, 1'b1, RNE,
            23'h000000, 8'd128, 1'b1, 1'b0,
            "Mantissa overflow, increment exponent"
        );

        // Test 19: Overflow to max exponent
        check_rounding(
            48'hFFFFFF_000000, 9'd254, 1'b0,
            1'b1, 1'b1, 1'b1, RNE,
            23'h000000, 8'd255, 1'b1, 1'b1,
            "Overflow to exponent 255 (infinity)"
        );

        // ====================================================================
        // Test Category 7: Inexact Flag
        // ====================================================================
        $display("\n--- Test Category 7: Inexact Flag ---");

        // Test 20: Inexact when any GRS bit is set
        check_rounding(
            48'h800000_000000, 9'd127, 1'b0,
            1'b0, 1'b0, 1'b1, RNE,
            23'h000000, 8'd127, 1'b1, 1'b0,
            "Inexact: S=1"
        );

        // Test 21: Exact when GRS = 000
        check_rounding(
            48'h800000_000000, 9'd127, 1'b0,
            1'b0, 1'b0, 1'b0, RNE,
            23'h000000, 8'd127, 1'b0, 1'b0,
            "Exact: GRS=000"
        );

        // ====================================================================
        // Test Category 8: Edge Cases
        // ====================================================================
        $display("\n--- Test Category 8: Edge Cases ---");

        // Test 22: Maximum mantissa
        check_rounding(
            48'hFFFFFF_000000, 9'd127, 1'b0,
            1'b0, 1'b0, 1'b0, RNE,
            23'h7FFFFF, 8'd127, 1'b0, 1'b0,
            "Maximum mantissa"
        );

        // Test 23: Minimum mantissa
        check_rounding(
            48'h800000_000000, 9'd1, 1'b0,
            1'b0, 1'b0, 1'b0, RNE,
            23'h000000, 8'd1, 1'b0, 1'b0,
            "Minimum exponent"
        );

        // Test 24: All rounding modes with same input
        check_rounding(
            48'h800000_A00000, 9'd100, 1'b0,
            1'b1, 1'b0, 1'b1, RNE,
            23'h000001, 8'd100, 1'b1, 1'b0,
            "Multi-mode test: RNE"
        );

        check_rounding(
            48'h800000_A00000, 9'd100, 1'b0,
            1'b1, 1'b0, 1'b1, RTZ,
            23'h000000, 8'd100, 1'b1, 1'b0,
            "Multi-mode test: RTZ"
        );

        check_rounding(
            48'h800000_A00000, 9'd100, 1'b0,
            1'b1, 1'b0, 1'b1, RUP,
            23'h000001, 8'd100, 1'b1, 1'b0,
            "Multi-mode test: RUP (positive)"
        );

        check_rounding(
            48'h800000_A00000, 9'd100, 1'b1,
            1'b1, 1'b0, 1'b1, RDN,
            23'h000001, 8'd100, 1'b1, 1'b0,
            "Multi-mode test: RDN (negative)"
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

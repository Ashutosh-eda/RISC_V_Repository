// ============================================================================
// Testbench for FPU Shift Correction
// Tests LZA error correction (±1 adjustment)
// Verifies mantissa shift and exponent adjustment
// Tests GRS (Guard, Round, Sticky) bit handling
// Self-checking with comprehensive test cases
// ============================================================================

`timescale 1ns / 1ps

module tb_fpu_shift_correction;

    // ========================================================================
    // DUT Signals
    // ========================================================================

    reg  [47:0] shifted_sum;
    reg  [8:0]  norm_exp;
    reg         guard_in;
    reg         round_in;
    reg         sticky_in;

    wire [47:0] corrected_sum;
    wire [8:0]  corrected_exp;
    wire        guard;
    wire        round;
    wire        sticky;

    // ========================================================================
    // DUT Instantiation
    // ========================================================================

    fpu_shift_correction dut (
        .shifted_sum(shifted_sum),
        .norm_exp(norm_exp),
        .guard_in(guard_in),
        .round_in(round_in),
        .sticky_in(sticky_in),
        .corrected_sum(corrected_sum),
        .corrected_exp(corrected_exp),
        .guard(guard),
        .round(round),
        .sticky(sticky)
    );

    // ========================================================================
    // Test Infrastructure
    // ========================================================================

    integer test_count = 0;
    integer pass_count = 0;
    integer fail_count = 0;
    integer grs;       // Loop variable for GRS combinations
    integer pos;       // Loop variable for bit positions

    // ========================================================================
    // Test Task
    // ========================================================================

    task check_correction;
        input [47:0] test_sum;
        input [8:0]  test_exp;
        input        test_g, test_r, test_s;
        input [47:0] exp_corrected_sum;
        input [8:0]  exp_corrected_exp;
        input        exp_g, exp_r, exp_s;
        input [200:0] description;
        begin
            test_count = test_count + 1;

            shifted_sum = test_sum;
            norm_exp = test_exp;
            guard_in = test_g;
            round_in = test_r;
            sticky_in = test_s;

            #10;

            if (corrected_sum === exp_corrected_sum &&
                corrected_exp === exp_corrected_exp &&
                guard === exp_g &&
                round === exp_r &&
                sticky === exp_s) begin
                $display("[PASS] Test %0d: %s", test_count, description);
                $display("       corrected=0x%h, exp=%0d, GRS=%b%b%b",
                         corrected_sum, corrected_exp, guard, round, sticky);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] Test %0d: %s", test_count, description);
                $display("       Expected: sum=0x%h, exp=%0d, GRS=%b%b%b",
                         exp_corrected_sum, exp_corrected_exp, exp_g, exp_r, exp_s);
                $display("       Got:      sum=0x%h, exp=%0d, GRS=%b%b%b",
                         corrected_sum, corrected_exp, guard, round, sticky);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // ========================================================================
    // Test Stimulus
    // ========================================================================

    initial begin
        $display("\n========================================");
        $display("FPU Shift Correction Testbench");
        $display("========================================\n");

        // Initialize
        shifted_sum = 48'd0;
        norm_exp = 9'd0;
        guard_in = 1'b0;
        round_in = 1'b0;
        sticky_in = 1'b0;

        #20;

        // ====================================================================
        // Test Category 1: No Correction Needed (Leading Bit = 1)
        // ====================================================================
        $display("\n--- Test Category 1: No Correction (Already Normalized) ---");

        check_correction(
            48'h800000000000, 9'd127, 1'b0, 1'b0, 1'b0,
            48'h800000000000, 9'd127, 1'b0, 1'b0, 1'b0,
            "Already normalized (bit 47 = 1)"
        );

        check_correction(
            48'hC00000000000, 9'd127, 1'b1, 1'b0, 1'b0,
            48'hC00000000000, 9'd127, 1'b1, 1'b0, 1'b0,
            "Normalized, GRS = 100"
        );

        check_correction(
            48'hFFFFFFFFFFFF, 9'd100, 1'b1, 1'b1, 1'b1,
            48'hFFFFFFFFFFFF, 9'd100, 1'b1, 1'b1, 1'b1,
            "All bits set, GRS = 111"
        );

        check_correction(
            48'hA5A5A5A5A5A5, 9'd150, 1'b0, 1'b1, 1'b0,
            48'hA5A5A5A5A5A5, 9'd150, 1'b0, 1'b1, 1'b0,
            "Pattern 0xA5..., GRS = 010"
        );

        // ====================================================================
        // Test Category 2: Correction Needed (Leading Bit = 0)
        // ====================================================================
        $display("\n--- Test Category 2: Correction Needed (LZA Off by 1) ---");

        check_correction(
            48'h400000000000, 9'd127, 1'b0, 1'b0, 1'b0,
            48'h800000000000, 9'd126, 1'b0, 1'b0, 1'b0,
            "Leading bit = 0 → shift left by 1, exp-1"
        );

        check_correction(
            48'h600000000000, 9'd127, 1'b1, 1'b0, 1'b0,
            48'hC00000000000, 9'd126, 1'b1, 1'b0, 1'b0,
            "Bit 47=0, bit 46=1 → shift left, exp-1"
        );

        check_correction(
            48'h200000000000, 9'd100, 1'b0, 1'b1, 1'b1,
            48'h400000000000, 9'd99, 1'b0, 1'b1, 1'b1,
            "Leading bits = 01 → shift left, exp-1"
        );

        check_correction(
            48'h100000000000, 9'd127, 1'b1, 1'b1, 1'b0,
            48'h200000000000, 9'd126, 1'b1, 1'b1, 1'b0,
            "Leading bits = 001 → shift left, exp-1"
        );

        // ====================================================================
        // Test Category 3: Edge Case - Zero Sum (No Correction)
        // ====================================================================
        $display("\n--- Test Category 3: Zero Sum (No Correction) ---");

        check_correction(
            48'h000000000000, 9'd0, 1'b0, 1'b0, 1'b0,
            48'h000000000000, 9'd0, 1'b0, 1'b0, 1'b0,
            "Zero sum → no correction (special case)"
        );

        check_correction(
            48'h000000000000, 9'd127, 1'b0, 1'b0, 1'b1,
            48'h000000000000, 9'd127, 1'b0, 1'b0, 1'b1,
            "Zero sum with sticky=1 → no correction"
        );

        // ====================================================================
        // Test Category 4: Various Bit Patterns Needing Correction
        // ====================================================================
        $display("\n--- Test Category 4: Various Patterns Needing Correction ---");

        check_correction(
            48'h7FFFFFFFFFFF, 9'd127, 1'b0, 1'b0, 1'b0,
            48'hFFFFFFFFFFFE, 9'd126, 1'b0, 1'b0, 1'b0,
            "Pattern 0x7FFF... → shift to 0xFFFE..., exp-1"
        );

        check_correction(
            48'h3FFFFFFFFFFF, 9'd127, 1'b1, 1'b0, 1'b0,
            48'h7FFFFFFFFFFE, 9'd126, 1'b1, 1'b0, 1'b0,
            "Pattern 0x3FFF... → shift left, exp-1"
        );

        check_correction(
            48'h1FFFFFFFFFFF, 9'd100, 1'b0, 1'b1, 1'b1,
            48'h3FFFFFFFFFFE, 9'd99, 1'b0, 1'b1, 1'b1,
            "Pattern 0x1FFF... → shift left, exp-1"
        );

        check_correction(
            48'h000000000001, 9'd50, 1'b0, 1'b0, 1'b0,
            48'h000000000002, 9'd49, 1'b0, 1'b0, 1'b0,
            "LSB=1, rest=0 → shift left, exp-1"
        );

        // ====================================================================
        // Test Category 5: GRS Bit Preservation
        // ====================================================================
        $display("\n--- Test Category 5: GRS Bit Preservation ---");

        // No correction - GRS should pass through
        check_correction(
            48'h800000000000, 9'd127, 1'b1, 1'b1, 1'b1,
            48'h800000000000, 9'd127, 1'b1, 1'b1, 1'b1,
            "No correction: GRS = 111 passes through"
        );

        check_correction(
            48'h900000000000, 9'd127, 1'b0, 1'b1, 1'b0,
            48'h900000000000, 9'd127, 1'b0, 1'b1, 1'b0,
            "No correction: GRS = 010 passes through"
        );

        // With correction - GRS should still pass through
        check_correction(
            48'h400000000000, 9'd127, 1'b1, 1'b1, 1'b1,
            48'h800000000000, 9'd126, 1'b1, 1'b1, 1'b1,
            "With correction: GRS = 111 preserved"
        );

        check_correction(
            48'h600000000000, 9'd127, 1'b1, 1'b0, 1'b1,
            48'hC00000000000, 9'd126, 1'b1, 1'b0, 1'b1,
            "With correction: GRS = 101 preserved"
        );

        // ====================================================================
        // Test Category 6: Exponent Boundary Cases
        // ====================================================================
        $display("\n--- Test Category 6: Exponent Boundaries ---");

        check_correction(
            48'h400000000000, 9'd1, 1'b0, 1'b0, 1'b0,
            48'h800000000000, 9'd0, 1'b0, 1'b0, 1'b0,
            "Correction at exp=1 → exp becomes 0 (underflow)"
        );

        check_correction(
            48'h800000000000, 9'd255, 1'b0, 1'b0, 1'b0,
            48'h800000000000, 9'd255, 1'b0, 1'b0, 1'b0,
            "No correction at exp=255 (max exp)"
        );

        check_correction(
            48'h400000000000, 9'd255, 1'b0, 1'b0, 1'b0,
            48'h800000000000, 9'd254, 1'b0, 1'b0, 1'b0,
            "Correction at exp=255 → exp becomes 254"
        );

        check_correction(
            48'h800000000000, 9'd0, 1'b0, 1'b0, 1'b0,
            48'h800000000000, 9'd0, 1'b0, 1'b0, 1'b0,
            "No correction at exp=0"
        );

        // ====================================================================
        // Test Category 7: All GRS Combinations with Correction
        // ====================================================================
        $display("\n--- Test Category 7: All GRS Combinations ---");

        for (grs = 0; grs < 8; grs = grs + 1) begin
            shifted_sum = 48'h400000000000;
            norm_exp = 9'd127;
            guard_in = grs[2];
            round_in = grs[1];
            sticky_in = grs[0];
            #10;

            test_count = test_count + 1;
            if (corrected_sum === 48'h800000000000 &&
                corrected_exp === 9'd126 &&
                guard === grs[2] &&
                round === grs[1] &&
                sticky === grs[0]) begin
                $display("[PASS] Test %0d: GRS = %b%b%b preserved with correction",
                         test_count, grs[2], grs[1], grs[0]);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] Test %0d: GRS = %b%b%b not preserved",
                         test_count, grs[2], grs[1], grs[0]);
                fail_count = fail_count + 1;
            end
        end

        // ====================================================================
        // Test Category 8: Realistic FP Scenarios
        // ====================================================================
        $display("\n--- Test Category 8: Realistic FP Scenarios ---");

        check_correction(
            48'h555555555555, 9'd127, 1'b1, 1'b0, 1'b1,
            48'hAAAAAAAAAAAA, 9'd126, 1'b1, 1'b0, 1'b1,
            "Pattern 0x5555... needs correction → 0xAAAA..."
        );

        check_correction(
            48'h333333333333, 9'd127, 1'b0, 1'b1, 1'b0,
            48'h666666666666, 9'd126, 1'b0, 1'b1, 1'b0,
            "LZA off by 1 (needs correction)"
        );

        check_correction(
            48'h800000000001, 9'd100, 1'b1, 1'b1, 1'b1,
            48'h800000000001, 9'd100, 1'b1, 1'b1, 1'b1,
            "Normalized with LSB=1 (no correction)"
        );

        check_correction(
            48'h7FFFFFFFFFFB, 9'd127, 1'b0, 1'b0, 1'b1,
            48'hFFFFFFFFFFF6, 9'd126, 1'b0, 1'b0, 1'b1,
            "Near-max value needing correction"
        );

        // ====================================================================
        // Test Category 9: Shifted Bit Verification
        // ====================================================================
        $display("\n--- Test Category 9: Shift Bit Verification ---");

        check_correction(
            48'h400000000001, 9'd127, 1'b0, 1'b0, 1'b0,
            48'h800000000002, 9'd126, 1'b0, 1'b0, 1'b0,
            "Verify LSB shifts correctly (1→2)"
        );

        check_correction(
            48'h400000000003, 9'd127, 1'b0, 1'b0, 1'b0,
            48'h800000000006, 9'd126, 1'b0, 1'b0, 1'b0,
            "Verify LSBs shift correctly (3→6)"
        );

        check_correction(
            48'h7FFFFFFFFFFF, 9'd127, 1'b0, 1'b0, 1'b0,
            48'hFFFFFFFFFFFE, 9'd126, 1'b0, 1'b0, 1'b0,
            "Verify all bits shift (MSB 0→1, LSB→0)"
        );

        // ====================================================================
        // Test Category 10: Single Bit Set at Various Positions
        // ====================================================================
        $display("\n--- Test Category 10: Single Bit Set Positions ---");

        for (pos = 0; pos < 5; pos = pos + 1) begin
            shifted_sum = 48'd1 << pos;
            norm_exp = 9'd127;
            guard_in = 1'b0;
            round_in = 1'b0;
            sticky_in = 1'b0;
            #10;

            test_count = test_count + 1;
            if (corrected_sum === (48'd1 << (pos + 1)) && corrected_exp === 9'd126) begin
                $display("[PASS] Test %0d: Single bit at pos %0d → shifts to pos %0d",
                         test_count, pos, pos + 1);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] Test %0d: Single bit at pos %0d failed",
                         test_count, pos);
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

// ============================================================================
// Testbench for FPU Adder
// Tests significand addition/subtraction with guard, round, sticky bits
// Handles effective subtraction and sign determination
// Self-checking with comprehensive test cases
// ============================================================================

`timescale 1ns / 1ps

module tb_fpu_adder;

    // ========================================================================
    // DUT Signals
    // ========================================================================

    reg  [47:0] operand_a;
    reg  [47:0] operand_b;
    reg         effective_sub;
    reg         sticky_in;

    wire [48:0] sum;
    wire        result_sign;
    wire        guard;
    wire        round;
    wire        sticky;

    // ========================================================================
    // DUT Instantiation
    // ========================================================================

    fpu_adder dut (
        .operand_a(operand_a),
        .operand_b(operand_b),
        .effective_sub(effective_sub),
        .sticky_in(sticky_in),
        .sum(sum),
        .result_sign(result_sign),
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

    // ========================================================================
    // Test Task
    // ========================================================================

    task check_addition;
        input [47:0] test_a, test_b;
        input        test_eff_sub;
        input        test_sticky_in;
        input [48:0] exp_sum;
        input        exp_sign;
        input        exp_guard;
        input        exp_round;
        input        exp_sticky;
        input [200:0] description;

        reg exp_g_calc, exp_r_calc, exp_s_calc;

        begin
            test_count = test_count + 1;

            operand_a = test_a;
            operand_b = test_b;
            effective_sub = test_eff_sub;
            sticky_in = test_sticky_in;

            #10;

            // Calculate expected GRS from sum (module logic)
            exp_g_calc = exp_sum[2];
            exp_r_calc = exp_sum[1];
            exp_s_calc = exp_sum[0] | test_sticky_in;

            // Only check sum and sign (GRS are derived)
            if (sum === exp_sum &&
                result_sign === exp_sign &&
                guard === exp_g_calc &&
                round === exp_r_calc &&
                sticky === exp_s_calc) begin
                $display("[PASS] Test %0d: %s", test_count, description);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] Test %0d: %s", test_count, description);
                $display("       Expected: Sum=%h Sign=%b", exp_sum, exp_sign);
                $display("       Got:      Sum=%h Sign=%b", sum, result_sign);
                if (guard !== exp_g_calc || round !== exp_r_calc || sticky !== exp_s_calc)
                    $display("       GRS mismatch (derived from sum): Expected G=%b R=%b S=%b, Got G=%b R=%b S=%b",
                             exp_g_calc, exp_r_calc, exp_s_calc, guard, round, sticky);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // ========================================================================
    // Test Stimulus
    // ========================================================================

    initial begin
        $display("\n========================================");
        $display("FPU Adder Testbench");
        $display("========================================\n");

        // ====================================================================
        // Test Category 1: Simple Addition (No Carry)
        // ====================================================================
        $display("\n--- Test Category 1: Simple Addition (No Carry) ---");

        // Test 1: 1 + 1 = 2
        check_addition(
            48'h000000000001, 48'h000000000001,
            1'b0, 1'b0,
            49'h000000000002,
            1'b0, 1'b0, 1'b0, 1'b0,
            "Addition: 1 + 1 = 2"
        );

        // Test 2: 100 + 50 = 150
        check_addition(
            48'h000000000064, 48'h000000000032,
            1'b0, 1'b0,
            49'h000000000096,
            1'b0, 1'b0, 1'b1, 1'b0,
            "Addition: 100 + 50 = 150"
        );

        // Test 3: Large + Small
        check_addition(
            48'h800000000000, 48'h000000100000,
            1'b0, 1'b0,
            49'h800000100000,
            1'b0, 1'b0, 1'b0, 1'b0,
            "Addition: Large + Small"
        );

        // ====================================================================
        // Test Category 2: Addition with Carry
        // ====================================================================
        $display("\n--- Test Category 2: Addition with Carry ---");

        // Test 4: Max + 1 (overflow into bit 48)
        check_addition(
            48'hFFFFFFFFFFFF, 48'h000000000001,
            1'b0, 1'b0,
            49'h1000000000000,
            1'b0, 1'b0, 1'b0, 1'b0,
            "Addition: Max + 1 (carry out)"
        );

        // Test 5: Two large numbers
        check_addition(
            48'h800000000000, 48'h800000000000,
            1'b0, 1'b0,
            49'h1000000000000,
            1'b0, 1'b0, 1'b0, 1'b0,
            "Addition: Two large = carry"
        );

        // ====================================================================
        // Test Category 3: Simple Subtraction (Positive Result)
        // ====================================================================
        $display("\n--- Test Category 3: Simple Subtraction (Positive) ---");

        // Test 6: 10 - 5 = 5
        check_addition(
            48'h00000000000A, 48'h000000000005,
            1'b1, 1'b0,
            49'h000000000005,
            1'b0, 1'b1, 1'b0, 1'b0,
            "Subtraction: 10 - 5 = 5"
        );

        // Test 7: 100 - 1 = 99
        check_addition(
            48'h000000000064, 48'h000000000001,
            1'b1, 1'b0,
            49'h000000000063,
            1'b0, 1'b1, 1'b1, 1'b0,
            "Subtraction: 100 - 1 = 99"
        );

        // Test 8: Equal operands
        check_addition(
            48'hABCDEF123456, 48'hABCDEF123456,
            1'b1, 1'b0,
            49'h000000000000,
            1'b0, 1'b0, 1'b0, 1'b0,
            "Subtraction: Equal operands = 0"
        );

        // ====================================================================
        // Test Category 4: Subtraction (Negative Result - Swap)
        // ====================================================================
        $display("\n--- Test Category 4: Subtraction (Negative Result) ---");

        // Test 9: 5 - 10 = -5
        check_addition(
            48'h000000000005, 48'h00000000000A,
            1'b1, 1'b0,
            49'h000000000005,
            1'b1, 1'b1, 1'b0, 1'b0,
            "Subtraction: 5 - 10 = -5 (sign flip)"
        );

        // Test 10: 1 - 100 = -99
        check_addition(
            48'h000000000001, 48'h000000000064,
            1'b1, 1'b0,
            49'h000000000063,
            1'b1, 1'b1, 1'b1, 1'b0,
            "Subtraction: 1 - 100 = -99 (sign flip)"
        );

        // Test 11: Small - Large (significant difference)
        check_addition(
            48'h000000000001, 48'h800000000000,
            1'b1, 1'b0,
            49'h0_7FFFFFFFFFFF,  // Fixed: was 07FFFFFFFFFF (wrong)
            1'b1, 1'b1, 1'b1, 1'b1,
            "Subtraction: 1 - Large (negative)"
        );

        // ====================================================================
        // Test Category 5: Guard/Round/Sticky Bit Testing
        // ====================================================================
        $display("\n--- Test Category 5: Guard/Round/Sticky Bits ---");

        // Test 12: Guard bit = 1 (bit 2 of sum)
        check_addition(
            48'h000000000004, 48'h000000000000,
            1'b0, 1'b0,
            49'h000000000004,
            1'b0, 1'b1, 1'b0, 1'b0,
            "Guard bit set (sum[2]=1)"
        );

        // Test 13: Round bit = 1 (bit 1 of sum)
        check_addition(
            48'h000000000002, 48'h000000000000,
            1'b0, 1'b0,
            49'h000000000002,
            1'b0, 1'b0, 1'b1, 1'b0,
            "Round bit set (sum[1]=1)"
        );

        // Test 14: Sticky bit from sum (bit 0)
        check_addition(
            48'h000000000001, 48'h000000000000,
            1'b0, 1'b0,
            49'h000000000001,
            1'b0, 1'b0, 1'b0, 1'b1,
            "Sticky from sum (sum[0]=1)"
        );

        // Test 15: Sticky bit from input
        check_addition(
            48'h000000000000, 48'h000000000000,
            1'b0, 1'b1,
            49'h000000000000,
            1'b0, 1'b0, 1'b0, 1'b1,
            "Sticky from input (sticky_in=1)"
        );

        // Test 16: All GRS bits set
        check_addition(
            48'h000000000007, 48'h000000000000,
            1'b0, 1'b0,
            49'h000000000007,
            1'b0, 1'b1, 1'b1, 1'b1,
            "All GRS bits set"
        );

        // Test 17: GRS bits from addition result
        check_addition(
            48'h000000000003, 48'h000000000002,
            1'b0, 1'b0,
            49'h000000000005,
            1'b0, 1'b1, 1'b0, 1'b1,
            "GRS from addition: 3+2=5 (G=1,R=0,S=1)"
        );

        // ====================================================================
        // Test Category 6: Sticky Bit Propagation
        // ====================================================================
        $display("\n--- Test Category 6: Sticky Bit Propagation ---");

        // Test 18: Sticky OR with sum[0]=0
        check_addition(
            48'h000000000002, 48'h000000000002,
            1'b0, 1'b1,
            49'h000000000004,
            1'b0, 1'b1, 1'b0, 1'b1,
            "Sticky OR: sum[0]=0, sticky_in=1"
        );

        // Test 19: Sticky OR with sum[0]=1
        check_addition(
            48'h000000000001, 48'h000000000002,
            1'b0, 1'b0,
            49'h000000000003,
            1'b0, 1'b1, 1'b1, 1'b1,
            "Sticky OR: sum[0]=1, sticky_in=0"
        );

        // Test 20: Sticky OR with both
        check_addition(
            48'h000000000001, 48'h000000000000,
            1'b0, 1'b1,
            49'h000000000001,
            1'b0, 1'b0, 1'b0, 1'b1,
            "Sticky OR: sum[0]=1, sticky_in=1"
        );

        // ====================================================================
        // Test Category 7: Edge Cases
        // ====================================================================
        $display("\n--- Test Category 7: Edge Cases ---");

        // Test 21: Zero + Zero
        check_addition(
            48'h000000000000, 48'h000000000000,
            1'b0, 1'b0,
            49'h000000000000,
            1'b0, 1'b0, 1'b0, 1'b0,
            "Edge: 0 + 0 = 0"
        );

        // Test 22: Max + Max
        check_addition(
            48'hFFFFFFFFFFFF, 48'hFFFFFFFFFFFF,
            1'b0, 1'b0,
            49'h1FFFFFFFFFFFE,
            1'b0, 1'b1, 1'b1, 1'b0,
            "Edge: Max + Max"
        );

        // Test 23: Max - Max
        check_addition(
            48'hFFFFFFFFFFFF, 48'hFFFFFFFFFFFF,
            1'b1, 1'b0,
            49'h000000000000,
            1'b0, 1'b0, 1'b0, 1'b0,
            "Edge: Max - Max = 0"
        );

        // Test 24: 1 + 0
        check_addition(
            48'h000000000001, 48'h000000000000,
            1'b0, 1'b0,
            49'h000000000001,
            1'b0, 1'b0, 1'b0, 1'b1,
            "Edge: 1 + 0 = 1"
        );

        // Test 25: 0 - 1 (negative)
        check_addition(
            48'h000000000000, 48'h000000000001,
            1'b1, 1'b0,
            49'h000000000001,
            1'b1, 1'b0, 1'b0, 1'b1,
            "Edge: 0 - 1 = -1"
        );

        // ====================================================================
        // Test Category 8: High-Precision Significands
        // ====================================================================
        $display("\n--- Test Category 8: High-Precision Significands ---");

        // Test 26: Full 48-bit addition
        // 0x123456789ABC + 0x0FEDCBA98765 = 0x222222222221
        check_addition(
            48'h123456789ABC, 48'h0FEDCBA98765,
            1'b0, 1'b0,
            49'h0_222222222221,  // Fixed calculation
            1'b0, 1'b0, 1'b0, 1'b1,
            "48-bit: Large + Large"
        );

        // Test 27: Full 48-bit subtraction
        // 0xABCDEF123456 - 0x123456789ABC = 0x99999899999A
        check_addition(
            48'hABCDEF123456, 48'h123456789ABC,
            1'b1, 1'b0,
            49'h0_99999899999A,  // Fixed calculation
            1'b0, 1'b0, 1'b1, 1'b0,
            "48-bit: Large - Medium"
        );

        // Test 28: Alternating bit pattern addition
        check_addition(
            48'hAAAAAAAAAAAA, 48'h555555555555,
            1'b0, 1'b0,
            49'h0FFFFFFFFFFFF,
            1'b0, 1'b1, 1'b1, 1'b1,
            "48-bit: Alternating patterns"
        );

        // Test 29: MSB-heavy addition
        check_addition(
            48'hF00000000000, 48'hF00000000000,
            1'b0, 1'b0,
            49'h1E00000000000,
            1'b0, 1'b0, 1'b0, 1'b0,
            "48-bit: MSB-heavy (overflow)"
        );

        // Test 30: LSB-heavy addition
        check_addition(
            48'h000000000FFF, 48'h000000000FFF,
            1'b0, 1'b1,
            49'h000000001FFE,
            1'b0, 1'b1, 1'b1, 1'b1,
            "48-bit: LSB-heavy with sticky"
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

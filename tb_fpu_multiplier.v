// ============================================================================
// Self-Checking Testbench for FPU Multiplier (24x24 Significand Multiply)
// Tests: Unsigned 24-bit significand multiplication
// Coverage: Identity, Zero, Maximum values, Random cases
// ============================================================================

`timescale 1ns / 1ps

module tb_fpu_multiplier;

    // ========================================================================
    // Test Infrastructure
    // ========================================================================
    reg  [23:0] multiplicand;
    reg  [23:0] multiplier;
    wire [47:0] product;

    integer test_count = 0;
    integer pass_count = 0;
    integer fail_count = 0;

    // ========================================================================
    // DUT Instantiation
    // ========================================================================
    fpu_multiplier uut (
        .multiplicand(multiplicand),
        .multiplier  (multiplier),
        .product     (product)
    );

    // ========================================================================
    // Test Tasks
    // ========================================================================
    task check_multiply;
        input [23:0] a;
        input [23:0] b;
        input [47:0] expected;
        input [200:0] description;

        reg [47:0] computed;

        begin
            test_count = test_count + 1;
            multiplicand = a;
            multiplier = b;
            #10; // Wait for combinational logic

            // Compute expected using Verilog multiplication
            computed = a * b;

            if (product === expected && product === computed) begin
                $display("[PASS] Test %0d: %s", test_count, description);
                $display("       %0d × %0d = %0d", a, b, product);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] Test %0d: %s", test_count, description);
                $display("  Multiplicand: 0x%06h (%0d)", a, a);
                $display("  Multiplier:   0x%06h (%0d)", b, b);
                $display("  Expected:     0x%012h (%0d)", expected, expected);
                $display("  Computed:     0x%012h (%0d)", computed, computed);
                $display("  Got:          0x%012h (%0d)", product, product);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // Random test generator
    task test_random;
        input integer count;
        integer i;
        reg [23:0] rand_a, rand_b;
        reg [47:0] expected;

        begin
            $display("\n--- Testing RANDOM CASES ---");
            for (i = 0; i < count; i = i + 1) begin
                rand_a = $random & 24'hFFFFFF;
                rand_b = $random & 24'hFFFFFF;
                expected = rand_a * rand_b;
                check_multiply(rand_a, rand_b, expected, "Random multiplication");
            end
        end
    endtask

    // ========================================================================
    // Test Vectors
    // ========================================================================
    initial begin
        $display("========================================");
        $display("FPU Multiplier Self-Checking Tests");
        $display("========================================\n");

        // --------------------------------------------------------------------
        // Category 1: Identity (×1.0)
        // --------------------------------------------------------------------
        $display("--- Testing IDENTITY ---");

        // 1.0 × 1.0 = 1.0
        // Significand 1.0 = 0x800000 (implicit bit set)
        check_multiply(
            24'h800000,
            24'h800000,
            48'h400000000000,  // 0x800000 × 0x800000 = 0x400000000000
            "1.0 × 1.0"
        );

        // 1.0 × 1.75 (testing different value)
        // 1.75 in mantissa = 1.11 binary = 0xE00000 (23 bits: 1 + 0.5 + 0.25)
        check_multiply(
            24'h800000,        // 1.0
            24'hE00000,        // 1.75
            48'h700000000000,  // 0x800000 × 0xE00000 = 0x700000000000
            "1.0 × 1.75"
        );

        // --------------------------------------------------------------------
        // Category 2: Zero
        // --------------------------------------------------------------------
        $display("\n--- Testing ZERO ---");

        // 1.0 × 0.0 = 0.0
        check_multiply(
            24'h800000,
            24'h000000,
            48'h000000000000,
            "1.0 × 0.0"
        );

        // 0.0 × 0.0 = 0.0
        check_multiply(
            24'h000000,
            24'h000000,
            48'h000000000000,
            "0.0 × 0.0"
        );

        // Any × 0 = 0
        check_multiply(
            24'hABCDEF,
            24'h000000,
            48'h000000000000,
            "Random × 0.0"
        );

        // --------------------------------------------------------------------
        // Category 3: Maximum Values
        // --------------------------------------------------------------------
        $display("\n--- Testing MAXIMUM VALUES ---");

        // Max × Max = Max²
        check_multiply(
            24'hFFFFFF,
            24'hFFFFFF,
            48'hFFFFFE000001,  // (2^24 - 1)² = 2^48 - 2^25 + 1
            "Max × Max"
        );

        // Max × 1.0
        check_multiply(
            24'hFFFFFF,
            24'h800000,
            48'h7FFFFF800000,
            "Max × 1.0"
        );

        // --------------------------------------------------------------------
        // Category 4: Powers of Two
        // --------------------------------------------------------------------
        $display("\n--- Testing POWERS OF TWO ---");

        // 2 × 2 = 4
        check_multiply(
            24'h000002,
            24'h000002,
            48'h000000000004,
            "2 × 2"
        );

        // 256 × 256 = 65536
        check_multiply(
            24'h000100,
            24'h000100,
            48'h000000010000,
            "256 × 256"
        );

        // 2^12 × 2^12 = 2^24
        check_multiply(
            24'h001000,
            24'h001000,
            48'h000001000000,
            "4096 × 4096"
        );

        // --------------------------------------------------------------------
        // Category 5: Small Values
        // --------------------------------------------------------------------
        $display("\n--- Testing SMALL VALUES ---");

        // 1 × 1 = 1
        check_multiply(
            24'h000001,
            24'h000001,
            48'h000000000001,
            "1 × 1"
        );

        // 1 × Max
        check_multiply(
            24'h000001,
            24'hFFFFFF,
            48'h000000FFFFFF,
            "1 × Max"
        );

        // 3 × 5 = 15
        check_multiply(
            24'h000003,
            24'h000005,
            48'h00000000000F,
            "3 × 5"
        );

        // --------------------------------------------------------------------
        // Category 6: Typical Significands (1.x format)
        // --------------------------------------------------------------------
        $display("\n--- Testing TYPICAL SIGNIFICANDS ---");

        // 1.5 × 1.5 = 2.25
        // 1.5 in significand = 0xC00000 (1.1 in binary)
        check_multiply(
            24'hC00000,
            24'hC00000,
            48'h900000000000,  // 0xC00000² = 0x900000000000
            "1.5 × 1.5"
        );

        // 1.25 × 1.25 = 1.5625
        // 1.25 = 0xA00000 (1.01 in binary)
        check_multiply(
            24'hA00000,
            24'hA00000,
            48'h640000000000,
            "1.25 × 1.25"
        );

        // --------------------------------------------------------------------
        // Category 7: Commutative Property
        // --------------------------------------------------------------------
        $display("\n--- Testing COMMUTATIVE PROPERTY ---");

        check_multiply(
            24'h123456,
            24'hABCDEF,
            24'h123456 * 24'hABCDEF,
            "A × B"
        );

        check_multiply(
            24'hABCDEF,
            24'h123456,
            24'hABCDEF * 24'h123456,
            "B × A (should equal A × B)"
        );

        // --------------------------------------------------------------------
        // Category 8: Random Cases
        // --------------------------------------------------------------------
        test_random(100);  // 100 random test cases

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

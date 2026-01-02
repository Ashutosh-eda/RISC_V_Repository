// ============================================================================
// Testbench for FPU Pack
// Tests IEEE 754 format assembly
// Self-checking with comprehensive test cases
// ============================================================================

`timescale 1ns / 1ps

module tb_fpu_pack;

    // ========================================================================
    // DUT Signals
    // ========================================================================

    reg         sign;
    reg  [7:0]  exponent;
    reg  [22:0] mantissa;
    wire [31:0] ieee_out;

    // ========================================================================
    // DUT Instantiation
    // ========================================================================

    fpu_pack dut (
        .sign(sign),
        .exponent(exponent),
        .mantissa(mantissa),
        .ieee_out(ieee_out)
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

    task check_pack;
        input        test_sign;
        input [7:0]  test_exponent;
        input [22:0] test_mantissa;
        input [31:0] expected;
        input [200:0] description;

        begin
            test_count = test_count + 1;

            sign = test_sign;
            exponent = test_exponent;
            mantissa = test_mantissa;

            #10;

            if (ieee_out === expected) begin
                $display("[PASS] Test %0d: %s", test_count, description);
                $display("       Result: %h", ieee_out);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] Test %0d: %s", test_count, description);
                $display("       Expected: %h", expected);
                $display("       Got:      %h", ieee_out);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // ========================================================================
    // Test Stimulus
    // ========================================================================

    initial begin
        $display("\n========================================");
        $display("FPU Pack Testbench");
        $display("========================================\n");

        // ====================================================================
        // Test Category 1: Standard Numbers
        // ====================================================================
        $display("\n--- Test Category 1: Standard Numbers ---");

        // Test 1: +1.0 = 0x3F800000
        check_pack(
            1'b0, 8'd127, 23'h000000,
            32'h3F800000,
            "+1.0"
        );

        // Test 2: -1.0 = 0xBF800000
        check_pack(
            1'b1, 8'd127, 23'h000000,
            32'hBF800000,
            "-1.0"
        );

        // Test 3: +2.0 = 0x40000000
        check_pack(
            1'b0, 8'd128, 23'h000000,
            32'h40000000,
            "+2.0"
        );

        // Test 4: +0.5 = 0x3F000000
        check_pack(
            1'b0, 8'd126, 23'h000000,
            32'h3F000000,
            "+0.5"
        );

        // ====================================================================
        // Test Category 2: Special Values - Zero
        // ====================================================================
        $display("\n--- Test Category 2: Special Values - Zero ---");

        // Test 5: +0.0 = 0x00000000
        check_pack(
            1'b0, 8'd0, 23'h000000,
            32'h00000000,
            "+0.0"
        );

        // Test 6: -0.0 = 0x80000000
        check_pack(
            1'b1, 8'd0, 23'h000000,
            32'h80000000,
            "-0.0"
        );

        // ====================================================================
        // Test Category 3: Special Values - Infinity
        // ====================================================================
        $display("\n--- Test Category 3: Special Values - Infinity ---");

        // Test 7: +Inf = 0x7F800000
        check_pack(
            1'b0, 8'd255, 23'h000000,
            32'h7F800000,
            "+Infinity"
        );

        // Test 8: -Inf = 0xFF800000
        check_pack(
            1'b1, 8'd255, 23'h000000,
            32'hFF800000,
            "-Infinity"
        );

        // ====================================================================
        // Test Category 4: Special Values - NaN
        // ====================================================================
        $display("\n--- Test Category 4: Special Values - NaN ---");

        // Test 9: Quiet NaN (canonical)
        check_pack(
            1'b0, 8'd255, 23'h400000,
            32'h7FC00000,
            "Quiet NaN (canonical)"
        );

        // Test 10: Signaling NaN
        check_pack(
            1'b0, 8'd255, 23'h200000,
            32'h7FA00000,
            "Signaling NaN"
        );

        // Test 11: Negative NaN
        check_pack(
            1'b1, 8'd255, 23'h400000,
            32'hFFC00000,
            "Negative NaN"
        );

        // ====================================================================
        // Test Category 5: Subnormal Numbers
        // ====================================================================
        $display("\n--- Test Category 5: Subnormal Numbers ---");

        // Test 12: Smallest positive subnormal
        check_pack(
            1'b0, 8'd0, 23'h000001,
            32'h00000001,
            "Smallest positive subnormal"
        );

        // Test 13: Largest positive subnormal
        check_pack(
            1'b0, 8'd0, 23'h7FFFFF,
            32'h007FFFFF,
            "Largest positive subnormal"
        );

        // ====================================================================
        // Test Category 6: Normal Numbers - Min/Max
        // ====================================================================
        $display("\n--- Test Category 6: Normal Numbers - Min/Max ---");

        // Test 14: Smallest positive normal
        check_pack(
            1'b0, 8'd1, 23'h000000,
            32'h00800000,
            "Smallest positive normal"
        );

        // Test 15: Largest positive normal
        check_pack(
            1'b0, 8'd254, 23'h7FFFFF,
            32'h7F7FFFFF,
            "Largest positive normal"
        );

        // Test 16: Smallest negative normal
        check_pack(
            1'b1, 8'd1, 23'h000000,
            32'h80800000,
            "Smallest negative normal"
        );

        // Test 17: Largest negative normal
        check_pack(
            1'b1, 8'd254, 23'h7FFFFF,
            32'hFF7FFFFF,
            "Largest negative normal"
        );

        // ====================================================================
        // Test Category 7: Arbitrary Values
        // ====================================================================
        $display("\n--- Test Category 7: Arbitrary Values ---");

        // Test 18: PI approximation
        check_pack(
            1'b0, 8'd128, 23'h490FDB,
            32'h40490FDB,
            "PI ≈ 3.14159"
        );

        // Test 19: E approximation
        check_pack(
            1'b0, 8'd128, 23'h2DF854,
            32'h402DF854,
            "e ≈ 2.71828"
        );

        // Test 20: Random positive
        check_pack(
            1'b0, 8'd100, 23'h123456,
            32'h32123456,
            "Random positive"
        );

        // Test 21: Random negative
        check_pack(
            1'b1, 8'd150, 23'h7ABCDE,
            32'hCB7ABCDE,
            "Random negative"
        );

        // ====================================================================
        // Test Category 8: Bit Pattern Edge Cases
        // ====================================================================
        $display("\n--- Test Category 8: Bit Pattern Edge Cases ---");

        // Test 22: All mantissa bits set
        check_pack(
            1'b0, 8'd127, 23'h7FFFFF,
            32'h3FFFFFFF,
            "All mantissa bits set"
        );

        // Test 23: All exponent bits set (except special)
        check_pack(
            1'b0, 8'd254, 23'h000000,
            32'h7F000000,
            "Max normal exponent"
        );

        // Test 24: Alternating bits in mantissa (23 bits: 101010...)
        check_pack(
            1'b0, 8'd127, 23'h555555,
            32'h3FD55555,
            "Alternating mantissa bits"
        );

        // Test 25: Alternating bits (other pattern: 010101...)
        check_pack(
            1'b0, 8'd127, 23'h2AAAAA,
            32'h3FAAAAAA,
            "Alternating mantissa bits (alt)"
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

// ============================================================================
// Testbench for Leading Zero Counter (LZC)
// Tests priority encoder for 48-bit leading zero counting
// Self-checking with comprehensive test cases
// ============================================================================

`timescale 1ns / 1ps

module tb_fpu_lzc;

    // ========================================================================
    // DUT Signals
    // ========================================================================

    reg  [47:0] data_in;
    wire [5:0]  count;

    // ========================================================================
    // DUT Instantiation
    // ========================================================================

    fpu_lzc dut (
        .data_in(data_in),
        .count(count)
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

    task check_lzc;
        input [47:0] test_data;
        input [5:0]  expected_count;
        input [200:0] description;

        begin
            test_count = test_count + 1;
            data_in = test_data;
            #10;

            if (count === expected_count) begin
                $display("[PASS] Test %0d: %s", test_count, description);
                $display("       Count: %0d", count);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] Test %0d: %s", test_count, description);
                $display("       Expected: %0d", expected_count);
                $display("       Got:      %0d", count);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // ========================================================================
    // Test Stimulus
    // ========================================================================

    initial begin
        $display("\n========================================");
        $display("FPU LZC Testbench");
        $display("========================================\n");

        // ====================================================================
        // Test Category 1: All Zeros
        // ====================================================================
        $display("\n--- Test Category 1: All Zeros ---");

        check_lzc(
            48'h000000000000,
            6'd48,
            "All zeros → 48 leading zeros"
        );

        // ====================================================================
        // Test Category 2: MSB Set (0 leading zeros)
        // ====================================================================
        $display("\n--- Test Category 2: MSB Set ---");

        check_lzc(
            48'h800000000000,
            6'd0,
            "MSB set → 0 leading zeros"
        );

        check_lzc(
            48'hFFFFFFFFFFFF,
            6'd0,
            "All ones → 0 leading zeros"
        );

        check_lzc(
            48'hAAAAAAAAAAAA,
            6'd0,
            "Alternating (MSB=1) → 0 LZ"
        );

        // ====================================================================
        // Test Category 3: Single Bit Set (Various Positions)
        // ====================================================================
        $display("\n--- Test Category 3: Single Bit Set ---");

        check_lzc(
            48'h400000000000,  // Bit 46
            6'd1,
            "Bit 46 set → 1 LZ"
        );

        check_lzc(
            48'h200000000000,  // Bit 45
            6'd2,
            "Bit 45 set → 2 LZ"
        );

        check_lzc(
            48'h100000000000,  // Bit 44
            6'd3,
            "Bit 44 set → 3 LZ"
        );

        check_lzc(
            48'h080000000000,  // Bit 43
            6'd4,
            "Bit 43 set → 4 LZ"
        );

        check_lzc(
            48'h040000000000,  // Bit 42
            6'd5,
            "Bit 42 set → 5 LZ"
        );

        check_lzc(
            48'h000000000001,  // Bit 0 (LSB)
            6'd47,
            "LSB set → 47 LZ"
        );

        // ====================================================================
        // Test Category 4: Powers of 2
        // ====================================================================
        $display("\n--- Test Category 4: Powers of 2 ---");

        check_lzc(
            48'h000100000000,  // Bit 32
            6'd15,
            "Bit 32 set → 15 LZ"
        );

        check_lzc(
            48'h000000010000,  // Bit 16
            6'd31,
            "Bit 16 set → 31 LZ"
        );

        check_lzc(
            48'h000000000100,  // Bit 8
            6'd39,
            "Bit 8 set → 39 LZ"
        );

        check_lzc(
            48'h000000000010,  // Bit 4
            6'd43,
            "Bit 4 set → 43 LZ"
        );

        // ====================================================================
        // Test Category 5: Byte Boundaries
        // ====================================================================
        $display("\n--- Test Category 5: Byte Boundaries ---");

        check_lzc(
            48'h010000000000,  // First bit of byte 5
            6'd7,
            "Byte 5 boundary → 7 LZ"
        );

        check_lzc(
            48'h000001000000,  // First bit of byte 3
            6'd23,
            "Byte 3 boundary → 23 LZ"
        );

        check_lzc(
            48'h000000000001,  // First bit of byte 0
            6'd47,
            "Byte 0 boundary → 47 LZ"
        );

        // ====================================================================
        // Test Category 6: Sequential Leading Zeros
        // ====================================================================
        $display("\n--- Test Category 6: Sequential Leading Zeros ---");

        check_lzc(
            48'h000000800000,  // 24 LZ
            6'd24,
            "24 leading zeros"
        );

        check_lzc(
            48'h000000400000,  // 25 LZ
            6'd25,
            "25 leading zeros"
        );

        check_lzc(
            48'h000000200000,  // 26 LZ
            6'd26,
            "26 leading zeros"
        );

        check_lzc(
            48'h000000100000,  // 27 LZ
            6'd27,
            "27 leading zeros"
        );

        check_lzc(
            48'h000000080000,  // 28 LZ
            6'd28,
            "28 leading zeros"
        );

        check_lzc(
            48'h000000040000,  // 29 LZ
            6'd29,
            "29 leading zeros"
        );

        check_lzc(
            48'h000000020000,  // 30 LZ
            6'd30,
            "30 leading zeros"
        );

        // ====================================================================
        // Test Category 7: Patterns with Trailing Ones
        // ====================================================================
        $display("\n--- Test Category 7: Patterns with Trailing Ones ---");

        check_lzc(
            48'h0000000000FF,
            6'd40,
            "8 trailing ones → 40 LZ"
        );

        check_lzc(
            48'h00000000FFFF,
            6'd32,
            "16 trailing ones → 32 LZ"
        );

        check_lzc(
            48'h000000FFFFFF,
            6'd24,
            "24 trailing ones → 24 LZ"
        );

        check_lzc(
            48'h0000FFFFFFFF,
            6'd16,
            "32 trailing ones → 16 LZ"
        );

        // ====================================================================
        // Test Category 8: Realistic FP Significand Patterns
        // ====================================================================
        $display("\n--- Test Category 8: Realistic FP Patterns ---");

        // Normalized significand (1.xxx format)
        check_lzc(
            48'h800123456789,
            6'd0,
            "Normalized significand (1.xxx)"
        );

        // Subnormal result (cancellation)
        check_lzc(
            48'h000000001234,
            6'd35,
            "Subnormal after cancellation"
        );

        // Nearly canceled (massive cancellation)
        check_lzc(
            48'h000000000008,
            6'd44,
            "Massive cancellation"
        );

        // Small result from multiplication
        check_lzc(
            48'h000080000000,
            6'd16,
            "Small product"
        );

        // ====================================================================
        // Test Category 9: Edge Cases
        // ====================================================================
        $display("\n--- Test Category 9: Edge Cases ---");

        check_lzc(
            48'h800000000001,
            6'd0,
            "MSB + LSB set → 0 LZ"
        );

        check_lzc(
            48'h000000000002,
            6'd46,
            "Second LSB set → 46 LZ"
        );

        check_lzc(
            48'h000000000004,
            6'd45,
            "Third LSB set → 45 LZ"
        );

        check_lzc(
            48'h000000000008,
            6'd44,
            "Fourth LSB set → 44 LZ"
        );

        // ====================================================================
        // Test Category 10: Nibble Boundaries (4-bit groups)
        // ====================================================================
        $display("\n--- Test Category 10: Nibble Boundaries ---");

        check_lzc(
            48'h080000000000,  // Nibble 11
            6'd4,
            "Nibble 11 → 4 LZ"
        );

        check_lzc(
            48'h000800000000,  // Nibble 8 (bit 35 set)
            6'd12,
            "Nibble 8 → 12 LZ"
        );

        check_lzc(
            48'h000008000000,  // Nibble 6 (bit 27 set)
            6'd20,
            "Nibble 6 → 20 LZ"
        );

        check_lzc(
            48'h000000080000,  // Nibble 4 (bit 19 set)
            6'd28,
            "Nibble 4 → 28 LZ"
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

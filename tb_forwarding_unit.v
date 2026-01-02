// ============================================================================
// Testbench for Integer Forwarding Unit
// Tests EX-to-EX and MEM-to-EX forwarding paths
// Self-checking with comprehensive test cases
// ============================================================================

`timescale 1ns / 1ps

module tb_forwarding_unit;

    // ========================================================================
    // DUT Signals
    // ========================================================================

    // From ID/EX Register
    reg  [4:0]  rs1_ex;
    reg  [4:0]  rs2_ex;

    // From EX/MEM Register
    reg  [4:0]  rd_mem;
    reg         reg_write_mem;

    // From MEM/WB Register
    reg  [4:0]  rd_wb;
    reg         reg_write_wb;

    // Outputs
    wire [1:0]  forward_a;    // For rs1
    wire [1:0]  forward_b;    // For rs2

    // ========================================================================
    // DUT Instantiation
    // ========================================================================

    forwarding_unit dut (
        .rs1_ex(rs1_ex),
        .rs2_ex(rs2_ex),
        .rd_mem(rd_mem),
        .reg_write_mem(reg_write_mem),
        .rd_wb(rd_wb),
        .reg_write_wb(reg_write_wb),
        .forward_a(forward_a),
        .forward_b(forward_b)
    );

    // ========================================================================
    // Test Infrastructure
    // ========================================================================

    integer test_count = 0;
    integer pass_count = 0;
    integer fail_count = 0;

    // Forwarding encoding constants
    localparam FWD_NONE = 2'b00;  // No forwarding (use ID/EX value)
    localparam FWD_WB   = 2'b01;  // Forward from WB stage
    localparam FWD_MEM  = 2'b10;  // Forward from MEM stage

    // ========================================================================
    // Test Task
    // ========================================================================

    task check_forwarding;
        input [4:0]  test_rs1_ex;
        input [4:0]  test_rs2_ex;
        input [4:0]  test_rd_mem;
        input        test_reg_write_mem;
        input [4:0]  test_rd_wb;
        input        test_reg_write_wb;
        input [1:0]  exp_forward_a;
        input [1:0]  exp_forward_b;
        input [200:0] description;

        begin
            test_count = test_count + 1;

            // Apply inputs
            rs1_ex = test_rs1_ex;
            rs2_ex = test_rs2_ex;
            rd_mem = test_rd_mem;
            reg_write_mem = test_reg_write_mem;
            rd_wb = test_rd_wb;
            reg_write_wb = test_reg_write_wb;

            #10; // Wait for combinational logic

            // Check outputs
            if (forward_a === exp_forward_a && forward_b === exp_forward_b) begin
                $display("[PASS] Test %0d: %s", test_count, description);
                $display("       forward_a=%b (%s), forward_b=%b (%s)",
                         forward_a, decode_fwd(forward_a),
                         forward_b, decode_fwd(forward_b));
                pass_count = pass_count + 1;
            end
            else begin
                $display("[FAIL] Test %0d: %s", test_count, description);
                $display("       Expected: forward_a=%b (%s), forward_b=%b (%s)",
                         exp_forward_a, decode_fwd(exp_forward_a),
                         exp_forward_b, decode_fwd(exp_forward_b));
                $display("       Got:      forward_a=%b (%s), forward_b=%b (%b (%s)",
                         forward_a, decode_fwd(forward_a),
                         forward_b, decode_fwd(forward_b));
                fail_count = fail_count + 1;
            end
        end
    endtask

    // Helper function to decode forwarding control
    function [63:0] decode_fwd;
        input [1:0] fwd;
        begin
            case (fwd)
                2'b00: decode_fwd = "NONE";
                2'b01: decode_fwd = "WB  ";
                2'b10: decode_fwd = "MEM ";
                2'b11: decode_fwd = "INV ";  // Invalid
                default: decode_fwd = "???";
            endcase
        end
    endfunction

    // ========================================================================
    // Test Stimulus
    // ========================================================================

    initial begin
        $display("\n========================================");
        $display("Forwarding Unit Testbench");
        $display("========================================\n");

        // Initialize all inputs
        rs1_ex = 5'd0;
        rs2_ex = 5'd0;
        rd_mem = 5'd0;
        reg_write_mem = 1'b0;
        rd_wb = 5'd0;
        reg_write_wb = 1'b0;

        #5; // Initial delay

        // ====================================================================
        // Test Category 1: No Forwarding Cases
        // ====================================================================
        $display("\n--- Test Category 1: No Forwarding ---");

        // Test 1: All zeros (no operation)
        check_forwarding(
            5'd0, 5'd0,     // rs1_ex, rs2_ex
            5'd0, 1'b0,     // rd_mem, reg_write_mem
            5'd0, 1'b0,     // rd_wb, reg_write_wb
            FWD_NONE, FWD_NONE, // No forwarding
            "No forwarding - all zeros"
        );

        // Test 2: Different registers (no dependency)
        check_forwarding(
            5'd1, 5'd2,     // rs1_ex=x1, rs2_ex=x2
            5'd3, 1'b1,     // rd_mem=x3 (writing)
            5'd4, 1'b1,     // rd_wb=x4 (writing)
            FWD_NONE, FWD_NONE, // No forwarding
            "No forwarding - different registers"
        );

        // Test 3: Register match but write disabled
        check_forwarding(
            5'd5, 5'd6,     // rs1_ex=x5, rs2_ex=x6
            5'd5, 1'b0,     // rd_mem=x5 (not writing)
            5'd6, 1'b0,     // rd_wb=x6 (not writing)
            FWD_NONE, FWD_NONE, // No forwarding
            "No forwarding - write disabled"
        );

        // Test 4: Writing to x0 (should not forward)
        check_forwarding(
            5'd0, 5'd0,     // rs1_ex=x0, rs2_ex=x0
            5'd0, 1'b1,     // rd_mem=x0 (writing)
            5'd0, 1'b1,     // rd_wb=x0 (writing)
            FWD_NONE, FWD_NONE, // No forwarding (x0 is always 0)
            "No forwarding - x0 is hardwired"
        );

        // ====================================================================
        // Test Category 2: Forward from MEM Stage (EX-to-EX)
        // ====================================================================
        $display("\n--- Test Category 2: Forward from MEM Stage ---");

        // Test 5: Forward rs1 from MEM
        check_forwarding(
            5'd10, 5'd2,    // rs1_ex=x10, rs2_ex=x2
            5'd10, 1'b1,    // rd_mem=x10 (writing)
            5'd3, 1'b1,     // rd_wb=x3
            FWD_MEM, FWD_NONE, // Forward rs1 from MEM
            "Forward rs1 from MEM stage"
        );

        // Test 6: Forward rs2 from MEM
        check_forwarding(
            5'd1, 5'd15,    // rs1_ex=x1, rs2_ex=x15
            5'd15, 1'b1,    // rd_mem=x15 (writing)
            5'd3, 1'b1,     // rd_wb=x3
            FWD_NONE, FWD_MEM, // Forward rs2 from MEM
            "Forward rs2 from MEM stage"
        );

        // Test 7: Forward both rs1 and rs2 from MEM
        check_forwarding(
            5'd7, 5'd8,     // rs1_ex=x7, rs2_ex=x8
            5'd7, 1'b1,     // rd_mem=x7 (writing)
            5'd8, 1'b1,     // rd_wb=x8 (writing)
            FWD_MEM, FWD_NONE, // Only rs1 forwards from MEM
            "Forward rs1 from MEM (rs2 from WB)"
        );

        // Test 8: Same source for both operands
        check_forwarding(
            5'd12, 5'd12,   // rs1_ex=x12, rs2_ex=x12 (same)
            5'd12, 1'b1,    // rd_mem=x12 (writing)
            5'd5, 1'b1,     // rd_wb=x5
            FWD_MEM, FWD_MEM, // Both forward from MEM
            "Forward both operands from MEM (same source)"
        );

        // ====================================================================
        // Test Category 3: Forward from WB Stage (MEM-to-EX)
        // ====================================================================
        $display("\n--- Test Category 3: Forward from WB Stage ---");

        // Test 9: Forward rs1 from WB
        check_forwarding(
            5'd20, 5'd2,    // rs1_ex=x20, rs2_ex=x2
            5'd3, 1'b1,     // rd_mem=x3
            5'd20, 1'b1,    // rd_wb=x20 (writing)
            FWD_WB, FWD_NONE, // Forward rs1 from WB
            "Forward rs1 from WB stage"
        );

        // Test 10: Forward rs2 from WB
        check_forwarding(
            5'd1, 5'd25,    // rs1_ex=x1, rs2_ex=x25
            5'd3, 1'b1,     // rd_mem=x3
            5'd25, 1'b1,    // rd_wb=x25 (writing)
            FWD_NONE, FWD_WB, // Forward rs2 from WB
            "Forward rs2 from WB stage"
        );

        // Test 11: Forward both rs1 and rs2 from WB
        check_forwarding(
            5'd30, 5'd31,   // rs1_ex=x30, rs2_ex=x31
            5'd5, 1'b1,     // rd_mem=x5
            5'd30, 1'b1,    // rd_wb=x30 (writing)
            FWD_WB, FWD_NONE, // Only rs1 forwards from WB
            "Forward rs1 from WB (rs2 no forward)"
        );

        // Test 12: Same source from WB for both operands
        check_forwarding(
            5'd18, 5'd18,   // rs1_ex=x18, rs2_ex=x18 (same)
            5'd5, 1'b1,     // rd_mem=x5
            5'd18, 1'b1,    // rd_wb=x18 (writing)
            FWD_WB, FWD_WB, // Both forward from WB
            "Forward both operands from WB (same source)"
        );

        // ====================================================================
        // Test Category 4: Priority Testing (MEM > WB)
        // ====================================================================
        $display("\n--- Test Category 4: Forwarding Priority ---");

        // Test 13: MEM has priority over WB for rs1
        check_forwarding(
            5'd14, 5'd2,    // rs1_ex=x14, rs2_ex=x2
            5'd14, 1'b1,    // rd_mem=x14 (writing) - NEWER
            5'd14, 1'b1,    // rd_wb=x14 (writing) - OLDER
            FWD_MEM, FWD_NONE, // MEM takes priority
            "MEM priority over WB for rs1"
        );

        // Test 14: MEM has priority over WB for rs2
        check_forwarding(
            5'd1, 5'd22,    // rs1_ex=x1, rs2_ex=x22
            5'd22, 1'b1,    // rd_mem=x22 (writing) - NEWER
            5'd22, 1'b1,    // rd_wb=x22 (writing) - OLDER
            FWD_NONE, FWD_MEM, // MEM takes priority
            "MEM priority over WB for rs2"
        );

        // Test 15: Both operands - MEM priority
        check_forwarding(
            5'd9, 5'd9,     // rs1_ex=x9, rs2_ex=x9 (same)
            5'd9, 1'b1,     // rd_mem=x9 (writing) - NEWER
            5'd9, 1'b1,     // rd_wb=x9 (writing) - OLDER
            FWD_MEM, FWD_MEM, // Both from MEM (higher priority)
            "MEM priority for both operands"
        );

        // Test 16: Different sources - rs1 from MEM, rs2 from WB
        check_forwarding(
            5'd11, 5'd13,   // rs1_ex=x11, rs2_ex=x13
            5'd11, 1'b1,    // rd_mem=x11 (writing)
            5'd13, 1'b1,    // rd_wb=x13 (writing)
            FWD_MEM, FWD_WB, // rs1 from MEM, rs2 from WB
            "rs1 from MEM, rs2 from WB"
        );

        // Test 17: Different sources - rs1 from WB, rs2 from MEM
        check_forwarding(
            5'd16, 5'd17,   // rs1_ex=x16, rs2_ex=x17
            5'd17, 1'b1,    // rd_mem=x17 (writing)
            5'd16, 1'b1,    // rd_wb=x16 (writing)
            FWD_WB, FWD_MEM, // rs1 from WB, rs2 from MEM
            "rs1 from WB, rs2 from MEM"
        );

        // ====================================================================
        // Test Category 5: Edge Cases
        // ====================================================================
        $display("\n--- Test Category 5: Edge Cases ---");

        // Test 18: Maximum register number (x31)
        check_forwarding(
            5'd31, 5'd31,   // rs1_ex=x31, rs2_ex=x31
            5'd31, 1'b1,    // rd_mem=x31 (writing)
            5'd30, 1'b1,    // rd_wb=x30
            FWD_MEM, FWD_MEM, // Both from MEM
            "Forward x31 from MEM"
        );

        // Test 19: Only rs1 needs forwarding
        check_forwarding(
            5'd19, 5'd2,    // rs1_ex=x19, rs2_ex=x2
            5'd19, 1'b1,    // rd_mem=x19 (writing)
            5'd3, 1'b1,     // rd_wb=x3
            FWD_MEM, FWD_NONE, // Only rs1 forwards
            "Only rs1 needs forwarding"
        );

        // Test 20: Only rs2 needs forwarding
        check_forwarding(
            5'd1, 5'd21,    // rs1_ex=x1, rs2_ex=x21
            5'd3, 1'b1,     // rd_mem=x3
            5'd21, 1'b1,    // rd_wb=x21 (writing)
            FWD_NONE, FWD_WB, // Only rs2 forwards
            "Only rs2 needs forwarding"
        );

        // Test 21: MEM writes but doesn't match, WB matches
        check_forwarding(
            5'd23, 5'd24,   // rs1_ex=x23, rs2_ex=x24
            5'd5, 1'b1,     // rd_mem=x5 (doesn't match)
            5'd23, 1'b1,    // rd_wb=x23 (matches rs1)
            FWD_WB, FWD_NONE, // rs1 from WB, rs2 none
            "MEM doesn't match, WB matches"
        );

        // Test 22: All registers different, all writing
        check_forwarding(
            5'd26, 5'd27,   // rs1_ex=x26, rs2_ex=x27
            5'd28, 1'b1,    // rd_mem=x28
            5'd29, 1'b1,    // rd_wb=x29
            FWD_NONE, FWD_NONE, // No matches
            "All different registers"
        );

        // Test 23: MEM and WB write to x0 (should not forward)
        check_forwarding(
            5'd0, 5'd1,     // rs1_ex=x0, rs2_ex=x1
            5'd0, 1'b1,     // rd_mem=x0
            5'd1, 1'b1,     // rd_wb=x1
            FWD_NONE, FWD_WB, // x0 doesn't forward, x1 does
            "x0 from MEM doesn't forward, x1 from WB does"
        );

        // Test 24: Complex scenario - all active
        check_forwarding(
            5'd4, 5'd6,     // rs1_ex=x4, rs2_ex=x6
            5'd4, 1'b1,     // rd_mem=x4 (matches rs1)
            5'd6, 1'b1,     // rd_wb=x6 (matches rs2)
            FWD_MEM, FWD_WB, // rs1 from MEM (priority), rs2 from WB
            "Both operands forward from different stages"
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
        end
        else begin
            $display("\n*** SOME TESTS FAILED ***\n");
        end

        $finish;
    end

endmodule

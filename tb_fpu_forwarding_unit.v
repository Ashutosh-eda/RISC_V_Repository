// ============================================================================
// Testbench for FPU Forwarding Unit
// Tests FP forwarding from MEM and WB stages back to EX stage
// Self-checking with comprehensive test cases
// ============================================================================

`timescale 1ns / 1ps

module tb_fpu_forwarding_unit;

    // ========================================================================
    // DUT Signals
    // ========================================================================

    // Source register addresses (from ID/EX register)
    reg  [4:0]  rs1_ex;
    reg  [4:0]  rs2_ex;
    reg  [4:0]  rs3_ex;

    // Destination registers in later stages
    reg  [4:0]  rd_mem;
    reg  [4:0]  rd_wb;

    // FP register write enables
    reg         fp_reg_write_mem;
    reg         fp_reg_write_wb;

    // Stage information from scoreboard (unused in current design)
    reg  [1:0]  rs1_stage;
    reg  [1:0]  rs2_stage;
    reg  [1:0]  rs3_stage;

    // Outputs
    wire [1:0]  forward_x;  // For rs1
    wire [1:0]  forward_y;  // For rs2
    wire [1:0]  forward_z;  // For rs3

    // ========================================================================
    // DUT Instantiation
    // ========================================================================

    fpu_forwarding_unit dut (
        .rs1_ex(rs1_ex),
        .rs2_ex(rs2_ex),
        .rs3_ex(rs3_ex),
        .rd_mem(rd_mem),
        .rd_wb(rd_wb),
        .fp_reg_write_mem(fp_reg_write_mem),
        .fp_reg_write_wb(fp_reg_write_wb),
        .rs1_stage(rs1_stage),
        .rs2_stage(rs2_stage),
        .rs3_stage(rs3_stage),
        .forward_x(forward_x),
        .forward_y(forward_y),
        .forward_z(forward_z)
    );

    // ========================================================================
    // Test Infrastructure
    // ========================================================================

    integer test_count = 0;
    integer pass_count = 0;
    integer fail_count = 0;

    // Forwarding encoding constants
    localparam FWD_NONE = 2'b00;  // Use register file
    localparam FWD_WB   = 2'b01;  // Forward from WB stage
    localparam FWD_MEM  = 2'b10;  // Forward from MEM stage
    localparam FWD_INV  = 2'b11;  // Invalid (should not occur)

    // ========================================================================
    // Test Task
    // ========================================================================

    task check_forwarding;
        input [4:0]  test_rs1_ex;
        input [4:0]  test_rs2_ex;
        input [4:0]  test_rs3_ex;
        input [4:0]  test_rd_mem;
        input [4:0]  test_rd_wb;
        input        test_fp_reg_write_mem;
        input        test_fp_reg_write_wb;
        input [1:0]  exp_forward_x;
        input [1:0]  exp_forward_y;
        input [1:0]  exp_forward_z;
        input [200:0] description;

        begin
            test_count = test_count + 1;

            // Apply inputs
            rs1_ex = test_rs1_ex;
            rs2_ex = test_rs2_ex;
            rs3_ex = test_rs3_ex;
            rd_mem = test_rd_mem;
            rd_wb = test_rd_wb;
            fp_reg_write_mem = test_fp_reg_write_mem;
            fp_reg_write_wb = test_fp_reg_write_wb;

            // Stage inputs (not used by current design, but set anyway)
            rs1_stage = 2'b00;
            rs2_stage = 2'b00;
            rs3_stage = 2'b00;

            #10; // Wait for combinational logic

            // Check outputs
            if (forward_x === exp_forward_x &&
                forward_y === exp_forward_y &&
                forward_z === exp_forward_z) begin
                $display("[PASS] Test %0d: %s", test_count, description);
                $display("       X=%s, Y=%s, Z=%s",
                         decode_fwd(forward_x),
                         decode_fwd(forward_y),
                         decode_fwd(forward_z));
                pass_count = pass_count + 1;
            end
            else begin
                $display("[FAIL] Test %0d: %s", test_count, description);
                $display("       Expected: X=%s, Y=%s, Z=%s",
                         decode_fwd(exp_forward_x),
                         decode_fwd(exp_forward_y),
                         decode_fwd(exp_forward_z));
                $display("       Got:      X=%s, Y=%s, Z=%s",
                         decode_fwd(forward_x),
                         decode_fwd(forward_y),
                         decode_fwd(forward_z));
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
                2'b11: decode_fwd = "INV ";
                default: decode_fwd = "??? ";
            endcase
        end
    endfunction

    // ========================================================================
    // Test Stimulus
    // ========================================================================

    initial begin
        $display("\n========================================");
        $display("FPU Forwarding Unit Testbench");
        $display("========================================\n");

        // Initialize all inputs
        rs1_ex = 5'd0;
        rs2_ex = 5'd0;
        rs3_ex = 5'd0;
        rd_mem = 5'd0;
        rd_wb = 5'd0;
        fp_reg_write_mem = 1'b0;
        fp_reg_write_wb = 1'b0;
        rs1_stage = 2'b00;
        rs2_stage = 2'b00;
        rs3_stage = 2'b00;

        #5; // Initial delay

        // ====================================================================
        // Test Category 1: No Forwarding Cases
        // ====================================================================
        $display("\n--- Test Category 1: No Forwarding ---");

        // Test 1: All zeros (no operation)
        check_forwarding(
            5'd0, 5'd0, 5'd0,     // rs1_ex, rs2_ex, rs3_ex
            5'd0, 5'd0,           // rd_mem, rd_wb
            1'b0, 1'b0,           // fp_reg_write_mem, fp_reg_write_wb
            FWD_NONE, FWD_NONE, FWD_NONE,
            "No forwarding - all zeros"
        );

        // Test 2: Different registers (no dependency)
        check_forwarding(
            5'd1, 5'd2, 5'd3,     // rs1_ex=f1, rs2_ex=f2, rs3_ex=f3
            5'd4, 5'd5,           // rd_mem=f4, rd_wb=f5
            1'b1, 1'b1,           // Both writing
            FWD_NONE, FWD_NONE, FWD_NONE,
            "No forwarding - different registers"
        );

        // Test 3: Register match but write disabled
        check_forwarding(
            5'd6, 5'd7, 5'd8,     // rs1_ex=f6, rs2_ex=f7, rs3_ex=f8
            5'd6, 5'd7,           // rd_mem=f6, rd_wb=f7 (match)
            1'b0, 1'b0,           // Write disabled
            FWD_NONE, FWD_NONE, FWD_NONE,
            "No forwarding - write disabled"
        );

        // Test 4: Writing to f0 (should not forward)
        check_forwarding(
            5'd0, 5'd0, 5'd0,     // rs1_ex=f0, rs2_ex=f0, rs3_ex=f0
            5'd0, 5'd0,           // rd_mem=f0, rd_wb=f0
            1'b1, 1'b1,           // Writing
            FWD_NONE, FWD_NONE, FWD_NONE,
            "No forwarding - f0 is special"
        );

        // ====================================================================
        // Test Category 2: Forward from MEM Stage
        // ====================================================================
        $display("\n--- Test Category 2: Forward from MEM Stage ---");

        // Test 5: Forward X (rs1) from MEM
        check_forwarding(
            5'd10, 5'd2, 5'd3,    // rs1_ex=f10, rs2_ex=f2, rs3_ex=f3
            5'd10, 5'd4,          // rd_mem=f10 (match), rd_wb=f4
            1'b1, 1'b1,           // Both writing
            FWD_MEM, FWD_NONE, FWD_NONE,
            "Forward X from MEM stage"
        );

        // Test 6: Forward Y (rs2) from MEM
        check_forwarding(
            5'd1, 5'd15, 5'd3,    // rs1_ex=f1, rs2_ex=f15, rs3_ex=f3
            5'd15, 5'd4,          // rd_mem=f15 (match), rd_wb=f4
            1'b1, 1'b1,           // Both writing
            FWD_NONE, FWD_MEM, FWD_NONE,
            "Forward Y from MEM stage"
        );

        // Test 7: Forward Z (rs3) from MEM
        check_forwarding(
            5'd1, 5'd2, 5'd20,    // rs1_ex=f1, rs2_ex=f2, rs3_ex=f20
            5'd20, 5'd4,          // rd_mem=f20 (match), rd_wb=f4
            1'b1, 1'b1,           // Both writing
            FWD_NONE, FWD_NONE, FWD_MEM,
            "Forward Z from MEM stage"
        );

        // Test 8: Forward all three from MEM (same source)
        check_forwarding(
            5'd12, 5'd12, 5'd12,  // All operands use f12
            5'd12, 5'd5,          // rd_mem=f12 (match all)
            1'b1, 1'b1,           // Both writing
            FWD_MEM, FWD_MEM, FWD_MEM,
            "Forward all operands from MEM (same source)"
        );

        // Test 9: Forward X and Y from MEM (different sources)
        check_forwarding(
            5'd13, 5'd14, 5'd3,   // rs1_ex=f13, rs2_ex=f14, rs3_ex=f3
            5'd13, 5'd14,         // rd_mem=f13, rd_wb=f14
            1'b1, 1'b1,           // Both writing
            FWD_MEM, FWD_NONE, FWD_NONE,
            "Forward X from MEM (Y matches WB)"
        );

        // ====================================================================
        // Test Category 3: Forward from WB Stage
        // ====================================================================
        $display("\n--- Test Category 3: Forward from WB Stage ---");

        // Test 10: Forward X from WB
        check_forwarding(
            5'd20, 5'd2, 5'd3,    // rs1_ex=f20, rs2_ex=f2, rs3_ex=f3
            5'd5, 5'd20,          // rd_mem=f5, rd_wb=f20 (match)
            1'b1, 1'b1,           // Both writing
            FWD_WB, FWD_NONE, FWD_NONE,
            "Forward X from WB stage"
        );

        // Test 11: Forward Y from WB
        check_forwarding(
            5'd1, 5'd25, 5'd3,    // rs1_ex=f1, rs2_ex=f25, rs3_ex=f3
            5'd5, 5'd25,          // rd_mem=f5, rd_wb=f25 (match)
            1'b1, 1'b1,           // Both writing
            FWD_NONE, FWD_WB, FWD_NONE,
            "Forward Y from WB stage"
        );

        // Test 12: Forward Z from WB
        check_forwarding(
            5'd1, 5'd2, 5'd28,    // rs1_ex=f1, rs2_ex=f2, rs3_ex=f28
            5'd5, 5'd28,          // rd_mem=f5, rd_wb=f28 (match)
            1'b1, 1'b1,           // Both writing
            FWD_NONE, FWD_NONE, FWD_WB,
            "Forward Z from WB stage"
        );

        // Test 13: Forward all three from WB (same source)
        check_forwarding(
            5'd18, 5'd18, 5'd18,  // All operands use f18
            5'd5, 5'd18,          // rd_mem=f5, rd_wb=f18 (match all)
            1'b1, 1'b1,           // Both writing
            FWD_WB, FWD_WB, FWD_WB,
            "Forward all operands from WB (same source)"
        );

        // ====================================================================
        // Test Category 4: Priority Testing (MEM > WB)
        // ====================================================================
        $display("\n--- Test Category 4: Forwarding Priority (MEM > WB) ---");

        // Test 14: MEM has priority over WB for X
        check_forwarding(
            5'd14, 5'd2, 5'd3,    // rs1_ex=f14, rs2_ex=f2, rs3_ex=f3
            5'd14, 5'd14,         // Both match f14
            1'b1, 1'b1,           // Both writing
            FWD_MEM, FWD_NONE, FWD_NONE,
            "MEM priority over WB for X"
        );

        // Test 15: MEM has priority over WB for Y
        check_forwarding(
            5'd1, 5'd22, 5'd3,    // rs1_ex=f1, rs2_ex=f22, rs3_ex=f3
            5'd22, 5'd22,         // Both match f22
            1'b1, 1'b1,           // Both writing
            FWD_NONE, FWD_MEM, FWD_NONE,
            "MEM priority over WB for Y"
        );

        // Test 16: MEM has priority over WB for Z
        check_forwarding(
            5'd1, 5'd2, 5'd26,    // rs1_ex=f1, rs2_ex=f2, rs3_ex=f26
            5'd26, 5'd26,         // Both match f26
            1'b1, 1'b1,           // Both writing
            FWD_NONE, FWD_NONE, FWD_MEM,
            "MEM priority over WB for Z"
        );

        // Test 17: All operands - MEM priority
        check_forwarding(
            5'd9, 5'd9, 5'd9,     // All use f9
            5'd9, 5'd9,           // Both match f9
            1'b1, 1'b1,           // Both writing
            FWD_MEM, FWD_MEM, FWD_MEM,
            "MEM priority for all operands"
        );

        // ====================================================================
        // Test Category 5: Mixed Forwarding Sources
        // ====================================================================
        $display("\n--- Test Category 5: Mixed Forwarding Sources ---");

        // Test 18: X from MEM, Y from WB, Z none
        check_forwarding(
            5'd11, 5'd13, 5'd3,   // rs1_ex=f11, rs2_ex=f13, rs3_ex=f3
            5'd11, 5'd13,         // rd_mem=f11, rd_wb=f13
            1'b1, 1'b1,           // Both writing
            FWD_MEM, FWD_WB, FWD_NONE,
            "X from MEM, Y from WB, Z none"
        );

        // Test 19: X from WB, Y from MEM, Z none
        check_forwarding(
            5'd16, 5'd17, 5'd3,   // rs1_ex=f16, rs2_ex=f17, rs3_ex=f3
            5'd17, 5'd16,         // rd_mem=f17, rd_wb=f16
            1'b1, 1'b1,           // Both writing
            FWD_WB, FWD_MEM, FWD_NONE,
            "X from WB, Y from MEM, Z none"
        );

        // Test 20: X from MEM, Y none, Z from WB
        check_forwarding(
            5'd19, 5'd2, 5'd21,   // rs1_ex=f19, rs2_ex=f2, rs3_ex=f21
            5'd19, 5'd21,         // rd_mem=f19, rd_wb=f21
            1'b1, 1'b1,           // Both writing
            FWD_MEM, FWD_NONE, FWD_WB,
            "X from MEM, Y none, Z from WB"
        );

        // Test 21: X none, Y from MEM, Z from WB
        check_forwarding(
            5'd1, 5'd23, 5'd24,   // rs1_ex=f1, rs2_ex=f23, rs3_ex=f24
            5'd23, 5'd24,         // rd_mem=f23, rd_wb=f24
            1'b1, 1'b1,           // Both writing
            FWD_NONE, FWD_MEM, FWD_WB,
            "X none, Y from MEM, Z from WB"
        );

        // Test 22: All three from different sources (complex)
        check_forwarding(
            5'd27, 5'd28, 5'd27,  // X and Z use same (f27), Y uses f28
            5'd27, 5'd28,         // rd_mem=f27, rd_wb=f28
            1'b1, 1'b1,           // Both writing
            FWD_MEM, FWD_WB, FWD_MEM,
            "X and Z from MEM (same), Y from WB"
        );

        // ====================================================================
        // Test Category 6: Edge Cases
        // ====================================================================
        $display("\n--- Test Category 6: Edge Cases ---");

        // Test 23: Maximum register f31
        check_forwarding(
            5'd31, 5'd30, 5'd29,  // rs1_ex=f31, rs2_ex=f30, rs3_ex=f29
            5'd31, 5'd30,         // rd_mem=f31, rd_wb=f30
            1'b1, 1'b1,           // Both writing
            FWD_MEM, FWD_WB, FWD_NONE,
            "Forward f31 from MEM, f30 from WB"
        );

        // Test 24: Only MEM writes (WB disabled)
        check_forwarding(
            5'd7, 5'd8, 5'd9,     // rs1_ex=f7, rs2_ex=f8, rs3_ex=f9
            5'd7, 5'd8,           // rd_mem=f7, rd_wb=f8
            1'b1, 1'b0,           // Only MEM writing
            FWD_MEM, FWD_NONE, FWD_NONE,
            "Only MEM writes - X from MEM, Y none"
        );

        // Test 25: Only WB writes (MEM disabled)
        check_forwarding(
            5'd7, 5'd8, 5'd9,     // rs1_ex=f7, rs2_ex=f8, rs3_ex=f9
            5'd7, 5'd8,           // rd_mem=f7, rd_wb=f8
            1'b0, 1'b1,           // Only WB writing
            FWD_NONE, FWD_WB, FWD_NONE,
            "Only WB writes - Y from WB, X none"
        );

        // Test 26: All registers same, forward from MEM
        check_forwarding(
            5'd15, 5'd15, 5'd15,  // All use f15
            5'd15, 5'd20,         // rd_mem=f15 (match), rd_wb=f20
            1'b1, 1'b1,           // Both writing
            FWD_MEM, FWD_MEM, FWD_MEM,
            "All same register, all from MEM"
        );

        // Test 27: Partial match - only X and Z
        check_forwarding(
            5'd10, 5'd2, 5'd10,   // X and Z use f10
            5'd10, 5'd5,          // rd_mem=f10 (match X and Z)
            1'b1, 1'b1,           // Both writing
            FWD_MEM, FWD_NONE, FWD_MEM,
            "X and Z from MEM (same source), Y none"
        );

        // Test 28: No sources match (extreme case)
        check_forwarding(
            5'd1, 5'd2, 5'd3,     // rs1_ex=f1, rs2_ex=f2, rs3_ex=f3
            5'd4, 5'd5,           // rd_mem=f4, rd_wb=f5 (no matches)
            1'b1, 1'b1,           // Both writing
            FWD_NONE, FWD_NONE, FWD_NONE,
            "No sources match - all NONE"
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

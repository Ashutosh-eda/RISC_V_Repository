// ============================================================================
// Testbench for Hazard Detection Unit
// Tests load-use hazard detection, branch flushing, and FPU stalls
// Self-checking with comprehensive test cases
// ============================================================================

`timescale 1ns / 1ps

module tb_hazard_unit;

    // ========================================================================
    // DUT Signals
    // ========================================================================

    // From Decode Stage
    reg  [4:0]  rs1_id;
    reg  [4:0]  rs2_id;

    // From Execute Stage
    reg  [4:0]  rd_ex;
    reg         mem_read_ex;
    reg         reg_write_ex;

    // From Memory Stage
    reg  [4:0]  rd_mem;
    reg         reg_write_mem;

    // From Writeback Stage
    reg  [4:0]  rd_wb;
    reg         reg_write_wb;

    // Branch/Jump Control
    reg         branch_taken;

    // FPU Hazard
    reg         stall_fpu;

    // Outputs
    wire        stall_if;
    wire        stall_id;
    wire        flush_id;
    wire        flush_ex;

    // ========================================================================
    // DUT Instantiation
    // ========================================================================

    hazard_unit dut (
        .rs1_id(rs1_id),
        .rs2_id(rs2_id),
        .rd_ex(rd_ex),
        .mem_read_ex(mem_read_ex),
        .reg_write_ex(reg_write_ex),
        .rd_mem(rd_mem),
        .reg_write_mem(reg_write_mem),
        .rd_wb(rd_wb),
        .reg_write_wb(reg_write_wb),
        .branch_taken(branch_taken),
        .stall_fpu(stall_fpu),
        .stall_if(stall_if),
        .stall_id(stall_id),
        .flush_id(flush_id),
        .flush_ex(flush_ex)
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

    task check_hazard;
        input [4:0]  test_rs1_id;
        input [4:0]  test_rs2_id;
        input [4:0]  test_rd_ex;
        input        test_mem_read_ex;
        input        test_reg_write_ex;
        input [4:0]  test_rd_mem;
        input        test_reg_write_mem;
        input [4:0]  test_rd_wb;
        input        test_reg_write_wb;
        input        test_branch_taken;
        input        test_stall_fpu;
        input        exp_stall_if;
        input        exp_stall_id;
        input        exp_flush_id;
        input        exp_flush_ex;
        input [200:0] description;

        begin
            test_count = test_count + 1;

            // Apply inputs
            rs1_id = test_rs1_id;
            rs2_id = test_rs2_id;
            rd_ex = test_rd_ex;
            mem_read_ex = test_mem_read_ex;
            reg_write_ex = test_reg_write_ex;
            rd_mem = test_rd_mem;
            reg_write_mem = test_reg_write_mem;
            rd_wb = test_rd_wb;
            reg_write_wb = test_reg_write_wb;
            branch_taken = test_branch_taken;
            stall_fpu = test_stall_fpu;

            #10; // Wait for combinational logic

            // Check outputs
            if (stall_if === exp_stall_if &&
                stall_id === exp_stall_id &&
                flush_id === exp_flush_id &&
                flush_ex === exp_flush_ex) begin
                $display("[PASS] Test %0d: %s", test_count, description);
                pass_count = pass_count + 1;
            end
            else begin
                $display("[FAIL] Test %0d: %s", test_count, description);
                $display("       Expected: stall_if=%b stall_id=%b flush_id=%b flush_ex=%b",
                         exp_stall_if, exp_stall_id, exp_flush_id, exp_flush_ex);
                $display("       Got:      stall_if=%b stall_id=%b flush_id=%b flush_ex=%b",
                         stall_if, stall_id, flush_id, flush_ex);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // ========================================================================
    // Test Stimulus
    // ========================================================================

    initial begin
        $display("\n========================================");
        $display("Hazard Unit Testbench");
        $display("========================================\n");

        // Initialize all inputs
        rs1_id = 5'd0;
        rs2_id = 5'd0;
        rd_ex = 5'd0;
        mem_read_ex = 1'b0;
        reg_write_ex = 1'b0;
        rd_mem = 5'd0;
        reg_write_mem = 1'b0;
        rd_wb = 5'd0;
        reg_write_wb = 1'b0;
        branch_taken = 1'b0;
        stall_fpu = 1'b0;

        #5; // Initial delay

        // ====================================================================
        // Test Category 1: No Hazards
        // ====================================================================
        $display("\n--- Test Category 1: No Hazards ---");

        // Test 1: All zeros (no operation)
        check_hazard(
            5'd0, 5'd0,     // rs1_id, rs2_id
            5'd0, 1'b0, 1'b0, // rd_ex, mem_read_ex, reg_write_ex
            5'd0, 1'b0,     // rd_mem, reg_write_mem
            5'd0, 1'b0,     // rd_wb, reg_write_wb
            1'b0, 1'b0,     // branch_taken, stall_fpu
            1'b0, 1'b0, 1'b0, 1'b0, // Expected: no stalls/flushes
            "No hazard - all zeros"
        );

        // Test 2: No dependency (different registers)
        check_hazard(
            5'd1, 5'd2,     // rs1_id=x1, rs2_id=x2
            5'd3, 1'b1, 1'b1, // rd_ex=x3 (load)
            5'd4, 1'b1,     // rd_mem=x4
            5'd5, 1'b1,     // rd_wb=x5
            1'b0, 1'b0,     // No branch, no FPU stall
            1'b0, 1'b0, 1'b0, 1'b0, // No hazard
            "No hazard - different registers"
        );

        // Test 3: Write to x0 (should not cause hazard)
        check_hazard(
            5'd0, 5'd0,     // rs1_id=x0, rs2_id=x0
            5'd0, 1'b1, 1'b1, // rd_ex=x0 (load)
            5'd0, 1'b1,     // rd_mem=x0
            5'd0, 1'b1,     // rd_wb=x0
            1'b0, 1'b0,     // No branch, no FPU stall
            1'b0, 1'b0, 1'b0, 1'b0, // No hazard (x0 is hardwired to 0)
            "No hazard - writes to x0"
        );

        // ====================================================================
        // Test Category 2: Load-Use Hazards
        // ====================================================================
        $display("\n--- Test Category 2: Load-Use Hazards ---");

        // Test 4: Load-use hazard on rs1
        check_hazard(
            5'd10, 5'd2,    // rs1_id=x10, rs2_id=x2
            5'd10, 1'b1, 1'b1, // rd_ex=x10 (load in EX)
            5'd4, 1'b1,     // rd_mem=x4
            5'd5, 1'b1,     // rd_wb=x5
            1'b0, 1'b0,     // No branch, no FPU stall
            1'b1, 1'b1, 1'b0, 1'b1, // Stall IF/ID, flush EX
            "Load-use hazard on rs1"
        );

        // Test 5: Load-use hazard on rs2
        check_hazard(
            5'd1, 5'd15,    // rs1_id=x1, rs2_id=x15
            5'd15, 1'b1, 1'b1, // rd_ex=x15 (load in EX)
            5'd4, 1'b1,     // rd_mem=x4
            5'd5, 1'b1,     // rd_wb=x5
            1'b0, 1'b0,     // No branch, no FPU stall
            1'b1, 1'b1, 1'b0, 1'b1, // Stall IF/ID, flush EX
            "Load-use hazard on rs2"
        );

        // Test 6: Load-use hazard on both rs1 and rs2
        check_hazard(
            5'd7, 5'd7,     // rs1_id=x7, rs2_id=x7
            5'd7, 1'b1, 1'b1, // rd_ex=x7 (load in EX)
            5'd4, 1'b1,     // rd_mem=x4
            5'd5, 1'b1,     // rd_wb=x5
            1'b0, 1'b0,     // No branch, no FPU stall
            1'b1, 1'b1, 1'b0, 1'b1, // Stall IF/ID, flush EX
            "Load-use hazard on both rs1 and rs2"
        );

        // Test 7: Not a load (mem_read_ex=0), so no hazard
        check_hazard(
            5'd10, 5'd2,    // rs1_id=x10, rs2_id=x2
            5'd10, 1'b0, 1'b1, // rd_ex=x10 (not a load)
            5'd4, 1'b1,     // rd_mem=x4
            5'd5, 1'b1,     // rd_wb=x5
            1'b0, 1'b0,     // No branch, no FPU stall
            1'b0, 1'b0, 1'b0, 1'b0, // No hazard
            "No load-use hazard (not a load)"
        );

        // Test 8: Not writing (reg_write_ex=0), so no hazard
        check_hazard(
            5'd10, 5'd2,    // rs1_id=x10, rs2_id=x2
            5'd10, 1'b1, 1'b0, // rd_ex=x10 (load but not writing)
            5'd4, 1'b1,     // rd_mem=x4
            5'd5, 1'b1,     // rd_wb=x5
            1'b0, 1'b0,     // No branch, no FPU stall
            1'b0, 1'b0, 1'b0, 1'b0, // No hazard
            "No load-use hazard (not writing)"
        );

        // ====================================================================
        // Test Category 3: Branch/Jump Hazards
        // ====================================================================
        $display("\n--- Test Category 3: Branch/Jump Hazards ---");

        // Test 9: Branch taken - flush IF and ID stages
        check_hazard(
            5'd1, 5'd2,     // rs1_id=x1, rs2_id=x2
            5'd3, 1'b0, 1'b1, // rd_ex=x3
            5'd4, 1'b1,     // rd_mem=x4
            5'd5, 1'b1,     // rd_wb=x5
            1'b1, 1'b0,     // Branch taken, no FPU stall
            1'b0, 1'b0, 1'b1, 1'b1, // No stall, flush ID and EX
            "Branch taken - flush pipeline"
        );

        // Test 10: Jump taken (also uses branch_taken signal)
        check_hazard(
            5'd10, 5'd11,   // rs1_id=x10, rs2_id=x11
            5'd12, 1'b0, 1'b1, // rd_ex=x12
            5'd13, 1'b1,    // rd_mem=x13
            5'd14, 1'b1,    // rd_wb=x14
            1'b1, 1'b0,     // Jump taken, no FPU stall
            1'b0, 1'b0, 1'b1, 1'b1, // No stall, flush ID and EX
            "Jump taken - flush pipeline"
        );

        // Test 11: Branch not taken - no action
        check_hazard(
            5'd1, 5'd2,     // rs1_id=x1, rs2_id=x2
            5'd3, 1'b0, 1'b1, // rd_ex=x3
            5'd4, 1'b1,     // rd_mem=x4
            5'd5, 1'b1,     // rd_wb=x5
            1'b0, 1'b0,     // Branch not taken, no FPU stall
            1'b0, 1'b0, 1'b0, 1'b0, // No hazard
            "Branch not taken - no flush"
        );

        // ====================================================================
        // Test Category 4: FPU Hazards
        // ====================================================================
        $display("\n--- Test Category 4: FPU Hazards ---");

        // Test 12: FPU stall asserted
        check_hazard(
            5'd1, 5'd2,     // rs1_id=f1, rs2_id=f2
            5'd3, 1'b0, 1'b0, // rd_ex=f3
            5'd4, 1'b0,     // rd_mem=f4
            5'd5, 1'b0,     // rd_wb=f5
            1'b0, 1'b1,     // No branch, FPU stall asserted
            1'b1, 1'b1, 1'b0, 1'b1, // Stall IF/ID, flush EX
            "FPU stall - insert bubble"
        );

        // Test 13: FPU stall not asserted
        check_hazard(
            5'd1, 5'd2,     // rs1_id=f1, rs2_id=f2
            5'd3, 1'b0, 1'b0, // rd_ex=f3
            5'd4, 1'b0,     // rd_mem=f4
            5'd5, 1'b0,     // rd_wb=f5
            1'b0, 1'b0,     // No branch, no FPU stall
            1'b0, 1'b0, 1'b0, 1'b0, // No hazard
            "FPU no stall - normal operation"
        );

        // ====================================================================
        // Test Category 5: Combined Hazards (Priority Testing)
        // ====================================================================
        $display("\n--- Test Category 5: Combined Hazards ---");

        // Test 14: Load-use hazard + branch taken (load-use takes priority for stall)
        check_hazard(
            5'd10, 5'd2,    // rs1_id=x10, rs2_id=x2
            5'd10, 1'b1, 1'b1, // rd_ex=x10 (load)
            5'd4, 1'b1,     // rd_mem=x4
            5'd5, 1'b1,     // rd_wb=x5
            1'b1, 1'b0,     // Branch taken, no FPU stall
            1'b0, 1'b0, 1'b1, 1'b1, // Branch flushes (overrides load-use)
            "Branch taken overrides load-use hazard"
        );

        // Test 15: FPU stall + branch taken (branch takes priority for flush)
        check_hazard(
            5'd1, 5'd2,     // rs1_id=f1, rs2_id=f2
            5'd3, 1'b0, 1'b0, // rd_ex=f3
            5'd4, 1'b0,     // rd_mem=f4
            5'd5, 1'b0,     // rd_wb=f5
            1'b1, 1'b1,     // Branch taken, FPU stall
            1'b0, 1'b0, 1'b1, 1'b1, // Branch flushes (overrides FPU stall)
            "Branch taken overrides FPU stall"
        );

        // Test 16: Load-use + FPU stall (both cause stalls)
        check_hazard(
            5'd10, 5'd2,    // rs1_id=x10, rs2_id=x2
            5'd10, 1'b1, 1'b1, // rd_ex=x10 (load)
            5'd4, 1'b1,     // rd_mem=x4
            5'd5, 1'b1,     // rd_wb=x5
            1'b0, 1'b1,     // No branch, FPU stall
            1'b1, 1'b1, 1'b0, 1'b1, // Stall IF/ID, flush EX
            "Load-use + FPU stall combined"
        );

        // ====================================================================
        // Test Category 6: Edge Cases
        // ====================================================================
        $display("\n--- Test Category 6: Edge Cases ---");

        // Test 17: Maximum register number (x31)
        check_hazard(
            5'd31, 5'd31,   // rs1_id=x31, rs2_id=x31
            5'd31, 1'b1, 1'b1, // rd_ex=x31 (load)
            5'd31, 1'b1,    // rd_mem=x31
            5'd31, 1'b1,    // rd_wb=x31
            1'b0, 1'b0,     // No branch, no FPU stall
            1'b1, 1'b1, 1'b0, 1'b1, // Load-use hazard
            "Load-use hazard with x31"
        );

        // Test 18: Only rs1 matches (rs2 doesn't)
        check_hazard(
            5'd8, 5'd9,     // rs1_id=x8, rs2_id=x9
            5'd8, 1'b1, 1'b1, // rd_ex=x8 (load)
            5'd4, 1'b1,     // rd_mem=x4
            5'd5, 1'b1,     // rd_wb=x5
            1'b0, 1'b0,     // No branch, no FPU stall
            1'b1, 1'b1, 1'b0, 1'b1, // Load-use hazard on rs1
            "Load-use hazard on rs1 only"
        );

        // Test 19: Only rs2 matches (rs1 doesn't)
        check_hazard(
            5'd8, 5'd9,     // rs1_id=x8, rs2_id=x9
            5'd9, 1'b1, 1'b1, // rd_ex=x9 (load)
            5'd4, 1'b1,     // rd_mem=x4
            5'd5, 1'b1,     // rd_wb=x5
            1'b0, 1'b0,     // No branch, no FPU stall
            1'b1, 1'b1, 1'b0, 1'b1, // Load-use hazard on rs2
            "Load-use hazard on rs2 only"
        );

        // Test 20: All control signals active
        check_hazard(
            5'd10, 5'd10,   // rs1_id=x10, rs2_id=x10
            5'd10, 1'b1, 1'b1, // rd_ex=x10 (load)
            5'd10, 1'b1,    // rd_mem=x10
            5'd10, 1'b1,    // rd_wb=x10
            1'b1, 1'b1,     // Branch taken, FPU stall
            1'b0, 1'b0, 1'b1, 1'b1, // Branch flush dominates
            "All hazards + branch (branch dominates)"
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

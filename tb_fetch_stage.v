// ============================================================================
// Testbench for Fetch Stage
// Tests PC management, sequential execution, branches, and stalls
// Verifies PC+4 calculation and branch target handling
// Self-checking with comprehensive test cases
// ============================================================================

`timescale 1ns / 1ps

module tb_fetch_stage;

    // ========================================================================
    // Clock and Reset
    // ========================================================================

    reg clk;
    reg rst_n;

    // ========================================================================
    // DUT Signals
    // ========================================================================

    reg        stall;
    reg        branch_taken;
    reg [31:0] branch_target;

    wire [31:0] pc_out;
    wire [31:0] pc_plus4;
    wire [31:0] imem_addr;
    wire        imem_req;

    // ========================================================================
    // DUT Instantiation
    // ========================================================================

    fetch_stage dut (
        .clk(clk),
        .rst_n(rst_n),
        .stall(stall),
        .branch_taken(branch_taken),
        .branch_target(branch_target),
        .pc_out(pc_out),
        .pc_plus4(pc_plus4),
        .imem_addr(imem_addr),
        .imem_req(imem_req)
    );

    // ========================================================================
    // Clock Generation
    // ========================================================================

    initial clk = 0;
    always #5 clk = ~clk;

    // ========================================================================
    // Test Infrastructure
    // ========================================================================

    integer test_count = 0;
    integer pass_count = 0;
    integer fail_count = 0;

    // ========================================================================
    // Test Tasks
    // ========================================================================

    task check_pc;
        input [31:0] exp_pc;
        input [31:0] exp_pc_plus4;
        input [200:0] description;
        begin
            test_count = test_count + 1;
            #1;

            if (pc_out === exp_pc && pc_plus4 === exp_pc_plus4 && imem_addr === exp_pc) begin
                $display("[PASS] Test %0d: %s", test_count, description);
                $display("       PC=0x%h, PC+4=0x%h", pc_out, pc_plus4);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] Test %0d: %s", test_count, description);
                $display("       Expected: PC=0x%h, PC+4=0x%h", exp_pc, exp_pc_plus4);
                $display("       Got:      PC=0x%h, PC+4=0x%h", pc_out, pc_plus4);
                fail_count = fail_count + 1;
            end
        end
    endtask

    task wait_cycle;
        begin
            @(posedge clk);
        end
    endtask

    // ========================================================================
    // Test Stimulus
    // ========================================================================

    initial begin
        $display("\n========================================");
        $display("Fetch Stage Testbench");
        $display("========================================\n");

        // Initialize
        rst_n = 0;
        stall = 0;
        branch_taken = 0;
        branch_target = 32'd0;

        repeat(3) @(posedge clk);
        rst_n = 1;
        @(posedge clk);

        // ====================================================================
        // Test Category 1: Reset and Initialization
        // ====================================================================
        $display("\n--- Test Category 1: Reset and Initialization ---");

        check_pc(
            32'h00000000, 32'h00000004,
            "PC initializes to 0x00000000 after reset"
        );

        test_count = test_count + 1;
        if (imem_req === 1'b1) begin
            $display("[PASS] Test %0d: imem_req is asserted", test_count);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Test %0d: imem_req should be 1", test_count);
            fail_count = fail_count + 1;
        end

        // ====================================================================
        // Test Category 2: Sequential Execution (PC += 4)
        // ====================================================================
        $display("\n--- Test Category 2: Sequential Execution ---");

        wait_cycle();
        check_pc(
            32'h00000004, 32'h00000008,
            "PC increments to 0x00000004"
        );

        wait_cycle();
        check_pc(
            32'h00000008, 32'h0000000C,
            "PC increments to 0x00000008"
        );

        wait_cycle();
        check_pc(
            32'h0000000C, 32'h00000010,
            "PC increments to 0x0000000C"
        );

        wait_cycle();
        check_pc(
            32'h00000010, 32'h00000014,
            "PC increments to 0x00000010"
        );

        // ====================================================================
        // Test Category 3: Branch Taken
        // ====================================================================
        $display("\n--- Test Category 3: Branch Taken ---");

        branch_taken = 1;
        branch_target = 32'h00001000;
        wait_cycle();
        branch_taken = 0;

        check_pc(
            32'h00001000, 32'h00001004,
            "PC jumps to branch target 0x00001000"
        );

        wait_cycle();
        check_pc(
            32'h00001004, 32'h00001008,
            "PC resumes sequential after branch"
        );

        // ====================================================================
        // Test Category 4: Backward Branch
        // ====================================================================
        $display("\n--- Test Category 4: Backward Branch (Loop) ---");

        branch_taken = 1;
        branch_target = 32'h00000100;
        wait_cycle();
        branch_taken = 0;

        check_pc(
            32'h00000100, 32'h00000104,
            "PC jumps backward to 0x00000100"
        );

        wait_cycle();
        check_pc(
            32'h00000104, 32'h00000108,
            "PC continues from backward branch target"
        );

        // ====================================================================
        // Test Category 5: Pipeline Stall
        // ====================================================================
        $display("\n--- Test Category 5: Pipeline Stall ---");

        stall = 1;
        wait_cycle();

        check_pc(
            32'h00000108, 32'h0000010C,
            "PC held during stall (PC=0x00000108)"
        );

        wait_cycle();
        check_pc(
            32'h00000108, 32'h0000010C,
            "PC remains stalled"
        );

        stall = 0;
        wait_cycle();

        check_pc(
            32'h0000010C, 32'h00000110,
            "PC resumes after stall"
        );

        // ====================================================================
        // Test Category 6: Branch During Stall (Priority)
        // ====================================================================
        $display("\n--- Test Category 6: Branch Priority over Stall ---");

        stall = 1;
        branch_taken = 1;
        branch_target = 32'h00002000;
        wait_cycle();
        stall = 0;
        branch_taken = 0;

        check_pc(
            32'h00002000, 32'h00002004,
            "Branch overrides stall (PC=0x00002000)"
        );

        // ====================================================================
        // Test Category 7: Multiple Consecutive Branches
        // ====================================================================
        $display("\n--- Test Category 7: Consecutive Branches ---");

        branch_taken = 1;
        branch_target = 32'h00003000;
        wait_cycle();

        branch_target = 32'h00004000;
        wait_cycle();

        branch_target = 32'h00005000;
        wait_cycle();
        branch_taken = 0;

        check_pc(
            32'h00005000, 32'h00005004,
            "Final PC after consecutive branches"
        );

        // ====================================================================
        // Test Category 8: Zero Address Branch
        // ====================================================================
        $display("\n--- Test Category 8: Branch to Address 0 ---");

        branch_taken = 1;
        branch_target = 32'h00000000;
        wait_cycle();
        branch_taken = 0;

        check_pc(
            32'h00000000, 32'h00000004,
            "Branch to reset vector (0x00000000)"
        );

        // ====================================================================
        // Test Category 9: Unaligned Branch Target (Allowed)
        // ====================================================================
        $display("\n--- Test Category 9: Unaligned Branch Target ---");

        branch_taken = 1;
        branch_target = 32'h00001002;  // Misaligned (not word-aligned)
        wait_cycle();
        branch_taken = 0;

        check_pc(
            32'h00001002, 32'h00001006,
            "Branch to unaligned address (hardware allows)"
        );

        // ====================================================================
        // Test Category 10: Long Sequential Run
        // ====================================================================
        $display("\n--- Test Category 10: Long Sequential Execution ---");

        // Branch to known address
        branch_taken = 1;
        branch_target = 32'h00010000;
        wait_cycle();
        branch_taken = 0;

        // Run 10 sequential cycles
        integer i;
        for (i = 0; i < 10; i = i + 1) begin
            test_count = test_count + 1;
            if (pc_out === (32'h00010000 + (i * 4)) &&
                pc_plus4 === (32'h00010004 + (i * 4))) begin
                $display("[PASS] Test %0d: Sequential [%0d] PC=0x%h",
                         test_count, i, pc_out);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] Test %0d: Sequential [%0d] expected 0x%h, got 0x%h",
                         test_count, i, (32'h00010000 + (i * 4)), pc_out);
                fail_count = fail_count + 1;
            end
            wait_cycle();
        end

        // ====================================================================
        // Test Category 11: Maximum Address Range
        // ====================================================================
        $display("\n--- Test Category 11: Maximum Address ---");

        branch_taken = 1;
        branch_target = 32'hFFFFFFFC;
        wait_cycle();
        branch_taken = 0;

        check_pc(
            32'hFFFFFFFC, 32'h00000000,
            "PC at max address (wraps on PC+4)"
        );

        wait_cycle();
        check_pc(
            32'h00000000, 32'h00000004,
            "PC wraps to 0 after max"
        );

        // ====================================================================
        // Test Category 12: Reset During Operation
        // ====================================================================
        $display("\n--- Test Category 12: Reset During Operation ---");

        branch_taken = 1;
        branch_target = 32'h00008000;
        wait_cycle();
        branch_taken = 0;
        wait_cycle();

        rst_n = 0;
        @(posedge clk);
        rst_n = 1;
        @(posedge clk);

        check_pc(
            32'h00000000, 32'h00000004,
            "PC resets to 0 after reset"
        );

        // ====================================================================
        // Test Category 13: Stall and Resume Pattern
        // ====================================================================
        $display("\n--- Test Category 13: Stall/Resume Pattern ---");

        for (i = 0; i < 3; i = i + 1) begin
            wait_cycle();  // Normal cycle
            stall = 1;
            wait_cycle();  // Stalled cycle
            stall = 0;
        end

        test_count = test_count + 1;
        if (pc_out === 32'h0000000C) begin
            $display("[PASS] Test %0d: Stall/resume pattern correct (PC=0x%h)",
                     test_count, pc_out);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Test %0d: Expected PC=0x0000000C, got 0x%h",
                     test_count, pc_out);
            fail_count = fail_count + 1;
        end

        // ====================================================================
        // Test Category 14: imem_req Always Asserted
        // ====================================================================
        $display("\n--- Test Category 14: imem_req Signal ---");

        for (i = 0; i < 5; i = i + 1) begin
            test_count = test_count + 1;
            if (imem_req === 1'b1) begin
                $display("[PASS] Test %0d: imem_req=1 (cycle %0d)",
                         test_count, i);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] Test %0d: imem_req should be 1 (cycle %0d)",
                         test_count, i);
                fail_count = fail_count + 1;
            end
            wait_cycle();
        end

        // ====================================================================
        // Test Summary
        // ====================================================================
        @(posedge clk);
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

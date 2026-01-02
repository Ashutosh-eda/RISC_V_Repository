// ============================================================================
// Testbench for IF/ID Pipeline Register
// Tests instruction/PC storage, stall, flush, and reset operations
// Verifies proper bubble insertion and value retention
// Self-checking with comprehensive test cases
// ============================================================================

`timescale 1ns / 1ps

module tb_if_id_reg;

    // ========================================================================
    // Clock and Reset
    // ========================================================================

    reg clk;
    reg rst_n;

    // ========================================================================
    // DUT Signals
    // ========================================================================

    reg        stall;
    reg        flush;
    reg [31:0] pc_if;
    reg [31:0] instr_if;
    reg [31:0] pc_plus4_if;

    wire [31:0] pc_id;
    wire [31:0] instr_id;
    wire [31:0] pc_plus4_id;

    // ========================================================================
    // DUT Instantiation
    // ========================================================================

    if_id_reg dut (
        .clk(clk),
        .rst_n(rst_n),
        .stall(stall),
        .flush(flush),
        .pc_if(pc_if),
        .instr_if(instr_if),
        .pc_plus4_if(pc_plus4_if),
        .pc_id(pc_id),
        .instr_id(instr_id),
        .pc_plus4_id(pc_plus4_id)
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

    localparam NOP = 32'h0000_0013;

    // ========================================================================
    // Test Tasks
    // ========================================================================

    task check_outputs;
        input [31:0] exp_pc;
        input [31:0] exp_instr;
        input [31:0] exp_pc_plus4;
        input [200:0] description;
        begin
            test_count = test_count + 1;
            #1;

            if (pc_id === exp_pc && instr_id === exp_instr && pc_plus4_id === exp_pc_plus4) begin
                $display("[PASS] Test %0d: %s", test_count, description);
                $display("       pc_id=0x%h, instr_id=0x%h, pc_plus4_id=0x%h",
                         pc_id, instr_id, pc_plus4_id);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] Test %0d: %s", test_count, description);
                $display("       Expected: pc=0x%h, instr=0x%h, pc_plus4=0x%h",
                         exp_pc, exp_instr, exp_pc_plus4);
                $display("       Got:      pc=0x%h, instr=0x%h, pc_plus4=0x%h",
                         pc_id, instr_id, pc_plus4_id);
                fail_count = fail_count + 1;
            end
        end
    endtask

    task wait_cycle;
        begin
            @(posedge clk);
        end
    endtask

    task apply_inputs;
        input [31:0] new_pc;
        input [31:0] new_instr;
        input [31:0] new_pc_plus4;
        begin
            pc_if = new_pc;
            instr_if = new_instr;
            pc_plus4_if = new_pc_plus4;
        end
    endtask

    // ========================================================================
    // Test Stimulus
    // ========================================================================

    initial begin
        $display("\n========================================");
        $display("IF/ID Pipeline Register Testbench");
        $display("========================================\n");

        // Initialize
        rst_n = 0;
        stall = 0;
        flush = 0;
        pc_if = 32'd0;
        instr_if = 32'd0;
        pc_plus4_if = 32'd0;

        repeat(3) @(posedge clk);
        rst_n = 1;
        @(posedge clk);

        // ====================================================================
        // Test Category 1: Reset Behavior
        // ====================================================================
        $display("\n--- Test Category 1: Reset Behavior ---");

        check_outputs(
            32'h00000000, NOP, 32'h00000000,
            "Reset: PC=0, instr=NOP, PC+4=0"
        );

        // ====================================================================
        // Test Category 2: Normal Operation (Data Propagation)
        // ====================================================================
        $display("\n--- Test Category 2: Normal Operation ---");

        apply_inputs(32'h00001000, 32'h12345678, 32'h00001004);
        wait_cycle();
        check_outputs(
            32'h00001000, 32'h12345678, 32'h00001004,
            "Normal: First instruction propagated"
        );

        apply_inputs(32'h00001004, 32'hABCDEF01, 32'h00001008);
        wait_cycle();
        check_outputs(
            32'h00001004, 32'hABCDEF01, 32'h00001008,
            "Normal: Second instruction propagated"
        );

        apply_inputs(32'h00001008, 32'h00000013, 32'h0000100C);
        wait_cycle();
        check_outputs(
            32'h00001008, 32'h00000013, 32'h0000100C,
            "Normal: NOP instruction (ADDI x0, x0, 0)"
        );

        apply_inputs(32'h0000100C, 32'hFFFFFFFF, 32'h00001010);
        wait_cycle();
        check_outputs(
            32'h0000100C, 32'hFFFFFFFF, 32'h00001010,
            "Normal: All 1s instruction"
        );

        // ====================================================================
        // Test Category 3: Stall Operation (Value Retention)
        // ====================================================================
        $display("\n--- Test Category 3: Stall Operation ---");

        apply_inputs(32'h00002000, 32'hDEADBEEF, 32'h00002004);
        wait_cycle();
        check_outputs(
            32'h00002000, 32'hDEADBEEF, 32'h00002004,
            "Before stall: New value captured"
        );

        // Assert stall, change inputs
        stall = 1;
        apply_inputs(32'h00003000, 32'hCAFEBABE, 32'h00003004);
        wait_cycle();
        check_outputs(
            32'h00002000, 32'hDEADBEEF, 32'h00002004,
            "During stall: Old value retained (inputs ignored)"
        );

        apply_inputs(32'h00004000, 32'h11111111, 32'h00004004);
        wait_cycle();
        check_outputs(
            32'h00002000, 32'hDEADBEEF, 32'h00002004,
            "During stall: Value still retained"
        );

        // Release stall
        stall = 0;
        apply_inputs(32'h00005000, 32'h22222222, 32'h00005004);
        wait_cycle();
        check_outputs(
            32'h00005000, 32'h22222222, 32'h00005004,
            "After stall: New value propagated"
        );

        // ====================================================================
        // Test Category 4: Flush Operation (Bubble Insertion)
        // ====================================================================
        $display("\n--- Test Category 4: Flush Operation (Bubble) ---");

        apply_inputs(32'h00006000, 32'h33333333, 32'h00006004);
        wait_cycle();
        check_outputs(
            32'h00006000, 32'h33333333, 32'h00006004,
            "Before flush: Normal instruction"
        );

        // Assert flush
        flush = 1;
        apply_inputs(32'h00007000, 32'h44444444, 32'h00007004);
        wait_cycle();
        flush = 0;
        check_outputs(
            32'h00000000, NOP, 32'h00000000,
            "During flush: Bubble inserted (NOP)"
        );

        apply_inputs(32'h00008000, 32'h55555555, 32'h00008004);
        wait_cycle();
        check_outputs(
            32'h00008000, 32'h55555555, 32'h00008004,
            "After flush: Normal operation resumes"
        );

        // ====================================================================
        // Test Category 5: Priority - Flush vs Stall
        // ====================================================================
        $display("\n--- Test Category 5: Flush Priority ---");

        apply_inputs(32'h00009000, 32'h66666666, 32'h00009004);
        wait_cycle();

        // Both flush and stall asserted
        flush = 1;
        stall = 1;
        apply_inputs(32'h0000A000, 32'h77777777, 32'h0000A004);
        wait_cycle();
        flush = 0;
        stall = 0;
        check_outputs(
            32'h00000000, NOP, 32'h00000000,
            "Flush + Stall: Flush takes priority (bubble inserted)"
        );

        // ====================================================================
        // Test Category 6: Multiple Consecutive Flushes
        // ====================================================================
        $display("\n--- Test Category 6: Consecutive Flushes ---");

        apply_inputs(32'h0000B000, 32'h88888888, 32'h0000B004);
        wait_cycle();

        flush = 1;
        wait_cycle();
        check_outputs(
            32'h00000000, NOP, 32'h00000000,
            "First flush: Bubble inserted"
        );

        wait_cycle();
        check_outputs(
            32'h00000000, NOP, 32'h00000000,
            "Second flush: Another bubble"
        );

        wait_cycle();
        flush = 0;
        check_outputs(
            32'h00000000, NOP, 32'h00000000,
            "Third flush: Yet another bubble"
        );

        apply_inputs(32'h0000C000, 32'h99999999, 32'h0000C004);
        wait_cycle();
        check_outputs(
            32'h0000C000, 32'h99999999, 32'h0000C004,
            "After flushes: Normal operation"
        );

        // ====================================================================
        // Test Category 7: Multiple Consecutive Stalls
        // ====================================================================
        $display("\n--- Test Category 7: Consecutive Stalls ---");

        apply_inputs(32'h0000D000, 32'hAAAAAAAA, 32'h0000D004);
        wait_cycle();
        check_outputs(
            32'h0000D000, 32'hAAAAAAAA, 32'h0000D004,
            "Before stalls: Value captured"
        );

        stall = 1;
        apply_inputs(32'h0000E000, 32'hBBBBBBBB, 32'h0000E004);
        wait_cycle();
        check_outputs(
            32'h0000D000, 32'hAAAAAAAA, 32'h0000D004,
            "Stall 1: Value retained"
        );

        apply_inputs(32'h0000F000, 32'hCCCCCCCC, 32'h0000F004);
        wait_cycle();
        check_outputs(
            32'h0000D000, 32'hAAAAAAAA, 32'h0000D004,
            "Stall 2: Value still retained"
        );

        apply_inputs(32'h00010000, 32'hDDDDDDDD, 32'h00010004);
        wait_cycle();
        stall = 0;
        check_outputs(
            32'h0000D000, 32'hAAAAAAAA, 32'h0000D004,
            "Stall 3: Value still retained"
        );

        apply_inputs(32'h00011000, 32'hEEEEEEEE, 32'h00011004);
        wait_cycle();
        check_outputs(
            32'h00011000, 32'hEEEEEEEE, 32'h00011004,
            "After stalls: New value propagated"
        );

        // ====================================================================
        // Test Category 8: Reset During Operation
        // ====================================================================
        $display("\n--- Test Category 8: Reset During Operation ---");

        apply_inputs(32'h00012000, 32'hFFFF0000, 32'h00012004);
        wait_cycle();
        check_outputs(
            32'h00012000, 32'hFFFF0000, 32'h00012004,
            "Before reset: Normal value"
        );

        rst_n = 0;
        @(posedge clk);
        check_outputs(
            32'h00000000, NOP, 32'h00000000,
            "During reset: All outputs cleared"
        );

        rst_n = 1;
        @(posedge clk);
        check_outputs(
            32'h00000000, NOP, 32'h00000000,
            "After reset release: Still cleared"
        );

        apply_inputs(32'h00013000, 32'h0000FFFF, 32'h00013004);
        wait_cycle();
        check_outputs(
            32'h00013000, 32'h0000FFFF, 32'h00013004,
            "After reset: Normal operation resumes"
        );

        // ====================================================================
        // Test Category 9: Stall/Flush Patterns
        // ====================================================================
        $display("\n--- Test Category 9: Stall/Flush Patterns ---");

        apply_inputs(32'h00014000, 32'h12340000, 32'h00014004);
        wait_cycle();
        check_outputs(
            32'h00014000, 32'h12340000, 32'h00014004,
            "Pattern: Initial value"
        );

        // Stall, then flush
        stall = 1;
        wait_cycle();
        check_outputs(
            32'h00014000, 32'h12340000, 32'h00014004,
            "Pattern: Stall active"
        );

        stall = 0;
        flush = 1;
        wait_cycle();
        flush = 0;
        check_outputs(
            32'h00000000, NOP, 32'h00000000,
            "Pattern: Flush after stall"
        );

        // ====================================================================
        // Test Category 10: Edge Case Instructions
        // ====================================================================
        $display("\n--- Test Category 10: Edge Case Instructions ---");

        apply_inputs(32'h00000000, 32'h00000000, 32'h00000004);
        wait_cycle();
        check_outputs(
            32'h00000000, 32'h00000000, 32'h00000004,
            "Edge: PC=0, instr=0"
        );

        apply_inputs(32'hFFFFFFFC, 32'hFFFFFFFF, 32'h00000000);
        wait_cycle();
        check_outputs(
            32'hFFFFFFFC, 32'hFFFFFFFF, 32'h00000000,
            "Edge: Max PC, all 1s instr, PC+4 wraps"
        );

        apply_inputs(32'h80000000, 32'h80000000, 32'h80000004);
        wait_cycle();
        check_outputs(
            32'h80000000, 32'h80000000, 32'h80000004,
            "Edge: High bit set (sign bit)"
        );

        // ====================================================================
        // Test Category 11: Realistic Pipeline Sequence
        // ====================================================================
        $display("\n--- Test Category 11: Realistic Pipeline Sequence ---");

        integer i;
        for (i = 0; i < 5; i = i + 1) begin
            apply_inputs(32'h00100000 + (i * 4),
                        32'h01000000 + i,
                        32'h00100004 + (i * 4));
            wait_cycle();

            test_count = test_count + 1;
            if (pc_id === (32'h00100000 + (i * 4)) &&
                instr_id === (32'h01000000 + i) &&
                pc_plus4_id === (32'h00100004 + (i * 4))) begin
                $display("[PASS] Test %0d: Sequence [%0d] pc=0x%h, instr=0x%h",
                         test_count, i, pc_id, instr_id);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] Test %0d: Sequence [%0d]", test_count, i);
                fail_count = fail_count + 1;
            end
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

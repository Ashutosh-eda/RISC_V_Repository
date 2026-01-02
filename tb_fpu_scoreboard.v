// ============================================================================
// Testbench for FPU Scoreboard with Forwarding Support
// Tests busy tracking, latency counters, stage detection, and hazard detection
// Self-checking with comprehensive test cases
// ============================================================================

`timescale 1ns / 1ps

module tb_fpu_scoreboard;

    // ========================================================================
    // DUT Signals
    // ========================================================================

    reg         clk;
    reg         rst_n;

    // From Decode Stage
    reg         fp_op_id;
    reg  [4:0]  rs1_id;
    reg  [4:0]  rs2_id;
    reg  [4:0]  rs3_id;
    reg         fma_op_id;

    // From Execute Stage
    reg         fp_op_ex;
    reg  [4:0]  rd_ex;
    reg  [2:0]  latency_ex;
    reg         flush_ex;

    // From Memory Stage
    reg  [4:0]  rd_mem;
    reg         fp_reg_write_mem;

    // From Writeback Stage
    reg  [4:0]  rd_wb;
    reg         fp_reg_write_wb;

    // Outputs
    wire        stall_fpu;
    wire [1:0]  rs1_stage;
    wire [1:0]  rs2_stage;
    wire [1:0]  rs3_stage;

    // ========================================================================
    // DUT Instantiation
    // ========================================================================

    fpu_scoreboard dut (
        .clk(clk),
        .rst_n(rst_n),
        .fp_op_id(fp_op_id),
        .rs1_id(rs1_id),
        .rs2_id(rs2_id),
        .rs3_id(rs3_id),
        .fma_op_id(fma_op_id),
        .fp_op_ex(fp_op_ex),
        .rd_ex(rd_ex),
        .latency_ex(latency_ex),
        .flush_ex(flush_ex),
        .rd_mem(rd_mem),
        .fp_reg_write_mem(fp_reg_write_mem),
        .rd_wb(rd_wb),
        .fp_reg_write_wb(fp_reg_write_wb),
        .stall_fpu(stall_fpu),
        .rs1_stage(rs1_stage),
        .rs2_stage(rs2_stage),
        .rs3_stage(rs3_stage)
    );

    // ========================================================================
    // Clock Generation
    // ========================================================================

    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 10ns period, 100MHz
    end

    // ========================================================================
    // Test Infrastructure
    // ========================================================================

    integer test_count = 0;
    integer pass_count = 0;
    integer fail_count = 0;

    // Stage encoding constants
    localparam STAGE_NONE = 2'b00;  // Use register file
    localparam STAGE_WB   = 2'b01;  // Result in WB stage
    localparam STAGE_MEM  = 2'b10;  // Result in MEM stage
    localparam STAGE_EX   = 2'b11;  // Result in EX stage (stall)

    // Latency constants
    localparam LAT_ADD = 3'd4;  // FP Add/Sub: 4 cycles
    localparam LAT_MUL = 3'd3;  // FP Mul: 3 cycles
    localparam LAT_FMA = 3'd6;  // FMA: 6 cycles

    // ========================================================================
    // Test Tasks
    // ========================================================================

    // Task: Check scoreboard state
    task check_state;
        input        exp_stall;
        input [1:0]  exp_rs1_stage;
        input [1:0]  exp_rs2_stage;
        input [1:0]  exp_rs3_stage;
        input [200:0] description;

        begin
            test_count = test_count + 1;

            #1; // Small delay for signals to settle

            if (stall_fpu === exp_stall &&
                rs1_stage === exp_rs1_stage &&
                rs2_stage === exp_rs2_stage &&
                rs3_stage === exp_rs3_stage) begin
                $display("[PASS] Test %0d: %s", test_count, description);
                $display("       stall=%b, rs1=%s, rs2=%s, rs3=%s",
                         stall_fpu,
                         decode_stage(rs1_stage),
                         decode_stage(rs2_stage),
                         decode_stage(rs3_stage));
                pass_count = pass_count + 1;
            end
            else begin
                $display("[FAIL] Test %0d: %s", test_count, description);
                $display("       Expected: stall=%b, rs1=%s, rs2=%s, rs3=%s",
                         exp_stall,
                         decode_stage(exp_rs1_stage),
                         decode_stage(exp_rs2_stage),
                         decode_stage(exp_rs3_stage));
                $display("       Got:      stall=%b, rs1=%s, rs2=%s, rs3=%s",
                         stall_fpu,
                         decode_stage(rs1_stage),
                         decode_stage(rs2_stage),
                         decode_stage(rs3_stage));
                fail_count = fail_count + 1;
            end
        end
    endtask

    // Helper function to decode stage
    function [63:0] decode_stage;
        input [1:0] stage;
        begin
            case (stage)
                2'b00: decode_stage = "NONE";
                2'b01: decode_stage = "WB  ";
                2'b10: decode_stage = "MEM ";
                2'b11: decode_stage = "EX  ";
                default: decode_stage = "??? ";
            endcase
        end
    endfunction

    // Task: Issue FP operation
    task issue_fp_op;
        input [4:0] rd;
        input [2:0] latency;
        begin
            fp_op_ex = 1'b1;
            rd_ex = rd;
            latency_ex = latency;
            @(posedge clk);
            fp_op_ex = 1'b0;
        end
    endtask

    // Task: Wait N cycles
    task wait_cycles;
        input integer n;
        integer i;
        begin
            for (i = 0; i < n; i = i + 1) begin
                @(posedge clk);
            end
        end
    endtask

    // ========================================================================
    // Test Stimulus
    // ========================================================================

    initial begin
        $display("\n========================================");
        $display("FPU Scoreboard Testbench");
        $display("========================================\n");

        // Initialize all inputs
        rst_n = 0;
        fp_op_id = 0;
        rs1_id = 0;
        rs2_id = 0;
        rs3_id = 0;
        fma_op_id = 0;
        fp_op_ex = 0;
        rd_ex = 0;
        latency_ex = 0;
        flush_ex = 0;
        rd_mem = 0;
        fp_reg_write_mem = 0;
        rd_wb = 0;
        fp_reg_write_wb = 0;

        // Reset sequence
        @(posedge clk);
        @(posedge clk);
        rst_n = 1;
        @(posedge clk);

        // ====================================================================
        // Test Category 1: Basic Operation - No Hazards
        // ====================================================================
        $display("\n--- Test Category 1: No Hazards ---");

        // Test 1: No operation
        fp_op_id = 0;
        rs1_id = 5'd1;
        rs2_id = 5'd2;
        check_state(1'b0, STAGE_NONE, STAGE_NONE, STAGE_NONE,
                    "No FP operation in ID stage");

        // Test 2: FP operation but no dependencies
        fp_op_id = 1;
        rs1_id = 5'd1;
        rs2_id = 5'd2;
        check_state(1'b0, STAGE_NONE, STAGE_NONE, STAGE_NONE,
                    "FP operation but no dependencies");

        @(posedge clk);

        // ====================================================================
        // Test Category 2: Single Operation Tracking
        // ====================================================================
        $display("\n--- Test Category 2: Single Operation Tracking ---");

        // Test 3: Issue FMUL to f10 (3-cycle latency)
        $display("\nIssuing FMUL to f10 (3 cycles)...");
        issue_fp_op(5'd10, LAT_MUL);

        // Cycle 1: Operation in EX stage
        fp_op_id = 1;
        rs1_id = 5'd10;  // Dependent on f10
        rs2_id = 5'd2;
        check_state(1'b1, STAGE_EX, STAGE_NONE, STAGE_NONE,
                    "Cycle 1 after issue - f10 in EX (stall)");

        // Cycle 2: Still in pipeline
        @(posedge clk);
        check_state(1'b1, STAGE_EX, STAGE_NONE, STAGE_NONE,
                    "Cycle 2 after issue - f10 still busy (stall)");

        // Cycle 3: Operation completes next cycle
        @(posedge clk);
        check_state(1'b1, STAGE_EX, STAGE_NONE, STAGE_NONE,
                    "Cycle 3 after issue - f10 completing (stall)");

        // Cycle 4: Operation complete, f10 available
        @(posedge clk);
        check_state(1'b0, STAGE_NONE, STAGE_NONE, STAGE_NONE,
                    "Cycle 4 after issue - f10 ready (no stall)");

        @(posedge clk);

        // ====================================================================
        // Test Category 3: Stage Detection for Forwarding
        // ====================================================================
        $display("\n--- Test Category 3: Stage Detection ---");

        // Test 4: Detect result in MEM stage
        $display("\nIssuing FADD to f5 (4 cycles)...");
        issue_fp_op(5'd5, LAT_ADD);
        wait_cycles(2); // Wait 2 cycles

        // Now simulate f5 in MEM stage (3 cycles after issue)
        rd_mem = 5'd5;
        fp_reg_write_mem = 1;
        fp_op_id = 1;
        rs1_id = 5'd5;
        rs2_id = 5'd3;
        check_state(1'b1, STAGE_EX, STAGE_NONE, STAGE_NONE,
                    "f5 still in EX stage");

        @(posedge clk);
        rd_mem = 5'd5;
        fp_reg_write_mem = 1;
        check_state(1'b0, STAGE_MEM, STAGE_NONE, STAGE_NONE,
                    "f5 in MEM stage (can forward, no stall)");

        // Test 5: Detect result in WB stage
        @(posedge clk);
        rd_mem = 5'd0;
        fp_reg_write_mem = 0;
        rd_wb = 5'd5;
        fp_reg_write_wb = 1;
        check_state(1'b0, STAGE_WB, STAGE_NONE, STAGE_NONE,
                    "f5 in WB stage (can forward, no stall)");

        rd_wb = 5'd0;
        fp_reg_write_wb = 0;
        @(posedge clk);

        // ====================================================================
        // Test Category 4: Multiple Dependencies
        // ====================================================================
        $display("\n--- Test Category 4: Multiple Dependencies ---");

        // Test 6: Issue FMA (uses rs1, rs2, rs3)
        $display("\nIssuing FMA to f20 (6 cycles)...");
        issue_fp_op(5'd20, LAT_FMA);

        // Check dependency on all three sources
        fp_op_id = 1;
        fma_op_id = 1;  // Enable rs3 checking
        rs1_id = 5'd20;
        rs2_id = 5'd21;
        rs3_id = 5'd20; // Also depends on f20
        check_state(1'b1, STAGE_EX, STAGE_NONE, STAGE_EX,
                    "FMA - f20 in EX for both rs1 and rs3 (stall)");

        fma_op_id = 0;
        @(posedge clk);

        // ====================================================================
        // Test Category 5: Pipeline Flush
        // ====================================================================
        $display("\n--- Test Category 5: Pipeline Flush ---");

        // Test 7: Issue operation then flush it
        $display("\nIssuing FMUL to f15 then flushing...");
        fp_op_ex = 1;
        rd_ex = 5'd15;
        latency_ex = LAT_MUL;
        flush_ex = 1;  // Flush immediately
        @(posedge clk);
        fp_op_ex = 0;
        flush_ex = 0;

        // f15 should NOT be marked busy due to flush
        fp_op_id = 1;
        rs1_id = 5'd15;
        rs2_id = 5'd2;
        check_state(1'b0, STAGE_NONE, STAGE_NONE, STAGE_NONE,
                    "Operation flushed - f15 not busy");

        @(posedge clk);

        // ====================================================================
        // Test Category 6: Back-to-Back Operations
        // ====================================================================
        $display("\n--- Test Category 6: Back-to-Back Operations ---");

        // Test 8: Issue operations to different registers
        $display("\nIssuing FMUL to f8, then FADD to f9...");
        issue_fp_op(5'd8, LAT_MUL);
        issue_fp_op(5'd9, LAT_ADD);

        // Both should be busy
        fp_op_id = 1;
        rs1_id = 5'd8;
        rs2_id = 5'd9;
        check_state(1'b1, STAGE_EX, STAGE_EX, STAGE_NONE,
                    "Both f8 and f9 busy in EX (stall)");

        @(posedge clk);

        // ====================================================================
        // Test Category 7: Same Register RAW
        // ====================================================================
        $display("\n--- Test Category 7: RAW on Same Register ---");

        // Clear state
        wait_cycles(6);

        // Test 9: Issue to f7, then immediately use f7
        $display("\nIssuing FADD to f7, then using f7...");
        issue_fp_op(5'd7, LAT_ADD);

        fp_op_id = 1;
        rs1_id = 5'd7;  // RAW hazard
        rs2_id = 5'd1;
        check_state(1'b1, STAGE_EX, STAGE_NONE, STAGE_NONE,
                    "RAW hazard - f7 in EX (stall)");

        @(posedge clk);
        check_state(1'b1, STAGE_EX, STAGE_NONE, STAGE_NONE,
                    "RAW hazard - f7 still in EX (stall)");

        wait_cycles(2);
        // After 4 cycles, should be ready
        check_state(1'b0, STAGE_NONE, STAGE_NONE, STAGE_NONE,
                    "f7 ready - no stall");

        @(posedge clk);

        // ====================================================================
        // Test Category 8: Zero Register (f0)
        // ====================================================================
        $display("\n--- Test Category 8: Register f0 ---");

        // Test 10: Operations on f0
        issue_fp_op(5'd0, LAT_MUL);

        fp_op_id = 1;
        rs1_id = 5'd0;
        rs2_id = 5'd0;
        // f0 is valid, so it can still create hazards
        check_state(1'b1, STAGE_EX, STAGE_EX, STAGE_NONE,
                    "f0 operations create hazards");

        wait_cycles(4);
        @(posedge clk);

        // ====================================================================
        // Test Category 9: Maximum Latency (FMA - 6 cycles)
        // ====================================================================
        $display("\n--- Test Category 9: Maximum Latency ---");

        // Test 11: Track FMA through full pipeline
        $display("\nIssuing FMA to f25 (6 cycles)...");
        issue_fp_op(5'd25, LAT_FMA);

        fp_op_id = 1;
        rs1_id = 5'd25;
        rs2_id = 5'd1;

        // Cycle 1
        check_state(1'b1, STAGE_EX, STAGE_NONE, STAGE_NONE,
                    "FMA cycle 1 - f25 in EX");
        @(posedge clk);

        // Cycle 2
        check_state(1'b1, STAGE_EX, STAGE_NONE, STAGE_NONE,
                    "FMA cycle 2 - f25 in EX");
        @(posedge clk);

        // Cycle 3
        check_state(1'b1, STAGE_EX, STAGE_NONE, STAGE_NONE,
                    "FMA cycle 3 - f25 in EX");
        @(posedge clk);

        // Cycle 4
        check_state(1'b1, STAGE_EX, STAGE_NONE, STAGE_NONE,
                    "FMA cycle 4 - f25 in EX");
        @(posedge clk);

        // Cycle 5
        check_state(1'b1, STAGE_EX, STAGE_NONE, STAGE_NONE,
                    "FMA cycle 5 - f25 in EX");
        @(posedge clk);

        // Cycle 6
        check_state(1'b1, STAGE_EX, STAGE_NONE, STAGE_NONE,
                    "FMA cycle 6 - f25 completing");
        @(posedge clk);

        // Cycle 7 - complete
        check_state(1'b0, STAGE_NONE, STAGE_NONE, STAGE_NONE,
                    "FMA cycle 7 - f25 ready");

        @(posedge clk);

        // ====================================================================
        // Test Category 10: Edge Cases
        // ====================================================================
        $display("\n--- Test Category 10: Edge Cases ---");

        // Test 12: Maximum register f31
        $display("\nIssuing to f31...");
        issue_fp_op(5'd31, LAT_MUL);

        fp_op_id = 1;
        rs1_id = 5'd31;
        rs2_id = 5'd30;
        check_state(1'b1, STAGE_EX, STAGE_NONE, STAGE_NONE,
                    "f31 in EX (stall)");

        wait_cycles(4);

        // Test 13: No FP operation in ID (fp_op_id=0)
        fp_op_id = 0;
        rs1_id = 5'd31;  // Even if f31 were busy, no stall without fp_op_id
        check_state(1'b0, STAGE_NONE, STAGE_NONE, STAGE_NONE,
                    "No FP op in ID - no stall");

        @(posedge clk);

        // ====================================================================
        // Test Summary
        // ====================================================================
        wait_cycles(2);

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

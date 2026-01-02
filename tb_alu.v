// ============================================================================
// Testbench for Arithmetic Logic Unit (ALU)
// Tests all RV32I integer operations
// Self-checking with comprehensive test cases
// ============================================================================

`timescale 1ns / 1ps

module tb_alu;

    // ========================================================================
    // DUT Signals
    // ========================================================================

    reg  [31:0] operand_a;
    reg  [31:0] operand_b;
    reg  [3:0]  alu_op;
    wire [31:0] result;
    wire        zero;

    // ========================================================================
    // DUT Instantiation
    // ========================================================================

    alu dut (
        .operand_a(operand_a),
        .operand_b(operand_b),
        .alu_op(alu_op),
        .result(result),
        .zero(zero)
    );

    // ========================================================================
    // Test Infrastructure
    // ========================================================================

    integer test_count = 0;
    integer pass_count = 0;
    integer fail_count = 0;

    // ALU operation encodings
    localparam ALU_ADD   = 4'b0000;
    localparam ALU_SUB   = 4'b0001;
    localparam ALU_SLL   = 4'b0010;
    localparam ALU_SLT   = 4'b0011;
    localparam ALU_SLTU  = 4'b0100;
    localparam ALU_XOR   = 4'b0101;
    localparam ALU_SRL   = 4'b0110;
    localparam ALU_SRA   = 4'b0111;
    localparam ALU_OR    = 4'b1000;
    localparam ALU_AND   = 4'b1001;
    localparam ALU_LUI   = 4'b1010;
    localparam ALU_AUIPC = 4'b1011;

    // ========================================================================
    // Test Task
    // ========================================================================

    task check_alu;
        input [31:0] test_a, test_b;
        input [3:0]  test_op;
        input [31:0] expected_result;
        input        expected_zero;
        input [200:0] description;

        begin
            test_count = test_count + 1;

            operand_a = test_a;
            operand_b = test_b;
            alu_op = test_op;

            #10;

            if (result === expected_result && zero === expected_zero) begin
                $display("[PASS] Test %0d: %s", test_count, description);
                $display("       Result: %h (Zero=%b)", result, zero);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] Test %0d: %s", test_count, description);
                $display("       Expected: %h (Zero=%b)", expected_result, expected_zero);
                $display("       Got:      %h (Zero=%b)", result, zero);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // ========================================================================
    // Test Stimulus
    // ========================================================================

    initial begin
        $display("\n========================================");
        $display("ALU Testbench");
        $display("========================================\n");

        // ====================================================================
        // Test Category 1: ADD Operation
        // ====================================================================
        $display("\n--- Test Category 1: ADD Operation ---");

        check_alu(
            32'd10, 32'd20, ALU_ADD,
            32'd30, 1'b0,
            "ADD: 10 + 20 = 30"
        );

        check_alu(
            32'd0, 32'd0, ALU_ADD,
            32'd0, 1'b1,
            "ADD: 0 + 0 = 0 (zero flag)"
        );

        check_alu(
            32'hFFFFFFFF, 32'h1, ALU_ADD,
            32'h0, 1'b1,
            "ADD: -1 + 1 = 0 (overflow wrap)"
        );

        check_alu(
            32'h80000000, 32'h80000000, ALU_ADD,
            32'h0, 1'b1,
            "ADD: Overflow wraps to zero"
        );

        // ====================================================================
        // Test Category 2: SUB Operation
        // ====================================================================
        $display("\n--- Test Category 2: SUB Operation ---");

        check_alu(
            32'd50, 32'd30, ALU_SUB,
            32'd20, 1'b0,
            "SUB: 50 - 30 = 20"
        );

        check_alu(
            32'd10, 32'd10, ALU_SUB,
            32'd0, 1'b1,
            "SUB: 10 - 10 = 0 (zero flag)"
        );

        check_alu(
            32'd5, 32'd10, ALU_SUB,
            32'hFFFFFFFB, 1'b0,
            "SUB: 5 - 10 = -5 (underflow)"
        );

        check_alu(
            32'h0, 32'h1, ALU_SUB,
            32'hFFFFFFFF, 1'b0,
            "SUB: 0 - 1 = -1"
        );

        // ====================================================================
        // Test Category 3: Shift Left Logical (SLL)
        // ====================================================================
        $display("\n--- Test Category 3: SLL Operation ---");

        check_alu(
            32'h00000001, 32'd1, ALU_SLL,
            32'h00000002, 1'b0,
            "SLL: 1 << 1 = 2"
        );

        check_alu(
            32'h00000001, 32'd8, ALU_SLL,
            32'h00000100, 1'b0,
            "SLL: 1 << 8 = 256"
        );

        check_alu(
            32'hFFFFFFFF, 32'd4, ALU_SLL,
            32'hFFFFFFF0, 1'b0,
            "SLL: 0xFFFFFFFF << 4"
        );

        check_alu(
            32'h12345678, 32'd31, ALU_SLL,
            32'h00000000, 1'b1,
            "SLL: Shift by 31 (all bits out)"
        );

        // Test shamt masking (only lower 5 bits used)
        check_alu(
            32'h00000001, 32'h00000021, ALU_SLL,  // shamt = 33 & 0x1F = 1
            32'h00000002, 1'b0,
            "SLL: shamt masking (33 & 0x1F = 1)"
        );

        // ====================================================================
        // Test Category 4: Shift Right Logical (SRL)
        // ====================================================================
        $display("\n--- Test Category 4: SRL Operation ---");

        check_alu(
            32'h00000100, 32'd8, ALU_SRL,
            32'h00000001, 1'b0,
            "SRL: 256 >> 8 = 1"
        );

        check_alu(
            32'hF0000000, 32'd4, ALU_SRL,
            32'h0F000000, 1'b0,
            "SRL: 0xF0000000 >> 4 (logical)"
        );

        check_alu(
            32'hFFFFFFFF, 32'd1, ALU_SRL,
            32'h7FFFFFFF, 1'b0,
            "SRL: 0xFFFFFFFF >> 1 (zero fill)"
        );

        check_alu(
            32'h00000001, 32'd1, ALU_SRL,
            32'h00000000, 1'b1,
            "SRL: 1 >> 1 = 0"
        );

        // ====================================================================
        // Test Category 5: Shift Right Arithmetic (SRA)
        // ====================================================================
        $display("\n--- Test Category 5: SRA Operation ---");

        check_alu(
            32'h00000100, 32'd8, ALU_SRA,
            32'h00000001, 1'b0,
            "SRA: 256 >>> 8 = 1 (positive)"
        );

        check_alu(
            32'hF0000000, 32'd4, ALU_SRA,
            32'hFF000000, 1'b0,
            "SRA: 0xF0000000 >>> 4 (sign extend)"
        );

        check_alu(
            32'hFFFFFFFF, 32'd1, ALU_SRA,
            32'hFFFFFFFF, 1'b0,
            "SRA: -1 >>> 1 = -1 (sign fill)"
        );

        check_alu(
            32'h80000000, 32'd31, ALU_SRA,
            32'hFFFFFFFF, 1'b0,
            "SRA: Min int >>> 31 = -1"
        );

        // ====================================================================
        // Test Category 6: Set Less Than (SLT)
        // ====================================================================
        $display("\n--- Test Category 6: SLT Operation ---");

        check_alu(
            32'd5, 32'd10, ALU_SLT,
            32'd1, 1'b0,
            "SLT: 5 < 10 = 1 (true)"
        );

        check_alu(
            32'd10, 32'd5, ALU_SLT,
            32'd0, 1'b1,
            "SLT: 10 < 5 = 0 (false)"
        );

        check_alu(
            32'd10, 32'd10, ALU_SLT,
            32'd0, 1'b1,
            "SLT: 10 < 10 = 0 (equal)"
        );

        // Signed comparison
        check_alu(
            32'hFFFFFFFF, 32'd1, ALU_SLT,  // -1 < 1
            32'd1, 1'b0,
            "SLT: -1 < 1 = 1 (signed)"
        );

        check_alu(
            32'd1, 32'hFFFFFFFF, ALU_SLT,  // 1 < -1
            32'd0, 1'b1,
            "SLT: 1 < -1 = 0 (signed)"
        );

        check_alu(
            32'h80000000, 32'd0, ALU_SLT,  // Min int < 0
            32'd1, 1'b0,
            "SLT: MIN_INT < 0 = 1"
        );

        // ====================================================================
        // Test Category 7: Set Less Than Unsigned (SLTU)
        // ====================================================================
        $display("\n--- Test Category 7: SLTU Operation ---");

        check_alu(
            32'd5, 32'd10, ALU_SLTU,
            32'd1, 1'b0,
            "SLTU: 5 < 10 = 1 (unsigned)"
        );

        check_alu(
            32'hFFFFFFFF, 32'd1, ALU_SLTU,  // Large unsigned < small
            32'd0, 1'b1,
            "SLTU: 0xFFFFFFFF < 1 = 0 (unsigned)"
        );

        check_alu(
            32'd1, 32'hFFFFFFFF, ALU_SLTU,
            32'd1, 1'b0,
            "SLTU: 1 < 0xFFFFFFFF = 1 (unsigned)"
        );

        check_alu(
            32'h80000000, 32'd0, ALU_SLTU,  // Large unsigned vs 0
            32'd0, 1'b1,
            "SLTU: 0x80000000 < 0 = 0"
        );

        // ====================================================================
        // Test Category 8: AND Operation
        // ====================================================================
        $display("\n--- Test Category 8: AND Operation ---");

        check_alu(
            32'hFFFFFFFF, 32'h12345678, ALU_AND,
            32'h12345678, 1'b0,
            "AND: 0xFFFFFFFF & 0x12345678"
        );

        check_alu(
            32'h00000000, 32'h12345678, ALU_AND,
            32'h00000000, 1'b1,
            "AND: 0x00000000 & anything = 0"
        );

        check_alu(
            32'hAAAAAAAA, 32'h55555555, ALU_AND,
            32'h00000000, 1'b1,
            "AND: Alternating bits = 0"
        );

        check_alu(
            32'hF0F0F0F0, 32'h0F0F0F0F, ALU_AND,
            32'h00000000, 1'b1,
            "AND: Complementary masks = 0"
        );

        // ====================================================================
        // Test Category 9: OR Operation
        // ====================================================================
        $display("\n--- Test Category 9: OR Operation ---");

        check_alu(
            32'h12345678, 32'h87654321, ALU_OR,
            32'h97755779, 1'b0,
            "OR: 0x12345678 | 0x87654321"
        );

        check_alu(
            32'h00000000, 32'h00000000, ALU_OR,
            32'h00000000, 1'b1,
            "OR: 0 | 0 = 0"
        );

        check_alu(
            32'hAAAAAAAA, 32'h55555555, ALU_OR,
            32'hFFFFFFFF, 1'b0,
            "OR: Alternating bits = 0xFFFFFFFF"
        );

        check_alu(
            32'hFFFFFFFF, 32'h12345678, ALU_OR,
            32'hFFFFFFFF, 1'b0,
            "OR: 0xFFFFFFFF | anything = 0xFFFFFFFF"
        );

        // ====================================================================
        // Test Category 10: XOR Operation
        // ====================================================================
        $display("\n--- Test Category 10: XOR Operation ---");

        check_alu(
            32'h12345678, 32'h12345678, ALU_XOR,
            32'h00000000, 1'b1,
            "XOR: Same values = 0"
        );

        check_alu(
            32'hFFFFFFFF, 32'h12345678, ALU_XOR,
            32'hEDCBA987, 1'b0,
            "XOR: 0xFFFFFFFF ^ 0x12345678 (invert)"
        );

        check_alu(
            32'hAAAAAAAA, 32'h55555555, ALU_XOR,
            32'hFFFFFFFF, 1'b0,
            "XOR: Alternating bits"
        );

        check_alu(
            32'h00000000, 32'h12345678, ALU_XOR,
            32'h12345678, 1'b0,
            "XOR: 0 ^ value = value"
        );

        // ====================================================================
        // Test Category 11: LUI Operation
        // ====================================================================
        $display("\n--- Test Category 11: LUI Operation ---");

        check_alu(
            32'h12345678, 32'hABCD0000, ALU_LUI,
            32'hABCD0000, 1'b0,
            "LUI: Load upper immediate"
        );

        check_alu(
            32'hDEADBEEF, 32'h00000000, ALU_LUI,
            32'h00000000, 1'b1,
            "LUI: Load zero"
        );

        check_alu(
            32'h00000000, 32'hFFFF0000, ALU_LUI,
            32'hFFFF0000, 1'b0,
            "LUI: Load 0xFFFF0000"
        );

        // ====================================================================
        // Test Category 12: AUIPC Operation
        // ====================================================================
        $display("\n--- Test Category 12: AUIPC Operation ---");

        check_alu(
            32'h00001000, 32'h00002000, ALU_AUIPC,
            32'h00003000, 1'b0,
            "AUIPC: PC + immediate"
        );

        check_alu(
            32'hFFFFFFFF, 32'h00000001, ALU_AUIPC,
            32'h00000000, 1'b1,
            "AUIPC: PC wrap around"
        );

        check_alu(
            32'h12345678, 32'hABCD0000, ALU_AUIPC,
            32'hBE015678, 1'b0,
            "AUIPC: Large PC + offset"
        );

        // ====================================================================
        // Test Category 13: Edge Cases
        // ====================================================================
        $display("\n--- Test Category 13: Edge Cases ---");

        check_alu(
            32'h00000000, 32'h00000000, ALU_ADD,
            32'h00000000, 1'b1,
            "Edge: All zeros ADD"
        );

        check_alu(
            32'hFFFFFFFF, 32'hFFFFFFFF, ALU_ADD,
            32'hFFFFFFFE, 1'b0,
            "Edge: All ones ADD"
        );

        check_alu(
            32'h7FFFFFFF, 32'h00000001, ALU_ADD,
            32'h80000000, 1'b0,
            "Edge: Positive overflow"
        );

        check_alu(
            32'h80000000, 32'hFFFFFFFF, ALU_ADD,
            32'h7FFFFFFF, 1'b0,
            "Edge: Negative overflow"
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

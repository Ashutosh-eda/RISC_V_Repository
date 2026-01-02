// ============================================================================
// Testbench for FPU Sign Logic
// Tests sign determination for all FPU operation types
// Covers: ADD, SUB, MUL, FMA, FMS, FNMADD, FNMSUB
// Self-checking with comprehensive test cases
// ============================================================================

`timescale 1ns / 1ps

module tb_fpu_sign_logic;

    // ========================================================================
    // DUT Signals
    // ========================================================================

    reg        xs, ys, zs;
    reg  [2:0] op_type;

    wire       prod_sign;
    wire       result_sign;

    // ========================================================================
    // DUT Instantiation
    // ========================================================================

    fpu_sign_logic dut (
        .xs(xs),
        .ys(ys),
        .zs(zs),
        .op_type(op_type),
        .prod_sign(prod_sign),
        .result_sign(result_sign)
    );

    // ========================================================================
    // Operation Type Encoding
    // ========================================================================

    localparam OP_ADD    = 3'b000;
    localparam OP_SUB    = 3'b001;
    localparam OP_MUL    = 3'b010;
    localparam OP_FMA    = 3'b011;
    localparam OP_FMS    = 3'b100;
    localparam OP_FNMADD = 3'b101;
    localparam OP_FNMSUB = 3'b110;

    // ========================================================================
    // Test Infrastructure
    // ========================================================================

    integer test_count = 0;
    integer pass_count = 0;
    integer fail_count = 0;
    integer i;

    // ========================================================================
    // Test Task
    // ========================================================================

    task check_sign;
        input        test_xs, test_ys, test_zs;
        input [2:0]  test_op;
        input        exp_prod_sign, exp_result_sign;
        input [200:0] description;
        begin
            test_count = test_count + 1;

            xs = test_xs;
            ys = test_ys;
            zs = test_zs;
            op_type = test_op;

            #10;

            // Check prod_sign, and result_sign only if not don't-care
            if (prod_sign === exp_prod_sign &&
                (exp_result_sign === 1'bx || result_sign === exp_result_sign)) begin
                $display("[PASS] Test %0d: %s", test_count, description);
                $display("       xs=%b, ys=%b, zs=%b, op=%b", xs, ys, zs, op_type);
                $display("       prod_sign=%b, result_sign=%b", prod_sign, result_sign);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] Test %0d: %s", test_count, description);
                $display("       xs=%b, ys=%b, zs=%b, op=%b", xs, ys, zs, op_type);
                $display("       Expected: prod_sign=%b, result_sign=%b",
                         exp_prod_sign, exp_result_sign);
                $display("       Got:      prod_sign=%b, result_sign=%b",
                         prod_sign, result_sign);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // ========================================================================
    // Test Stimulus
    // ========================================================================

    initial begin
        $display("\n========================================");
        $display("FPU Sign Logic Testbench");
        $display("========================================\n");

        // Initialize
        xs = 0;
        ys = 0;
        zs = 0;
        op_type = OP_ADD;

        #20;

        // ====================================================================
        // Test Category 1: Multiplication (Product Sign)
        // ====================================================================
        $display("\n--- Test Category 1: Multiplication (Product Sign) ---");

        check_sign(
            1'b0, 1'b0, 1'b0,
            OP_MUL,
            1'b0, 1'b0,
            "MUL: (+) × (+) = (+)"
        );

        check_sign(
            1'b0, 1'b1, 1'b0,
            OP_MUL,
            1'b1, 1'b1,
            "MUL: (+) × (-) = (-)"
        );

        check_sign(
            1'b1, 1'b0, 1'b0,
            OP_MUL,
            1'b1, 1'b1,
            "MUL: (-) × (+) = (-)"
        );

        check_sign(
            1'b1, 1'b1, 1'b0,
            OP_MUL,
            1'b0, 1'b0,
            "MUL: (-) × (-) = (+)"
        );

        // ====================================================================
        // Test Category 2: Addition (OP_ADD)
        // ====================================================================
        $display("\n--- Test Category 2: Addition (OP_ADD) ---");

        check_sign(
            1'b0, 1'b0, 1'b0,
            OP_ADD,
            1'b0, 1'b0,
            "ADD: (+) + (+) = (+)"
        );

        check_sign(
            1'b0, 1'b0, 1'b1,
            OP_ADD,
            1'b0, 1'b0,
            "ADD: (+) + (-) (preliminary)"
        );

        check_sign(
            1'b1, 1'b0, 1'b0,
            OP_ADD,
            1'b1, 1'b1,
            "ADD: (-) + (+) (preliminary)"
        );

        check_sign(
            1'b1, 1'b0, 1'b1,
            OP_ADD,
            1'b1, 1'b1,
            "ADD: (-) + (-) = (-)"
        );

        // ====================================================================
        // Test Category 3: Subtraction (OP_SUB)
        // ====================================================================
        $display("\n--- Test Category 3: Subtraction (OP_SUB) ---");

        check_sign(
            1'b0, 1'b0, 1'b0,
            OP_SUB,
            1'b0, 1'b0,
            "SUB: (+) - (+) (preliminary)"
        );

        check_sign(
            1'b0, 1'b0, 1'b1,
            OP_SUB,
            1'b0, 1'b0,
            "SUB: (+) - (-) = (+)"
        );

        check_sign(
            1'b1, 1'b0, 1'b0,
            OP_SUB,
            1'b1, 1'b1,
            "SUB: (-) - (+) = (-)"
        );

        check_sign(
            1'b1, 1'b0, 1'b1,
            OP_SUB,
            1'b1, 1'b1,
            "SUB: (-) - (-) (preliminary)"
        );

        // ====================================================================
        // Test Category 4: FMA (Fused Multiply-Add)
        // ====================================================================
        $display("\n--- Test Category 4: FMA (X×Y + Z) ---");

        check_sign(
            1'b0, 1'b0, 1'b0,
            OP_FMA,
            1'b0, 1'b0,
            "FMA: (+×+) + (+) = (+) + (+)"
        );

        check_sign(
            1'b0, 1'b1, 1'b0,
            OP_FMA,
            1'b1, 1'b1,
            "FMA: (+×-) + (+) = (-) + (+)"
        );

        check_sign(
            1'b1, 1'b0, 1'b1,
            OP_FMA,
            1'b1, 1'b1,
            "FMA: (-×+) + (-) = (-) + (-)"
        );

        check_sign(
            1'b1, 1'b1, 1'b0,
            OP_FMA,
            1'b0, 1'b0,
            "FMA: (-×-) + (+) = (+) + (+)"
        );

        check_sign(
            1'b0, 1'b0, 1'b1,
            OP_FMA,
            1'b0, 1'b0,
            "FMA: (+×+) + (-) = (+) + (-)"
        );

        check_sign(
            1'b1, 1'b1, 1'b1,
            OP_FMA,
            1'b0, 1'b0,
            "FMA: (-×-) + (-) = (+) + (-)"
        );

        // ====================================================================
        // Test Category 5: FMS (Fused Multiply-Subtract)
        // ====================================================================
        $display("\n--- Test Category 5: FMS (X×Y - Z) ---");

        check_sign(
            1'b0, 1'b0, 1'b0,
            OP_FMS,
            1'b0, 1'b0,
            "FMS: (+×+) - (+) = (+) - (+)"
        );

        check_sign(
            1'b0, 1'b1, 1'b0,
            OP_FMS,
            1'b1, 1'b1,
            "FMS: (+×-) - (+) = (-) - (+)"
        );

        check_sign(
            1'b1, 1'b0, 1'b1,
            OP_FMS,
            1'b1, 1'b1,
            "FMS: (-×+) - (-) = (-) - (-)"
        );

        check_sign(
            1'b1, 1'b1, 1'b0,
            OP_FMS,
            1'b0, 1'b0,
            "FMS: (-×-) - (+) = (+) - (+)"
        );

        check_sign(
            1'b0, 1'b0, 1'b1,
            OP_FMS,
            1'b0, 1'b0,
            "FMS: (+×+) - (-) = (+) - (-)"
        );

        check_sign(
            1'b1, 1'b1, 1'b1,
            OP_FMS,
            1'b0, 1'b0,
            "FMS: (-×-) - (-) = (+) - (-)"
        );

        // ====================================================================
        // Test Category 6: FNMADD (Negated FMA)
        // ====================================================================
        $display("\n--- Test Category 6: FNMADD -((X×Y) + Z) ---");

        check_sign(
            1'b0, 1'b0, 1'b0,
            OP_FNMADD,
            1'b0, 1'b1,
            "FNMADD: -((+×+) + (+)) = -(+)"
        );

        check_sign(
            1'b0, 1'b1, 1'b0,
            OP_FNMADD,
            1'b1, 1'b0,
            "FNMADD: -((+×-) + (+)) = -(-)"
        );

        check_sign(
            1'b1, 1'b0, 1'b1,
            OP_FNMADD,
            1'b1, 1'b0,
            "FNMADD: -((-×+) + (-)) = -(-)"
        );

        check_sign(
            1'b1, 1'b1, 1'b0,
            OP_FNMADD,
            1'b0, 1'b1,
            "FNMADD: -((-×-) + (+)) = -(+)"
        );

        // ====================================================================
        // Test Category 7: FNMSUB (Negated FMS)
        // ====================================================================
        $display("\n--- Test Category 7: FNMSUB -((X×Y) - Z) ---");

        check_sign(
            1'b0, 1'b0, 1'b0,
            OP_FNMSUB,
            1'b0, 1'b1,
            "FNMSUB: -((+×+) - (+)) = -(+)"
        );

        check_sign(
            1'b0, 1'b1, 1'b0,
            OP_FNMSUB,
            1'b1, 1'b0,
            "FNMSUB: -((+×-) - (+)) = -(-)"
        );

        check_sign(
            1'b1, 1'b0, 1'b1,
            OP_FNMSUB,
            1'b1, 1'b0,
            "FNMSUB: -((-×+) - (-)) = -(-)"
        );

        check_sign(
            1'b1, 1'b1, 1'b0,
            OP_FNMSUB,
            1'b0, 1'b1,
            "FNMSUB: -((-×-) - (+)) = -(+)"
        );

        // ====================================================================
        // Test Category 8: Product Sign Consistency
        // ====================================================================
        $display("\n--- Test Category 8: Product Sign Consistency ---");

        // Product sign should be same regardless of operation type
        check_sign(
            1'b0, 1'b0, 1'b0,
            OP_FMA,
            1'b0, 1'bx,
            "Product: (+×+) = (+) [FMA]"
        );

        check_sign(
            1'b0, 1'b0, 1'b0,
            OP_FMS,
            1'b0, 1'bx,
            "Product: (+×+) = (+) [FMS]"
        );

        check_sign(
            1'b0, 1'b1, 1'b0,
            OP_FNMADD,
            1'b1, 1'bx,
            "Product: (+×-) = (-) [FNMADD]"
        );

        check_sign(
            1'b1, 1'b1, 1'b0,
            OP_FNMSUB,
            1'b0, 1'bx,
            "Product: (-×-) = (+) [FNMSUB]"
        );

        // ====================================================================
        // Test Category 9: All Sign Combinations
        // ====================================================================
        $display("\n--- Test Category 9: All Sign Combinations ---");

        // Test all 8 sign combinations (xs, ys, zs)
        for (i = 0; i < 8; i = i + 1) begin
            xs = i[2];
            ys = i[1];
            zs = i[0];
            op_type = OP_MUL;
            #10;

            test_count = test_count + 1;
            if (prod_sign === (xs ^ ys)) begin
                $display("[PASS] Test %0d: All combinations [%0d]: xs=%b, ys=%b → prod=%b",
                         test_count, i, xs, ys, prod_sign);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] Test %0d: All combinations [%0d]: xs=%b, ys=%b → prod=%b (expected %b)",
                         test_count, i, xs, ys, prod_sign, xs ^ ys);
                fail_count = fail_count + 1;
            end
        end

        // ====================================================================
        // Test Category 10: Edge Cases
        // ====================================================================
        $display("\n--- Test Category 10: Edge Cases ---");

        check_sign(
            1'b0, 1'b0, 1'b0,
            3'b111,  // Invalid operation
            1'b0, 1'b0,
            "Default case handling"
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

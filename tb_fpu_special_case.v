// ============================================================================
// Testbench for FPU Special Case Handler
// Tests IEEE 754 special case handling:
//   - NaN propagation and conversion
//   - Infinity arithmetic
//   - Overflow and underflow
//   - Invalid operations
// Self-checking with comprehensive test cases
// ============================================================================

`timescale 1ns / 1ps

module tb_fpu_special_case;

    // ========================================================================
    // DUT Signals
    // ========================================================================

    reg  [31:0] normal_result;
    reg         normal_sign;
    reg         x_nan, y_nan, z_nan;
    reg         x_snan, y_snan, z_snan;
    reg         x_inf, y_inf, z_inf;
    reg         x_zero, y_zero, z_zero;
    reg         overflow, underflow, invalid_op;
    reg  [2:0]  op_type;
    reg  [2:0]  rm;
    wire [31:0] result;

    // ========================================================================
    // DUT Instantiation
    // ========================================================================

    fpu_special_case dut (
        .normal_result(normal_result),
        .normal_sign(normal_sign),
        .x_nan(x_nan), .y_nan(y_nan), .z_nan(z_nan),
        .x_snan(x_snan), .y_snan(y_snan), .z_snan(z_snan),
        .x_inf(x_inf), .y_inf(y_inf), .z_inf(z_inf),
        .x_zero(x_zero), .y_zero(y_zero), .z_zero(z_zero),
        .overflow(overflow),
        .underflow(underflow),
        .invalid_op(invalid_op),
        .op_type(op_type),
        .rm(rm),
        .result(result)
    );

    // ========================================================================
    // Test Infrastructure
    // ========================================================================

    integer test_count = 0;
    integer pass_count = 0;
    integer fail_count = 0;

    // Operation types
    localparam OP_ADD = 3'b000;
    localparam OP_SUB = 3'b001;
    localparam OP_MUL = 3'b010;
    localparam OP_FMA = 3'b011;
    localparam OP_FMS = 3'b100;

    // Rounding modes
    localparam RNE = 3'b000;
    localparam RTZ = 3'b001;
    localparam RDN = 3'b010;
    localparam RUP = 3'b011;
    localparam RMM = 3'b100;

    // IEEE 754 Constants
    localparam QNAN_POS    = 32'h7FC00000;
    localparam QNAN_NEG    = 32'hFFC00000;
    localparam INF_POS     = 32'h7F800000;
    localparam INF_NEG     = 32'hFF800000;
    localparam ZERO_POS    = 32'h00000000;
    localparam ZERO_NEG    = 32'h80000000;
    localparam MAX_NORMAL  = 32'h7F7FFFFF;

    // ========================================================================
    // Test Task
    // ========================================================================

    task check_special_case;
        input [31:0] test_normal_result;
        input        test_normal_sign;
        input        test_x_nan, test_y_nan, test_z_nan;
        input        test_x_snan, test_y_snan, test_z_snan;
        input        test_x_inf, test_y_inf, test_z_inf;
        input        test_x_zero, test_y_zero, test_z_zero;
        input        test_overflow, test_underflow, test_invalid_op;
        input [2:0]  test_op_type, test_rm;
        input [31:0] expected;
        input [200:0] description;

        begin
            test_count = test_count + 1;

            normal_result = test_normal_result;
            normal_sign = test_normal_sign;
            x_nan = test_x_nan; y_nan = test_y_nan; z_nan = test_z_nan;
            x_snan = test_x_snan; y_snan = test_y_snan; z_snan = test_z_snan;
            x_inf = test_x_inf; y_inf = test_y_inf; z_inf = test_z_inf;
            x_zero = test_x_zero; y_zero = test_y_zero; z_zero = test_z_zero;
            overflow = test_overflow;
            underflow = test_underflow;
            invalid_op = test_invalid_op;
            op_type = test_op_type;
            rm = test_rm;

            #10;

            if (result === expected) begin
                $display("[PASS] Test %0d: %s", test_count, description);
                $display("       Result: %h", result);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] Test %0d: %s", test_count, description);
                $display("       Expected: %h", expected);
                $display("       Got:      %h", result);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // ========================================================================
    // Test Stimulus
    // ========================================================================

    initial begin
        $display("\n========================================");
        $display("FPU Special Case Handler Testbench");
        $display("========================================\n");

        // ====================================================================
        // Test Category 1: Signaling NaN - Highest Priority
        // ====================================================================
        $display("\n--- Test Category 1: Signaling NaN (Highest Priority) ---");

        // Test 1: sNaN in X
        check_special_case(
            32'h40000000, 1'b0,
            1'b0, 1'b0, 1'b0,  // NaN flags
            1'b1, 1'b0, 1'b0,  // sNaN flags (X has sNaN)
            1'b0, 1'b0, 1'b0,  // Inf flags
            1'b0, 1'b0, 1'b0,  // Zero flags
            1'b0, 1'b0, 1'b0,  // Exception flags
            OP_ADD, RNE,
            QNAN_POS,
            "sNaN in X → qNaN"
        );

        // Test 2: sNaN in Y
        check_special_case(
            32'h40000000, 1'b0,
            1'b0, 1'b0, 1'b0,
            1'b0, 1'b1, 1'b0,  // sNaN in Y
            1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0,
            OP_MUL, RNE,
            QNAN_POS,
            "sNaN in Y → qNaN"
        );

        // Test 3: sNaN in Z
        check_special_case(
            32'h40000000, 1'b0,
            1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b1,  // sNaN in Z
            1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0,
            OP_FMA, RNE,
            QNAN_POS,
            "sNaN in Z → qNaN"
        );

        // ====================================================================
        // Test Category 2: Quiet NaN Propagation
        // ====================================================================
        $display("\n--- Test Category 2: Quiet NaN Propagation ---");

        // Test 4: qNaN in X
        check_special_case(
            32'h40000000, 1'b0,
            1'b1, 1'b0, 1'b0,  // qNaN in X
            1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0,
            OP_ADD, RNE,
            {1'b0, 8'hFF, 1'b1, 22'd0},  // Quietized NaN
            "qNaN in X propagates"
        );

        // Test 5: qNaN in Y
        check_special_case(
            32'h40000000, 1'b0,
            1'b0, 1'b1, 1'b0,  // qNaN in Y
            1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0,
            OP_MUL, RNE,
            {1'b0, 8'hFF, 1'b1, 22'd0},
            "qNaN in Y propagates"
        );

        // Test 6: qNaN in Z
        check_special_case(
            32'h40000000, 1'b0,
            1'b0, 1'b0, 1'b1,  // qNaN in Z
            1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0,
            OP_FMA, RNE,
            {1'b0, 8'hFF, 1'b1, 22'd0},
            "qNaN in Z propagates"
        );

        // ====================================================================
        // Test Category 3: Invalid Operations
        // ====================================================================
        $display("\n--- Test Category 3: Invalid Operations ---");

        // Test 7: Invalid operation flag set
        check_special_case(
            32'h40000000, 1'b0,
            1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b1,  // Invalid operation
            OP_SUB, RNE,
            QNAN_POS,
            "Invalid operation → qNaN"
        );

        // Test 8: 0 × Inf (MUL)
        check_special_case(
            32'h40000000, 1'b0,
            1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0,
            1'b1, 1'b0, 1'b0,  // X is Inf
            1'b0, 1'b1, 1'b0,  // Y is Zero
            1'b0, 1'b0, 1'b0,
            OP_MUL, RNE,
            QNAN_POS,
            "0 × Inf → qNaN"
        );

        // Test 9: Inf × 0 (MUL)
        check_special_case(
            32'h40000000, 1'b0,
            1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0,
            1'b0, 1'b1, 1'b0,  // Y is Inf
            1'b1, 1'b0, 1'b0,  // X is Zero
            1'b0, 1'b0, 1'b0,
            OP_MUL, RNE,
            QNAN_POS,
            "Inf × 0 → qNaN"
        );

        // Test 10: 0 × Inf in FMA
        check_special_case(
            32'h40000000, 1'b0,
            1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0,
            1'b1, 1'b0, 1'b0,  // X is Inf
            1'b0, 1'b1, 1'b0,  // Y is Zero
            1'b0, 1'b0, 1'b0,
            OP_FMA, RNE,
            QNAN_POS,
            "FMA: 0 × Inf → qNaN"
        );

        // ====================================================================
        // Test Category 4: Infinity Arithmetic - Multiplication
        // ====================================================================
        $display("\n--- Test Category 4: Infinity Arithmetic (MUL) ---");

        // Test 11: Inf × normal (positive result)
        check_special_case(
            32'h40000000, 1'b0,  // Normal result, positive sign
            1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0,
            1'b1, 1'b0, 1'b0,  // X is Inf
            1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0,
            OP_MUL, RNE,
            INF_POS,
            "Inf × normal → +Inf"
        );

        // Test 12: Inf × normal (negative result)
        check_special_case(
            32'h40000000, 1'b1,  // Normal result, negative sign
            1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0,
            1'b1, 1'b0, 1'b0,  // X is Inf
            1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0,
            OP_MUL, RNE,
            INF_NEG,
            "Inf × normal → -Inf"
        );

        // Test 13: Inf × Inf (positive)
        check_special_case(
            32'h40000000, 1'b0,
            1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0,
            1'b1, 1'b1, 1'b0,  // X and Y are Inf
            1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0,
            OP_MUL, RNE,
            INF_POS,
            "Inf × Inf → +Inf"
        );

        // ====================================================================
        // Test Category 5: Infinity Arithmetic - Addition
        // ====================================================================
        $display("\n--- Test Category 5: Infinity Arithmetic (ADD/SUB) ---");

        // Test 14: Inf + normal
        check_special_case(
            32'h40000000, 1'b0,
            1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0,
            1'b1, 1'b0, 1'b0,  // X is Inf
            1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0,
            OP_ADD, RNE,
            INF_POS,
            "Inf + normal → +Inf"
        );

        // Test 15: Inf + Inf (same sign)
        check_special_case(
            32'h40000000, 1'b0,
            1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0,
            1'b1, 1'b1, 1'b0,  // Both Inf
            1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0,
            OP_ADD, RNE,
            INF_POS,
            "Inf + Inf → +Inf"
        );

        // ====================================================================
        // Test Category 6: Overflow Handling
        // ====================================================================
        $display("\n--- Test Category 6: Overflow Handling ---");

        // Test 16: Overflow with RNE → Inf
        check_special_case(
            32'h40000000, 1'b0,
            1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0,
            1'b1, 1'b0, 1'b0,  // Overflow
            OP_ADD, RNE,
            INF_POS,
            "Overflow + RNE → +Inf"
        );

        // Test 17: Overflow with RTZ → Max
        check_special_case(
            32'h40000000, 1'b0,
            1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0,
            1'b1, 1'b0, 1'b0,  // Overflow
            OP_MUL, RTZ,
            MAX_NORMAL,
            "Overflow + RTZ → Max normal"
        );

        // Test 18: Overflow with RDN, positive → Max
        check_special_case(
            32'h40000000, 1'b0,
            1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0,
            1'b1, 1'b0, 1'b0,  // Overflow
            OP_ADD, RDN,
            MAX_NORMAL,
            "Overflow + RDN (pos) → Max"
        );

        // Test 19: Overflow with RDN, negative → -Inf
        check_special_case(
            32'h40000000, 1'b1,  // Negative result
            1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0,
            1'b1, 1'b0, 1'b0,  // Overflow
            OP_ADD, RDN,
            INF_NEG,
            "Overflow + RDN (neg) → -Inf"
        );

        // Test 20: Overflow with RUP, positive → +Inf
        check_special_case(
            32'h40000000, 1'b0,
            1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0,
            1'b1, 1'b0, 1'b0,  // Overflow
            OP_MUL, RUP,
            INF_POS,
            "Overflow + RUP (pos) → +Inf"
        );

        // Test 21: Overflow with RUP, negative → Max
        check_special_case(
            32'h40000000, 1'b1,
            1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0,
            1'b1, 1'b0, 1'b0,  // Overflow
            OP_MUL, RUP,
            {1'b1, MAX_NORMAL[30:0]},
            "Overflow + RUP (neg) → -Max"
        );

        // Test 22: Overflow with RMM → Inf
        check_special_case(
            32'h40000000, 1'b0,
            1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0,
            1'b1, 1'b0, 1'b0,  // Overflow
            OP_ADD, RMM,
            INF_POS,
            "Overflow + RMM → +Inf"
        );

        // ====================================================================
        // Test Category 7: Underflow Handling
        // ====================================================================
        $display("\n--- Test Category 7: Underflow Handling ---");

        // Test 23: Underflow, positive → +0
        check_special_case(
            32'h00100000, 1'b0,
            1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0,
            1'b0, 1'b1, 1'b0,  // Underflow
            OP_MUL, RNE,
            ZERO_POS,
            "Underflow (pos) → +0"
        );

        // Test 24: Underflow, negative → -0
        check_special_case(
            32'h00100000, 1'b1,
            1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0,
            1'b0, 1'b1, 1'b0,  // Underflow
            OP_MUL, RNE,
            ZERO_NEG,
            "Underflow (neg) → -0"
        );

        // ====================================================================
        // Test Category 8: Normal Result Pass-Through
        // ====================================================================
        $display("\n--- Test Category 8: Normal Result Pass-Through ---");

        // Test 25: No special cases, return normal result
        check_special_case(
            32'h40490FDB, 1'b0,  // PI
            1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0,  // No exceptions
            OP_ADD, RNE,
            32'h40490FDB,
            "Normal result passes through"
        );

        // Test 26: Normal negative result
        check_special_case(
            32'hC0490FDB, 1'b1,  // -PI
            1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0,
            OP_SUB, RNE,
            32'hC0490FDB,
            "Normal negative result"
        );

        // ====================================================================
        // Test Category 9: Priority Testing
        // ====================================================================
        $display("\n--- Test Category 9: Priority Testing ---");

        // Test 27: sNaN beats overflow
        check_special_case(
            32'h40000000, 1'b0,
            1'b0, 1'b0, 1'b0,
            1'b1, 1'b0, 1'b0,  // sNaN
            1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0,
            1'b1, 1'b0, 1'b0,  // Overflow (lower priority)
            OP_MUL, RNE,
            QNAN_POS,
            "sNaN has priority over overflow"
        );

        // Test 28: qNaN beats infinity
        check_special_case(
            32'h40000000, 1'b0,
            1'b1, 1'b0, 1'b0,  // qNaN
            1'b0, 1'b0, 1'b0,
            1'b1, 1'b0, 1'b0,  // Infinity (lower priority)
            1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0,
            OP_ADD, RNE,
            {1'b0, 8'hFF, 1'b1, 22'd0},
            "qNaN has priority over infinity"
        );

        // Test 29: Invalid op beats infinity
        check_special_case(
            32'h40000000, 1'b0,
            1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0,
            1'b1, 1'b0, 1'b0,  // Infinity
            1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b1,  // Invalid operation (higher priority)
            OP_ADD, RNE,
            QNAN_POS,
            "Invalid op has priority over infinity"
        );

        // Test 30: Overflow beats normal result
        check_special_case(
            32'h40000000, 1'b0,
            1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0,
            1'b1, 1'b0, 1'b0,  // Overflow
            OP_MUL, RNE,
            INF_POS,
            "Overflow has priority over normal"
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

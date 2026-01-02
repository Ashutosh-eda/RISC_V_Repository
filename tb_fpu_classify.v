// ============================================================================
// Testbench for FPU Classify Module
// Tests unpacking and classification of all three operands (X, Y, Z)
// Verifies sign, exponent, mantissa extraction and special value detection
// Self-checking with comprehensive test cases
// ============================================================================

`timescale 1ns / 1ps

module tb_fpu_classify;

    // ========================================================================
    // DUT Signals
    // ========================================================================

    reg  [31:0] x_in, y_in, z_in;

    // X operand outputs
    wire        xs;
    wire [7:0]  xe;
    wire [23:0] xm;
    wire        x_zero, x_inf, x_nan, x_qnan, x_snan, x_subnormal;

    // Y operand outputs
    wire        ys;
    wire [7:0]  ye;
    wire [23:0] ym;
    wire        y_zero, y_inf, y_nan, y_qnan, y_snan, y_subnormal;

    // Z operand outputs
    wire        zs;
    wire [7:0]  ze;
    wire [23:0] zm;
    wire        z_zero, z_inf, z_nan, z_qnan, z_snan, z_subnormal;

    // ========================================================================
    // DUT Instantiation
    // ========================================================================

    fpu_classify dut (
        .x_in(x_in), .y_in(y_in), .z_in(z_in),
        .xs(xs), .xe(xe), .xm(xm),
        .x_zero(x_zero), .x_inf(x_inf), .x_nan(x_nan),
        .x_qnan(x_qnan), .x_snan(x_snan), .x_subnormal(x_subnormal),
        .ys(ys), .ye(ye), .ym(ym),
        .y_zero(y_zero), .y_inf(y_inf), .y_nan(y_nan),
        .y_qnan(y_qnan), .y_snan(y_snan), .y_subnormal(y_subnormal),
        .zs(zs), .ze(ze), .zm(zm),
        .z_zero(z_zero), .z_inf(z_inf), .z_nan(z_nan),
        .z_qnan(z_qnan), .z_snan(z_snan), .z_subnormal(z_subnormal)
    );

    // ========================================================================
    // Test Infrastructure
    // ========================================================================

    integer test_count = 0;
    integer pass_count = 0;
    integer fail_count = 0;

    // IEEE 754 Constants
    localparam POS_ONE      = 32'h3F800000;  // +1.0
    localparam NEG_ONE      = 32'hBF800000;  // -1.0
    localparam POS_ZERO     = 32'h00000000;  // +0.0
    localparam NEG_ZERO     = 32'h80000000;  // -0.0
    localparam POS_INF      = 32'h7F800000;  // +Infinity
    localparam NEG_INF      = 32'hFF800000;  // -Infinity
    localparam QNAN_POS     = 32'h7FC00000;  // Quiet NaN
    localparam SNAN_POS     = 32'h7FA00000;  // Signaling NaN
    localparam SUBNORM_MIN  = 32'h00000001;  // Smallest subnormal
    localparam SUBNORM_MAX  = 32'h007FFFFF;  // Largest subnormal
    localparam NORMAL_MIN   = 32'h00800000;  // Smallest normal

    // ========================================================================
    // Test Task
    // ========================================================================

    task check_classify;
        input [31:0] test_x, test_y, test_z;

        // Expected X outputs
        input        exp_xs;
        input [7:0]  exp_xe;
        input [23:0] exp_xm;
        input        exp_x_zero, exp_x_inf, exp_x_nan;
        input        exp_x_qnan, exp_x_snan, exp_x_subnormal;

        // Expected Y outputs
        input        exp_ys;
        input [7:0]  exp_ye;
        input [23:0] exp_ym;
        input        exp_y_zero, exp_y_inf, exp_y_nan;
        input        exp_y_qnan, exp_y_snan, exp_y_subnormal;

        // Expected Z outputs
        input        exp_zs;
        input [7:0]  exp_ze;
        input [23:0] exp_zm;
        input        exp_z_zero, exp_z_inf, exp_z_nan;
        input        exp_z_qnan, exp_z_snan, exp_z_subnormal;

        input [200:0] description;

        reg all_match;

        begin
            test_count = test_count + 1;

            x_in = test_x;
            y_in = test_y;
            z_in = test_z;

            #10;

            all_match = (xs === exp_xs) && (xe === exp_xe) && (xm === exp_xm) &&
                        (x_zero === exp_x_zero) && (x_inf === exp_x_inf) &&
                        (x_nan === exp_x_nan) && (x_qnan === exp_x_qnan) &&
                        (x_snan === exp_x_snan) && (x_subnormal === exp_x_subnormal) &&
                        (ys === exp_ys) && (ye === exp_ye) && (ym === exp_ym) &&
                        (y_zero === exp_y_zero) && (y_inf === exp_y_inf) &&
                        (y_nan === exp_y_nan) && (y_qnan === exp_y_qnan) &&
                        (y_snan === exp_y_snan) && (y_subnormal === exp_y_subnormal) &&
                        (zs === exp_zs) && (ze === exp_ze) && (zm === exp_zm) &&
                        (z_zero === exp_z_zero) && (z_inf === exp_z_inf) &&
                        (z_nan === exp_z_nan) && (z_qnan === exp_z_qnan) &&
                        (z_snan === exp_z_snan) && (z_subnormal === exp_z_subnormal);

            if (all_match) begin
                $display("[PASS] Test %0d: %s", test_count, description);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] Test %0d: %s", test_count, description);

                if (xs !== exp_xs || xe !== exp_xe || xm !== exp_xm ||
                    x_zero !== exp_x_zero || x_inf !== exp_x_inf ||
                    x_nan !== exp_x_nan || x_qnan !== exp_x_qnan ||
                    x_snan !== exp_x_snan || x_subnormal !== exp_x_subnormal) begin
                    $display("  X MISMATCH:");
                    $display("    Expected: S=%b E=%h M=%h Z=%b I=%b N=%b QN=%b SN=%b Sub=%b",
                             exp_xs, exp_xe, exp_xm, exp_x_zero, exp_x_inf,
                             exp_x_nan, exp_x_qnan, exp_x_snan, exp_x_subnormal);
                    $display("    Got:      S=%b E=%h M=%h Z=%b I=%b N=%b QN=%b SN=%b Sub=%b",
                             xs, xe, xm, x_zero, x_inf, x_nan, x_qnan, x_snan, x_subnormal);
                end

                if (ys !== exp_ys || ye !== exp_ye || ym !== exp_ym ||
                    y_zero !== exp_y_zero || y_inf !== exp_y_inf ||
                    y_nan !== exp_y_nan || y_qnan !== exp_y_qnan ||
                    y_snan !== exp_y_snan || y_subnormal !== exp_y_subnormal) begin
                    $display("  Y MISMATCH:");
                    $display("    Expected: S=%b E=%h M=%h Z=%b I=%b N=%b QN=%b SN=%b Sub=%b",
                             exp_ys, exp_ye, exp_ym, exp_y_zero, exp_y_inf,
                             exp_y_nan, exp_y_qnan, exp_y_snan, exp_y_subnormal);
                    $display("    Got:      S=%b E=%h M=%h Z=%b I=%b N=%b QN=%b SN=%b Sub=%b",
                             ys, ye, ym, y_zero, y_inf, y_nan, y_qnan, y_snan, y_subnormal);
                end

                if (zs !== exp_zs || ze !== exp_ze || zm !== exp_zm ||
                    z_zero !== exp_z_zero || z_inf !== exp_z_inf ||
                    z_nan !== exp_z_nan || z_qnan !== exp_z_qnan ||
                    z_snan !== exp_z_snan || z_subnormal !== exp_z_subnormal) begin
                    $display("  Z MISMATCH:");
                    $display("    Expected: S=%b E=%h M=%h Z=%b I=%b N=%b QN=%b SN=%b Sub=%b",
                             exp_zs, exp_ze, exp_zm, exp_z_zero, exp_z_inf,
                             exp_z_nan, exp_z_qnan, exp_z_snan, exp_z_subnormal);
                    $display("    Got:      S=%b E=%h M=%h Z=%b I=%b N=%b QN=%b SN=%b Sub=%b",
                             zs, ze, zm, z_zero, z_inf, z_nan, z_qnan, z_snan, z_subnormal);
                end

                fail_count = fail_count + 1;
            end
        end
    endtask

    // ========================================================================
    // Test Stimulus
    // ========================================================================

    initial begin
        $display("\n========================================");
        $display("FPU Classify Testbench");
        $display("========================================\n");

        // ====================================================================
        // Test Category 1: All Normal Numbers
        // ====================================================================
        $display("\n--- Test Category 1: All Normal Numbers ---");

        // Test 1: All +1.0
        check_classify(
            POS_ONE, POS_ONE, POS_ONE,
            // X: +1.0
            1'b0, 8'd127, 24'h800000,
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
            // Y: +1.0
            1'b0, 8'd127, 24'h800000,
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
            // Z: +1.0
            1'b0, 8'd127, 24'h800000,
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
            "All operands = +1.0"
        );

        // Test 2: All -1.0
        check_classify(
            NEG_ONE, NEG_ONE, NEG_ONE,
            // X: -1.0
            1'b1, 8'd127, 24'h800000,
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
            // Y: -1.0
            1'b1, 8'd127, 24'h800000,
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
            // Z: -1.0
            1'b1, 8'd127, 24'h800000,
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
            "All operands = -1.0"
        );

        // Test 3: Mixed normal numbers
        check_classify(
            POS_ONE, NEG_ONE, 32'h40000000,  // +1.0, -1.0, +2.0
            // X: +1.0
            1'b0, 8'd127, 24'h800000,
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
            // Y: -1.0
            1'b1, 8'd127, 24'h800000,
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
            // Z: +2.0
            1'b0, 8'd128, 24'h800000,
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
            "Mixed: +1.0, -1.0, +2.0"
        );

        // ====================================================================
        // Test Category 2: All Zeros
        // ====================================================================
        $display("\n--- Test Category 2: Zero Detection ---");

        // Test 4: All +0.0
        check_classify(
            POS_ZERO, POS_ZERO, POS_ZERO,
            // X: +0.0
            1'b0, 8'd0, 24'h000000,
            1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
            // Y: +0.0
            1'b0, 8'd0, 24'h000000,
            1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
            // Z: +0.0
            1'b0, 8'd0, 24'h000000,
            1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
            "All operands = +0.0"
        );

        // Test 5: All -0.0
        check_classify(
            NEG_ZERO, NEG_ZERO, NEG_ZERO,
            // X: -0.0
            1'b1, 8'd0, 24'h000000,
            1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
            // Y: -0.0
            1'b1, 8'd0, 24'h000000,
            1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
            // Z: -0.0
            1'b1, 8'd0, 24'h000000,
            1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
            "All operands = -0.0"
        );

        // Test 6: Mixed zeros
        check_classify(
            POS_ZERO, NEG_ZERO, POS_ZERO,
            // X: +0.0
            1'b0, 8'd0, 24'h000000,
            1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
            // Y: -0.0
            1'b1, 8'd0, 24'h000000,
            1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
            // Z: +0.0
            1'b0, 8'd0, 24'h000000,
            1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
            "Mixed: +0.0, -0.0, +0.0"
        );

        // ====================================================================
        // Test Category 3: Infinity Detection
        // ====================================================================
        $display("\n--- Test Category 3: Infinity Detection ---");

        // Test 7: All +Inf
        check_classify(
            POS_INF, POS_INF, POS_INF,
            // X: +Inf
            1'b0, 8'd255, 24'h000000,
            1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0,
            // Y: +Inf
            1'b0, 8'd255, 24'h000000,
            1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0,
            // Z: +Inf
            1'b0, 8'd255, 24'h000000,
            1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0,
            "All operands = +Inf"
        );

        // Test 8: All -Inf
        check_classify(
            NEG_INF, NEG_INF, NEG_INF,
            // X: -Inf
            1'b1, 8'd255, 24'h000000,
            1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0,
            // Y: -Inf
            1'b1, 8'd255, 24'h000000,
            1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0,
            // Z: -Inf
            1'b1, 8'd255, 24'h000000,
            1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0,
            "All operands = -Inf"
        );

        // Test 9: Mixed infinities
        check_classify(
            POS_INF, NEG_INF, POS_INF,
            // X: +Inf
            1'b0, 8'd255, 24'h000000,
            1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0,
            // Y: -Inf
            1'b1, 8'd255, 24'h000000,
            1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0,
            // Z: +Inf
            1'b0, 8'd255, 24'h000000,
            1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0,
            "Mixed: +Inf, -Inf, +Inf"
        );

        // ====================================================================
        // Test Category 4: NaN Detection
        // ====================================================================
        $display("\n--- Test Category 4: NaN Detection ---");

        // Test 10: All quiet NaN
        check_classify(
            QNAN_POS, QNAN_POS, QNAN_POS,
            // X: qNaN
            1'b0, 8'd255, 24'hC00000,
            1'b0, 1'b0, 1'b1, 1'b1, 1'b0, 1'b0,
            // Y: qNaN
            1'b0, 8'd255, 24'hC00000,
            1'b0, 1'b0, 1'b1, 1'b1, 1'b0, 1'b0,
            // Z: qNaN
            1'b0, 8'd255, 24'hC00000,
            1'b0, 1'b0, 1'b1, 1'b1, 1'b0, 1'b0,
            "All operands = qNaN"
        );

        // Test 11: All signaling NaN
        check_classify(
            SNAN_POS, SNAN_POS, SNAN_POS,
            // X: sNaN
            1'b0, 8'd255, 24'hA00000,
            1'b0, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0,
            // Y: sNaN
            1'b0, 8'd255, 24'hA00000,
            1'b0, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0,
            // Z: sNaN
            1'b0, 8'd255, 24'hA00000,
            1'b0, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0,
            "All operands = sNaN"
        );

        // Test 12: Mixed NaNs
        check_classify(
            QNAN_POS, SNAN_POS, QNAN_POS,
            // X: qNaN
            1'b0, 8'd255, 24'hC00000,
            1'b0, 1'b0, 1'b1, 1'b1, 1'b0, 1'b0,
            // Y: sNaN
            1'b0, 8'd255, 24'hA00000,
            1'b0, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0,
            // Z: qNaN
            1'b0, 8'd255, 24'hC00000,
            1'b0, 1'b0, 1'b1, 1'b1, 1'b0, 1'b0,
            "Mixed: qNaN, sNaN, qNaN"
        );

        // ====================================================================
        // Test Category 5: Subnormal Detection
        // ====================================================================
        $display("\n--- Test Category 5: Subnormal Detection ---");

        // Test 13: Smallest subnormals
        check_classify(
            SUBNORM_MIN, SUBNORM_MIN, SUBNORM_MIN,
            // X: smallest subnormal
            1'b0, 8'd0, 24'h000001,
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1,
            // Y: smallest subnormal
            1'b0, 8'd0, 24'h000001,
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1,
            // Z: smallest subnormal
            1'b0, 8'd0, 24'h000001,
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1,
            "All smallest subnormal"
        );

        // Test 14: Largest subnormals
        check_classify(
            SUBNORM_MAX, SUBNORM_MAX, SUBNORM_MAX,
            // X: largest subnormal
            1'b0, 8'd0, 24'h7FFFFF,
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1,
            // Y: largest subnormal
            1'b0, 8'd0, 24'h7FFFFF,
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1,
            // Z: largest subnormal
            1'b0, 8'd0, 24'h7FFFFF,
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1,
            "All largest subnormal"
        );

        // Test 15: Mixed subnormals
        check_classify(
            SUBNORM_MIN, SUBNORM_MAX, 32'h00400000,
            // X: smallest subnormal
            1'b0, 8'd0, 24'h000001,
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1,
            // Y: largest subnormal
            1'b0, 8'd0, 24'h7FFFFF,
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1,
            // Z: mid subnormal
            1'b0, 8'd0, 24'h400000,
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1,
            "Mixed subnormals"
        );

        // ====================================================================
        // Test Category 6: Mixed Special Values
        // ====================================================================
        $display("\n--- Test Category 6: Mixed Special Values ---");

        // Test 16: Zero, Inf, NaN
        check_classify(
            POS_ZERO, POS_INF, QNAN_POS,
            // X: +0.0
            1'b0, 8'd0, 24'h000000,
            1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
            // Y: +Inf
            1'b0, 8'd255, 24'h000000,
            1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0,
            // Z: qNaN
            1'b0, 8'd255, 24'hC00000,
            1'b0, 1'b0, 1'b1, 1'b1, 1'b0, 1'b0,
            "Mixed: +0, +Inf, qNaN"
        );

        // Test 17: Normal, Subnormal, Zero
        check_classify(
            POS_ONE, SUBNORM_MIN, NEG_ZERO,
            // X: +1.0
            1'b0, 8'd127, 24'h800000,
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
            // Y: subnormal
            1'b0, 8'd0, 24'h000001,
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1,
            // Z: -0.0
            1'b1, 8'd0, 24'h000000,
            1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
            "Mixed: Normal, Subnormal, Zero"
        );

        // Test 18: All different special values
        check_classify(
            NEG_INF, SNAN_POS, SUBNORM_MAX,
            // X: -Inf
            1'b1, 8'd255, 24'h000000,
            1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0,
            // Y: sNaN
            1'b0, 8'd255, 24'hA00000,
            1'b0, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0,
            // Z: largest subnormal
            1'b0, 8'd0, 24'h7FFFFF,
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1,
            "Mixed: -Inf, sNaN, Subnormal"
        );

        // ====================================================================
        // Test Category 7: Boundary Cases
        // ====================================================================
        $display("\n--- Test Category 7: Boundary Cases ---");

        // Test 19: Smallest normal numbers
        check_classify(
            NORMAL_MIN, NORMAL_MIN, NORMAL_MIN,
            // X: smallest normal
            1'b0, 8'd1, 24'h800000,
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
            // Y: smallest normal
            1'b0, 8'd1, 24'h800000,
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
            // Z: smallest normal
            1'b0, 8'd1, 24'h800000,
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
            "All smallest normal"
        );

        // Test 20: Largest normal numbers
        check_classify(
            32'h7F7FFFFF, 32'h7F7FFFFF, 32'h7F7FFFFF,
            // X: largest normal
            1'b0, 8'd254, 24'hFFFFFF,
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
            // Y: largest normal
            1'b0, 8'd254, 24'hFFFFFF,
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
            // Z: largest normal
            1'b0, 8'd254, 24'hFFFFFF,
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
            "All largest normal"
        );

        // Test 21: Boundary between subnormal and normal
        check_classify(
            SUBNORM_MAX, NORMAL_MIN, POS_ONE,
            // X: largest subnormal
            1'b0, 8'd0, 24'h7FFFFF,
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1,
            // Y: smallest normal
            1'b0, 8'd1, 24'h800000,
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
            // Z: +1.0
            1'b0, 8'd127, 24'h800000,
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
            "Boundary: Subnormal/Normal"
        );

        // ====================================================================
        // Test Category 8: Real FMA Operand Patterns
        // ====================================================================
        $display("\n--- Test Category 8: Real FMA Operand Patterns ---");

        // Test 22: Typical FMA: x*y+z all normal
        check_classify(
            32'h40490FDB, 32'h402DF854, 32'h3F000000,  // PI, e, 0.5
            // X: PI
            1'b0, 8'd128, 24'hC90FDB,
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
            // Y: e
            1'b0, 8'd128, 24'hADF854,
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
            // Z: 0.5
            1'b0, 8'd126, 24'h800000,
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
            "FMA typical: PI × e + 0.5"
        );

        // Test 23: FMA with one zero
        check_classify(
            POS_ZERO, POS_ONE, NEG_ONE,
            // X: +0.0
            1'b0, 8'd0, 24'h000000,
            1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
            // Y: +1.0
            1'b0, 8'd127, 24'h800000,
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
            // Z: -1.0
            1'b1, 8'd127, 24'h800000,
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
            "FMA with zero: 0 × 1 + (-1)"
        );

        // Test 24: FMA with infinity
        check_classify(
            POS_INF, POS_ONE, NEG_ONE,
            // X: +Inf
            1'b0, 8'd255, 24'h000000,
            1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0,
            // Y: +1.0
            1'b0, 8'd127, 24'h800000,
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
            // Z: -1.0
            1'b1, 8'd127, 24'h800000,
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
            "FMA with Inf: Inf × 1 + (-1)"
        );

        // Test 25: FMA with NaN
        check_classify(
            QNAN_POS, POS_ONE, POS_ONE,
            // X: qNaN
            1'b0, 8'd255, 24'hC00000,
            1'b0, 1'b0, 1'b1, 1'b1, 1'b0, 1'b0,
            // Y: +1.0
            1'b0, 8'd127, 24'h800000,
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
            // Z: +1.0
            1'b0, 8'd127, 24'h800000,
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
            "FMA with NaN: NaN × 1 + 1"
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

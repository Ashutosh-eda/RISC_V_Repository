// ============================================================================
// Self-Checking Testbench for Complex Multiplier
// Tests: (a+jb) × (c+jd) = (ac-bd) + j(ad+bc)
// Coverage: Identity, Conjugate, Pure imaginary, Latency verification
// ============================================================================

`timescale 1ns / 1ps

module tb_complex_multiplier;

    // ========================================================================
    // Test Infrastructure
    // ========================================================================
    reg         clk;
    reg         rst_n;
    reg  [31:0] a_real, a_imag;  // First complex number
    reg  [31:0] b_real, b_imag;  // Second complex number
    wire [31:0] result_real, result_imag;
    wire        valid;

    integer test_count = 0;
    integer pass_count = 0;
    integer fail_count = 0;
    integer cycle_count = 0;

    // Result queue (7-cycle latency)
    reg [31:0] expected_real_queue [0:15];
    reg [31:0] expected_imag_queue [0:15];
    reg [200:0] description_queue [0:15];
    integer queue_head = 0;
    integer queue_tail = 0;

    // ========================================================================
    // Clock Generation
    // ========================================================================
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100 MHz
    end

    // ========================================================================
    // DUT Instantiation
    // ========================================================================
    complex_multiplier uut (
        .clk        (clk),
        .rst_n      (rst_n),
        .a_real     (a_real),
        .a_imag     (a_imag),
        .b_real     (b_real),
        .b_imag     (b_imag),
        .result_real(result_real),
        .result_imag(result_imag),
        .valid      (valid)
    );

    // ========================================================================
    // Helper Functions
    // ========================================================================
    function [31:0] real_to_fp32;
        input real value;
        begin
            real_to_fp32 = $realtobits(value);
        end
    endfunction

    function real fp32_to_real;
        input [31:0] bits;
        begin
            fp32_to_real = $bitstoreal(bits);
        end
    endfunction

    function is_close;
        input [31:0] a;
        input [31:0] b;
        real val_a, val_b, diff;
        begin
            val_a = fp32_to_real(a);
            val_b = fp32_to_real(b);
            diff = (val_a > val_b) ? (val_a - val_b) : (val_b - val_a);
            is_close = (diff < 1e-5) || (a === b);
        end
    endfunction

    // ========================================================================
    // Test Tasks
    // ========================================================================

    // Test complex multiplication
    task test_complex_mul;
        input real ar, ai, br, bi;
        input real expected_r, expected_i;
        input [200:0] description;

        begin
            // Send inputs
            a_real = real_to_fp32(ar);
            a_imag = real_to_fp32(ai);
            b_real = real_to_fp32(br);
            b_imag = real_to_fp32(bi);

            // Queue expected results (7-cycle delay)
            expected_real_queue[queue_tail] = real_to_fp32(expected_r);
            expected_imag_queue[queue_tail] = real_to_fp32(expected_i);
            description_queue[queue_tail] = description;
            queue_tail = (queue_tail + 1) % 16;

            @(posedge clk);
        end
    endtask

    // Check output
    task check_output;
        real got_r, got_i, exp_r, exp_i;
        begin
            if (valid && (queue_head != queue_tail)) begin
                test_count = test_count + 1;
                got_r = fp32_to_real(result_real);
                got_i = fp32_to_real(result_imag);
                exp_r = fp32_to_real(expected_real_queue[queue_head]);
                exp_i = fp32_to_real(expected_imag_queue[queue_head]);

                if (is_close(result_real, expected_real_queue[queue_head]) &&
                    is_close(result_imag, expected_imag_queue[queue_head])) begin
                    $display("[PASS] Test %0d: %s", test_count, description_queue[queue_head]);
                    $display("       Result: (%f + j%f)", got_r, got_i);
                    pass_count = pass_count + 1;
                end else begin
                    $display("[FAIL] Test %0d: %s", test_count, description_queue[queue_head]);
                    $display("  Expected: (%f + j%f)", exp_r, exp_i);
                    $display("  Got:      (%f + j%f)", got_r, got_i);
                    $display("  Error:    real=%.2e imag=%.2e",
                             got_r - exp_r, got_i - exp_i);
                    fail_count = fail_count + 1;
                end

                queue_head = (queue_head + 1) % 16;
            end
        end
    endtask

    // ========================================================================
    // Test Sequence
    // ========================================================================
    initial begin
        $display("========================================");
        $display("Complex Multiplier Tests");
        $display("Formula: (a+jb) × (c+jd) = (ac-bd) + j(ad+bc)");
        $display("========================================\n");

        // Initialize
        rst_n = 0;
        a_real = 0; a_imag = 0;
        b_real = 0; b_imag = 0;
        queue_head = 0;
        queue_tail = 0;

        repeat(5) @(posedge clk);
        rst_n = 1;
        repeat(2) @(posedge clk);

        // --------------------------------------------------------------------
        // Category 1: Identity (×1)
        // --------------------------------------------------------------------
        $display("--- Testing IDENTITY ---");

        // (1+j0) × (1+j0) = (1+j0)
        test_complex_mul(
            1.0, 0.0,    // a = 1+j0
            1.0, 0.0,    // b = 1+j0
            1.0, 0.0,    // Result
            "(1+j0) × (1+j0) = (1+j0)"
        );

        // (2+j3) × (1+j0) = (2+j3)
        test_complex_mul(
            2.0, 3.0,
            1.0, 0.0,
            2.0, 3.0,
            "(2+j3) × (1+j0) = (2+j3)"
        );

        // Wait for pipeline (7 cycles)
        repeat(7) @(posedge clk);

        repeat(2) begin
            check_output();
            @(posedge clk);
        end

        // --------------------------------------------------------------------
        // Category 2: Pure Imaginary
        // --------------------------------------------------------------------
        $display("\n--- Testing PURE IMAGINARY ---");

        // (0+j1) × (0+j1) = (-1+j0)
        // j² = -1
        test_complex_mul(
            0.0, 1.0,
            0.0, 1.0,
            -1.0, 0.0,
            "(j) × (j) = -1"
        );

        // (0+j2) × (0+j3) = (-6+j0)
        test_complex_mul(
            0.0, 2.0,
            0.0, 3.0,
            -6.0, 0.0,
            "(j2) × (j3) = -6"
        );

        // (2+j0) × (0+j3) = (0+j6)
        test_complex_mul(
            2.0, 0.0,
            0.0, 3.0,
            0.0, 6.0,
            "2 × (j3) = j6"
        );

        repeat(3) begin
            check_output();
            @(posedge clk);
        end

        // --------------------------------------------------------------------
        // Category 3: Conjugate Multiplication
        // --------------------------------------------------------------------
        $display("\n--- Testing CONJUGATE ---");

        // (1+j1) × (1-j1) = (2+j0)
        // (a+jb)(a-jb) = a² + b²
        test_complex_mul(
            1.0, 1.0,
            1.0, -1.0,
            2.0, 0.0,
            "(1+j) × (1-j) = 2"
        );

        // (3+j4) × (3-j4) = (25+j0)
        test_complex_mul(
            3.0, 4.0,
            3.0, -4.0,
            25.0, 0.0,
            "(3+j4) × (3-j4) = 25"
        );

        repeat(2) begin
            check_output();
            @(posedge clk);
        end

        // --------------------------------------------------------------------
        // Category 4: General Complex Numbers
        // --------------------------------------------------------------------
        $display("\n--- Testing GENERAL CASES ---");

        // (2+j3) × (4+j5) = (8-15) + j(10+12) = (-7+j22)
        test_complex_mul(
            2.0, 3.0,
            4.0, 5.0,
            -7.0, 22.0,
            "(2+j3) × (4+j5) = (-7+j22)"
        );

        // (1+j2) × (3+j4) = (3-8) + j(4+6) = (-5+j10)
        test_complex_mul(
            1.0, 2.0,
            3.0, 4.0,
            -5.0, 10.0,
            "(1+j2) × (3+j4) = (-5+j10)"
        );

        // (-2+j3) × (1-j2) = (-2+6) + j(-4+3) = (4-j)
        test_complex_mul(
            -2.0, 3.0,
            1.0, -2.0,
            4.0, -1.0,
            "(-2+j3) × (1-j2) = (4-j)"
        );

        repeat(3) begin
            check_output();
            @(posedge clk);
        end

        // --------------------------------------------------------------------
        // Category 5: Zero
        // --------------------------------------------------------------------
        $display("\n--- Testing ZERO ---");

        // (0+j0) × (5+j7) = (0+j0)
        test_complex_mul(
            0.0, 0.0,
            5.0, 7.0,
            0.0, 0.0,
            "(0) × (5+j7) = 0"
        );

        // (3+j4) × (0+j0) = (0+j0)
        test_complex_mul(
            3.0, 4.0,
            0.0, 0.0,
            0.0, 0.0,
            "(3+j4) × (0) = 0"
        );

        repeat(2) begin
            check_output();
            @(posedge clk);
        end

        // --------------------------------------------------------------------
        // Category 6: Rotation (Twiddle Factors)
        // --------------------------------------------------------------------
        $display("\n--- Testing ROTATION (Twiddle Factors) ---");

        // (1+j0) × (0.707-j0.707) ≈ (0.707-j0.707) [45° rotation]
        test_complex_mul(
            1.0, 0.0,
            0.707, -0.707,
            0.707, -0.707,
            "(1) × W^1 = W^1"
        );

        // (1+j0) × (0-j1) = (0-j) [-90° rotation]
        test_complex_mul(
            1.0, 0.0,
            0.0, -1.0,
            0.0, -1.0,
            "(1) × (-j) = -j"
        );

        // (1+j1) × (0-j1) = (1-j1)
        test_complex_mul(
            1.0, 1.0,
            0.0, -1.0,
            1.0, -1.0,
            "(1+j) × (-j) = (1-j)"
        );

        repeat(3) begin
            check_output();
            @(posedge clk);
        end

        // --------------------------------------------------------------------
        // Category 7: Latency Verification
        // --------------------------------------------------------------------
        $display("\n--- Testing LATENCY (7 cycles) ---");

        // Send continuous stream
        cycle_count = 0;
        repeat(3) begin
            test_complex_mul(
                1.0, 1.0,
                2.0, 2.0,
                0.0, 4.0,  // (1+j)(2+j2) = (2-2) + j(2+2) = j4
                "Continuous stream test"
            );
        end

        // First valid should appear after exactly 7 cycles from start
        repeat(7) begin
            @(posedge clk);
            cycle_count = cycle_count + 1;
        end

        if (valid) begin
            $display("[PASS] Valid asserted after %0d cycles (expected 7)", cycle_count);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Valid NOT asserted after 7 cycles");
            fail_count = fail_count + 1;
        end

        repeat(3) begin
            check_output();
            @(posedge clk);
        end

        // --------------------------------------------------------------------
        // Category 8: Commutative Property
        // --------------------------------------------------------------------
        $display("\n--- Testing COMMUTATIVE PROPERTY ---");

        // (a+jb) × (c+jd) should equal (c+jd) × (a+jb)
        test_complex_mul(
            2.5, 3.7,
            4.2, -1.8,
            17.16, 11.04,  // Pre-computed
            "A × B"
        );

        test_complex_mul(
            4.2, -1.8,
            2.5, 3.7,
            17.16, 11.04,  // Should be same
            "B × A (commutative)"
        );

        repeat(2) begin
            check_output();
            @(posedge clk);
        end

        // --------------------------------------------------------------------
        // Drain Pipeline
        // --------------------------------------------------------------------
        $display("\n--- Draining Pipeline ---");
        repeat(10) begin
            check_output();
            @(posedge clk);
        end

        // --------------------------------------------------------------------
        // Test Summary
        // --------------------------------------------------------------------
        $display("\n========================================");
        $display("Test Summary:");
        $display("  Total Tests: %0d", test_count);
        $display("  Passed:      %0d", pass_count);
        $display("  Failed:      %0d", fail_count);
        if (test_count > 0)
            $display("  Pass Rate:   %.2f%%", (pass_count * 100.0) / test_count);
        $display("========================================\n");

        if (fail_count == 0) begin
            $display("*** ALL TESTS PASSED ***\n");
        end else begin
            $display("*** SOME TESTS FAILED ***\n");
        end

        $finish;
    end

    // Monitor valid signal
    always @(posedge clk) begin
        if (valid) begin
            check_output();
        end
    end

    // Timeout
    initial begin
        #200000;
        $display("\n[ERROR] Testbench timeout!");
        $finish;
    end

endmodule

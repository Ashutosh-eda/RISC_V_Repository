// ============================================================================
// Self-Checking Testbench for FFT Butterfly Radix-2
// Tests: Out0 = X + Y×W, Out1 = X - Y×W
// Coverage: All twiddle factors, Real/Complex inputs, Latency
// ============================================================================

`timescale 1ns / 1ps

module tb_fft_butterfly_radix2;

    // ========================================================================
    // Test Infrastructure
    // ========================================================================
    reg         clk;
    reg         rst_n;
    reg  [31:0] x_real, x_imag;
    reg  [31:0] y_real, y_imag;
    reg  [31:0] w_real, w_imag;
    wire [31:0] out0_real, out0_imag;
    wire [31:0] out1_real, out1_imag;
    wire        valid;

    integer test_count = 0;
    integer pass_count = 0;
    integer fail_count = 0;

    // Result queue (11-cycle latency)
    reg [31:0] exp_out0_real_q [0:20];
    reg [31:0] exp_out0_imag_q [0:20];
    reg [31:0] exp_out1_real_q [0:20];
    reg [31:0] exp_out1_imag_q [0:20];
    reg [200:0] description_q [0:20];
    integer q_head = 0;
    integer q_tail = 0;

    // ========================================================================
    // Clock Generation
    // ========================================================================
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // ========================================================================
    // DUT Instantiation
    // ========================================================================
    fft_butterfly_radix2 uut (
        .clk       (clk),
        .rst_n     (rst_n),
        .x_real    (x_real),
        .x_imag    (x_imag),
        .y_real    (y_real),
        .y_imag    (y_imag),
        .w_real    (w_real),
        .w_imag    (w_imag),
        .out0_real (out0_real),
        .out0_imag (out0_imag),
        .out1_real (out1_real),
        .out1_imag (out1_imag),
        .valid     (valid)
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
        input [31:0] a, b;
        real va, vb, diff;
        begin
            va = fp32_to_real(a);
            vb = fp32_to_real(b);
            diff = (va > vb) ? (va - vb) : (vb - va);
            is_close = (diff < 1e-4) || (a === b);
        end
    endfunction

    // ========================================================================
    // Test Tasks
    // ========================================================================
    task test_butterfly;
        input real xr, xi, yr, yi, wr, wi;
        input real exp_out0r, exp_out0i, exp_out1r, exp_out1i;
        input [200:0] desc;

        begin
            // Send inputs
            x_real = real_to_fp32(xr);
            x_imag = real_to_fp32(xi);
            y_real = real_to_fp32(yr);
            y_imag = real_to_fp32(yi);
            w_real = real_to_fp32(wr);
            w_imag = real_to_fp32(wi);

            // Queue expected (11-cycle delay)
            exp_out0_real_q[q_tail] = real_to_fp32(exp_out0r);
            exp_out0_imag_q[q_tail] = real_to_fp32(exp_out0i);
            exp_out1_real_q[q_tail] = real_to_fp32(exp_out1r);
            exp_out1_imag_q[q_tail] = real_to_fp32(exp_out1i);
            description_q[q_tail] = desc;
            q_tail = (q_tail + 1) % 21;

            @(posedge clk);
        end
    endtask

    task check_output;
        real got_out0r, got_out0i, got_out1r, got_out1i;
        real exp_out0r, exp_out0i, exp_out1r, exp_out1i;

        begin
            if (valid && (q_head != q_tail)) begin
                test_count = test_count + 1;

                got_out0r = fp32_to_real(out0_real);
                got_out0i = fp32_to_real(out0_imag);
                got_out1r = fp32_to_real(out1_real);
                got_out1i = fp32_to_real(out1_imag);

                exp_out0r = fp32_to_real(exp_out0_real_q[q_head]);
                exp_out0i = fp32_to_real(exp_out0_imag_q[q_head]);
                exp_out1r = fp32_to_real(exp_out1_real_q[q_head]);
                exp_out1i = fp32_to_real(exp_out1_imag_q[q_head]);

                if (is_close(out0_real, exp_out0_real_q[q_head]) &&
                    is_close(out0_imag, exp_out0_imag_q[q_head]) &&
                    is_close(out1_real, exp_out1_real_q[q_head]) &&
                    is_close(out1_imag, exp_out1_imag_q[q_head])) begin

                    $display("[PASS] Test %0d: %s", test_count, description_q[q_head]);
                    $display("       Out0: (%f + j%f)", got_out0r, got_out0i);
                    $display("       Out1: (%f + j%f)", got_out1r, got_out1i);
                    pass_count = pass_count + 1;
                end else begin
                    $display("[FAIL] Test %0d: %s", test_count, description_q[q_head]);
                    $display("  Out0 Expected: (%f + j%f)", exp_out0r, exp_out0i);
                    $display("  Out0 Got:      (%f + j%f)", got_out0r, got_out0i);
                    $display("  Out1 Expected: (%f + j%f)", exp_out1r, exp_out1i);
                    $display("  Out1 Got:      (%f + j%f)", got_out1r, got_out1i);
                    fail_count = fail_count + 1;
                end

                q_head = (q_head + 1) % 21;
            end
        end
    endtask

    // ========================================================================
    // Test Sequence
    // ========================================================================
    initial begin
        $display("========================================");
        $display("FFT Butterfly Radix-2 Tests");
        $display("Out0 = X + Y×W");
        $display("Out1 = X - Y×W");
        $display("========================================\n");

        // Initialize
        rst_n = 0;
        x_real = 0; x_imag = 0;
        y_real = 0; y_imag = 0;
        w_real = 0; w_imag = 0;
        q_head = 0; q_tail = 0;

        repeat(5) @(posedge clk);
        rst_n = 1;
        repeat(2) @(posedge clk);

        // --------------------------------------------------------------------
        // Category 1: W = 1.0 (No Rotation)
        // --------------------------------------------------------------------
        $display("--- Testing W = 1.0 (No Rotation) ---");

        // X=(1,0), Y=(1,0), W=(1,0)
        // Y×W = (1,0)
        // Out0 = (1,0) + (1,0) = (2,0)
        // Out1 = (1,0) - (1,0) = (0,0)
        test_butterfly(
            1.0, 0.0,    // X
            1.0, 0.0,    // Y
            1.0, 0.0,    // W
            2.0, 0.0,    // Out0
            0.0, 0.0,    // Out1
            "X=(1,0), Y=(1,0), W=(1,0)"
        );

        // X=(2,3), Y=(4,5), W=(1,0)
        // Out0 = (2,3) + (4,5) = (6,8)
        // Out1 = (2,3) - (4,5) = (-2,-2)
        test_butterfly(
            2.0, 3.0,
            4.0, 5.0,
            1.0, 0.0,
            6.0, 8.0,
            -2.0, -2.0,
            "X=(2,3), Y=(4,5), W=(1,0)"
        );

        repeat(11) @(posedge clk);
        repeat(2) begin
            check_output();
            @(posedge clk);
        end

        // --------------------------------------------------------------------
        // Category 2: W = -j (90° Rotation)
        // --------------------------------------------------------------------
        $display("\n--- Testing W = -j (90° Rotation) ---");

        // X=(1,0), Y=(1,0), W=(0,-1)
        // Y×W = (1,0)×(0,-1) = (0,-1)
        // Out0 = (1,0) + (0,-1) = (1,-1)
        // Out1 = (1,0) - (0,-1) = (1,1)
        test_butterfly(
            1.0, 0.0,
            1.0, 0.0,
            0.0, -1.0,
            1.0, -1.0,
            1.0, 1.0,
            "X=(1,0), Y=(1,0), W=(0,-j)"
        );

        // X=(2,0), Y=(3,0), W=(0,-1)
        // Y×W = (3,0)×(0,-1) = (0,-3)
        // Out0 = (2,0) + (0,-3) = (2,-3)
        // Out1 = (2,0) - (0,-3) = (2,3)
        test_butterfly(
            2.0, 0.0,
            3.0, 0.0,
            0.0, -1.0,
            2.0, -3.0,
            2.0, 3.0,
            "X=(2,0), Y=(3,0), W=(0,-j)"
        );

        repeat(2) begin
            check_output();
            @(posedge clk);
        end

        // --------------------------------------------------------------------
        // Category 3: W = 0.707 - j0.707 (45° Rotation)
        // --------------------------------------------------------------------
        $display("\n--- Testing W = 0.707-j0.707 (45° Rotation) ---");

        // X=(1,0), Y=(1,0), W=(0.707,-0.707)
        // Y×W = (0.707,-0.707)
        // Out0 = (1,0) + (0.707,-0.707) = (1.707,-0.707)
        // Out1 = (1,0) - (0.707,-0.707) = (0.293,0.707)
        test_butterfly(
            1.0, 0.0,
            1.0, 0.0,
            0.707, -0.707,
            1.707, -0.707,
            0.293, 0.707,
            "X=(1,0), Y=(1,0), W=(0.707-j0.707)"
        );

        check_output();
        @(posedge clk);

        // --------------------------------------------------------------------
        // Category 4: W = -0.707 - j0.707 (135° Rotation)
        // --------------------------------------------------------------------
        $display("\n--- Testing W = -0.707-j0.707 (135° Rotation) ---");

        // X=(1,0), Y=(1,0), W=(-0.707,-0.707)
        // Y×W = (-0.707,-0.707)
        // Out0 = (1,0) + (-0.707,-0.707) = (0.293,-0.707)
        // Out1 = (1,0) - (-0.707,-0.707) = (1.707,0.707)
        test_butterfly(
            1.0, 0.0,
            1.0, 0.0,
            -0.707, -0.707,
            0.293, -0.707,
            1.707, 0.707,
            "X=(1,0), Y=(1,0), W=(-0.707-j0.707)"
        );

        check_output();
        @(posedge clk);

        // --------------------------------------------------------------------
        // Category 5: Zero Input
        // --------------------------------------------------------------------
        $display("\n--- Testing ZERO INPUTS ---");

        // X=(0,0), Y=(5,7), W=(1,0)
        // Out0 = (0,0) + (5,7) = (5,7)
        // Out1 = (0,0) - (5,7) = (-5,-7)
        test_butterfly(
            0.0, 0.0,
            5.0, 7.0,
            1.0, 0.0,
            5.0, 7.0,
            -5.0, -7.0,
            "X=(0,0), Y=(5,7), W=(1,0)"
        );

        // X=(3,4), Y=(0,0), W=(1,0)
        // Out0 = (3,4) + (0,0) = (3,4)
        // Out1 = (3,4) - (0,0) = (3,4)
        test_butterfly(
            3.0, 4.0,
            0.0, 0.0,
            1.0, 0.0,
            3.0, 4.0,
            3.0, 4.0,
            "X=(3,4), Y=(0,0), W=(1,0)"
        );

        repeat(2) begin
            check_output();
            @(posedge clk);
        end

        // --------------------------------------------------------------------
        // Category 6: Complex Inputs
        // --------------------------------------------------------------------
        $display("\n--- Testing COMPLEX INPUTS ---");

        // X=(1,2), Y=(3,4), W=(0.5,0.5)
        // Y×W = (3,4)×(0.5,0.5) = (1.5-2.0, 1.5+2.0) = (-0.5,3.5)
        // Out0 = (1,2) + (-0.5,3.5) = (0.5,5.5)
        // Out1 = (1,2) - (-0.5,3.5) = (1.5,-1.5)
        test_butterfly(
            1.0, 2.0,
            3.0, 4.0,
            0.5, 0.5,
            0.5, 5.5,
            1.5, -1.5,
            "X=(1,2), Y=(3,4), W=(0.5,0.5)"
        );

        check_output();
        @(posedge clk);

        // --------------------------------------------------------------------
        // Category 7: Latency Verification
        // --------------------------------------------------------------------
        $display("\n--- Testing LATENCY (11 cycles) ---");

        // Send 3 back-to-back operations
        repeat(3) begin
            test_butterfly(
                1.0, 1.0,
                2.0, 2.0,
                1.0, 0.0,
                3.0, 3.0,
                -1.0, -1.0,
                "Continuous stream"
            );
        end

        // Check valid appears after 11 cycles
        repeat(11) @(posedge clk);
        if (valid) begin
            $display("[PASS] Valid asserted after 11 cycles");
        end else begin
            $display("[FAIL] Valid NOT asserted after 11 cycles");
            fail_count = fail_count + 1;
        end

        repeat(3) begin
            check_output();
            @(posedge clk);
        end

        // --------------------------------------------------------------------
        // Drain Pipeline
        // --------------------------------------------------------------------
        repeat(15) begin
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

    // Monitor valid
    always @(posedge clk) begin
        if (valid) check_output();
    end

    // Timeout
    initial begin
        #300000;
        $display("\n[ERROR] Timeout!");
        $finish;
    end

endmodule

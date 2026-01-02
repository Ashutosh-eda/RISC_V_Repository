// ============================================================================
// Self-Checking Testbench for FP32 Multiplier Pipeline
// Tests: Full IEEE 754 single-precision multiplication
// Coverage: Normal, Special cases, Overflow, Underflow, Latency
// ============================================================================

`timescale 1ns / 1ps

module tb_fp32_multiplier_pipe;

    // ========================================================================
    // Test Infrastructure
    // ========================================================================
    reg         clk;
    reg         rst_n;
    reg  [31:0] x;
    reg  [31:0] y;
    reg  [2:0]  rm;
    wire [31:0] product;
    wire [4:0]  flags;

    integer test_count = 0;
    integer pass_count = 0;
    integer fail_count = 0;

    // Result queue for pipeline (3-cycle latency)
    reg [31:0] expected_queue [0:10];
    reg [200:0] description_queue [0:10];
    integer queue_head = 0;
    integer queue_tail = 0;

    // ========================================================================
    // Clock Generation
    // ========================================================================
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100 MHz clock
    end

    // ========================================================================
    // DUT Instantiation
    // ========================================================================
    fp32_multiplier_pipe uut (
        .clk     (clk),
        .rst_n   (rst_n),
        .x       (x),
        .y       (y),
        .rm      (rm),
        .product (product),
        .flags   (flags)
    );

    // ========================================================================
    // Helper Functions
    // ========================================================================

    // Convert real to IEEE 754 single-precision bits
    function [31:0] real_to_fp32;
        input real value;
        begin
            // $shortrealtobits returns 32-bit IEEE 754 single-precision
            real_to_fp32 = $shortrealtobits(value);
        end
    endfunction

    // Convert IEEE 754 bits to real
    function real fp32_to_real;
        input [31:0] bits;
        begin
            fp32_to_real = $bitstoreal(bits);
        end
    endfunction

    // Check if two FP values are approximately equal
    function is_close;
        input [31:0] a;
        input [31:0] b;
        input real tolerance;
        real val_a, val_b, diff;
        begin
            val_a = fp32_to_real(a);
            val_b = fp32_to_real(b);
            diff = (val_a > val_b) ? (val_a - val_b) : (val_b - val_a);
            is_close = (diff < tolerance) || (a === b); // Exact match or within tolerance
        end
    endfunction

    // ========================================================================
    // Test Tasks
    // ========================================================================

    // Enqueue a test case
    task test_multiply;
        input [31:0] val_x;
        input [31:0] val_y;
        input [31:0] expected;
        input [200:0] description;

        begin
            // Send inputs to pipeline
            x = val_x;
            y = val_y;
            rm = 3'b000; // Round to nearest, ties to even

            // Store expected result in queue (3-cycle delay)
            expected_queue[queue_tail] = expected;
            description_queue[queue_tail] = description;
            queue_tail = (queue_tail + 1) % 11;

            @(posedge clk);
        end
    endtask

    // Check output against queue
    task check_output;
        real val_result, val_expected;
        begin
            if (queue_head != queue_tail) begin
                test_count = test_count + 1;

                // Handle special cases (NaN, Inf)
                if (expected_queue[queue_head][30:23] == 8'hFF) begin
                    // Expected is Inf or NaN
                    if (product[30:23] == 8'hFF) begin
                        // Check if both are Inf or both are NaN
                        if ((expected_queue[queue_head][22:0] == 0 && product[22:0] == 0) ||
                            (expected_queue[queue_head][22:0] != 0 && product[22:0] != 0)) begin
                            $display("[PASS] Test %0d: %s", test_count, description_queue[queue_head]);
                            pass_count = pass_count + 1;
                        end else begin
                            $display("[FAIL] Test %0d: %s", test_count, description_queue[queue_head]);
                            $display("  Expected: 0x%08h (Inf/NaN)", expected_queue[queue_head]);
                            $display("  Got:      0x%08h", product);
                            fail_count = fail_count + 1;
                        end
                    end else begin
                        $display("[FAIL] Test %0d: %s", test_count, description_queue[queue_head]);
                        $display("  Expected Inf/NaN, got normal value");
                        fail_count = fail_count + 1;
                    end
                end else if (is_close(product, expected_queue[queue_head], 1e-6)) begin
                    val_result = fp32_to_real(product);
                    val_expected = fp32_to_real(expected_queue[queue_head]);
                    $display("[PASS] Test %0d: %s", test_count, description_queue[queue_head]);
                    $display("       Result: %f (0x%08h)", val_result, product);
                    pass_count = pass_count + 1;
                end else begin
                    val_result = fp32_to_real(product);
                    val_expected = fp32_to_real(expected_queue[queue_head]);
                    $display("[FAIL] Test %0d: %s", test_count, description_queue[queue_head]);
                    $display("  Expected: %f (0x%08h)", val_expected, expected_queue[queue_head]);
                    $display("  Got:      %f (0x%08h)", val_result, product);
                    $display("  Flags:    NV=%b DZ=%b OF=%b UF=%b NX=%b",
                             flags[4], flags[3], flags[2], flags[1], flags[0]);
                    fail_count = fail_count + 1;
                end

                queue_head = (queue_head + 1) % 11;
            end
        end
    endtask

    // ========================================================================
    // Test Sequence
    // ========================================================================
    initial begin
        $display("========================================");
        $display("FP32 Multiplier Pipeline Tests");
        $display("========================================\n");

        // Initialize
        rst_n = 0;
        x = 0;
        y = 0;
        rm = 0;
        queue_head = 0;
        queue_tail = 0;

        repeat(5) @(posedge clk);
        rst_n = 1;
        repeat(2) @(posedge clk);

        // --------------------------------------------------------------------
        // Category 1: Basic Multiplication
        // --------------------------------------------------------------------
        $display("--- Testing BASIC MULTIPLICATION ---");

        test_multiply(
            real_to_fp32(1.0),
            real_to_fp32(1.0),
            real_to_fp32(1.0),
            "1.0 × 1.0 = 1.0"
        );

        test_multiply(
            real_to_fp32(2.0),
            real_to_fp32(3.0),
            real_to_fp32(6.0),
            "2.0 × 3.0 = 6.0"
        );

        test_multiply(
            real_to_fp32(0.5),
            real_to_fp32(0.5),
            real_to_fp32(0.25),
            "0.5 × 0.5 = 0.25"
        );

        test_multiply(
            real_to_fp32(-2.0),
            real_to_fp32(3.0),
            real_to_fp32(-6.0),
            "-2.0 × 3.0 = -6.0"
        );

        test_multiply(
            real_to_fp32(-2.0),
            real_to_fp32(-3.0),
            real_to_fp32(6.0),
            "-2.0 × -3.0 = 6.0"
        );

        // Wait for pipeline to fill (3 cycles)
        repeat(3) @(posedge clk);

        // Start checking outputs
        repeat(5) begin
            check_output();
            @(posedge clk);
        end

        // --------------------------------------------------------------------
        // Category 2: Zero
        // --------------------------------------------------------------------
        $display("\n--- Testing ZERO ---");

        test_multiply(
            real_to_fp32(1.0),
            real_to_fp32(0.0),
            real_to_fp32(0.0),
            "1.0 × 0.0 = 0.0"
        );

        test_multiply(
            real_to_fp32(0.0),
            real_to_fp32(0.0),
            real_to_fp32(0.0),
            "0.0 × 0.0 = 0.0"
        );

        test_multiply(
            real_to_fp32(-0.0),
            real_to_fp32(1.0),
            real_to_fp32(-0.0),
            "-0.0 × 1.0 = -0.0"
        );

        repeat(3) begin
            check_output();
            @(posedge clk);
        end

        // --------------------------------------------------------------------
        // Category 3: Infinity
        // --------------------------------------------------------------------
        $display("\n--- Testing INFINITY ---");

        test_multiply(
            32'h7F800000,  // +Inf
            real_to_fp32(2.0),
            32'h7F800000,  // +Inf
            "+Inf × 2.0 = +Inf"
        );

        test_multiply(
            32'hFF800000,  // -Inf
            real_to_fp32(2.0),
            32'hFF800000,  // -Inf
            "-Inf × 2.0 = -Inf"
        );

        test_multiply(
            32'h7F800000,  // +Inf
            32'h7F800000,  // +Inf
            32'h7F800000,  // +Inf
            "+Inf × +Inf = +Inf"
        );

        test_multiply(
            32'h7F800000,  // +Inf
            real_to_fp32(0.0),
            32'h7FC00000,  // NaN (Inf × 0)
            "+Inf × 0.0 = NaN"
        );

        repeat(4) begin
            check_output();
            @(posedge clk);
        end

        // --------------------------------------------------------------------
        // Category 4: NaN
        // --------------------------------------------------------------------
        $display("\n--- Testing NaN ---");

        test_multiply(
            32'h7FC00000,  // QNaN
            real_to_fp32(2.0),
            32'h7FC00000,  // NaN (NaN propagates)
            "NaN × 2.0 = NaN"
        );

        test_multiply(
            real_to_fp32(1.0),
            32'h7FA00000,  // SNaN
            32'h7FC00000,  // QNaN (SNaN becomes QNaN)
            "1.0 × SNaN = QNaN"
        );

        repeat(2) begin
            check_output();
            @(posedge clk);
        end

        // --------------------------------------------------------------------
        // Category 5: Large Numbers (Overflow)
        // --------------------------------------------------------------------
        $display("\n--- Testing OVERFLOW ---");

        test_multiply(
            32'h7F7FFFFF,  // Max normal
            real_to_fp32(2.0),
            32'h7F800000,  // +Inf (overflow)
            "Max × 2.0 = +Inf (overflow)"
        );

        test_multiply(
            real_to_fp32(1e38),
            real_to_fp32(1e38),
            32'h7F800000,  // +Inf (overflow)
            "1e38 × 1e38 = +Inf (overflow)"
        );

        repeat(2) begin
            check_output();
            @(posedge clk);
        end

        // --------------------------------------------------------------------
        // Category 6: Small Numbers (Underflow)
        // --------------------------------------------------------------------
        $display("\n--- Testing UNDERFLOW ---");

        test_multiply(
            real_to_fp32(1e-20),
            real_to_fp32(1e-20),
            real_to_fp32(0.0),  // Underflow to zero
            "1e-20 × 1e-20 = 0 (underflow)"
        );

        test_multiply(
            32'h00800000,  // Min normal
            real_to_fp32(0.5),
            32'h00400000,  // Subnormal result
            "Min_normal × 0.5 = Subnormal"
        );

        repeat(2) begin
            check_output();
            @(posedge clk);
        end

        // --------------------------------------------------------------------
        // Category 7: Random Cases
        // --------------------------------------------------------------------
        $display("\n--- Testing RANDOM CASES ---");

        repeat(20) begin
            automatic real rand_a = $random / 1000.0;
            automatic real rand_b = $random / 1000.0;
            automatic real expected_result = rand_a * rand_b;

            test_multiply(
                real_to_fp32(rand_a),
                real_to_fp32(rand_b),
                real_to_fp32(expected_result),
                "Random multiplication"
            );

            check_output();
            @(posedge clk);
        end

        // --------------------------------------------------------------------
        // Drain Pipeline
        // --------------------------------------------------------------------
        $display("\n--- Draining Pipeline ---");
        repeat(5) begin
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

    // Timeout watchdog
    initial begin
        #100000; // 100 us timeout
        $display("\n[ERROR] Testbench timeout!");
        $finish;
    end

endmodule

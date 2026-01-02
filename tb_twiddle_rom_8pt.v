// ============================================================================
// Testbench for Twiddle ROM (8-Point FFT)
// Tests pre-computed twiddle factor lookup
// Verifies IEEE 754 floating-point values for W^0, W^1, W^2, W^3
// Self-checking with comprehensive test cases
// ============================================================================

`timescale 1ns / 1ps

module tb_twiddle_rom_8pt;

    // ========================================================================
    // Clock
    // ========================================================================

    reg clk;

    // ========================================================================
    // DUT Signals
    // ========================================================================

    reg [1:0]  addr;
    wire [31:0] w_real;
    wire [31:0] w_imag;

    // ========================================================================
    // DUT Instantiation
    // ========================================================================

    twiddle_rom_8pt dut (
        .clk(clk),
        .addr(addr),
        .w_real(w_real),
        .w_imag(w_imag)
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
    integer i;

    // Expected twiddle factor values (IEEE 754 single-precision)
    localparam W0_REAL = 32'h3F800000;  // 1.0
    localparam W0_IMAG = 32'h00000000;  // 0.0

    localparam W1_REAL = 32'h3F3504F3;  // 0.7071067811865476
    localparam W1_IMAG = 32'hBF3504F3;  // -0.7071067811865476

    localparam W2_REAL = 32'h00000000;  // 0.0
    localparam W2_IMAG = 32'hBF800000;  // -1.0

    localparam W3_REAL = 32'hBF3504F3;  // -0.7071067811865476
    localparam W3_IMAG = 32'hBF3504F3;  // -0.7071067811865476

    // ========================================================================
    // Test Tasks
    // ========================================================================

    task check_twiddle;
        input [1:0]   test_addr;
        input [31:0]  exp_real;
        input [31:0]  exp_imag;
        input [200:0] description;
        begin
            test_count = test_count + 1;
            addr = test_addr;
            @(posedge clk);
            #1;

            if (w_real === exp_real && w_imag === exp_imag) begin
                $display("[PASS] Test %0d: %s", test_count, description);
                $display("       W^%0d = 0x%h + j*0x%h", test_addr, w_real, w_imag);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] Test %0d: %s", test_count, description);
                $display("       Expected: real=0x%h, imag=0x%h", exp_real, exp_imag);
                $display("       Got:      real=0x%h, imag=0x%h", w_real, w_imag);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // ========================================================================
    // Test Stimulus
    // ========================================================================

    initial begin
        $display("\n========================================");
        $display("Twiddle ROM 8-Point FFT Testbench");
        $display("========================================\n");

        // Initialize
        addr = 2'b00;

        @(posedge clk);
        @(posedge clk);

        // ====================================================================
        // Test Category 1: All Four Twiddle Factors
        // ====================================================================
        $display("\n--- Test Category 1: All Twiddle Factors ---");

        check_twiddle(
            2'b00, W0_REAL, W0_IMAG,
            "W^0 = 1 + j*0 (e^(-j*0))"
        );

        check_twiddle(
            2'b01, W1_REAL, W1_IMAG,
            "W^1 = 0.707 - j*0.707 (e^(-j*pi/4))"
        );

        check_twiddle(
            2'b10, W2_REAL, W2_IMAG,
            "W^2 = 0 - j*1 (e^(-j*pi/2))"
        );

        check_twiddle(
            2'b11, W3_REAL, W3_IMAG,
            "W^3 = -0.707 - j*0.707 (e^(-j*3pi/4))"
        );

        // ====================================================================
        // Test Category 2: Sequential Access Pattern
        // ====================================================================
        $display("\n--- Test Category 2: Sequential Access ---");

        check_twiddle(
            2'b00, W0_REAL, W0_IMAG,
            "Sequential: W^0"
        );

        check_twiddle(
            2'b01, W1_REAL, W1_IMAG,
            "Sequential: W^1"
        );

        check_twiddle(
            2'b10, W2_REAL, W2_IMAG,
            "Sequential: W^2"
        );

        check_twiddle(
            2'b11, W3_REAL, W3_IMAG,
            "Sequential: W^3"
        );

        // ====================================================================
        // Test Category 3: Reverse Order Access
        // ====================================================================
        $display("\n--- Test Category 3: Reverse Order ---");

        check_twiddle(
            2'b11, W3_REAL, W3_IMAG,
            "Reverse: W^3"
        );

        check_twiddle(
            2'b10, W2_REAL, W2_IMAG,
            "Reverse: W^2"
        );

        check_twiddle(
            2'b01, W1_REAL, W1_IMAG,
            "Reverse: W^1"
        );

        check_twiddle(
            2'b00, W0_REAL, W0_IMAG,
            "Reverse: W^0"
        );

        // ====================================================================
        // Test Category 4: Random Access Pattern
        // ====================================================================
        $display("\n--- Test Category 4: Random Access ---");

        check_twiddle(
            2'b10, W2_REAL, W2_IMAG,
            "Random: W^2"
        );

        check_twiddle(
            2'b00, W0_REAL, W0_IMAG,
            "Random: W^0"
        );

        check_twiddle(
            2'b11, W3_REAL, W3_IMAG,
            "Random: W^3"
        );

        check_twiddle(
            2'b01, W1_REAL, W1_IMAG,
            "Random: W^1"
        );

        // ====================================================================
        // Test Category 5: Repeated Access to Same Address
        // ====================================================================
        $display("\n--- Test Category 5: Repeated Access ---");

        check_twiddle(
            2'b00, W0_REAL, W0_IMAG,
            "Repeated: W^0 (1st)"
        );

        check_twiddle(
            2'b00, W0_REAL, W0_IMAG,
            "Repeated: W^0 (2nd)"
        );

        check_twiddle(
            2'b00, W0_REAL, W0_IMAG,
            "Repeated: W^0 (3rd)"
        );

        check_twiddle(
            2'b01, W1_REAL, W1_IMAG,
            "Repeated: W^1 (1st)"
        );

        check_twiddle(
            2'b01, W1_REAL, W1_IMAG,
            "Repeated: W^1 (2nd)"
        );

        // ====================================================================
        // Test Category 6: Pipeline Behavior (Back-to-back Reads)
        // ====================================================================
        $display("\n--- Test Category 6: Back-to-back Reads ---");

        addr = 2'b00;
        @(posedge clk);
        addr = 2'b01;
        @(posedge clk);
        addr = 2'b10;
        @(posedge clk);
        addr = 2'b11;
        @(posedge clk);
        #1;

        test_count = test_count + 1;
        if (w_real === W3_REAL && w_imag === W3_IMAG) begin
            $display("[PASS] Test %0d: Back-to-back: Final value is W^3",
                     test_count);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Test %0d: Back-to-back reads", test_count);
            fail_count = fail_count + 1;
        end

        // ====================================================================
        // Test Category 7: Verify Mathematical Properties
        // ====================================================================
        $display("\n--- Test Category 7: Mathematical Properties ---");

        // W^0 should be 1 (identity)
        addr = 2'b00;
        @(posedge clk);
        #1;
        test_count = test_count + 1;
        if (w_real === 32'h3F800000 && w_imag === 32'h00000000) begin
            $display("[PASS] Test %0d: W^0 is identity (1 + j*0)", test_count);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Test %0d: W^0 is not identity", test_count);
            fail_count = fail_count + 1;
        end

        // W^2 should be purely imaginary (-j)
        addr = 2'b10;
        @(posedge clk);
        #1;
        test_count = test_count + 1;
        if (w_real === 32'h00000000 && w_imag === 32'hBF800000) begin
            $display("[PASS] Test %0d: W^2 is purely imaginary (0 - j*1)",
                     test_count);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Test %0d: W^2 is not purely imaginary", test_count);
            fail_count = fail_count + 1;
        end

        // W^1 and W^3 should have equal magnitude components
        addr = 2'b01;
        @(posedge clk);
        #1;
        test_count = test_count + 1;
        if (w_real === 32'h3F3504F3 && w_imag === 32'hBF3504F3) begin
            $display("[PASS] Test %0d: W^1 has equal magnitude real/imag",
                     test_count);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Test %0d: W^1 magnitude mismatch", test_count);
            fail_count = fail_count + 1;
        end

        // ====================================================================
        // Test Category 8: Verify Sign Patterns
        // ====================================================================
        $display("\n--- Test Category 8: Sign Patterns ---");

        // W^0: (+, 0)
        addr = 2'b00;
        @(posedge clk);
        #1;
        test_count = test_count + 1;
        if (w_real[31] == 1'b0 && w_imag[31] == 1'b0) begin
            $display("[PASS] Test %0d: W^0 signs: (+real, +imag)", test_count);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Test %0d: W^0 sign pattern wrong", test_count);
            fail_count = fail_count + 1;
        end

        // W^1: (+, -)
        addr = 2'b01;
        @(posedge clk);
        #1;
        test_count = test_count + 1;
        if (w_real[31] == 1'b0 && w_imag[31] == 1'b1) begin
            $display("[PASS] Test %0d: W^1 signs: (+real, -imag)", test_count);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Test %0d: W^1 sign pattern wrong", test_count);
            fail_count = fail_count + 1;
        end

        // W^2: (0, -)
        addr = 2'b10;
        @(posedge clk);
        #1;
        test_count = test_count + 1;
        if (w_real === 32'h00000000 && w_imag[31] == 1'b1) begin
            $display("[PASS] Test %0d: W^2 signs: (0, -imag)", test_count);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Test %0d: W^2 sign pattern wrong", test_count);
            fail_count = fail_count + 1;
        end

        // W^3: (-, -)
        addr = 2'b11;
        @(posedge clk);
        #1;
        test_count = test_count + 1;
        if (w_real[31] == 1'b1 && w_imag[31] == 1'b1) begin
            $display("[PASS] Test %0d: W^3 signs: (-real, -imag)", test_count);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Test %0d: W^3 sign pattern wrong", test_count);
            fail_count = fail_count + 1;
        end

        // ====================================================================
        // Test Category 9: Extended Continuous Access
        // ====================================================================
        $display("\n--- Test Category 9: Extended Access Pattern ---");

        for (i = 0; i < 8; i = i + 1) begin
            addr = i[1:0];
            @(posedge clk);
            #1;

            test_count = test_count + 1;
            case (i[1:0])
                2'b00: begin
                    if (w_real === W0_REAL && w_imag === W0_IMAG) begin
                        $display("[PASS] Test %0d: Extended [%0d] W^0", test_count, i);
                        pass_count = pass_count + 1;
                    end else begin
                        $display("[FAIL] Test %0d: Extended [%0d]", test_count, i);
                        fail_count = fail_count + 1;
                    end
                end
                2'b01: begin
                    if (w_real === W1_REAL && w_imag === W1_IMAG) begin
                        $display("[PASS] Test %0d: Extended [%0d] W^1", test_count, i);
                        pass_count = pass_count + 1;
                    end else begin
                        $display("[FAIL] Test %0d: Extended [%0d]", test_count, i);
                        fail_count = fail_count + 1;
                    end
                end
                2'b10: begin
                    if (w_real === W2_REAL && w_imag === W2_IMAG) begin
                        $display("[PASS] Test %0d: Extended [%0d] W^2", test_count, i);
                        pass_count = pass_count + 1;
                    end else begin
                        $display("[FAIL] Test %0d: Extended [%0d]", test_count, i);
                        fail_count = fail_count + 1;
                    end
                end
                2'b11: begin
                    if (w_real === W3_REAL && w_imag === W3_IMAG) begin
                        $display("[PASS] Test %0d: Extended [%0d] W^3", test_count, i);
                        pass_count = pass_count + 1;
                    end else begin
                        $display("[FAIL] Test %0d: Extended [%0d]", test_count, i);
                        fail_count = fail_count + 1;
                    end
                end
            endcase
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

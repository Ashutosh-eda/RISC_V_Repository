// ============================================================================
// Testbench for FFT Buffer (8-Point)
// Tests dual-port memory for 8 complex samples
// Verifies write/read operations for real and imaginary components
// Self-checking with comprehensive test cases
// ============================================================================

`timescale 1ns / 1ps

module tb_fft_buffer_8pt;

    // ========================================================================
    // Clock and Reset
    // ========================================================================

    reg clk;
    reg rst_n;

    // ========================================================================
    // DUT Signals
    // ========================================================================

    // Write port
    reg        wr_en;
    reg [2:0]  wr_addr;
    reg [31:0] wr_real;
    reg [31:0] wr_imag;

    // Read port
    reg [2:0]  rd_addr;
    wire [31:0] rd_real;
    wire [31:0] rd_imag;

    // ========================================================================
    // DUT Instantiation
    // ========================================================================

    fft_buffer_8pt dut (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(wr_en),
        .wr_addr(wr_addr),
        .wr_real(wr_real),
        .wr_imag(wr_imag),
        .rd_addr(rd_addr),
        .rd_real(rd_real),
        .rd_imag(rd_imag)
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

    // ========================================================================
    // Test Tasks
    // ========================================================================

    task write_sample;
        input [2:0]  addr;
        input [31:0] real_val;
        input [31:0] imag_val;
        begin
            wr_en = 1'b1;
            wr_addr = addr;
            wr_real = real_val;
            wr_imag = imag_val;
            @(posedge clk);
            wr_en = 1'b0;
        end
    endtask

    task read_and_check;
        input [2:0]   addr;
        input [31:0]  exp_real;
        input [31:0]  exp_imag;
        input [200:0] description;
        begin
            test_count = test_count + 1;
            rd_addr = addr;
            #1;

            if (rd_real === exp_real && rd_imag === exp_imag) begin
                $display("[PASS] Test %0d: %s", test_count, description);
                $display("       addr=%0d: real=0x%h, imag=0x%h", addr, rd_real, rd_imag);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] Test %0d: %s", test_count, description);
                $display("       Expected: real=0x%h, imag=0x%h", exp_real, exp_imag);
                $display("       Got:      real=0x%h, imag=0x%h", rd_real, rd_imag);
                fail_count = fail_count + 1;
            end
        end
    endtask

    task wait_cycle;
        begin
            @(posedge clk);
        end
    endtask

    // ========================================================================
    // Test Stimulus
    // ========================================================================

    initial begin
        $display("\n========================================");
        $display("FFT Buffer 8-Point Testbench");
        $display("========================================\n");

        // Initialize
        rst_n = 0;
        wr_en = 0;
        wr_addr = 3'd0;
        wr_real = 32'd0;
        wr_imag = 32'd0;
        rd_addr = 3'd0;

        repeat(3) @(posedge clk);
        rst_n = 1;
        @(posedge clk);

        // ====================================================================
        // Test Category 1: Reset Verification
        // ====================================================================
        $display("\n--- Test Category 1: Reset Verification ---");

        read_and_check(
            3'd0, 32'h00000000, 32'h00000000,
            "Reset: addr 0 is zero"
        );

        read_and_check(
            3'd3, 32'h00000000, 32'h00000000,
            "Reset: addr 3 is zero"
        );

        read_and_check(
            3'd7, 32'h00000000, 32'h00000000,
            "Reset: addr 7 is zero"
        );

        // ====================================================================
        // Test Category 2: Write and Read Single Samples
        // ====================================================================
        $display("\n--- Test Category 2: Write and Read Single Samples ---");

        write_sample(3'd0, 32'h3F800000, 32'h00000000);  // 1.0 + j*0.0
        read_and_check(
            3'd0, 32'h3F800000, 32'h00000000,
            "Write/Read: Sample 0 (1.0 + j*0.0)"
        );

        write_sample(3'd1, 32'h40000000, 32'h40400000);  // 2.0 + j*3.0
        read_and_check(
            3'd1, 32'h40000000, 32'h40400000,
            "Write/Read: Sample 1 (2.0 + j*3.0)"
        );

        write_sample(3'd7, 32'hBF800000, 32'h3F800000);  // -1.0 + j*1.0
        read_and_check(
            3'd7, 32'hBF800000, 32'h3F800000,
            "Write/Read: Sample 7 (-1.0 + j*1.0)"
        );

        // ====================================================================
        // Test Category 3: Sequential Write All Samples
        // ====================================================================
        $display("\n--- Test Category 3: Sequential Write All Samples ---");

        write_sample(3'd0, 32'h00000000, 32'h00000000);  // 0 + j*0
        write_sample(3'd1, 32'h3F800000, 32'h00000000);  // 1 + j*0
        write_sample(3'd2, 32'h40000000, 32'h00000000);  // 2 + j*0
        write_sample(3'd3, 32'h40400000, 32'h00000000);  // 3 + j*0
        write_sample(3'd4, 32'h40800000, 32'h00000000);  // 4 + j*0
        write_sample(3'd5, 32'h40A00000, 32'h00000000);  // 5 + j*0
        write_sample(3'd6, 32'h40C00000, 32'h00000000);  // 6 + j*0
        write_sample(3'd7, 32'h40E00000, 32'h00000000);  // 7 + j*0

        read_and_check(
            3'd0, 32'h00000000, 32'h00000000,
            "Sequential read: Sample 0"
        );

        read_and_check(
            3'd4, 32'h40800000, 32'h00000000,
            "Sequential read: Sample 4"
        );

        read_and_check(
            3'd7, 32'h40E00000, 32'h00000000,
            "Sequential read: Sample 7"
        );

        // ====================================================================
        // Test Category 4: Overwrite Existing Data
        // ====================================================================
        $display("\n--- Test Category 4: Overwrite Existing Data ---");

        write_sample(3'd2, 32'hDEADBEEF, 32'hCAFEBABE);
        read_and_check(
            3'd2, 32'hDEADBEEF, 32'hCAFEBABE,
            "Overwrite: Sample 2 new value"
        );

        // Verify other samples unchanged
        read_and_check(
            3'd1, 32'h3F800000, 32'h00000000,
            "Overwrite: Sample 1 unchanged"
        );

        read_and_check(
            3'd3, 32'h40400000, 32'h00000000,
            "Overwrite: Sample 3 unchanged"
        );

        // ====================================================================
        // Test Category 5: Complex Number Patterns
        // ====================================================================
        $display("\n--- Test Category 5: Complex Number Patterns ---");

        write_sample(3'd0, 32'h3F3504F3, 32'h3F3504F3);  // 0.707 + j*0.707
        read_and_check(
            3'd0, 32'h3F3504F3, 32'h3F3504F3,
            "Complex: 0.707 + j*0.707 (45 deg)"
        );

        write_sample(3'd1, 32'h00000000, 32'h3F800000);  // 0 + j*1 (90 deg)
        read_and_check(
            3'd1, 32'h00000000, 32'h3F800000,
            "Complex: 0 + j*1 (90 deg)"
        );

        write_sample(3'd2, 32'hBF800000, 32'h00000000);  // -1 + j*0 (180 deg)
        read_and_check(
            3'd2, 32'hBF800000, 32'h00000000,
            "Complex: -1 + j*0 (180 deg)"
        );

        write_sample(3'd3, 32'h00000000, 32'hBF800000);  // 0 - j*1 (270 deg)
        read_and_check(
            3'd3, 32'h00000000, 32'hBF800000,
            "Complex: 0 - j*1 (270 deg)"
        );

        // ====================================================================
        // Test Category 6: Simultaneous Read/Write (Same Address)
        // ====================================================================
        $display("\n--- Test Category 6: Simultaneous Read/Write ---");

        rd_addr = 3'd4;
        write_sample(3'd4, 32'h12345678, 32'hABCDEF01);
        #1;

        test_count = test_count + 1;
        // After write, read should reflect new value on next cycle
        @(posedge clk);
        #1;
        if (rd_real === 32'h12345678 && rd_imag === 32'hABCDEF01) begin
            $display("[PASS] Test %0d: Simultaneous R/W: New value visible",
                     test_count);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Test %0d: Simultaneous R/W failed", test_count);
            fail_count = fail_count + 1;
        end

        // ====================================================================
        // Test Category 7: Write Disabled (wr_en=0)
        // ====================================================================
        $display("\n--- Test Category 7: Write Disabled ---");

        write_sample(3'd5, 32'hAAAAAAAA, 32'hBBBBBBBB);
        read_and_check(
            3'd5, 32'hAAAAAAAA, 32'hBBBBBBBB,
            "Before wr_en=0: Sample 5"
        );

        wr_en = 1'b0;
        wr_addr = 3'd5;
        wr_real = 32'hCCCCCCCC;
        wr_imag = 32'hDDDDDDDD;
        @(posedge clk);

        read_and_check(
            3'd5, 32'hAAAAAAAA, 32'hBBBBBBBB,
            "After wr_en=0: Sample 5 unchanged"
        );

        // ====================================================================
        // Test Category 8: All Addresses Sequential Read
        // ====================================================================
        $display("\n--- Test Category 8: All Addresses Sequential Read ---");

        // Write known pattern
        write_sample(3'd0, 32'h10000000, 32'h20000000);
        write_sample(3'd1, 32'h10000001, 32'h20000001);
        write_sample(3'd2, 32'h10000002, 32'h20000002);
        write_sample(3'd3, 32'h10000003, 32'h20000003);
        write_sample(3'd4, 32'h10000004, 32'h20000004);
        write_sample(3'd5, 32'h10000005, 32'h20000005);
        write_sample(3'd6, 32'h10000006, 32'h20000006);
        write_sample(3'd7, 32'h10000007, 32'h20000007);

        integer i;
        for (i = 0; i < 8; i = i + 1) begin
            rd_addr = i[2:0];
            #1;

            test_count = test_count + 1;
            if (rd_real === (32'h10000000 + i) &&
                rd_imag === (32'h20000000 + i)) begin
                $display("[PASS] Test %0d: Sequential read [%0d] = 0x%h + j*0x%h",
                         test_count, i, rd_real, rd_imag);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] Test %0d: Sequential read [%0d]", test_count, i);
                fail_count = fail_count + 1;
            end
            @(posedge clk);
        end

        // ====================================================================
        // Test Category 9: Reverse Order Access
        // ====================================================================
        $display("\n--- Test Category 9: Reverse Order Access ---");

        read_and_check(
            3'd7, 32'h10000007, 32'h20000007,
            "Reverse: addr 7"
        );

        read_and_check(
            3'd6, 32'h10000006, 32'h20000006,
            "Reverse: addr 6"
        );

        read_and_check(
            3'd0, 32'h10000000, 32'h20000000,
            "Reverse: addr 0"
        );

        // ====================================================================
        // Test Category 10: Random Access Pattern
        // ====================================================================
        $display("\n--- Test Category 10: Random Access ---");

        read_and_check(
            3'd3, 32'h10000003, 32'h20000003,
            "Random: addr 3"
        );

        read_and_check(
            3'd1, 32'h10000001, 32'h20000001,
            "Random: addr 1"
        );

        read_and_check(
            3'd5, 32'h10000005, 32'h20000005,
            "Random: addr 5"
        );

        read_and_check(
            3'd2, 32'h10000002, 32'h20000002,
            "Random: addr 2"
        );

        // ====================================================================
        // Test Category 11: Edge Case Values
        // ====================================================================
        $display("\n--- Test Category 11: Edge Case Values ---");

        write_sample(3'd0, 32'hFFFFFFFF, 32'hFFFFFFFF);  // All 1s
        read_and_check(
            3'd0, 32'hFFFFFFFF, 32'hFFFFFFFF,
            "Edge: All 1s"
        );

        write_sample(3'd1, 32'h00000000, 32'h00000000);  // All 0s
        read_and_check(
            3'd1, 32'h00000000, 32'h00000000,
            "Edge: All 0s"
        );

        write_sample(3'd2, 32'h80000000, 32'h7FFFFFFF);  // Sign extremes
        read_and_check(
            3'd2, 32'h80000000, 32'h7FFFFFFF,
            "Edge: Sign bit extremes"
        );

        write_sample(3'd3, 32'h7F800000, 32'hFF800000);  // +Inf, -Inf
        read_and_check(
            3'd3, 32'h7F800000, 32'hFF800000,
            "Edge: +Infinity, -Infinity"
        );

        // ====================================================================
        // Test Category 12: Reset During Operation
        // ====================================================================
        $display("\n--- Test Category 12: Reset During Operation ---");

        write_sample(3'd4, 32'hDEADBEEF, 32'hCAFEBABE);
        read_and_check(
            3'd4, 32'hDEADBEEF, 32'hCAFEBABE,
            "Before reset: Sample 4"
        );

        rst_n = 0;
        @(posedge clk);
        rst_n = 1;
        @(posedge clk);

        read_and_check(
            3'd4, 32'h00000000, 32'h00000000,
            "After reset: Sample 4 cleared"
        );

        read_and_check(
            3'd0, 32'h00000000, 32'h00000000,
            "After reset: Sample 0 cleared"
        );

        // ====================================================================
        // Test Category 13: Realistic FFT Input/Output
        // ====================================================================
        $display("\n--- Test Category 13: Realistic FFT Data ---");

        // Write a simple 8-point time-domain signal
        write_sample(3'd0, 32'h3F800000, 32'h00000000);  // 1.0 + j*0
        write_sample(3'd1, 32'h3F800000, 32'h00000000);  // 1.0 + j*0
        write_sample(3'd2, 32'h3F800000, 32'h00000000);  // 1.0 + j*0
        write_sample(3'd3, 32'h3F800000, 32'h00000000);  // 1.0 + j*0
        write_sample(3'd4, 32'hBF800000, 32'h00000000);  // -1.0 + j*0
        write_sample(3'd5, 32'hBF800000, 32'h00000000);  // -1.0 + j*0
        write_sample(3'd6, 32'hBF800000, 32'h00000000);  // -1.0 + j*0
        write_sample(3'd7, 32'hBF800000, 32'h00000000);  // -1.0 + j*0

        read_and_check(
            3'd0, 32'h3F800000, 32'h00000000,
            "Realistic: Time sample 0"
        );

        read_and_check(
            3'd4, 32'hBF800000, 32'h00000000,
            "Realistic: Time sample 4"
        );

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

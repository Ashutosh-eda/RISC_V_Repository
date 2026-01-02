// ============================================================================
// Testbench for FFT Control Unit (8-Point)
// Tests FSM control for 3-stage radix-2 DIT FFT
// Verifies address generation, stage progression, and butterfly sequencing
// Self-checking with comprehensive test cases
// ============================================================================

`timescale 1ns / 1ps

module tb_fft_control_8pt;

    // ========================================================================
    // Clock and Reset
    // ========================================================================

    reg clk;
    reg rst_n;

    // ========================================================================
    // DUT Signals
    // ========================================================================

    // Control inputs
    reg        start;
    reg        butterfly_valid;

    // Status outputs
    wire        busy;
    wire        done;

    // Buffer control
    wire [2:0]  rd_addr_x;
    wire [2:0]  rd_addr_y;
    wire [2:0]  wr_addr_0;
    wire [2:0]  wr_addr_1;
    wire        wr_en;

    // Butterfly control
    wire        butterfly_enable;
    wire [1:0]  twiddle_addr;

    // Stage tracking
    wire [1:0]  current_stage;
    wire [1:0]  butterfly_idx;

    // ========================================================================
    // DUT Instantiation
    // ========================================================================

    fft_control_8pt dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .butterfly_valid(butterfly_valid),
        .busy(busy),
        .done(done),
        .rd_addr_x(rd_addr_x),
        .rd_addr_y(rd_addr_y),
        .wr_addr_0(wr_addr_0),
        .wr_addr_1(wr_addr_1),
        .wr_en(wr_en),
        .butterfly_enable(butterfly_enable),
        .twiddle_addr(twiddle_addr),
        .current_stage(current_stage),
        .butterfly_idx(butterfly_idx)
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

    task wait_cycle;
        begin
            @(posedge clk);
        end
    endtask

    task check_idle;
        input [200:0] description;
        begin
            test_count = test_count + 1;
            #1;

            if (busy === 1'b0 && done === 1'b0 && butterfly_enable === 1'b0 &&
                wr_en === 1'b0) begin
                $display("[PASS] Test %0d: %s", test_count, description);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] Test %0d: %s", test_count, description);
                $display("       busy=%b, done=%b, bf_en=%b, wr_en=%b",
                         busy, done, butterfly_enable, wr_en);
                fail_count = fail_count + 1;
            end
        end
    endtask

    task check_addresses;
        input [2:0]   exp_rd_x;
        input [2:0]   exp_rd_y;
        input [2:0]   exp_wr_0;
        input [2:0]   exp_wr_1;
        input [1:0]   exp_twiddle;
        input [200:0] description;
        begin
            test_count = test_count + 1;
            #1;

            if (rd_addr_x === exp_rd_x && rd_addr_y === exp_rd_y &&
                wr_addr_0 === exp_wr_0 && wr_addr_1 === exp_wr_1 &&
                twiddle_addr === exp_twiddle) begin
                $display("[PASS] Test %0d: %s", test_count, description);
                $display("       rd_x=%0d, rd_y=%0d, wr_0=%0d, wr_1=%0d, tw=%0d",
                         rd_addr_x, rd_addr_y, wr_addr_0, wr_addr_1, twiddle_addr);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] Test %0d: %s", test_count, description);
                $display("       Expected: rd_x=%0d, rd_y=%0d, wr_0=%0d, wr_1=%0d, tw=%0d",
                         exp_rd_x, exp_rd_y, exp_wr_0, exp_wr_1, exp_twiddle);
                $display("       Got:      rd_x=%0d, rd_y=%0d, wr_0=%0d, wr_1=%0d, tw=%0d",
                         rd_addr_x, rd_addr_y, wr_addr_0, wr_addr_1, twiddle_addr);
                fail_count = fail_count + 1;
            end
        end
    endtask

    task do_butterfly;
        input integer wait_cycles;
        begin
            // Wait for butterfly_enable
            wait (butterfly_enable == 1'b1);
            @(posedge clk);

            // Simulate butterfly latency
            repeat(wait_cycles) @(posedge clk);

            // Assert butterfly_valid
            butterfly_valid = 1'b1;
            @(posedge clk);
            butterfly_valid = 1'b0;
        end
    endtask

    // ========================================================================
    // Test Stimulus
    // ========================================================================

    initial begin
        $display("\n========================================");
        $display("FFT Control 8-Point Testbench");
        $display("========================================\n");

        // Initialize
        rst_n = 0;
        start = 0;
        butterfly_valid = 0;

        repeat(3) @(posedge clk);
        rst_n = 1;
        @(posedge clk);

        // ====================================================================
        // Test Category 1: Reset and Idle State
        // ====================================================================
        $display("\n--- Test Category 1: Reset and Idle State ---");

        check_idle("After reset: FSM in IDLE state");

        test_count = test_count + 1;
        if (current_stage === 2'b00 && butterfly_idx === 2'b00) begin
            $display("[PASS] Test %0d: Initial stage=0, butterfly=0", test_count);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Test %0d: Initial counters wrong", test_count);
            fail_count = fail_count + 1;
        end

        // ====================================================================
        // Test Category 2: Start Sequence
        // ====================================================================
        $display("\n--- Test Category 2: Start Sequence ---");

        start = 1'b1;
        @(posedge clk);
        start = 1'b0;

        test_count = test_count + 1;
        #1;
        if (busy === 1'b1) begin
            $display("[PASS] Test %0d: busy asserted after start", test_count);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Test %0d: busy not asserted", test_count);
            fail_count = fail_count + 1;
        end

        // ====================================================================
        // Test Category 3: Stage 0 Butterfly 0 Addresses
        // ====================================================================
        $display("\n--- Test Category 3: Stage 0 Addressing ---");

        // Wait for butterfly_enable in COMPUTE state
        wait (butterfly_enable == 1'b1);

        check_addresses(
            3'd0, 3'd4, 3'd0, 3'd4, 2'b00,
            "Stage 0, Butterfly 0: rd=(0,4), wr=(0,4), W^0"
        );

        // Complete butterfly 0
        repeat(2) @(posedge clk);
        butterfly_valid = 1'b1;
        @(posedge clk);
        butterfly_valid = 1'b0;

        // Wait for next butterfly
        wait (butterfly_enable == 1'b1);

        check_addresses(
            3'd1, 3'd5, 3'd1, 3'd5, 2'b00,
            "Stage 0, Butterfly 1: rd=(1,5), wr=(1,5), W^0"
        );

        repeat(2) @(posedge clk);
        butterfly_valid = 1'b1;
        @(posedge clk);
        butterfly_valid = 1'b0;

        wait (butterfly_enable == 1'b1);

        check_addresses(
            3'd2, 3'd6, 3'd2, 3'd6, 2'b00,
            "Stage 0, Butterfly 2: rd=(2,6), wr=(2,6), W^0"
        );

        repeat(2) @(posedge clk);
        butterfly_valid = 1'b1;
        @(posedge clk);
        butterfly_valid = 1'b0;

        wait (butterfly_enable == 1'b1);

        check_addresses(
            3'd3, 3'd7, 3'd3, 3'd7, 2'b00,
            "Stage 0, Butterfly 3: rd=(3,7), wr=(3,7), W^0"
        );

        repeat(2) @(posedge clk);
        butterfly_valid = 1'b1;
        @(posedge clk);
        butterfly_valid = 1'b0;

        // ====================================================================
        // Test Category 4: Stage 1 Addressing
        // ====================================================================
        $display("\n--- Test Category 4: Stage 1 Addressing ---");

        wait (butterfly_enable == 1'b1);
        test_count = test_count + 1;
        #1;
        if (current_stage === 2'b01) begin
            $display("[PASS] Test %0d: Advanced to Stage 1", test_count);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Test %0d: Did not advance to Stage 1", test_count);
            fail_count = fail_count + 1;
        end

        check_addresses(
            3'd0, 3'd2, 3'd0, 3'd2, 2'b00,
            "Stage 1, Butterfly 0: rd=(0,2), wr=(0,2), W^0"
        );

        repeat(2) @(posedge clk);
        butterfly_valid = 1'b1;
        @(posedge clk);
        butterfly_valid = 1'b0;

        wait (butterfly_enable == 1'b1);

        check_addresses(
            3'd1, 3'd3, 3'd1, 3'd3, 2'b10,
            "Stage 1, Butterfly 1: rd=(1,3), wr=(1,3), W^2"
        );

        repeat(2) @(posedge clk);
        butterfly_valid = 1'b1;
        @(posedge clk);
        butterfly_valid = 1'b0;

        wait (butterfly_enable == 1'b1);

        check_addresses(
            3'd4, 3'd6, 3'd4, 3'd6, 2'b00,
            "Stage 1, Butterfly 2: rd=(4,6), wr=(4,6), W^0"
        );

        repeat(2) @(posedge clk);
        butterfly_valid = 1'b1;
        @(posedge clk);
        butterfly_valid = 1'b0;

        wait (butterfly_enable == 1'b1);

        check_addresses(
            3'd5, 3'd7, 3'd5, 3'd7, 2'b10,
            "Stage 1, Butterfly 3: rd=(5,7), wr=(5,7), W^2"
        );

        repeat(2) @(posedge clk);
        butterfly_valid = 1'b1;
        @(posedge clk);
        butterfly_valid = 1'b0;

        // ====================================================================
        // Test Category 5: Stage 2 Addressing
        // ====================================================================
        $display("\n--- Test Category 5: Stage 2 Addressing ---");

        wait (butterfly_enable == 1'b1);
        test_count = test_count + 1;
        #1;
        if (current_stage === 2'b10) begin
            $display("[PASS] Test %0d: Advanced to Stage 2", test_count);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Test %0d: Did not advance to Stage 2", test_count);
            fail_count = fail_count + 1;
        end

        check_addresses(
            3'd0, 3'd1, 3'd0, 3'd1, 2'b00,
            "Stage 2, Butterfly 0: rd=(0,1), wr=(0,1), W^0"
        );

        repeat(2) @(posedge clk);
        butterfly_valid = 1'b1;
        @(posedge clk);
        butterfly_valid = 1'b0;

        wait (butterfly_enable == 1'b1);

        check_addresses(
            3'd2, 3'd3, 3'd2, 3'd3, 2'b01,
            "Stage 2, Butterfly 1: rd=(2,3), wr=(2,3), W^1"
        );

        repeat(2) @(posedge clk);
        butterfly_valid = 1'b1;
        @(posedge clk);
        butterfly_valid = 1'b0;

        wait (butterfly_enable == 1'b1);

        check_addresses(
            3'd4, 3'd5, 3'd4, 3'd5, 2'b10,
            "Stage 2, Butterfly 2: rd=(4,5), wr=(4,5), W^2"
        );

        repeat(2) @(posedge clk);
        butterfly_valid = 1'b1;
        @(posedge clk);
        butterfly_valid = 1'b0;

        wait (butterfly_enable == 1'b1);

        check_addresses(
            3'd6, 3'd7, 3'd6, 3'd7, 2'b11,
            "Stage 2, Butterfly 3: rd=(6,7), wr=(6,7), W^3"
        );

        repeat(2) @(posedge clk);
        butterfly_valid = 1'b1;
        @(posedge clk);
        butterfly_valid = 1'b0;

        // ====================================================================
        // Test Category 6: Done State
        // ====================================================================
        $display("\n--- Test Category 6: Done State ---");

        @(posedge clk);
        test_count = test_count + 1;
        #1;
        if (done === 1'b1 && busy === 1'b0) begin
            $display("[PASS] Test %0d: FFT complete, done asserted", test_count);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Test %0d: Done state incorrect", test_count);
            $display("       done=%b, busy=%b", done, busy);
            fail_count = fail_count + 1;
        end

        @(posedge clk);
        check_idle("After done: Return to IDLE");

        // ====================================================================
        // Test Category 7: Second FFT Run
        // ====================================================================
        $display("\n--- Test Category 7: Second FFT Run ---");

        start = 1'b1;
        @(posedge clk);
        start = 1'b0;

        test_count = test_count + 1;
        #1;
        if (busy === 1'b1 && current_stage === 2'b00 && butterfly_idx === 2'b00) begin
            $display("[PASS] Test %0d: Second run started, counters reset",
                     test_count);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Test %0d: Second run initialization failed",
                     test_count);
            fail_count = fail_count + 1;
        end

        // Run through first few butterflies of second FFT
        integer bf_count;
        for (bf_count = 0; bf_count < 4; bf_count = bf_count + 1) begin
            wait (butterfly_enable == 1'b1);
            repeat(2) @(posedge clk);
            butterfly_valid = 1'b1;
            @(posedge clk);
            butterfly_valid = 1'b0;
        end

        test_count = test_count + 1;
        #1;
        if (current_stage === 2'b01 && butterfly_idx === 2'b00) begin
            $display("[PASS] Test %0d: Second run progressing correctly",
                     test_count);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Test %0d: Second run progression failed",
                     test_count);
            fail_count = fail_count + 1;
        end

        // Complete second FFT
        for (bf_count = 0; bf_count < 8; bf_count = bf_count + 1) begin
            wait (butterfly_enable == 1'b1);
            repeat(2) @(posedge clk);
            butterfly_valid = 1'b1;
            @(posedge clk);
            butterfly_valid = 1'b0;
        end

        @(posedge clk);
        @(posedge clk);
        check_idle("Second run complete: Back to IDLE");

        // ====================================================================
        // Test Category 8: Write Enable Timing
        // ====================================================================
        $display("\n--- Test Category 8: Write Enable Timing ---");

        start = 1'b1;
        @(posedge clk);
        start = 1'b0;

        wait (butterfly_enable == 1'b1);
        @(posedge clk);
        @(posedge clk);
        butterfly_valid = 1'b1;
        @(posedge clk);
        butterfly_valid = 1'b0;

        test_count = test_count + 1;
        #1;
        if (wr_en === 1'b1) begin
            $display("[PASS] Test %0d: wr_en asserted during WRITE_BACK",
                     test_count);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Test %0d: wr_en not asserted", test_count);
            fail_count = fail_count + 1;
        end

        @(posedge clk);
        test_count = test_count + 1;
        #1;
        if (wr_en === 1'b0) begin
            $display("[PASS] Test %0d: wr_en deasserted after WRITE_BACK",
                     test_count);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Test %0d: wr_en still asserted", test_count);
            fail_count = fail_count + 1;
        end

        // Complete remaining butterflies
        for (bf_count = 0; bf_count < 11; bf_count = bf_count + 1) begin
            wait (butterfly_enable == 1'b1);
            repeat(2) @(posedge clk);
            butterfly_valid = 1'b1;
            @(posedge clk);
            butterfly_valid = 1'b0;
        end

        @(posedge clk);
        @(posedge clk);

        // ====================================================================
        // Test Category 9: Reset During Operation
        // ====================================================================
        $display("\n--- Test Category 9: Reset During Operation ---");

        start = 1'b1;
        @(posedge clk);
        start = 1'b0;

        wait (butterfly_enable == 1'b1);
        repeat(2) @(posedge clk);

        rst_n = 0;
        @(posedge clk);
        rst_n = 1;
        @(posedge clk);

        check_idle("After reset during operation: Back to IDLE");

        test_count = test_count + 1;
        #1;
        if (current_stage === 2'b00 && butterfly_idx === 2'b00) begin
            $display("[PASS] Test %0d: Counters reset after mid-operation reset",
                     test_count);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Test %0d: Counters not reset", test_count);
            fail_count = fail_count + 1;
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

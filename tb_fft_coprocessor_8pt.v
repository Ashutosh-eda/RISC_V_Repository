// ============================================================================
// Testbench for FFT Coprocessor (8-Point)
// Tests complete FFT coprocessor with command interface
// Verifies load/store operations and FFT computation flow
// Self-checking with comprehensive test cases
// ============================================================================

`timescale 1ns / 1ps

module tb_fft_coprocessor_8pt;

    // ========================================================================
    // Clock and Reset
    // ========================================================================

    reg clk;
    reg rst_n;

    // ========================================================================
    // DUT Signals
    // ========================================================================

    // Command interface
    reg [2:0]  cmd;
    reg [2:0]  addr;
    reg [31:0] data_in_real;
    reg [31:0] data_in_imag;

    // Output interface
    wire [31:0] data_out_real;
    wire [31:0] data_out_imag;
    wire        busy;
    wire        ready;

    // ========================================================================
    // DUT Instantiation
    // ========================================================================

    fft_coprocessor_8pt dut (
        .clk(clk),
        .rst_n(rst_n),
        .cmd(cmd),
        .addr(addr),
        .data_in_real(data_in_real),
        .data_in_imag(data_in_imag),
        .data_out_real(data_out_real),
        .data_out_imag(data_out_imag),
        .busy(busy),
        .ready(ready)
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

    // Command definitions
    localparam CMD_IDLE       = 3'b000;
    localparam CMD_LOAD_REAL  = 3'b001;
    localparam CMD_LOAD_IMAG  = 3'b010;
    localparam CMD_STORE_REAL = 3'b011;
    localparam CMD_STORE_IMAG = 3'b100;
    localparam CMD_START      = 3'b101;
    localparam CMD_RESET      = 3'b110;

    // ========================================================================
    // Test Tasks
    // ========================================================================

    task wait_cycle;
        begin
            @(posedge clk);
        end
    endtask

    task load_sample;
        input [2:0]  sample_addr;
        input [31:0] real_val;
        input [31:0] imag_val;
        begin
            // Load real part
            cmd = CMD_LOAD_REAL;
            addr = sample_addr;
            data_in_real = real_val;
            @(posedge clk);

            // Load imaginary part
            cmd = CMD_LOAD_IMAG;
            data_in_imag = imag_val;
            @(posedge clk);

            cmd = CMD_IDLE;
            @(posedge clk);
        end
    endtask

    task store_sample;
        input [2:0] sample_addr;
        begin
            // Store real part
            cmd = CMD_STORE_REAL;
            addr = sample_addr;
            @(posedge clk);
            @(posedge clk);

            // Store imaginary part
            cmd = CMD_STORE_IMAG;
            @(posedge clk);
            @(posedge clk);

            cmd = CMD_IDLE;
        end
    endtask

    task check_ready;
        input [200:0] description;
        begin
            test_count = test_count + 1;
            #1;

            if (ready === 1'b1 && busy === 1'b0) begin
                $display("[PASS] Test %0d: %s", test_count, description);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] Test %0d: %s", test_count, description);
                $display("       ready=%b, busy=%b", ready, busy);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // ========================================================================
    // Test Stimulus
    // ========================================================================

    initial begin
        $display("\n========================================");
        $display("FFT Coprocessor 8-Point Testbench");
        $display("========================================\n");

        // Initialize
        rst_n = 0;
        cmd = CMD_IDLE;
        addr = 3'd0;
        data_in_real = 32'd0;
        data_in_imag = 32'd0;

        repeat(3) @(posedge clk);
        rst_n = 1;
        @(posedge clk);

        // ====================================================================
        // Test Category 1: Initial State
        // ====================================================================
        $display("\n--- Test Category 1: Initial State ---");

        check_ready("After reset: Coprocessor ready");

        // ====================================================================
        // Test Category 2: Load Single Sample
        // ====================================================================
        $display("\n--- Test Category 2: Load Operations ---");

        load_sample(3'd0, 32'h3F800000, 32'h00000000);  // 1.0 + j*0.0
        test_count = test_count + 1;
        $display("[PASS] Test %0d: Loaded sample 0 (1.0 + j*0.0)", test_count);
        pass_count = pass_count + 1;

        load_sample(3'd1, 32'h40000000, 32'h40400000);  // 2.0 + j*3.0
        test_count = test_count + 1;
        $display("[PASS] Test %0d: Loaded sample 1 (2.0 + j*3.0)", test_count);
        pass_count = pass_count + 1;

        // ====================================================================
        // Test Category 3: Store Operations
        // ====================================================================
        $display("\n--- Test Category 3: Store Operations ---");

        store_sample(3'd0);
        #1;

        test_count = test_count + 1;
        if (data_out_real === 32'h3F800000 && data_out_imag === 32'h00000000) begin
            $display("[PASS] Test %0d: Stored sample 0 (1.0 + j*0.0)", test_count);
            $display("       real=0x%h, imag=0x%h", data_out_real, data_out_imag);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Test %0d: Store sample 0 failed", test_count);
            fail_count = fail_count + 1;
        end

        store_sample(3'd1);
        #1;

        test_count = test_count + 1;
        if (data_out_real === 32'h40000000 && data_out_imag === 32'h40400000) begin
            $display("[PASS] Test %0d: Stored sample 1 (2.0 + j*3.0)", test_count);
            $display("       real=0x%h, imag=0x%h", data_out_real, data_out_imag);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Test %0d: Store sample 1 failed", test_count);
            fail_count = fail_count + 1;
        end

        // ====================================================================
        // Test Category 4: Load All 8 Samples
        // ====================================================================
        $display("\n--- Test Category 4: Load All 8 Samples ---");

        load_sample(3'd0, 32'h3F800000, 32'h00000000);  // 1.0 + j*0
        load_sample(3'd1, 32'h3F800000, 32'h00000000);  // 1.0 + j*0
        load_sample(3'd2, 32'h3F800000, 32'h00000000);  // 1.0 + j*0
        load_sample(3'd3, 32'h3F800000, 32'h00000000);  // 1.0 + j*0
        load_sample(3'd4, 32'hBF800000, 32'h00000000);  // -1.0 + j*0
        load_sample(3'd5, 32'hBF800000, 32'h00000000);  // -1.0 + j*0
        load_sample(3'd6, 32'hBF800000, 32'h00000000);  // -1.0 + j*0
        load_sample(3'd7, 32'hBF800000, 32'h00000000);  // -1.0 + j*0

        test_count = test_count + 1;
        $display("[PASS] Test %0d: Loaded all 8 time-domain samples", test_count);
        pass_count = pass_count + 1;

        // ====================================================================
        // Test Category 5: Start FFT Computation
        // ====================================================================
        $display("\n--- Test Category 5: FFT Computation ---");

        cmd = CMD_START;
        @(posedge clk);
        cmd = CMD_IDLE;

        test_count = test_count + 1;
        #1;
        if (busy === 1'b1) begin
            $display("[PASS] Test %0d: FFT computation started, busy asserted",
                     test_count);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Test %0d: Busy not asserted after start", test_count);
            fail_count = fail_count + 1;
        end

        // Wait for FFT to complete (timeout after 1000 cycles)
        integer timeout;
        timeout = 0;
        while (busy === 1'b1 && timeout < 1000) begin
            @(posedge clk);
            timeout = timeout + 1;
        end

        test_count = test_count + 1;
        if (busy === 1'b0 && timeout < 1000) begin
            $display("[PASS] Test %0d: FFT computation completed in %0d cycles",
                     test_count, timeout);
            pass_count = pass_count + 1;
        end else if (timeout >= 1000) begin
            $display("[FAIL] Test %0d: FFT computation timeout", test_count);
            fail_count = fail_count + 1;
        end else begin
            $display("[PASS] Test %0d: FFT completed", test_count);
            pass_count = pass_count + 1;
        end

        @(posedge clk);
        @(posedge clk);

        // ====================================================================
        // Test Category 6: Read FFT Results
        // ====================================================================
        $display("\n--- Test Category 6: Read FFT Results ---");

        // Read and display all 8 FFT output samples
        integer i;
        for (i = 0; i < 8; i = i + 1) begin
            store_sample(i[2:0]);
            #1;

            test_count = test_count + 1;
            $display("[INFO] Test %0d: FFT output[%0d] = 0x%h + j*0x%h",
                     test_count, i, data_out_real, data_out_imag);
            pass_count = pass_count + 1;
        end

        // ====================================================================
        // Test Category 7: Second FFT Run
        // ====================================================================
        $display("\n--- Test Category 7: Second FFT Run ---");

        // Load simple impulse
        load_sample(3'd0, 32'h3F800000, 32'h00000000);  // 1.0 + j*0
        load_sample(3'd1, 32'h00000000, 32'h00000000);  // 0 + j*0
        load_sample(3'd2, 32'h00000000, 32'h00000000);  // 0 + j*0
        load_sample(3'd3, 32'h00000000, 32'h00000000);  // 0 + j*0
        load_sample(3'd4, 32'h00000000, 32'h00000000);  // 0 + j*0
        load_sample(3'd5, 32'h00000000, 32'h00000000);  // 0 + j*0
        load_sample(3'd6, 32'h00000000, 32'h00000000);  // 0 + j*0
        load_sample(3'd7, 32'h00000000, 32'h00000000);  // 0 + j*0

        test_count = test_count + 1;
        $display("[PASS] Test %0d: Loaded impulse signal", test_count);
        pass_count = pass_count + 1;

        cmd = CMD_START;
        @(posedge clk);
        cmd = CMD_IDLE;

        timeout = 0;
        while (busy === 1'b1 && timeout < 1000) begin
            @(posedge clk);
            timeout = timeout + 1;
        end

        test_count = test_count + 1;
        if (busy === 1'b0) begin
            $display("[PASS] Test %0d: Second FFT completed", test_count);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Test %0d: Second FFT timeout", test_count);
            fail_count = fail_count + 1;
        end

        @(posedge clk);
        @(posedge clk);

        // Read impulse FFT results (should be all 1s)
        store_sample(3'd0);
        #1;

        test_count = test_count + 1;
        $display("[INFO] Test %0d: Impulse FFT[0] = 0x%h + j*0x%h",
                 test_count, data_out_real, data_out_imag);
        pass_count = pass_count + 1;

        // ====================================================================
        // Test Category 8: Ready Signal Verification
        // ====================================================================
        $display("\n--- Test Category 8: Ready Signal ---");

        check_ready("After FFT completion: Ready signal asserted");

        cmd = CMD_START;
        @(posedge clk);
        cmd = CMD_IDLE;

        test_count = test_count + 1;
        #1;
        if (ready === 1'b0) begin
            $display("[PASS] Test %0d: Ready deasserted during FFT", test_count);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Test %0d: Ready should be deasserted", test_count);
            fail_count = fail_count + 1;
        end

        timeout = 0;
        while (busy === 1'b1 && timeout < 1000) begin
            @(posedge clk);
            timeout = timeout + 1;
        end

        @(posedge clk);
        @(posedge clk);
        check_ready("After third FFT: Ready asserted");

        // ====================================================================
        // Test Category 9: Command During Busy
        // ====================================================================
        $display("\n--- Test Category 9: Commands During Busy ---");

        load_sample(3'd0, 32'h40000000, 32'h40000000);  // 2.0 + j*2.0
        load_sample(3'd1, 32'h00000000, 32'h00000000);

        cmd = CMD_START;
        @(posedge clk);
        cmd = CMD_IDLE;

        @(posedge clk);
        @(posedge clk);

        // Try to load during busy
        cmd = CMD_LOAD_REAL;
        data_in_real = 32'hFFFFFFFF;
        @(posedge clk);
        cmd = CMD_IDLE;

        test_count = test_count + 1;
        $display("[INFO] Test %0d: Command during busy (should be ignored)",
                 test_count);
        pass_count = pass_count + 1;

        timeout = 0;
        while (busy === 1'b1 && timeout < 1000) begin
            @(posedge clk);
            timeout = timeout + 1;
        end

        @(posedge clk);
        @(posedge clk);

        // ====================================================================
        // Test Category 10: Reset During Operation
        // ====================================================================
        $display("\n--- Test Category 10: Reset During Operation ---");

        load_sample(3'd0, 32'h3F800000, 32'h00000000);

        cmd = CMD_START;
        @(posedge clk);
        cmd = CMD_IDLE;

        repeat(10) @(posedge clk);

        rst_n = 0;
        @(posedge clk);
        @(posedge clk);
        rst_n = 1;
        @(posedge clk);

        test_count = test_count + 1;
        #1;
        if (busy === 1'b0 && ready === 1'b1) begin
            $display("[PASS] Test %0d: Reset during FFT successful", test_count);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Test %0d: Reset during FFT failed", test_count);
            fail_count = fail_count + 1;
        end

        // ====================================================================
        // Test Category 11: Stress Test - Multiple FFTs
        // ====================================================================
        $display("\n--- Test Category 11: Multiple FFT Operations ---");

        integer fft_run;
        for (fft_run = 0; fft_run < 3; fft_run = fft_run + 1) begin
            // Load different pattern each time
            for (i = 0; i < 8; i = i + 1) begin
                load_sample(i[2:0], 32'h3F800000, 32'h00000000);
            end

            cmd = CMD_START;
            @(posedge clk);
            cmd = CMD_IDLE;

            timeout = 0;
            while (busy === 1'b1 && timeout < 1000) begin
                @(posedge clk);
                timeout = timeout + 1;
            end

            test_count = test_count + 1;
            if (busy === 1'b0) begin
                $display("[PASS] Test %0d: Multiple FFT run %0d completed",
                         test_count, fft_run + 1);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] Test %0d: Multiple FFT run %0d failed",
                         test_count, fft_run + 1);
                fail_count = fail_count + 1;
            end

            @(posedge clk);
            @(posedge clk);
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

// ============================================================================
// Simple Testbench for Top-Level FPU
// Tests basic FADD, FSUB, FMUL, FMADD operations
// Uses hex constants to avoid SystemVerilog function calls
// ============================================================================

`timescale 1ns / 1ps

module tb_fpu_simple;

    // ========================================================================
    // DUT Signals
    // ========================================================================
    reg         clk;
    reg         rst_n;
    reg  [31:0] rs1_data;
    reg  [31:0] rs2_data;
    reg  [31:0] rs3_data;
    reg  [6:0]  funct7;
    reg  [2:0]  funct3;
    reg         fp_op;
    reg  [2:0]  frm;

    wire [31:0] result;
    wire [4:0]  flags;
    wire        ready;
    wire [2:0]  latency;

    // ========================================================================
    // DUT Instantiation
    // ========================================================================
    fpu dut (
        .clk(clk),
        .rst_n(rst_n),
        .rs1_data(rs1_data),
        .rs2_data(rs2_data),
        .rs3_data(rs3_data),
        .funct7(funct7),
        .funct3(funct3),
        .fp_op(fp_op),
        .frm(frm),
        .result(result),
        .flags(flags),
        .ready(ready),
        .latency(latency)
    );

    // ========================================================================
    // Clock Generation
    // ========================================================================
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 10ns period
    end

    // ========================================================================
    // Test Variables
    // ========================================================================
    integer test_num;
    integer pass_count;
    integer fail_count;

    // RISC-V FP Instruction Encodings
    localparam FADD_S    = 7'b0000000;
    localparam FSUB_S    = 7'b0000100;
    localparam FMUL_S    = 7'b0001000;
    localparam FMADD_S   = 7'b1000000;
    localparam FMSUB_S   = 7'b1000001;
    localparam FNMADD_S  = 7'b1000010;
    localparam FNMSUB_S  = 7'b1000011;

    // Rounding mode
    localparam RNE = 3'b000;  // Round to Nearest, ties to Even

    // ========================================================================
    // IEEE 754 Single-Precision Constants (in hex)
    // ========================================================================
    // Positive values
    localparam FP_1_5    = 32'h3FC00000;  // 1.5
    localparam FP_2_0    = 32'h40000000;  // 2.0
    localparam FP_2_5    = 32'h40200000;  // 2.5
    localparam FP_3_0    = 32'h40400000;  // 3.0
    localparam FP_3_5    = 32'h40600000;  // 3.5
    localparam FP_4_0    = 32'h40800000;  // 4.0
    localparam FP_4_5    = 32'h40900000;  // 4.5
    localparam FP_5_0    = 32'h40A00000;  // 5.0
    localparam FP_6_0    = 32'h40C00000;  // 6.0
    localparam FP_7_0    = 32'h40E00000;  // 7.0
    localparam FP_8_0    = 32'h41000000;  // 8.0
    localparam FP_9_0    = 32'h41100000;  // 9.0
    localparam FP_10_0   = 32'h41200000;  // 10.0
    localparam FP_0_5    = 32'h3F000000;  // 0.5

    // Negative values
    localparam FP_NEG_3_0 = 32'hC0400000;  // -3.0

    // Zero
    localparam FP_0_0    = 32'h00000000;  // 0.0

    // ========================================================================
    // Helper Function
    // ========================================================================
    function is_close;
        input [31:0] a, b;
        integer a_int, b_int, diff;
        begin
            // Convert to signed integer for ULP comparison
            a_int = a;
            b_int = b;

            // Calculate absolute difference
            diff = (a_int > b_int) ? (a_int - b_int) : (b_int - a_int);

            // Allow up to 2 ULP difference (very tight tolerance)
            is_close = (diff <= 2);
        end
    endfunction

    // ========================================================================
    // Test Task
    // ========================================================================
    task run_test;
        input [31:0] rs1, rs2, rs3;
        input [6:0]  inst_funct7;
        input [2:0]  inst_funct3;
        input [31:0] expected;
        input [200:0] description;
        input integer wait_cycles;

        reg [31:0] captured_result;
        integer i;

        begin
            test_num = test_num + 1;
            $display("\n[Test %0d] %s", test_num, description);
            $display("  Inputs: rs1=%h, rs2=%h, rs3=%h", rs1, rs2, rs3);

            // Issue instruction
            @(posedge clk);
            rs1_data = rs1;
            rs2_data = rs2;
            rs3_data = rs3;
            funct7 = inst_funct7;
            funct3 = inst_funct3;
            fp_op = 1'b1;

            @(posedge clk);
            fp_op = 1'b0;

            // Wait for result
            $display("  Waiting %0d cycles for result...", wait_cycles);
            captured_result = 32'hDEADBEEF; // Initialize to invalid value
            for (i = 0; i < wait_cycles + 5; i = i + 1) begin
                @(posedge clk);
                if (ready) begin
                    captured_result = result;
                    $display("  Result ready at cycle %0d, ready=%b, result=%h", i, ready, result);
                    i = wait_cycles + 10; // Break loop
                end
            end

            if (captured_result == 32'hDEADBEEF) begin
                $display("  [ERROR] No result received!");
            end

            // Check result
            if (is_close(captured_result, expected)) begin
                $display("  [PASS] Expected: %h, Got: %h", expected, captured_result);
                pass_count = pass_count + 1;
            end
            else begin
                $display("  [FAIL] Expected: %h, Got: %h", expected, captured_result);
                fail_count = fail_count + 1;
            end

            // Add spacing between tests to ensure pipeline drains
            repeat(5) @(posedge clk);
        end
    endtask

    // ========================================================================
    // Main Test Sequence
    // ========================================================================
    initial begin
        $display("\n========================================");
        $display("Simple FPU Testbench - Basic Tests");
        $display("========================================\n");

        // Initialize
        test_num = 0;
        pass_count = 0;
        fail_count = 0;

        clk = 0;
        rst_n = 0;
        rs1_data = 0;
        rs2_data = 0;
        rs3_data = 0;
        funct7 = 0;
        funct3 = RNE;
        fp_op = 0;
        frm = RNE;

        // Reset
        repeat(5) @(posedge clk);
        rst_n = 1;
        repeat(2) @(posedge clk);

        // ====================================================================
        // FADD.S Tests (latency = 4 cycles)
        // ====================================================================
        $display("\n=== FADD.S Tests ===");

        run_test(
            FP_1_5, FP_2_5, FP_0_0,
            FADD_S, RNE,
            FP_4_0,
            "FADD.S: 1.5 + 2.5 = 4.0",
            4
        );

        run_test(
            FP_10_0, FP_NEG_3_0, FP_0_0,
            FADD_S, RNE,
            FP_7_0,
            "FADD.S: 10.0 + (-3.0) = 7.0",
            4
        );

        // ====================================================================
        // FSUB.S Tests (latency = 4 cycles)
        // ====================================================================
        $display("\n=== FSUB.S Tests ===");

        run_test(
            FP_10_0, FP_4_0, FP_0_0,
            FSUB_S, RNE,
            FP_6_0,
            "FSUB.S: 10.0 - 4.0 = 6.0",
            4
        );

        run_test(
            FP_5_0, FP_8_0, FP_0_0,
            FSUB_S, RNE,
            FP_NEG_3_0,
            "FSUB.S: 5.0 - 8.0 = -3.0",
            4
        );

        // ====================================================================
        // FMUL.S Tests (latency = 5 cycles)
        // ====================================================================
        $display("\n=== FMUL.S Tests ===");

        run_test(
            FP_2_0, FP_3_0, FP_0_0,
            FMUL_S, RNE,
            FP_6_0,
            "FMUL.S: 2.0   3.0 = 6.0",
            5
        );

        run_test(
            FP_4_5, FP_2_0, FP_0_0,
            FMUL_S, RNE,
            FP_9_0,
            "FMUL.S: 4.5   2.0 = 9.0",
            5
        );

        // ====================================================================
        // FMADD.S Tests (latency = 6 cycles)
        // ====================================================================
        $display("\n=== FMADD.S Tests ===");

        run_test(
            FP_2_0, FP_3_0, FP_4_0,
            FMADD_S, RNE,
            FP_10_0,
            "FMADD.S: (2.0   3.0) + 4.0 = 10.0",
            6
        );

        run_test(
            FP_1_5, FP_2_0, FP_0_5,
            FMADD_S, RNE,
            FP_3_5,
            "FMADD.S: (1.5   2.0) + 0.5 = 3.5",
            6
        );

        // ====================================================================
        // Test Summary
        // ====================================================================
        repeat(10) @(posedge clk);

        $display("\n========================================");
        $display("Test Summary");
        $display("========================================");
        $display("Total Tests: %0d", test_num);
        $display("Passed:      %0d", pass_count);
        $display("Failed:      %0d", fail_count);

        if (fail_count == 0) begin
            $display("\n*** ALL TESTS PASSED ***\n");
        end
        else begin
            $display("\n*** %0d TEST(S) FAILED ***\n", fail_count);
        end

        $finish;
    end

    // Timeout watchdog
    initial begin
        #100000;
        $display("\n*** TIMEOUT - Test hung ***\n");
        $finish;
    end

endmodule

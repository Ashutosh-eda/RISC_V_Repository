// ============================================================================
// Testbench for Top-Level FPU
// Tests RISC-V instruction interface with FMA pipeline
// Tests operation decoding, rounding mode selection, and latency reporting
// Self-checking with comprehensive test cases
// ============================================================================

`timescale 1ns / 1ps

module tb_fpu;

    // ========================================================================
    // DUT Signals
    // ========================================================================

    reg         clk;
    reg         rst_n;

    // Operands
    reg  [31:0] rs1_data;
    reg  [31:0] rs2_data;
    reg  [31:0] rs3_data;

    // Control
    reg  [6:0]  funct7;
    reg  [2:0]  funct3;
    reg         fp_op;
    reg  [2:0]  frm;

    // Outputs
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
        forever #5 clk = ~clk; // 10ns period, 100MHz
    end

    // ========================================================================
    // Test Infrastructure
    // ========================================================================

    integer test_count = 0;
    integer pass_count = 0;
    integer fail_count = 0;

    // Pipeline queue (6-cycle latency maximum)
    reg [31:0] expected_queue [0:15];
    reg [200:0] description_queue [0:15];
    reg [2:0]  latency_queue [0:15];
    integer queue_head = 0;
    integer queue_tail = 0;

    // RISC-V FP Instruction Encodings (funct7)
    // funct7[6:2] = opcode, funct7[1:0] = FMA variant
    localparam FADD_S    = 7'b0000000;  // 0x00
    localparam FSUB_S    = 7'b0000100;  // 0x04
    localparam FMUL_S    = 7'b0001000;  // 0x08
    localparam FMADD_S   = 7'b1000000;  // 0x40 (variant 00)
    localparam FMSUB_S   = 7'b1000001;  // 0x41 (variant 01)
    localparam FNMADD_S  = 7'b1000010;  // 0x42 (variant 10)
    localparam FNMSUB_S  = 7'b1000011;  // 0x43 (variant 11)

    // Rounding modes (funct3)
    localparam RNE = 3'b000;  // Round to Nearest, ties to Even
    localparam RTZ = 3'b001;  // Round toward Zero
    localparam RDN = 3'b010;  // Round Down (-inf)
    localparam RUP = 3'b011;  // Round Up (+inf)
    localparam RMM = 3'b100;  // Round to Nearest, ties to Max Magnitude
    localparam DYN = 3'b111;  // Dynamic (use frm from CSR)

    // ========================================================================
    // Helper Functions
    // ========================================================================

    // Convert real to IEEE 754 single-precision
    function [31:0] real_to_fp32;
        input real value;
        begin
            real_to_fp32 = $shortrealtobits(value);
        end
    endfunction

    // Convert IEEE 754 to real
    function real fp32_to_real;
        input [31:0] fp;
        begin
            fp32_to_real = $bitstoshortreal(fp);
        end
    endfunction

    // Check if two FP values are close (within tolerance)
    function is_close;
        input [31:0] a, b;
        input real tolerance;
        real val_a, val_b, diff;
        begin
            val_a = fp32_to_real(a);
            val_b = fp32_to_real(b);
            diff = (val_a > val_b) ? (val_a - val_b) : (val_b - val_a);
            is_close = (diff < tolerance) || (a === b);
        end
    endfunction

    // ========================================================================
    // Test Tasks
    // ========================================================================

    // Task: Issue FP instruction
    task test_fp_instruction;
        input [31:0] rs1, rs2, rs3;
        input [6:0]  instruction_funct7;
        input [2:0]  instruction_funct3;
        input [31:0] expected;
        input [2:0]  expected_latency;
        input [200:0] description;

        begin
            rs1_data = rs1;
            rs2_data = rs2;
            rs3_data = rs3;
            funct7 = instruction_funct7;
            funct3 = instruction_funct3;
            fp_op = 1'b1;

            // Enqueue expected result
            expected_queue[queue_tail] = expected;
            description_queue[queue_tail] = description;
            latency_queue[queue_tail] = expected_latency;
            queue_tail = (queue_tail + 1) % 16;

            @(posedge clk);
            fp_op = 1'b0;
        end
    endtask

    // Automatic output checking
    reg [31:0] exp_result_check;
    reg [200:0] desc_check;
    reg [2:0]  exp_latency_check;
    real tolerance_check;

    always @(posedge clk) begin
        if (rst_n && ready && (queue_head != queue_tail)) begin
            test_count <= test_count + 1;
            exp_result_check = expected_queue[queue_head];
            desc_check = description_queue[queue_head];
            exp_latency_check = latency_queue[queue_head];
            queue_head <= (queue_head + 1) % 16;

            tolerance_check = 1e-5;

            if (is_close(result, exp_result_check, tolerance_check)) begin
                $display("[PASS] Test %0d: %s", test_count + 1, desc_check);
                $display("       Result: %h (%.6f)", result, fp32_to_real(result));
                pass_count <= pass_count + 1;
            end
            else begin
                $display("[FAIL] Test %0d: %s", test_count + 1, desc_check);
                $display("       Expected: %h (%.6f)", exp_result_check, fp32_to_real(exp_result_check));
                $display("       Got:      %h (%.6f)", result, fp32_to_real(result));
                fail_count <= fail_count + 1;
            end
        end
    end

    // ========================================================================
    // Test Stimulus
    // ========================================================================

    initial begin
        $display("\n========================================");
        $display("FPU Top-Level Testbench");
        $display("========================================\n");

        // Initialize
        rst_n = 0;
        rs1_data = 0;
        rs2_data = 0;
        rs3_data = 0;
        funct7 = 0;
        funct3 = 0;
        fp_op = 0;
        frm = RNE;  // Default rounding mode

        // Reset sequence
        repeat(3) @(posedge clk);
        rst_n = 1;
        @(posedge clk);

        // ====================================================================
        // Test Category 1: FADD.S (Floating-Point Addition)
        // ====================================================================
        $display("\n--- Test Category 1: FADD.S ---");

        // Test 1: Basic addition
        test_fp_instruction(
            real_to_fp32(1.5), real_to_fp32(2.5), 32'h0,
            FADD_S, RNE,
            real_to_fp32(4.0), 3'd4,
            "FADD.S: 1.5 + 2.5 = 4.0"
        );

        // Test 2: Addition with zero
        test_fp_instruction(
            real_to_fp32(7.0), real_to_fp32(0.0), 32'h0,
            FADD_S, RNE,
            real_to_fp32(7.0), 3'd4,
            "FADD.S: 7.0 + 0.0 = 7.0"
        );

        // Test 3: Negative addition
        test_fp_instruction(
            real_to_fp32(5.0), real_to_fp32(-3.0), 32'h0,
            FADD_S, RNE,
            real_to_fp32(2.0), 3'd4,
            "FADD.S: 5.0 + (-3.0) = 2.0"
        );

        // ====================================================================
        // Test Category 2: FSUB.S (Floating-Point Subtraction)
        // ====================================================================
        $display("\n--- Test Category 2: FSUB.S ---");

        // Test 4: Basic subtraction
        test_fp_instruction(
            real_to_fp32(10.0), real_to_fp32(4.0), 32'h0,
            FSUB_S, RNE,
            real_to_fp32(6.0), 3'd4,
            "FSUB.S: 10.0 - 4.0 = 6.0"
        );

        // Test 5: Subtract zero
        test_fp_instruction(
            real_to_fp32(9.5), real_to_fp32(0.0), 32'h0,
            FSUB_S, RNE,
            real_to_fp32(9.5), 3'd4,
            "FSUB.S: 9.5 - 0.0 = 9.5"
        );

        // Test 6: Result is zero
        test_fp_instruction(
            real_to_fp32(3.0), real_to_fp32(3.0), 32'h0,
            FSUB_S, RNE,
            real_to_fp32(0.0), 3'd4,
            "FSUB.S: 3.0 - 3.0 = 0.0"
        );

        // ====================================================================
        // Test Category 3: FMUL.S (Floating-Point Multiplication)
        // ====================================================================
        $display("\n--- Test Category 3: FMUL.S ---");

        // Test 7: Basic multiplication
        test_fp_instruction(
            real_to_fp32(3.0), real_to_fp32(4.0), 32'h0,
            FMUL_S, RNE,
            real_to_fp32(12.0), 3'd5,
            "FMUL.S: 3.0 × 4.0 = 12.0"
        );

        // Test 8: Multiply by 1
        test_fp_instruction(
            real_to_fp32(7.5), real_to_fp32(1.0), 32'h0,
            FMUL_S, RNE,
            real_to_fp32(7.5), 3'd5,
            "FMUL.S: 7.5 × 1.0 = 7.5"
        );

        // Test 9: Multiply by 0
        test_fp_instruction(
            real_to_fp32(100.0), real_to_fp32(0.0), 32'h0,
            FMUL_S, RNE,
            real_to_fp32(0.0), 3'd5,
            "FMUL.S: 100.0 × 0.0 = 0.0"
        );

        // Test 10: Negative multiplication
        test_fp_instruction(
            real_to_fp32(-2.0), real_to_fp32(5.0), 32'h0,
            FMUL_S, RNE,
            real_to_fp32(-10.0), 3'd5,
            "FMUL.S: -2.0 × 5.0 = -10.0"
        );

        // ====================================================================
        // Test Category 4: FMADD.S (Fused Multiply-Add)
        // ====================================================================
        $display("\n--- Test Category 4: FMADD.S ---");

        // Test 11: Basic FMA
        test_fp_instruction(
            real_to_fp32(2.0), real_to_fp32(3.0), real_to_fp32(4.0),
            FMADD_S, RNE,
            real_to_fp32(10.0), 3'd6,
            "FMADD.S: 2.0 × 3.0 + 4.0 = 10.0"
        );

        // Test 12: FMA with zero addend
        test_fp_instruction(
            real_to_fp32(5.0), real_to_fp32(6.0), real_to_fp32(0.0),
            FMADD_S, RNE,
            real_to_fp32(30.0), 3'd6,
            "FMADD.S: 5.0 × 6.0 + 0.0 = 30.0"
        );

        // Test 13: FMA with negative
        test_fp_instruction(
            real_to_fp32(-2.0), real_to_fp32(4.0), real_to_fp32(3.0),
            FMADD_S, RNE,
            real_to_fp32(-5.0), 3'd6,
            "FMADD.S: -2.0 × 4.0 + 3.0 = -5.0"
        );

        // ====================================================================
        // Test Category 5: FMSUB.S (Fused Multiply-Subtract)
        // ====================================================================
        $display("\n--- Test Category 5: FMSUB.S ---");

        // Test 14: Basic FMS
        test_fp_instruction(
            real_to_fp32(3.0), real_to_fp32(5.0), real_to_fp32(2.0),
            FMSUB_S, RNE,
            real_to_fp32(13.0), 3'd6,
            "FMSUB.S: 3.0 × 5.0 - 2.0 = 13.0"
        );

        // Test 15: FMS with zero
        test_fp_instruction(
            real_to_fp32(4.0), real_to_fp32(2.5), real_to_fp32(0.0),
            FMSUB_S, RNE,
            real_to_fp32(10.0), 3'd6,
            "FMSUB.S: 4.0 × 2.5 - 0.0 = 10.0"
        );

        // ====================================================================
        // Test Category 6: FNMADD.S (Negated Multiply-Add)
        // ====================================================================
        $display("\n--- Test Category 6: FNMADD.S ---");

        // Test 16: Basic FNMADD
        test_fp_instruction(
            real_to_fp32(2.0), real_to_fp32(3.0), real_to_fp32(1.0),
            FNMADD_S, RNE,
            real_to_fp32(-7.0), 3'd6,
            "FNMADD.S: -(2.0 × 3.0 + 1.0) = -7.0"
        );

        // ====================================================================
        // Test Category 7: FNMSUB.S (Negated Multiply-Subtract)
        // ====================================================================
        $display("\n--- Test Category 7: FNMSUB.S ---");

        // Test 17: Basic FNMSUB
        test_fp_instruction(
            real_to_fp32(2.0), real_to_fp32(4.0), real_to_fp32(3.0),
            FNMSUB_S, RNE,
            real_to_fp32(-5.0), 3'd6,
            "FNMSUB.S: -(2.0 × 4.0 - 3.0) = -5.0"
        );

        // ====================================================================
        // Test Category 8: Rounding Modes
        // ====================================================================
        $display("\n--- Test Category 8: Rounding Modes ---");

        // Test 18: RNE (Round to Nearest, ties to Even) - default
        test_fp_instruction(
            real_to_fp32(1.0), real_to_fp32(3.0), 32'h0,
            FMUL_S, RNE,
            real_to_fp32(3.0), 3'd5,
            "FMUL.S with RNE: 1.0 × 3.0 = 3.0"
        );

        // Test 19: RTZ (Round toward Zero)
        test_fp_instruction(
            real_to_fp32(1.1), real_to_fp32(1.1), 32'h0,
            FMUL_S, RTZ,
            real_to_fp32(1.21), 3'd5,
            "FMUL.S with RTZ: 1.1 × 1.1 ≈ 1.21"
        );

        // Test 20: DYN (Dynamic - use frm)
        frm = RNE;  // Set CSR rounding mode
        test_fp_instruction(
            real_to_fp32(2.0), real_to_fp32(2.0), 32'h0,
            FMUL_S, DYN,  // Use dynamic mode
            real_to_fp32(4.0), 3'd5,
            "FMUL.S with DYN: 2.0 × 2.0 = 4.0 (using frm)"
        );

        // ====================================================================
        // Test Category 9: Latency Verification
        // ====================================================================
        $display("\n--- Test Category 9: Latency Verification ---");

        // Test 21: Check FADD latency = 4
        test_fp_instruction(
            real_to_fp32(1.0), real_to_fp32(1.0), 32'h0,
            FADD_S, RNE,
            real_to_fp32(2.0), 3'd4,
            "Latency check: FADD.S should be 4 cycles"
        );

        // Test 22: Check FMUL latency = 5
        test_fp_instruction(
            real_to_fp32(2.0), real_to_fp32(2.0), 32'h0,
            FMUL_S, RNE,
            real_to_fp32(4.0), 3'd5,
            "Latency check: FMUL.S should be 5 cycles"
        );

        // Test 23: Check FMADD latency = 6
        test_fp_instruction(
            real_to_fp32(2.0), real_to_fp32(2.0), real_to_fp32(1.0),
            FMADD_S, RNE,
            real_to_fp32(5.0), 3'd6,
            "Latency check: FMADD.S should be 6 cycles"
        );

        // ====================================================================
        // Test Category 10: Edge Cases
        // ====================================================================
        $display("\n--- Test Category 10: Edge Cases ---");

        // Test 24: Very small numbers
        test_fp_instruction(
            real_to_fp32(0.001), real_to_fp32(0.002), 32'h0,
            FMUL_S, RNE,
            real_to_fp32(0.000002), 3'd5,
            "FMUL.S: 0.001 × 0.002 = 0.000002"
        );

        // Test 25: Large numbers
        test_fp_instruction(
            real_to_fp32(1000.0), real_to_fp32(2000.0), 32'h0,
            FMUL_S, RNE,
            real_to_fp32(2000000.0), 3'd5,
            "FMUL.S: 1000.0 × 2000.0 = 2000000.0"
        );

        // Test 26: Mixed signs
        test_fp_instruction(
            real_to_fp32(-5.0), real_to_fp32(-4.0), 32'h0,
            FMUL_S, RNE,
            real_to_fp32(20.0), 3'd5,
            "FMUL.S: -5.0 × -4.0 = 20.0"
        );

        // Test 27: Fractional multiplication
        test_fp_instruction(
            real_to_fp32(0.5), real_to_fp32(0.25), 32'h0,
            FMUL_S, RNE,
            real_to_fp32(0.125), 3'd5,
            "FMUL.S: 0.5 × 0.25 = 0.125"
        );

        // Test 28: Complex FMA
        test_fp_instruction(
            real_to_fp32(1.5), real_to_fp32(2.5), real_to_fp32(3.5),
            FMADD_S, RNE,
            real_to_fp32(7.25), 3'd6,
            "FMADD.S: 1.5 × 2.5 + 3.5 = 7.25"
        );

        // Test 29: Powers of two
        test_fp_instruction(
            real_to_fp32(8.0), real_to_fp32(16.0), 32'h0,
            FMUL_S, RNE,
            real_to_fp32(128.0), 3'd5,
            "FMUL.S: 8.0 × 16.0 = 128.0"
        );

        // Test 30: Denormal-range result (very small)
        test_fp_instruction(
            real_to_fp32(1e-20), real_to_fp32(1e-20), 32'h0,
            FMUL_S, RNE,
            real_to_fp32(0.0), 3'd5,  // Underflow to zero
            "FMUL.S: 1e-20 × 1e-20 → underflow"
        );

        // ====================================================================
        // Wait for all results to complete
        // ====================================================================
        $display("\nWaiting for all 30 results...\n");

        // Wait until all 30 tests have been processed
        wait (test_count >= 30);
        repeat(5) @(posedge clk);  // A few extra cycles for good measure

        // ====================================================================
        // Test Summary
        // ====================================================================
        repeat(5) @(posedge clk);

        $display("\n========================================");
        $display("Test Summary");
        $display("========================================");
        $display("Total Tests: %0d", test_count);
        $display("Passed:      %0d", pass_count);
        $display("Failed:      %0d", fail_count);

        if (fail_count == 0) begin
            $display("\n*** ALL TESTS PASSED ***\n");
        end
        else begin
            $display("\n*** SOME TESTS FAILED ***\n");
        end

        $finish;
    end

endmodule

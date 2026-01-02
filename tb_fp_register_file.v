// ============================================================================
// Testbench for Floating-Point Register File (f0-f31)
// Tests triple-port reads, single-port write
// All registers are writable (no hardwired zero)
// Self-checking with comprehensive test cases
// ============================================================================

`timescale 1ns / 1ps

module tb_fp_register_file;

    // ========================================================================
    // Clock and Reset
    // ========================================================================

    reg clk;
    reg rst_n;

    // ========================================================================
    // DUT Signals
    // ========================================================================

    reg  [4:0]  rs1_addr, rs2_addr, rs3_addr;
    reg  [4:0]  rd_addr;
    reg  [31:0] wr_data;
    reg         wr_en;

    wire [31:0] rs1_data, rs2_data, rs3_data;

    // ========================================================================
    // DUT Instantiation
    // ========================================================================

    fp_register_file dut (
        .clk(clk),
        .rst_n(rst_n),
        .rs1_addr(rs1_addr),
        .rs2_addr(rs2_addr),
        .rs3_addr(rs3_addr),
        .rd_addr(rd_addr),
        .wr_data(wr_data),
        .wr_en(wr_en),
        .rs1_data(rs1_data),
        .rs2_data(rs2_data),
        .rs3_data(rs3_data)
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
    integer errors;

    // IEEE 754 Constants
    localparam FP_ZERO      = 32'h00000000;  // +0.0
    localparam FP_ONE       = 32'h3F800000;  // +1.0
    localparam FP_TWO       = 32'h40000000;  // +2.0
    localparam FP_HALF      = 32'h3F000000;  // +0.5
    localparam FP_NEG_ONE   = 32'hBF800000;  // -1.0
    localparam FP_PI        = 32'h40490FDB;  // π ≈ 3.14159

    // ========================================================================
    // Test Tasks
    // ========================================================================

    task write_fp_reg;
        input [4:0]  addr;
        input [31:0] data;
        begin
            @(posedge clk);      // Wait for clean clock edge FIRST
            rd_addr = addr;      // Setup signals after clock edge
            wr_data = data;
            wr_en = 1'b1;
            @(posedge clk);      // Write happens on THIS edge
            wr_en = 1'b0;
        end
    endtask

    task read_and_check;
        input [4:0]  addr;
        input [31:0] expected;
        input [200:0] description;
        begin
            test_count = test_count + 1;
            rs1_addr = addr;
            #1;

            if (rs1_data === expected) begin
                $display("[PASS] Test %0d: %s", test_count, description);
                $display("       f%0d = 0x%h", addr, rs1_data);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] Test %0d: %s", test_count, description);
                $display("       Expected: 0x%h", expected);
                $display("       Got:      0x%h", rs1_data);
                fail_count = fail_count + 1;
            end
        end
    endtask

    task check_triple_read;
        input [4:0]  addr1, addr2, addr3;
        input [31:0] exp1, exp2, exp3;
        input [200:0] description;
        begin
            test_count = test_count + 1;
            rs1_addr = addr1;
            rs2_addr = addr2;
            rs3_addr = addr3;
            #1;

            if (rs1_data === exp1 && rs2_data === exp2 && rs3_data === exp3) begin
                $display("[PASS] Test %0d: %s", test_count, description);
                $display("       f%0d=0x%h, f%0d=0x%h, f%0d=0x%h",
                         addr1, rs1_data, addr2, rs2_data, addr3, rs3_data);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] Test %0d: %s", test_count, description);
                $display("       Expected: f%0d=0x%h, f%0d=0x%h, f%0d=0x%h",
                         addr1, exp1, addr2, exp2, addr3, exp3);
                $display("       Got:      f%0d=0x%h, f%0d=0x%h, f%0d=0x%h",
                         addr1, rs1_data, addr2, rs2_data, addr3, rs3_data);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // ========================================================================
    // Test Stimulus
    // ========================================================================

    initial begin
        $display("\n========================================");
        $display("FP Register File Testbench");
        $display("========================================\n");

        // Initialize
        rst_n = 0;
        rs1_addr = 5'd0;
        rs2_addr = 5'd0;
        rs3_addr = 5'd0;
        rd_addr = 5'd0;
        wr_data = 32'd0;
        wr_en = 1'b0;

        repeat(3) @(posedge clk);
        rst_n = 1;
        @(posedge clk);

        // ====================================================================
        // Test Category 1: f0 is NOT Hardwired (Unlike Integer x0)
        // ====================================================================
        $display("\n--- Test Category 1: f0 is Writable ---");

        read_and_check(
            5'd0, FP_ZERO,
            "f0 reads +0.0 initially"
        );

        write_fp_reg(5'd0, FP_ONE);
        read_and_check(
            5'd0, FP_ONE,
            "f0 can be written (holds 1.0)"
        );

        write_fp_reg(5'd0, FP_ZERO);
        read_and_check(
            5'd0, FP_ZERO,
            "f0 back to +0.0"
        );

        // ====================================================================
        // Test Category 2: Single Register Write/Read
        // ====================================================================
        $display("\n--- Test Category 2: Single Register Write/Read ---");

        write_fp_reg(5'd1, FP_ONE);
        read_and_check(
            5'd1, FP_ONE,
            "Write/Read f1 (1.0)"
        );

        write_fp_reg(5'd10, FP_PI);
        read_and_check(
            5'd10, FP_PI,
            "Write/Read f10 (π)"
        );

        write_fp_reg(5'd31, FP_NEG_ONE);
        read_and_check(
            5'd31, FP_NEG_ONE,
            "Write/Read f31 (-1.0)"
        );

        // ====================================================================
        // Test Category 3: Overwrite Existing Data
        // ====================================================================
        $display("\n--- Test Category 3: Overwrite Existing Data ---");

        write_fp_reg(5'd5, FP_ONE);
        read_and_check(
            5'd5, FP_ONE,
            "Initial write to f5 (1.0)"
        );

        write_fp_reg(5'd5, FP_TWO);
        read_and_check(
            5'd5, FP_TWO,
            "Overwrite f5 (2.0)"
        );

        write_fp_reg(5'd5, FP_ZERO);
        read_and_check(
            5'd5, FP_ZERO,
            "Write +0.0 to f5"
        );

        // ====================================================================
        // Test Category 4: Triple Port Read (FMA Use Case)
        // ====================================================================
        $display("\n--- Test Category 4: Triple Port Read (FMA) ---");

        write_fp_reg(5'd2, FP_ONE);
        write_fp_reg(5'd3, FP_TWO);
        write_fp_reg(5'd4, FP_HALF);

        check_triple_read(
            5'd2, 5'd3, 5'd4,
            FP_ONE, FP_TWO, FP_HALF,
            "FMA read: f2=1.0, f3=2.0, f4=0.5"
        );

        check_triple_read(
            5'd0, 5'd1, 5'd10,
            FP_ZERO, FP_ONE, FP_PI,
            "Triple read: f0, f1, f10"
        );

        check_triple_read(
            5'd5, 5'd5, 5'd5,
            FP_ZERO, FP_ZERO, FP_ZERO,
            "Read same register on all 3 ports"
        );

        // ====================================================================
        // Test Category 5: All Registers Sequential Write/Read
        // ====================================================================
        $display("\n--- Test Category 5: All Registers Sequential ---");

        // Write unique FP value to each register
        for (i = 0; i < 32; i = i + 1) begin
            write_fp_reg(i[4:0], (32'h3F800000 + (i << 16)));  // Vary pattern
        end

        // Read back and verify
        test_count = test_count + 1;
        errors = 0;
        for (i = 0; i < 32; i = i + 1) begin
            rs1_addr = i[4:0];
            #1;
            if (rs1_data !== (32'h3F800000 + (i << 16))) begin
                $display("  [ERROR] f%0d: Expected 0x%h, Got 0x%h",
                         i, (32'h3F800000 + (i << 16)), rs1_data);
                errors = errors + 1;
            end
        end

        if (errors == 0) begin
            $display("[PASS] Test %0d: All 32 FP registers verified", test_count);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Test %0d: %0d FP registers failed", test_count, errors);
            fail_count = fail_count + 1;
        end

        // ====================================================================
        // Test Category 6: Write Enable Control
        // ====================================================================
        $display("\n--- Test Category 6: Write Enable Control ---");

        write_fp_reg(5'd7, FP_PI);
        read_and_check(
            5'd7, FP_PI,
            "Initial write to f7 (π)"
        );

        // Attempt write with wr_en=0
        rd_addr = 5'd7;
        wr_data = FP_TWO;
        wr_en = 1'b0;
        @(posedge clk);

        read_and_check(
            5'd7, FP_PI,
            "f7 unchanged (wr_en=0)"
        );

        // ====================================================================
        // Test Category 7: FP Special Values
        // ====================================================================
        $display("\n--- Test Category 7: FP Special Values ---");

        write_fp_reg(5'd8, 32'h00000000);
        read_and_check(
            5'd8, 32'h00000000,
            "+0.0"
        );

        write_fp_reg(5'd9, 32'h80000000);
        read_and_check(
            5'd9, 32'h80000000,
            "-0.0"
        );

        write_fp_reg(5'd11, 32'h7F800000);
        read_and_check(
            5'd11, 32'h7F800000,
            "+Infinity"
        );

        write_fp_reg(5'd12, 32'hFF800000);
        read_and_check(
            5'd12, 32'hFF800000,
            "-Infinity"
        );

        write_fp_reg(5'd13, 32'h7FC00000);
        read_and_check(
            5'd13, 32'h7FC00000,
            "Quiet NaN"
        );

        // ====================================================================
        // Test Category 8: Reset Behavior
        // ====================================================================
        $display("\n--- Test Category 8: Reset Behavior ---");

        write_fp_reg(5'd15, FP_PI);
        read_and_check(
            5'd15, FP_PI,
            "f15 before reset"
        );

        // Apply reset
        rst_n = 0;
        @(posedge clk);
        @(posedge clk);
        rst_n = 1;
        @(posedge clk);

        read_and_check(
            5'd15, FP_ZERO,
            "f15 cleared to +0.0 after reset"
        );

        read_and_check(
            5'd0, FP_ZERO,
            "f0 cleared to +0.0 after reset"
        );

        // ====================================================================
        // Test Category 9: Boundary Registers
        // ====================================================================
        $display("\n--- Test Category 9: Boundary Registers ---");

        write_fp_reg(5'd0, FP_ONE);
        write_fp_reg(5'd1, FP_TWO);
        write_fp_reg(5'd31, FP_HALF);

        check_triple_read(
            5'd0, 5'd1, 5'd31,
            FP_ONE, FP_TWO, FP_HALF,
            "f0 (first), f1, f31 (last)"
        );

        // ====================================================================
        // Test Category 10: Rapid Write/Read
        // ====================================================================
        $display("\n--- Test Category 10: Rapid Write/Read ---");

        for (i = 0; i < 5; i = i + 1) begin
            write_fp_reg(5'd20, 32'h40000000 + (i << 10));
        end

        read_and_check(
            5'd20, 32'h40000000 + (4 << 10),
            "f20 after rapid writes (last value)"
        );

        // ====================================================================
        // Test Category 11: FMA-Style Triple Read
        // ====================================================================
        $display("\n--- Test Category 11: FMA-Style Triple Read ---");

        // Set up typical FMA scenario: f6 = f7 * f8 + f9
        write_fp_reg(5'd7, 32'h40000000);  // 2.0
        write_fp_reg(5'd8, 32'h3F000000);  // 0.5
        write_fp_reg(5'd9, 32'h3F800000);  // 1.0

        check_triple_read(
            5'd7, 5'd8, 5'd9,
            32'h40000000, 32'h3F000000, 32'h3F800000,
            "FMA operands: 2.0 * 0.5 + 1.0"
        );

        // All three ports reading different registers
        write_fp_reg(5'd25, 32'h3DCCCCCD);  // 0.1
        write_fp_reg(5'd26, 32'h3E4CCCCD);  // 0.2
        write_fp_reg(5'd27, 32'h3E99999A);  // 0.3

        check_triple_read(
            5'd25, 5'd26, 5'd27,
            32'h3DCCCCCD, 32'h3E4CCCCD, 32'h3E99999A,
            "FMA: 0.1, 0.2, 0.3"
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

// ============================================================================
// Testbench for Integer Register File (x0-x31)
// Tests dual-port reads, single-port write, x0 hardwired to zero
// Self-checking with comprehensive test cases
// ============================================================================

`timescale 1ns / 1ps

module tb_register_file;

    // ========================================================================
    // Clock and Reset
    // ========================================================================

    reg clk;
    reg rst_n;

    // ========================================================================
    // DUT Signals
    // ========================================================================

    reg  [4:0]  rs1_addr, rs2_addr;
    reg  [4:0]  rd_addr;
    reg  [31:0] wr_data;
    reg         wr_en;

    wire [31:0] rs1_data, rs2_data;

    // ========================================================================
    // DUT Instantiation
    // ========================================================================

    register_file dut (
        .clk(clk),
        .rst_n(rst_n),
        .rs1_addr(rs1_addr),
        .rs2_addr(rs2_addr),
        .rd_addr(rd_addr),
        .wr_data(wr_data),
        .wr_en(wr_en),
        .rs1_data(rs1_data),
        .rs2_data(rs2_data)
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

    // ========================================================================
    // Test Tasks
    // ========================================================================

    task write_reg;
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
            #1;  // Small delay for combinational logic to settle

            if (rs1_data === expected) begin
                $display("[PASS] Test %0d: %s", test_count, description);
                $display("       x%0d = 0x%h", addr, rs1_data);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] Test %0d: %s", test_count, description);
                $display("       Expected: 0x%h", expected);
                $display("       Got:      0x%h", rs1_data);
                fail_count = fail_count + 1;
            end
        end
    endtask

    task check_dual_read;
        input [4:0]  addr1, addr2;
        input [31:0] exp1, exp2;
        input [200:0] description;
        begin
            test_count = test_count + 1;
            rs1_addr = addr1;
            rs2_addr = addr2;
            #1;  // Small delay for combinational logic to settle

            if (rs1_data === exp1 && rs2_data === exp2) begin
                $display("[PASS] Test %0d: %s", test_count, description);
                $display("       x%0d=0x%h, x%0d=0x%h", addr1, rs1_data, addr2, rs2_data);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] Test %0d: %s", test_count, description);
                $display("       Expected: x%0d=0x%h, x%0d=0x%h", addr1, exp1, addr2, exp2);
                $display("       Got:      x%0d=0x%h, x%0d=0x%h", addr1, rs1_data, addr2, rs2_data);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // ========================================================================
    // Test Stimulus
    // ========================================================================

    initial begin
        $display("\n========================================");
        $display("Integer Register File Testbench");
        $display("========================================\n");

        // Initialize
        rst_n = 0;
        rs1_addr = 5'd0;
        rs2_addr = 5'd0;
        rd_addr = 5'd0;
        wr_data = 32'd0;
        wr_en = 1'b0;

        repeat(3) @(posedge clk);
        rst_n = 1;
        @(posedge clk);

        // ====================================================================
        // Test Category 1: x0 Hardwired to Zero
        // ====================================================================
        $display("\n--- Test Category 1: x0 Hardwired to Zero ---");

        read_and_check(
            5'd0, 32'h0,
            "x0 reads zero initially"
        );

        // Try to write to x0 (should be ignored)
        write_reg(5'd0, 32'hDEADBEEF);
        read_and_check(
            5'd0, 32'h0,
            "x0 still zero after write attempt"
        );

        // ====================================================================
        // Test Category 2: Single Register Write/Read
        // ====================================================================
        $display("\n--- Test Category 2: Single Register Write/Read ---");

        write_reg(5'd1, 32'h12345678);
        read_and_check(
            5'd1, 32'h12345678,
            "Write/Read x1"
        );

        write_reg(5'd10, 32'hABCDEF01);
        read_and_check(
            5'd10, 32'hABCDEF01,
            "Write/Read x10"
        );

        write_reg(5'd31, 32'hFFFFFFFF);
        read_and_check(
            5'd31, 32'hFFFFFFFF,
            "Write/Read x31 (last register)"
        );

        // ====================================================================
        // Test Category 3: Overwrite Existing Data
        // ====================================================================
        $display("\n--- Test Category 3: Overwrite Existing Data ---");

        write_reg(5'd5, 32'h11111111);
        read_and_check(
            5'd5, 32'h11111111,
            "Initial write to x5"
        );

        write_reg(5'd5, 32'h22222222);
        read_and_check(
            5'd5, 32'h22222222,
            "Overwrite x5"
        );

        write_reg(5'd5, 32'h0);
        read_and_check(
            5'd5, 32'h0,
            "Write zero to x5"
        );

        // ====================================================================
        // Test Category 4: Dual Port Read
        // ====================================================================
        $display("\n--- Test Category 4: Dual Port Read ---");

        write_reg(5'd2, 32'hAAAAAAAA);
        write_reg(5'd3, 32'h55555555);

        check_dual_read(
            5'd2, 5'd3,
            32'hAAAAAAAA, 32'h55555555,
            "Simultaneous read x2 and x3"
        );

        check_dual_read(
            5'd0, 5'd1,
            32'h0, 32'h12345678,
            "Read x0 (zero) and x1 simultaneously"
        );

        check_dual_read(
            5'd10, 5'd10,
            32'hABCDEF01, 32'hABCDEF01,
            "Read same register on both ports"
        );

        // ====================================================================
        // Test Category 5: All Registers Sequential Write/Read
        // ====================================================================
        $display("\n--- Test Category 5: All Registers Sequential ---");

        // Write unique value to each register
        for (i = 1; i < 32; i = i + 1) begin
            write_reg(i[4:0], (32'h10000000 + i));
        end

        // Read back and verify
        test_count = test_count + 1;
        errors = 0;
        for (i = 1; i < 32; i = i + 1) begin
            rs1_addr = i[4:0];
            #1;
            if (rs1_data !== (32'h10000000 + i)) begin
                $display("  [ERROR] x%0d: Expected 0x%h, Got 0x%h",
                         i, (32'h10000000 + i), rs1_data);
                errors = errors + 1;
            end
        end

        if (errors == 0) begin
            $display("[PASS] Test %0d: All 31 registers verified", test_count);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Test %0d: %0d registers failed", test_count, errors);
            fail_count = fail_count + 1;
        end

        // ====================================================================
        // Test Category 6: Write Enable Control
        // ====================================================================
        $display("\n--- Test Category 6: Write Enable Control ---");

        write_reg(5'd7, 32'h77777777);
        read_and_check(
            5'd7, 32'h77777777,
            "Initial write to x7"
        );

        // Attempt write with wr_en=0
        rd_addr = 5'd7;
        wr_data = 32'h99999999;
        wr_en = 1'b0;
        @(posedge clk);

        read_and_check(
            5'd7, 32'h77777777,
            "x7 unchanged (wr_en=0)"
        );

        // ====================================================================
        // Test Category 7: Data Patterns
        // ====================================================================
        $display("\n--- Test Category 7: Data Patterns ---");

        write_reg(5'd8, 32'h00000000);
        read_and_check(
            5'd8, 32'h00000000,
            "All zeros pattern"
        );

        write_reg(5'd9, 32'hFFFFFFFF);
        read_and_check(
            5'd9, 32'hFFFFFFFF,
            "All ones pattern"
        );

        write_reg(5'd11, 32'hAAAAAAAA);
        read_and_check(
            5'd11, 32'hAAAAAAAA,
            "Alternating 10 pattern"
        );

        write_reg(5'd12, 32'h55555555);
        read_and_check(
            5'd12, 32'h55555555,
            "Alternating 01 pattern"
        );

        // ====================================================================
        // Test Category 8: Reset Behavior
        // ====================================================================
        $display("\n--- Test Category 8: Reset Behavior ---");

        write_reg(5'd15, 32'hFEDCBA98);
        read_and_check(
            5'd15, 32'hFEDCBA98,
            "x15 before reset"
        );

        // Apply reset
        rst_n = 0;
        @(posedge clk);
        @(posedge clk);
        rst_n = 1;
        @(posedge clk);

        read_and_check(
            5'd15, 32'h0,
            "x15 cleared after reset"
        );

        read_and_check(
            5'd1, 32'h0,
            "x1 cleared after reset"
        );

        // ====================================================================
        // Test Category 9: Boundary Registers
        // ====================================================================
        $display("\n--- Test Category 9: Boundary Registers ---");

        write_reg(5'd0, 32'h12345678);
        write_reg(5'd1, 32'hAAAAAAAA);
        write_reg(5'd31, 32'hBBBBBBBB);

        check_dual_read(
            5'd0, 5'd1,
            32'h0, 32'hAAAAAAAA,
            "x0 (zero) and x1 (first writable)"
        );

        check_dual_read(
            5'd30, 5'd31,
            32'h0, 32'hBBBBBBBB,
            "x30 and x31 (last register)"
        );

        // ====================================================================
        // Test Category 10: Rapid Write/Read
        // ====================================================================
        $display("\n--- Test Category 10: Rapid Write/Read ---");

        for (i = 0; i < 5; i = i + 1) begin
            write_reg(5'd20, 32'hA0000000 + i);
        end

        read_and_check(
            5'd20, 32'hA0000004,
            "x20 after rapid writes (last value)"
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

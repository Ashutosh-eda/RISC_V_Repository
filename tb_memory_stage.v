// ============================================================================
// Testbench for Memory Stage
// Tests load/store operations with different sizes (byte, halfword, word)
// Verifies sign extension, alignment, and byte enables
// Self-checking with comprehensive test cases
// ============================================================================

`timescale 1ns / 1ps

module tb_memory_stage;

    // ========================================================================
    // Clock and Reset
    // ========================================================================

    reg clk;
    reg rst_n;

    // ========================================================================
    // DUT Signals
    // ========================================================================

    reg  [31:0] alu_result_mem;
    reg  [31:0] rs2_data_mem;
    reg  [2:0]  funct3_mem;
    reg         mem_read_mem;
    reg         mem_write_mem;

    wire [31:0] dmem_addr;
    wire [31:0] dmem_wdata;
    reg  [31:0] dmem_rdata;
    wire        dmem_we;
    wire [3:0]  dmem_be;
    wire        dmem_req;
    wire [31:0] mem_rdata;

    // ========================================================================
    // DUT Instantiation
    // ========================================================================

    memory_stage dut (
        .clk(clk),
        .rst_n(rst_n),
        .alu_result_mem(alu_result_mem),
        .rs2_data_mem(rs2_data_mem),
        .funct3_mem(funct3_mem),
        .mem_read_mem(mem_read_mem),
        .mem_write_mem(mem_write_mem),
        .dmem_addr(dmem_addr),
        .dmem_wdata(dmem_wdata),
        .dmem_rdata(dmem_rdata),
        .dmem_we(dmem_we),
        .dmem_be(dmem_be),
        .dmem_req(dmem_req),
        .mem_rdata(mem_rdata)
    );

    // ========================================================================
    // Function Codes
    // ========================================================================

    localparam FUNCT3_LB  = 3'b000;  // Load Byte
    localparam FUNCT3_LH  = 3'b001;  // Load Halfword
    localparam FUNCT3_LW  = 3'b010;  // Load Word
    localparam FUNCT3_LBU = 3'b100;  // Load Byte Unsigned
    localparam FUNCT3_LHU = 3'b101;  // Load Halfword Unsigned
    localparam FUNCT3_SB  = 3'b000;  // Store Byte
    localparam FUNCT3_SH  = 3'b001;  // Store Halfword
    localparam FUNCT3_SW  = 3'b010;  // Store Word

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

    task check_store;
        input [31:0] test_addr;
        input [31:0] test_data;
        input [2:0]  test_funct3;
        input [31:0] exp_wdata;
        input [3:0]  exp_be;
        input [200:0] description;
        begin
            test_count = test_count + 1;

            alu_result_mem = test_addr;
            rs2_data_mem = test_data;
            funct3_mem = test_funct3;
            mem_read_mem = 1'b0;
            mem_write_mem = 1'b1;

            #10;

            if (dmem_wdata === exp_wdata && dmem_be === exp_be &&
                dmem_addr === test_addr && dmem_we === 1'b1 && dmem_req === 1'b1) begin
                $display("[PASS] Test %0d: %s", test_count, description);
                $display("       addr=0x%h, wdata=0x%h, be=%b",
                         dmem_addr, dmem_wdata, dmem_be);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] Test %0d: %s", test_count, description);
                $display("       Expected: wdata=0x%h, be=%b", exp_wdata, exp_be);
                $display("       Got:      wdata=0x%h, be=%b", dmem_wdata, dmem_be);
                fail_count = fail_count + 1;
            end
        end
    endtask

    task check_load;
        input [31:0] test_addr;
        input [31:0] test_rdata;
        input [2:0]  test_funct3;
        input [31:0] exp_mem_rdata;
        input [200:0] description;
        begin
            test_count = test_count + 1;

            alu_result_mem = test_addr;
            dmem_rdata = test_rdata;
            funct3_mem = test_funct3;
            mem_read_mem = 1'b1;
            mem_write_mem = 1'b0;

            #10;

            if (mem_rdata === exp_mem_rdata && dmem_addr === test_addr &&
                dmem_we === 1'b0 && dmem_req === 1'b1) begin
                $display("[PASS] Test %0d: %s", test_count, description);
                $display("       addr=0x%h, rdata=0x%h", dmem_addr, mem_rdata);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] Test %0d: %s", test_count, description);
                $display("       Expected: rdata=0x%h", exp_mem_rdata);
                $display("       Got:      rdata=0x%h", mem_rdata);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // ========================================================================
    // Test Stimulus
    // ========================================================================

    initial begin
        $display("\n========================================");
        $display("Memory Stage Testbench");
        $display("========================================\n");

        // Initialize
        rst_n = 0;
        alu_result_mem = 32'd0;
        rs2_data_mem = 32'd0;
        funct3_mem = 3'd0;
        mem_read_mem = 1'b0;
        mem_write_mem = 1'b0;
        dmem_rdata = 32'd0;

        repeat(3) @(posedge clk);
        rst_n = 1;
        @(posedge clk);

        // ====================================================================
        // Test Category 1: Store Word (SW)
        // ====================================================================
        $display("\n--- Test Category 1: Store Word (SW) ---");

        check_store(
            32'h00001000, 32'hDEADBEEF, FUNCT3_SW,
            32'hDEADBEEF, 4'b1111,
            "SW: Store word at aligned address"
        );

        check_store(
            32'h00002004, 32'h12345678, FUNCT3_SW,
            32'h12345678, 4'b1111,
            "SW: Store different word"
        );

        check_store(
            32'h00003000, 32'hFFFFFFFF, FUNCT3_SW,
            32'hFFFFFFFF, 4'b1111,
            "SW: Store all 1s"
        );

        check_store(
            32'h00004000, 32'h00000000, FUNCT3_SW,
            32'h00000000, 4'b1111,
            "SW: Store all 0s"
        );

        // ====================================================================
        // Test Category 2: Store Halfword (SH)
        // ====================================================================
        $display("\n--- Test Category 2: Store Halfword (SH) ---");

        check_store(
            32'h00001000, 32'h0000ABCD, FUNCT3_SH,
            32'h0000ABCD, 4'b0011,
            "SH: Store halfword at offset 0"
        );

        check_store(
            32'h00001002, 32'h00001234, FUNCT3_SH,
            32'h12340000, 4'b1100,
            "SH: Store halfword at offset 2"
        );

        check_store(
            32'h00002000, 32'hFFFFFFFF, FUNCT3_SH,
            32'h0000FFFF, 4'b0011,
            "SH: Store halfword (all 1s in lower 16)"
        );

        check_store(
            32'h00002002, 32'h00005678, FUNCT3_SH,
            32'h56780000, 4'b1100,
            "SH: Store halfword at offset 2 (different data)"
        );

        // ====================================================================
        // Test Category 3: Store Byte (SB)
        // ====================================================================
        $display("\n--- Test Category 3: Store Byte (SB) ---");

        check_store(
            32'h00001000, 32'h000000AB, FUNCT3_SB,
            32'h000000AB, 4'b0001,
            "SB: Store byte at offset 0"
        );

        check_store(
            32'h00001001, 32'h000000CD, FUNCT3_SB,
            32'h0000CD00, 4'b0010,
            "SB: Store byte at offset 1"
        );

        check_store(
            32'h00001002, 32'h000000EF, FUNCT3_SB,
            32'h00EF0000, 4'b0100,
            "SB: Store byte at offset 2"
        );

        check_store(
            32'h00001003, 32'h00000012, FUNCT3_SB,
            32'h12000000, 4'b1000,
            "SB: Store byte at offset 3"
        );

        // ====================================================================
        // Test Category 4: Load Word (LW)
        // ====================================================================
        $display("\n--- Test Category 4: Load Word (LW) ---");

        check_load(
            32'h00001000, 32'hDEADBEEF, FUNCT3_LW,
            32'hDEADBEEF,
            "LW: Load word"
        );

        check_load(
            32'h00002000, 32'h12345678, FUNCT3_LW,
            32'h12345678,
            "LW: Load different word"
        );

        check_load(
            32'h00003000, 32'hFFFFFFFF, FUNCT3_LW,
            32'hFFFFFFFF,
            "LW: Load all 1s"
        );

        check_load(
            32'h00004000, 32'h00000000, FUNCT3_LW,
            32'h00000000,
            "LW: Load all 0s"
        );

        // ====================================================================
        // Test Category 5: Load Halfword (LH - Signed)
        // ====================================================================
        $display("\n--- Test Category 5: Load Halfword Signed (LH) ---");

        check_load(
            32'h00001000, 32'h0000ABCD, FUNCT3_LH,
            32'hFFFFABCD,
            "LH: Load halfword offset 0 (negative, sign-extended)"
        );

        check_load(
            32'h00001002, 32'h1234FFFF, FUNCT3_LH,
            32'h00001234,
            "LH: Load halfword offset 2 (positive)"
        );

        check_load(
            32'h00002000, 32'h00007FFF, FUNCT3_LH,
            32'h00007FFF,
            "LH: Load positive halfword (max positive)"
        );

        check_load(
            32'h00002002, 32'hABCD8000, FUNCT3_LH,
            32'hFFFFABCD,
            "LH: Load negative halfword at offset 2"
        );

        // ====================================================================
        // Test Category 6: Load Halfword Unsigned (LHU)
        // ====================================================================
        $display("\n--- Test Category 6: Load Halfword Unsigned (LHU) ---");

        check_load(
            32'h00001000, 32'h0000ABCD, FUNCT3_LHU,
            32'h0000ABCD,
            "LHU: Load halfword offset 0 (zero-extended)"
        );

        check_load(
            32'h00001002, 32'hFFFF0000, FUNCT3_LHU,
            32'h0000FFFF,
            "LHU: Load halfword offset 2 (all 1s, zero-extended)"
        );

        check_load(
            32'h00002000, 32'h00008000, FUNCT3_LHU,
            32'h00008000,
            "LHU: Load 0x8000 (MSB=1, but zero-extended)"
        );

        // ====================================================================
        // Test Category 7: Load Byte (LB - Signed)
        // ====================================================================
        $display("\n--- Test Category 7: Load Byte Signed (LB) ---");

        check_load(
            32'h00001000, 32'h000000FF, FUNCT3_LB,
            32'hFFFFFFFF,
            "LB: Load byte offset 0 (negative, sign-extended)"
        );

        check_load(
            32'h00001001, 32'h000012FF, FUNCT3_LB,
            32'h00000012,
            "LB: Load byte offset 1 (positive)"
        );

        check_load(
            32'h00001002, 32'h0080FFFF, FUNCT3_LB,
            32'hFFFFFF80,
            "LB: Load byte offset 2 (0x80, negative)"
        );

        check_load(
            32'h00001003, 32'h7FFFFFFF, FUNCT3_LB,
            32'h0000007F,
            "LB: Load byte offset 3 (0x7F, positive)"
        );

        // ====================================================================
        // Test Category 8: Load Byte Unsigned (LBU)
        // ====================================================================
        $display("\n--- Test Category 8: Load Byte Unsigned (LBU) ---");

        check_load(
            32'h00001000, 32'h000000FF, FUNCT3_LBU,
            32'h000000FF,
            "LBU: Load byte offset 0 (zero-extended)"
        );

        check_load(
            32'h00001001, 32'h0000AB00, FUNCT3_LBU,
            32'h000000AB,
            "LBU: Load byte offset 1"
        );

        check_load(
            32'h00001002, 32'h00CD0000, FUNCT3_LBU,
            32'h000000CD,
            "LBU: Load byte offset 2"
        );

        check_load(
            32'h00001003, 32'hEF000000, FUNCT3_LBU,
            32'h000000EF,
            "LBU: Load byte offset 3"
        );

        // ====================================================================
        // Test Category 9: No Memory Operation
        // ====================================================================
        $display("\n--- Test Category 9: No Memory Operation ---");

        alu_result_mem = 32'h00001000;
        rs2_data_mem = 32'hDEADBEEF;
        funct3_mem = FUNCT3_SW;
        mem_read_mem = 1'b0;
        mem_write_mem = 1'b0;
        #10;

        test_count = test_count + 1;
        if (dmem_we === 1'b0 && dmem_req === 1'b0 && mem_rdata === 32'd0) begin
            $display("[PASS] Test %0d: No operation (we=0, req=0, rdata=0)",
                     test_count);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Test %0d: Expected no memory operation", test_count);
            fail_count = fail_count + 1;
        end

        // ====================================================================
        // Test Category 10: Sign Extension Edge Cases
        // ====================================================================
        $display("\n--- Test Category 10: Sign Extension Edge Cases ---");

        check_load(
            32'h00001000, 32'h00000080, FUNCT3_LB,
            32'hFFFFFF80,
            "LB: 0x80 → sign-extended to 0xFFFFFF80"
        );

        check_load(
            32'h00001000, 32'h0000007F, FUNCT3_LB,
            32'h0000007F,
            "LB: 0x7F → zero-extended (positive)"
        );

        check_load(
            32'h00001000, 32'h00008000, FUNCT3_LH,
            32'hFFFF8000,
            "LH: 0x8000 → sign-extended to 0xFFFF8000"
        );

        check_load(
            32'h00001000, 32'h00007FFF, FUNCT3_LH,
            32'h00007FFF,
            "LH: 0x7FFF → zero-extended (positive)"
        );

        // ====================================================================
        // Test Category 11: Realistic Scenarios
        // ====================================================================
        $display("\n--- Test Category 11: Realistic Scenarios ---");

        // Store then load pattern
        check_store(
            32'h00005000, 32'hCAFEBABE, FUNCT3_SW,
            32'hCAFEBABE, 4'b1111,
            "Realistic: Store 0xCAFEBABE"
        );

        check_load(
            32'h00005000, 32'hCAFEBABE, FUNCT3_LW,
            32'hCAFEBABE,
            "Realistic: Load back 0xCAFEBABE"
        );

        // Byte operations
        check_store(
            32'h00006000, 32'h000000FF, FUNCT3_SB,
            32'h000000FF, 4'b0001,
            "Realistic: Store byte 0xFF"
        );

        check_load(
            32'h00006000, 32'h000000FF, FUNCT3_LBU,
            32'h000000FF,
            "Realistic: Load byte unsigned"
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

// ============================================================================
// Testbench for EX/MEM Pipeline Register
// Tests execution results and control signal propagation
// Verifies proper data storage for memory stage
// Self-checking with comprehensive test cases
// ============================================================================

`timescale 1ns / 1ps

module tb_ex_mem_reg;

    // ========================================================================
    // Clock and Reset
    // ========================================================================

    reg clk;
    reg rst_n;

    // ========================================================================
    // DUT Signals
    // ========================================================================

    // Data inputs
    reg [31:0] alu_result_ex;
    reg [31:0] rs2_data_ex;
    reg [31:0] fpu_result_ex;
    reg [4:0]  rd_ex;
    reg [2:0]  funct3_ex;

    // Control inputs
    reg        reg_write_ex;
    reg        mem_read_ex;
    reg        mem_write_ex;
    reg        mem_to_reg_ex;
    reg        fp_op_ex;
    reg        fp_reg_write_ex;

    // Data outputs
    wire [31:0] alu_result_mem;
    wire [31:0] rs2_data_mem;
    wire [31:0] fpu_result_mem;
    wire [4:0]  rd_mem;
    wire [2:0]  funct3_mem;

    // Control outputs
    wire        reg_write_mem;
    wire        mem_read_mem;
    wire        mem_write_mem;
    wire        mem_to_reg_mem;
    wire        fp_op_mem;
    wire        fp_reg_write_mem;

    // ========================================================================
    // DUT Instantiation
    // ========================================================================

    ex_mem_reg dut (
        .clk(clk),
        .rst_n(rst_n),
        .alu_result_ex(alu_result_ex),
        .rs2_data_ex(rs2_data_ex),
        .fpu_result_ex(fpu_result_ex),
        .rd_ex(rd_ex),
        .funct3_ex(funct3_ex),
        .reg_write_ex(reg_write_ex),
        .mem_read_ex(mem_read_ex),
        .mem_write_ex(mem_write_ex),
        .mem_to_reg_ex(mem_to_reg_ex),
        .fp_op_ex(fp_op_ex),
        .fp_reg_write_ex(fp_reg_write_ex),
        .alu_result_mem(alu_result_mem),
        .rs2_data_mem(rs2_data_mem),
        .fpu_result_mem(fpu_result_mem),
        .rd_mem(rd_mem),
        .funct3_mem(funct3_mem),
        .reg_write_mem(reg_write_mem),
        .mem_read_mem(mem_read_mem),
        .mem_write_mem(mem_write_mem),
        .mem_to_reg_mem(mem_to_reg_mem),
        .fp_op_mem(fp_op_mem),
        .fp_reg_write_mem(fp_reg_write_mem)
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

    task reset_inputs;
        begin
            alu_result_ex = 32'd0;
            rs2_data_ex = 32'd0;
            fpu_result_ex = 32'd0;
            rd_ex = 5'd0;
            funct3_ex = 3'd0;
            reg_write_ex = 1'b0;
            mem_read_ex = 1'b0;
            mem_write_ex = 1'b0;
            mem_to_reg_ex = 1'b0;
            fp_op_ex = 1'b0;
            fp_reg_write_ex = 1'b0;
        end
    endtask

    task check_all_zero;
        input [200:0] description;
        begin
            test_count = test_count + 1;
            #1;

            if (alu_result_mem === 32'd0 && rs2_data_mem === 32'd0 &&
                fpu_result_mem === 32'd0 && rd_mem === 5'd0 &&
                funct3_mem === 3'd0 && reg_write_mem === 1'b0 &&
                mem_read_mem === 1'b0 && mem_write_mem === 1'b0 &&
                mem_to_reg_mem === 1'b0 && fp_op_mem === 1'b0 &&
                fp_reg_write_mem === 1'b0) begin
                $display("[PASS] Test %0d: %s", test_count, description);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] Test %0d: %s", test_count, description);
                $display("       Some outputs are not zero");
                fail_count = fail_count + 1;
            end
        end
    endtask

    task check_propagation;
        input [200:0] description;
        begin
            test_count = test_count + 1;
            #1;

            if (alu_result_mem === alu_result_ex && rs2_data_mem === rs2_data_ex &&
                fpu_result_mem === fpu_result_ex && rd_mem === rd_ex &&
                funct3_mem === funct3_ex && reg_write_mem === reg_write_ex &&
                mem_read_mem === mem_read_ex && mem_write_mem === mem_write_ex &&
                mem_to_reg_mem === mem_to_reg_ex && fp_op_mem === fp_op_ex &&
                fp_reg_write_mem === fp_reg_write_ex) begin
                $display("[PASS] Test %0d: %s", test_count, description);
                $display("       ALU=0x%h, rs2=0x%h, rd=%0d",
                         alu_result_mem, rs2_data_mem, rd_mem);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] Test %0d: %s", test_count, description);
                $display("       Some signals did not propagate correctly");
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
        $display("EX/MEM Pipeline Register Testbench");
        $display("========================================\n");

        // Initialize
        rst_n = 0;
        reset_inputs();

        repeat(3) @(posedge clk);
        rst_n = 1;
        @(posedge clk);

        // ====================================================================
        // Test Category 1: Reset Behavior
        // ====================================================================
        $display("\n--- Test Category 1: Reset Behavior ---");

        check_all_zero("Reset: All outputs are zero");

        // ====================================================================
        // Test Category 2: ALU Result Propagation
        // ====================================================================
        $display("\n--- Test Category 2: ALU Result Propagation ---");

        alu_result_ex = 32'h12345678;
        rd_ex = 5'd10;
        reg_write_ex = 1'b1;
        wait_cycle();
        check_propagation("ADD result (address calculation)");

        alu_result_ex = 32'hABCDEF01;
        rd_ex = 5'd15;
        wait_cycle();
        check_propagation("SUB result");

        alu_result_ex = 32'hFFFFFFFF;
        rd_ex = 5'd20;
        wait_cycle();
        check_propagation("All 1s result");

        alu_result_ex = 32'h00000000;
        rd_ex = 5'd0;
        wait_cycle();
        check_propagation("Zero result");

        // ====================================================================
        // Test Category 3: Load Instruction (Memory Read)
        // ====================================================================
        $display("\n--- Test Category 3: Load Instruction ---");

        reset_inputs();
        alu_result_ex = 32'h00010000;  // Load address
        rd_ex = 5'd8;
        funct3_ex = 3'b010;  // LW
        reg_write_ex = 1'b1;
        mem_read_ex = 1'b1;
        mem_to_reg_ex = 1'b1;
        wait_cycle();
        check_propagation("Load word (LW) - address ready");

        alu_result_ex = 32'h00020004;
        funct3_ex = 3'b001;  // LH
        wait_cycle();
        check_propagation("Load halfword (LH)");

        alu_result_ex = 32'h00030008;
        funct3_ex = 3'b000;  // LB
        wait_cycle();
        check_propagation("Load byte (LB)");

        alu_result_ex = 32'h0004000C;
        funct3_ex = 3'b101;  // LHU
        wait_cycle();
        check_propagation("Load halfword unsigned (LHU)");

        alu_result_ex = 32'h00050010;
        funct3_ex = 3'b100;  // LBU
        wait_cycle();
        check_propagation("Load byte unsigned (LBU)");

        // ====================================================================
        // Test Category 4: Store Instruction (Memory Write)
        // ====================================================================
        $display("\n--- Test Category 4: Store Instruction ---");

        reset_inputs();
        alu_result_ex = 32'h00020000;  // Store address
        rs2_data_ex = 32'hDEADBEEF;    // Data to store
        funct3_ex = 3'b010;  // SW
        mem_write_ex = 1'b1;
        wait_cycle();
        check_propagation("Store word (SW) - addr and data ready");

        alu_result_ex = 32'h00030004;
        rs2_data_ex = 32'h0000CAFE;
        funct3_ex = 3'b001;  // SH
        wait_cycle();
        check_propagation("Store halfword (SH)");

        alu_result_ex = 32'h00040008;
        rs2_data_ex = 32'h000000AB;
        funct3_ex = 3'b000;  // SB
        wait_cycle();
        check_propagation("Store byte (SB)");

        // ====================================================================
        // Test Category 5: FPU Result Propagation
        // ====================================================================
        $display("\n--- Test Category 5: FPU Result Propagation ---");

        reset_inputs();
        fpu_result_ex = 32'h3F800000;  // 1.0
        rd_ex = 5'd11;
        reg_write_ex = 1'b1;
        fp_op_ex = 1'b1;
        fp_reg_write_ex = 1'b1;
        wait_cycle();
        check_propagation("FPU result = 1.0");

        fpu_result_ex = 32'h40000000;  // 2.0
        rd_ex = 5'd12;
        wait_cycle();
        check_propagation("FPU result = 2.0");

        fpu_result_ex = 32'h7F800000;  // +Infinity
        rd_ex = 5'd13;
        wait_cycle();
        check_propagation("FPU result = +Inf");

        fpu_result_ex = 32'h00000000;  // +0.0
        rd_ex = 5'd14;
        wait_cycle();
        check_propagation("FPU result = +0.0");

        // ====================================================================
        // Test Category 6: Combined ALU and FPU Results
        // ====================================================================
        $display("\n--- Test Category 6: Combined ALU and FPU ---");

        reset_inputs();
        alu_result_ex = 32'h12340000;
        fpu_result_ex = 32'h3F000000;  // 0.5
        rd_ex = 5'd16;
        reg_write_ex = 1'b1;
        fp_op_ex = 1'b1;
        fp_reg_write_ex = 1'b1;
        wait_cycle();
        check_propagation("Both ALU and FPU results");

        // ====================================================================
        // Test Category 7: Store with FPU Data
        // ====================================================================
        $display("\n--- Test Category 7: FP Store Instruction ---");

        reset_inputs();
        alu_result_ex = 32'h00060000;  // Store address
        rs2_data_ex = 32'h40400000;    // FP data (3.0)
        funct3_ex = 3'b010;  // FSW (store word)
        mem_write_ex = 1'b1;
        wait_cycle();
        check_propagation("FP store word (FSW)");

        // ====================================================================
        // Test Category 8: All Control Signals Asserted
        // ====================================================================
        $display("\n--- Test Category 8: Maximum Control ---");

        reset_inputs();
        alu_result_ex = 32'hAAAAAAAA;
        rs2_data_ex = 32'hBBBBBBBB;
        fpu_result_ex = 32'hCCCCCCCC;
        rd_ex = 5'd31;
        funct3_ex = 3'b111;
        reg_write_ex = 1'b1;
        mem_read_ex = 1'b1;
        mem_write_ex = 1'b1;
        mem_to_reg_ex = 1'b1;
        fp_op_ex = 1'b1;
        fp_reg_write_ex = 1'b1;
        wait_cycle();
        check_propagation("All control signals asserted");

        // ====================================================================
        // Test Category 9: Reset During Operation
        // ====================================================================
        $display("\n--- Test Category 9: Reset During Operation ---");

        reset_inputs();
        alu_result_ex = 32'hFFFF0000;
        rs2_data_ex = 32'h0000FFFF;
        reg_write_ex = 1'b1;
        wait_cycle();

        rst_n = 0;
        @(posedge clk);
        check_all_zero("During reset: All cleared");

        rst_n = 1;
        @(posedge clk);
        check_all_zero("After reset release: Still cleared");

        alu_result_ex = 32'hDEADBEEF;
        wait_cycle();
        check_propagation("After reset: Normal operation");

        // ====================================================================
        // Test Category 10: Edge Cases
        // ====================================================================
        $display("\n--- Test Category 10: Edge Cases ---");

        reset_inputs();
        alu_result_ex = 32'h80000000;  // Sign bit set
        rs2_data_ex = 32'h7FFFFFFF;    // Max positive
        rd_ex = 5'd0;  // x0 register
        wait_cycle();
        check_propagation("Edge: Sign bit set, rd=x0");

        alu_result_ex = 32'hFFFFFFFC;  // Address near max
        funct3_ex = 3'b010;
        mem_read_ex = 1'b1;
        rd_ex = 5'd31;  // x31 register
        wait_cycle();
        check_propagation("Edge: Max address, rd=x31");

        // ====================================================================
        // Test Category 11: Data Pattern Tests
        // ====================================================================
        $display("\n--- Test Category 11: Data Patterns ---");

        reset_inputs();
        alu_result_ex = 32'hA5A5A5A5;
        rs2_data_ex = 32'h5A5A5A5A;
        fpu_result_ex = 32'hF0F0F0F0;
        wait_cycle();
        check_propagation("Pattern: Alternating bits");

        alu_result_ex = 32'h00FF00FF;
        rs2_data_ex = 32'hFF00FF00;
        fpu_result_ex = 32'h0F0F0F0F;
        wait_cycle();
        check_propagation("Pattern: Byte patterns");

        // ====================================================================
        // Test Category 12: Sequential Operations
        // ====================================================================
        $display("\n--- Test Category 12: Sequential Operations ---");

        integer i;
        for (i = 0; i < 5; i = i + 1) begin
            reset_inputs();
            alu_result_ex = 32'h10000000 + (i * 16);
            rs2_data_ex = 32'h20000000 + i;
            fpu_result_ex = 32'h30000000 + i;
            rd_ex = 5'd8 + i;
            funct3_ex = i[2:0];
            reg_write_ex = 1'b1;
            wait_cycle();

            test_count = test_count + 1;
            if (alu_result_mem === (32'h10000000 + (i * 16)) &&
                rs2_data_mem === (32'h20000000 + i) &&
                fpu_result_mem === (32'h30000000 + i) &&
                rd_mem === (5'd8 + i) &&
                funct3_mem === i[2:0]) begin
                $display("[PASS] Test %0d: Sequential [%0d] ALU=0x%h",
                         test_count, i, alu_result_mem);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] Test %0d: Sequential [%0d]", test_count, i);
                fail_count = fail_count + 1;
            end
        end

        // ====================================================================
        // Test Category 13: Realistic Memory Operations
        // ====================================================================
        $display("\n--- Test Category 13: Realistic Scenarios ---");

        // Load from array
        reset_inputs();
        alu_result_ex = 32'h00100000;  // Base + offset
        rd_ex = 5'd5;
        funct3_ex = 3'b010;  // LW
        reg_write_ex = 1'b1;
        mem_read_ex = 1'b1;
        mem_to_reg_ex = 1'b1;
        wait_cycle();
        check_propagation("Realistic: Array load");

        // Store to array
        reset_inputs();
        alu_result_ex = 32'h00100004;  // Next element
        rs2_data_ex = 32'h00000042;    // Value to store
        funct3_ex = 3'b010;  // SW
        mem_write_ex = 1'b1;
        wait_cycle();
        check_propagation("Realistic: Array store");

        // FP computation result
        reset_inputs();
        fpu_result_ex = 32'h40490FDB;  // Pi
        rd_ex = 5'd10;
        reg_write_ex = 1'b1;
        fp_op_ex = 1'b1;
        fp_reg_write_ex = 1'b1;
        wait_cycle();
        check_propagation("Realistic: FP result (Pi)");

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

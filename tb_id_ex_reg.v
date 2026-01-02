// ============================================================================
// Testbench for ID/EX Pipeline Register
// Tests decode data and control signal propagation
// Verifies flush operation and proper signal zeroing
// Self-checking with comprehensive test cases
// ============================================================================

`timescale 1ns / 1ps

module tb_id_ex_reg;

    // ========================================================================
    // Clock and Reset
    // ========================================================================

    reg clk;
    reg rst_n;

    // ========================================================================
    // DUT Signals
    // ========================================================================

    reg        flush;

    // Data inputs
    reg [31:0] pc_id;
    reg [31:0] rs1_data_id;
    reg [31:0] rs2_data_id;
    reg [31:0] imm_id;
    reg [4:0]  rd_id;
    reg [4:0]  rs1_id;
    reg [4:0]  rs2_id;
    reg [2:0]  funct3_id;
    reg [6:0]  funct7_id;

    // FPU data inputs
    reg [31:0] fp_rs1_data_id;
    reg [31:0] fp_rs2_data_id;
    reg [31:0] fp_rs3_data_id;
    reg [4:0]  fp_rs3_id;

    // Control inputs
    reg        reg_write_id;
    reg        mem_read_id;
    reg        mem_write_id;
    reg        mem_to_reg_id;
    reg        alu_src_id;
    reg        branch_id;
    reg        jump_id;
    reg [3:0]  alu_op_id;
    reg        fp_op_id;
    reg        fft_op_id;
    reg        fp_reg_write_id;
    reg        fma_op_id;

    // Data outputs
    wire [31:0] pc_ex;
    wire [31:0] rs1_data_ex;
    wire [31:0] rs2_data_ex;
    wire [31:0] imm_ex;
    wire [4:0]  rd_ex;
    wire [4:0]  rs1_ex;
    wire [4:0]  rs2_ex;
    wire [2:0]  funct3_ex;
    wire [6:0]  funct7_ex;

    wire [31:0] fp_rs1_data_ex;
    wire [31:0] fp_rs2_data_ex;
    wire [31:0] fp_rs3_data_ex;
    wire [4:0]  fp_rs3_ex;

    // Control outputs
    wire        reg_write_ex;
    wire        mem_read_ex;
    wire        mem_write_ex;
    wire        mem_to_reg_ex;
    wire        alu_src_ex;
    wire        branch_ex;
    wire        jump_ex;
    wire [3:0]  alu_op_ex;
    wire        fp_op_ex;
    wire        fft_op_ex;
    wire        fp_reg_write_ex;
    wire        fma_op_ex;

    // ========================================================================
    // DUT Instantiation
    // ========================================================================

    id_ex_reg dut (
        .clk(clk),
        .rst_n(rst_n),
        .flush(flush),
        .pc_id(pc_id),
        .rs1_data_id(rs1_data_id),
        .rs2_data_id(rs2_data_id),
        .imm_id(imm_id),
        .rd_id(rd_id),
        .rs1_id(rs1_id),
        .rs2_id(rs2_id),
        .funct3_id(funct3_id),
        .funct7_id(funct7_id),
        .fp_rs1_data_id(fp_rs1_data_id),
        .fp_rs2_data_id(fp_rs2_data_id),
        .fp_rs3_data_id(fp_rs3_data_id),
        .fp_rs3_id(fp_rs3_id),
        .reg_write_id(reg_write_id),
        .mem_read_id(mem_read_id),
        .mem_write_id(mem_write_id),
        .mem_to_reg_id(mem_to_reg_id),
        .alu_src_id(alu_src_id),
        .branch_id(branch_id),
        .jump_id(jump_id),
        .alu_op_id(alu_op_id),
        .fp_op_id(fp_op_id),
        .fft_op_id(fft_op_id),
        .fp_reg_write_id(fp_reg_write_id),
        .fma_op_id(fma_op_id),
        .pc_ex(pc_ex),
        .rs1_data_ex(rs1_data_ex),
        .rs2_data_ex(rs2_data_ex),
        .imm_ex(imm_ex),
        .rd_ex(rd_ex),
        .rs1_ex(rs1_ex),
        .rs2_ex(rs2_ex),
        .funct3_ex(funct3_ex),
        .funct7_ex(funct7_ex),
        .fp_rs1_data_ex(fp_rs1_data_ex),
        .fp_rs2_data_ex(fp_rs2_data_ex),
        .fp_rs3_data_ex(fp_rs3_data_ex),
        .fp_rs3_ex(fp_rs3_ex),
        .reg_write_ex(reg_write_ex),
        .mem_read_ex(mem_read_ex),
        .mem_write_ex(mem_write_ex),
        .mem_to_reg_ex(mem_to_reg_ex),
        .alu_src_ex(alu_src_ex),
        .branch_ex(branch_ex),
        .jump_ex(jump_ex),
        .alu_op_ex(alu_op_ex),
        .fp_op_ex(fp_op_ex),
        .fft_op_ex(fft_op_ex),
        .fp_reg_write_ex(fp_reg_write_ex),
        .fma_op_ex(fma_op_ex)
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
            flush = 0;
            pc_id = 32'd0;
            rs1_data_id = 32'd0;
            rs2_data_id = 32'd0;
            imm_id = 32'd0;
            rd_id = 5'd0;
            rs1_id = 5'd0;
            rs2_id = 5'd0;
            funct3_id = 3'd0;
            funct7_id = 7'd0;
            fp_rs1_data_id = 32'd0;
            fp_rs2_data_id = 32'd0;
            fp_rs3_data_id = 32'd0;
            fp_rs3_id = 5'd0;
            reg_write_id = 1'b0;
            mem_read_id = 1'b0;
            mem_write_id = 1'b0;
            mem_to_reg_id = 1'b0;
            alu_src_id = 1'b0;
            branch_id = 1'b0;
            jump_id = 1'b0;
            alu_op_id = 4'd0;
            fp_op_id = 1'b0;
            fft_op_id = 1'b0;
            fp_reg_write_id = 1'b0;
            fma_op_id = 1'b0;
        end
    endtask

    task check_all_zero;
        input [200:0] description;
        begin
            test_count = test_count + 1;
            #1;

            if (pc_ex === 32'd0 && rs1_data_ex === 32'd0 && rs2_data_ex === 32'd0 &&
                imm_ex === 32'd0 && rd_ex === 5'd0 && rs1_ex === 5'd0 && rs2_ex === 5'd0 &&
                funct3_ex === 3'd0 && funct7_ex === 7'd0 &&
                fp_rs1_data_ex === 32'd0 && fp_rs2_data_ex === 32'd0 &&
                fp_rs3_data_ex === 32'd0 && fp_rs3_ex === 5'd0 &&
                reg_write_ex === 1'b0 && mem_read_ex === 1'b0 && mem_write_ex === 1'b0 &&
                mem_to_reg_ex === 1'b0 && alu_src_ex === 1'b0 && branch_ex === 1'b0 &&
                jump_ex === 1'b0 && alu_op_ex === 4'd0 && fp_op_ex === 1'b0 &&
                fft_op_ex === 1'b0 && fp_reg_write_ex === 1'b0 && fma_op_ex === 1'b0) begin
                $display("[PASS] Test %0d: %s", test_count, description);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] Test %0d: %s", test_count, description);
                $display("       Some outputs are not zero");
                fail_count = fail_count + 1;
            end
        end
    endtask

    task check_data_propagation;
        input [200:0] description;
        begin
            test_count = test_count + 1;
            #1;

            if (pc_ex === pc_id && rs1_data_ex === rs1_data_id && rs2_data_ex === rs2_data_id &&
                imm_ex === imm_id && rd_ex === rd_id && rs1_ex === rs1_id && rs2_ex === rs2_id &&
                funct3_ex === funct3_id && funct7_ex === funct7_id &&
                fp_rs1_data_ex === fp_rs1_data_id && fp_rs2_data_ex === fp_rs2_data_id &&
                fp_rs3_data_ex === fp_rs3_data_id && fp_rs3_ex === fp_rs3_id &&
                reg_write_ex === reg_write_id && mem_read_ex === mem_read_id &&
                mem_write_ex === mem_write_id && mem_to_reg_ex === mem_to_reg_id &&
                alu_src_ex === alu_src_id && branch_ex === branch_id && jump_ex === jump_id &&
                alu_op_ex === alu_op_id && fp_op_ex === fp_op_id && fft_op_ex === fft_op_id &&
                fp_reg_write_ex === fp_reg_write_id && fma_op_ex === fma_op_id) begin
                $display("[PASS] Test %0d: %s", test_count, description);
                $display("       All signals propagated correctly");
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
        $display("ID/EX Pipeline Register Testbench");
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
        // Test Category 2: Integer ALU Instruction Propagation
        // ====================================================================
        $display("\n--- Test Category 2: Integer ALU Propagation ---");

        pc_id = 32'h00001000;
        rs1_data_id = 32'h12345678;
        rs2_data_id = 32'hABCDEF01;
        imm_id = 32'h00000020;
        rd_id = 5'd10;
        rs1_id = 5'd5;
        rs2_id = 5'd6;
        funct3_id = 3'b000;  // ADD funct3
        funct7_id = 7'b0000000;
        reg_write_id = 1'b1;
        alu_src_id = 1'b0;  // Use rs2
        alu_op_id = 4'b0000;  // ADD

        wait_cycle();
        check_data_propagation("Integer ADD instruction");

        // ====================================================================
        // Test Category 3: Load Instruction Propagation
        // ====================================================================
        $display("\n--- Test Category 3: Load Instruction ---");

        reset_inputs();
        pc_id = 32'h00002000;
        rs1_data_id = 32'h00010000;  // Base address
        imm_id = 32'h00000010;       // Offset
        rd_id = 5'd8;
        rs1_id = 5'd3;
        funct3_id = 3'b010;  // LW
        reg_write_id = 1'b1;
        mem_read_id = 1'b1;
        mem_to_reg_id = 1'b1;
        alu_src_id = 1'b1;   // Use immediate
        alu_op_id = 4'b0000;  // ADD for address calculation

        wait_cycle();
        check_data_propagation("Load word (LW) instruction");

        // ====================================================================
        // Test Category 4: Store Instruction Propagation
        // ====================================================================
        $display("\n--- Test Category 4: Store Instruction ---");

        reset_inputs();
        pc_id = 32'h00003000;
        rs1_data_id = 32'h00020000;  // Base address
        rs2_data_id = 32'hDEADBEEF;  // Data to store
        imm_id = 32'h00000008;       // Offset
        rs1_id = 5'd4;
        rs2_id = 5'd7;
        funct3_id = 3'b010;  // SW
        mem_write_id = 1'b1;
        alu_src_id = 1'b1;   // Use immediate
        alu_op_id = 4'b0000;  // ADD

        wait_cycle();
        check_data_propagation("Store word (SW) instruction");

        // ====================================================================
        // Test Category 5: Branch Instruction Propagation
        // ====================================================================
        $display("\n--- Test Category 5: Branch Instruction ---");

        reset_inputs();
        pc_id = 32'h00004000;
        rs1_data_id = 32'h00000042;
        rs2_data_id = 32'h00000042;
        imm_id = 32'h00000100;  // Branch offset
        rs1_id = 5'd9;
        rs2_id = 5'd10;
        funct3_id = 3'b000;  // BEQ
        branch_id = 1'b1;
        alu_op_id = 4'b0110;  // SUB for comparison

        wait_cycle();
        check_data_propagation("Branch equal (BEQ) instruction");

        // ====================================================================
        // Test Category 6: Jump Instruction Propagation
        // ====================================================================
        $display("\n--- Test Category 6: Jump Instruction ---");

        reset_inputs();
        pc_id = 32'h00005000;
        imm_id = 32'h00001000;  // Jump offset
        rd_id = 5'd1;  // Return address register
        reg_write_id = 1'b1;
        jump_id = 1'b1;

        wait_cycle();
        check_data_propagation("Jump and link (JAL) instruction");

        // ====================================================================
        // Test Category 7: FPU Instruction Propagation
        // ====================================================================
        $display("\n--- Test Category 7: FPU Instruction ---");

        reset_inputs();
        pc_id = 32'h00006000;
        fp_rs1_data_id = 32'h3F800000;  // 1.0
        fp_rs2_data_id = 32'h40000000;  // 2.0
        rd_id = 5'd11;
        funct3_id = 3'b000;
        funct7_id = 7'b0000000;
        fp_op_id = 1'b1;
        fp_reg_write_id = 1'b1;

        wait_cycle();
        check_data_propagation("FPU FADD instruction");

        // ====================================================================
        // Test Category 8: FMA Instruction Propagation (3 operands)
        // ====================================================================
        $display("\n--- Test Category 8: FMA Instruction ---");

        reset_inputs();
        pc_id = 32'h00007000;
        fp_rs1_data_id = 32'h40400000;  // 3.0
        fp_rs2_data_id = 32'h40800000;  // 4.0
        fp_rs3_data_id = 32'h40A00000;  // 5.0
        fp_rs3_id = 5'd12;
        rd_id = 5'd13;
        funct3_id = 3'b000;
        fp_op_id = 1'b1;
        fp_reg_write_id = 1'b1;
        fma_op_id = 1'b1;

        wait_cycle();
        check_data_propagation("FPU FMADD instruction (rs1*rs2+rs3)");

        // ====================================================================
        // Test Category 9: FFT Instruction Propagation
        // ====================================================================
        $display("\n--- Test Category 9: FFT Instruction ---");

        reset_inputs();
        pc_id = 32'h00008000;
        rs1_data_id = 32'h00030000;
        funct3_id = 3'b001;
        fft_op_id = 1'b1;

        wait_cycle();
        check_data_propagation("FFT coprocessor instruction");

        // ====================================================================
        // Test Category 10: Flush Operation (Bubble Insertion)
        // ====================================================================
        $display("\n--- Test Category 10: Flush Operation ---");

        reset_inputs();
        pc_id = 32'h00009000;
        rs1_data_id = 32'hAAAAAAAA;
        rs2_data_id = 32'hBBBBBBBB;
        rd_id = 5'd14;
        reg_write_id = 1'b1;
        mem_write_id = 1'b1;

        wait_cycle();
        check_data_propagation("Before flush: Normal propagation");

        flush = 1;
        pc_id = 32'h0000A000;
        rs1_data_id = 32'hCCCCCCCC;
        wait_cycle();
        flush = 0;

        check_all_zero("During flush: Bubble inserted (all zeros)");

        reset_inputs();
        pc_id = 32'h0000B000;
        rs1_data_id = 32'hDDDDDDDD;
        wait_cycle();
        check_data_propagation("After flush: Normal operation resumes");

        // ====================================================================
        // Test Category 11: Multiple Consecutive Flushes
        // ====================================================================
        $display("\n--- Test Category 11: Consecutive Flushes ---");

        flush = 1;
        wait_cycle();
        check_all_zero("Flush 1: Bubble");

        wait_cycle();
        check_all_zero("Flush 2: Another bubble");

        flush = 0;
        pc_id = 32'h0000C000;
        wait_cycle();
        check_data_propagation("After flushes: Normal operation");

        // ====================================================================
        // Test Category 12: Reset During Operation
        // ====================================================================
        $display("\n--- Test Category 12: Reset During Operation ---");

        reset_inputs();
        pc_id = 32'h0000D000;
        rs1_data_id = 32'hEEEEEEEE;
        reg_write_id = 1'b1;
        wait_cycle();

        rst_n = 0;
        @(posedge clk);
        check_all_zero("During reset: All cleared");

        rst_n = 1;
        @(posedge clk);
        check_all_zero("After reset release: Still cleared");

        pc_id = 32'h0000E000;
        wait_cycle();
        check_data_propagation("After reset: Normal operation");

        // ====================================================================
        // Test Category 13: All Control Signals Asserted
        // ====================================================================
        $display("\n--- Test Category 13: Maximum Control ---");

        reset_inputs();
        pc_id = 32'h0000F000;
        rs1_data_id = 32'hFFFF0000;
        rs2_data_id = 32'h0000FFFF;
        imm_id = 32'hFFFFFFFF;
        rd_id = 5'd31;
        rs1_id = 5'd30;
        rs2_id = 5'd29;
        funct3_id = 3'b111;
        funct7_id = 7'b1111111;
        reg_write_id = 1'b1;
        mem_read_id = 1'b1;
        mem_write_id = 1'b1;
        mem_to_reg_id = 1'b1;
        alu_src_id = 1'b1;
        branch_id = 1'b1;
        jump_id = 1'b1;
        alu_op_id = 4'b1111;
        fp_op_id = 1'b1;
        fft_op_id = 1'b1;
        fp_reg_write_id = 1'b1;
        fma_op_id = 1'b1;

        wait_cycle();
        check_data_propagation("All control signals asserted");

        // ====================================================================
        // Test Category 14: Sequential Instructions
        // ====================================================================
        $display("\n--- Test Category 14: Sequential Instructions ---");

        integer i;
        for (i = 0; i < 4; i = i + 1) begin
            reset_inputs();
            pc_id = 32'h00010000 + (i * 4);
            rs1_data_id = 32'h10000000 + i;
            rs2_data_id = 32'h20000000 + i;
            rd_id = 5'd8 + i;
            reg_write_id = 1'b1;
            wait_cycle();

            test_count = test_count + 1;
            if (pc_ex === (32'h00010000 + (i * 4)) &&
                rs1_data_ex === (32'h10000000 + i) &&
                rs2_data_ex === (32'h20000000 + i) &&
                rd_ex === (5'd8 + i)) begin
                $display("[PASS] Test %0d: Sequential [%0d] pc=0x%h",
                         test_count, i, pc_ex);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] Test %0d: Sequential [%0d]", test_count, i);
                fail_count = fail_count + 1;
            end
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

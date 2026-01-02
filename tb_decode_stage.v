// ============================================================================
// Testbench for Decode Stage
// Tests instruction decoding, immediate generation, and control signals
// Includes integer and FP register file integration
// Self-checking with comprehensive test cases
// ============================================================================

`timescale 1ns / 1ps

module tb_decode_stage;

    // ========================================================================
    // Clock and Reset
    // ========================================================================

    reg clk;
    reg rst_n;

    // ========================================================================
    // DUT Signals
    // ========================================================================

    reg  [31:0] instr;
    reg  [31:0] pc;
    reg  [31:0] wb_data;
    reg  [4:0]  wb_rd;
    reg         wb_reg_write;
    reg         wb_fp_reg_write;

    wire [31:0] rs1_data, rs2_data;
    wire [31:0] fp_rs1_data, fp_rs2_data, fp_rs3_data;
    wire [31:0] imm;
    wire [4:0]  rd, rs1, rs2, rs3;
    wire [2:0]  funct3;
    wire [6:0]  funct7;
    wire        reg_write, mem_read, mem_write, mem_to_reg;
    wire        alu_src, branch, jump;
    wire [3:0]  alu_op;
    wire        fp_op, fft_op, fp_reg_write, fma_op, csr_op;

    // ========================================================================
    // DUT Instantiation
    // ========================================================================

    decode_stage dut (
        .clk(clk), .rst_n(rst_n),
        .instr(instr), .pc(pc),
        .wb_data(wb_data), .wb_rd(wb_rd),
        .wb_reg_write(wb_reg_write),
        .wb_fp_reg_write(wb_fp_reg_write),
        .rs1_data(rs1_data), .rs2_data(rs2_data),
        .fp_rs1_data(fp_rs1_data), .fp_rs2_data(fp_rs2_data),
        .fp_rs3_data(fp_rs3_data),
        .imm(imm), .rd(rd), .rs1(rs1), .rs2(rs2), .rs3(rs3),
        .funct3(funct3), .funct7(funct7),
        .reg_write(reg_write), .mem_read(mem_read),
        .mem_write(mem_write), .mem_to_reg(mem_to_reg),
        .alu_src(alu_src), .branch(branch), .jump(jump),
        .alu_op(alu_op), .fp_op(fp_op), .fft_op(fft_op),
        .fp_reg_write(fp_reg_write), .fma_op(fma_op),
        .csr_op(csr_op)
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

    // ALU opcodes
    localparam ALU_ADD  = 4'b0000;
    localparam ALU_SUB  = 4'b0001;
    localparam ALU_SLL  = 4'b0010;
    localparam ALU_SLT  = 4'b0011;
    localparam ALU_SLTU = 4'b0100;
    localparam ALU_XOR  = 4'b0101;
    localparam ALU_SRL  = 4'b0110;
    localparam ALU_SRA  = 4'b0111;
    localparam ALU_OR   = 4'b1000;
    localparam ALU_AND  = 4'b1001;
    localparam ALU_LUI  = 4'b1010;
    localparam ALU_AUIPC= 4'b1011;

    // ========================================================================
    // Instruction Encoding Helper Functions
    // ========================================================================

    function [31:0] encode_r_type;
        input [6:0] opcode;
        input [4:0] rd_val, rs1_val, rs2_val;
        input [2:0] funct3_val;
        input [6:0] funct7_val;
        begin
            encode_r_type = {funct7_val, rs2_val, rs1_val, funct3_val, rd_val, opcode};
        end
    endfunction

    function [31:0] encode_i_type;
        input [6:0] opcode;
        input [4:0] rd_val, rs1_val;
        input [2:0] funct3_val;
        input [11:0] imm_val;
        begin
            encode_i_type = {imm_val, rs1_val, funct3_val, rd_val, opcode};
        end
    endfunction

    function [31:0] encode_s_type;
        input [6:0] opcode;
        input [4:0] rs1_val, rs2_val;
        input [2:0] funct3_val;
        input [11:0] imm_val;
        begin
            encode_s_type = {imm_val[11:5], rs2_val, rs1_val, funct3_val, imm_val[4:0], opcode};
        end
    endfunction

    function [31:0] encode_b_type;
        input [6:0] opcode;
        input [4:0] rs1_val, rs2_val;
        input [2:0] funct3_val;
        input [12:0] imm_val;
        begin
            encode_b_type = {imm_val[12], imm_val[10:5], rs2_val, rs1_val, funct3_val,
                            imm_val[4:1], imm_val[11], opcode};
        end
    endfunction

    function [31:0] encode_u_type;
        input [6:0] opcode;
        input [4:0] rd_val;
        input [19:0] imm_val;
        begin
            encode_u_type = {imm_val, rd_val, opcode};
        end
    endfunction

    function [31:0] encode_j_type;
        input [6:0] opcode;
        input [4:0] rd_val;
        input [20:0] imm_val;
        begin
            encode_j_type = {imm_val[20], imm_val[10:1], imm_val[11],
                            imm_val[19:12], rd_val, opcode};
        end
    endfunction

    // ========================================================================
    // Test Task
    // ========================================================================

    task check_decode;
        input [31:0] test_instr;
        input [31:0] exp_imm;
        input [3:0]  exp_alu_op;
        input        exp_reg_write, exp_mem_read, exp_mem_write;
        input        exp_mem_to_reg, exp_alu_src, exp_branch, exp_jump;
        input        exp_fp_op, exp_fft_op, exp_fp_reg_write;
        input        exp_fma_op, exp_csr_op;
        input [200:0] description;

        begin
            test_count = test_count + 1;
            instr = test_instr;
            @(posedge clk);
            #1;

            if (imm === exp_imm &&
                alu_op === exp_alu_op &&
                reg_write === exp_reg_write &&
                mem_read === exp_mem_read &&
                mem_write === exp_mem_write &&
                mem_to_reg === exp_mem_to_reg &&
                alu_src === exp_alu_src &&
                branch === exp_branch &&
                jump === exp_jump &&
                fp_op === exp_fp_op &&
                fft_op === exp_fft_op &&
                fp_reg_write === exp_fp_reg_write &&
                fma_op === exp_fma_op &&
                csr_op === exp_csr_op) begin
                $display("[PASS] Test %0d: %s", test_count, description);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] Test %0d: %s", test_count, description);
                $display("  Immediate: Exp=%h Got=%h", exp_imm, imm);
                $display("  ALU_OP: Exp=%h Got=%h", exp_alu_op, alu_op);
                $display("  Control: RW=%b MR=%b MW=%b M2R=%b AS=%b BR=%b J=%b",
                         reg_write, mem_read, mem_write, mem_to_reg, alu_src, branch, jump);
                $display("  FP: FP=%b FFT=%b FPRW=%b FMA=%b CSR=%b",
                         fp_op, fft_op, fp_reg_write, fma_op, csr_op);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // ========================================================================
    // Test Stimulus
    // ========================================================================

    initial begin
        $display("\n========================================");
        $display("Decode Stage Testbench");
        $display("========================================\n");

        // Initialize
        rst_n = 0;
        instr = 32'h00000013;  // NOP (ADDI x0, x0, 0)
        pc = 32'h0;
        wb_data = 32'h0;
        wb_rd = 5'd0;
        wb_reg_write = 1'b0;
        wb_fp_reg_write = 1'b0;

        repeat(3) @(posedge clk);
        rst_n = 1;
        @(posedge clk);

        // ====================================================================
        // Test Category 1: R-Type Instructions (OP)
        // ====================================================================
        $display("\n--- Test Category 1: R-Type Instructions ---");

        // ADD x1, x2, x3
        check_decode(
            encode_r_type(7'b0110011, 5'd1, 5'd2, 5'd3, 3'b000, 7'b0000000),
            32'd0, ALU_ADD,
            1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,  // reg_write=1, others=0
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
            "ADD x1, x2, x3"
        );

        // SUB x5, x6, x7
        check_decode(
            encode_r_type(7'b0110011, 5'd5, 5'd6, 5'd7, 3'b000, 7'b0100000),
            32'd0, ALU_SUB,
            1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
            "SUB x5, x6, x7"
        );

        // XOR x10, x11, x12
        check_decode(
            encode_r_type(7'b0110011, 5'd10, 5'd11, 5'd12, 3'b100, 7'b0000000),
            32'd0, ALU_XOR,
            1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
            "XOR x10, x11, x12"
        );

        // SLL x15, x16, x17
        check_decode(
            encode_r_type(7'b0110011, 5'd15, 5'd16, 5'd17, 3'b001, 7'b0000000),
            32'd0, ALU_SLL,
            1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
            "SLL x15, x16, x17"
        );

        // ====================================================================
        // Test Category 2: I-Type Instructions (OP_IMM)
        // ====================================================================
        $display("\n--- Test Category 2: I-Type ALU Instructions ---");

        // ADDI x1, x2, 100
        check_decode(
            encode_i_type(7'b0010011, 5'd1, 5'd2, 3'b000, 12'd100),
            32'd100, ALU_ADD,
            1'b1, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0,  // alu_src=1
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
            "ADDI x1, x2, 100"
        );

        // ADDI x5, x6, -50 (sign extended)
        check_decode(
            encode_i_type(7'b0010011, 5'd5, 5'd6, 3'b000, 12'hFCE),  // -50 in 12-bit
            32'hFFFFFFCE, ALU_ADD,
            1'b1, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
            "ADDI x5, x6, -50 (sign extend)"
        );

        // SLTI x3, x4, 10
        check_decode(
            encode_i_type(7'b0010011, 5'd3, 5'd4, 3'b010, 12'd10),
            32'd10, ALU_SLT,
            1'b1, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
            "SLTI x3, x4, 10"
        );

        // XORI x7, x8, 255
        check_decode(
            encode_i_type(7'b0010011, 5'd7, 5'd8, 3'b100, 12'd255),
            32'd255, ALU_XOR,
            1'b1, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
            "XORI x7, x8, 255"
        );

        // ====================================================================
        // Test Category 3: Load Instructions
        // ====================================================================
        $display("\n--- Test Category 3: Load Instructions ---");

        // LW x1, 100(x2)
        check_decode(
            encode_i_type(7'b0000011, 5'd1, 5'd2, 3'b010, 12'd100),
            32'd100, ALU_ADD,
            1'b1, 1'b1, 1'b0, 1'b1, 1'b1, 1'b0, 1'b0,  // mem_read=1, mem_to_reg=1
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
            "LW x1, 100(x2)"
        );

        // FLW f3, 200(x4) - FP load
        check_decode(
            encode_i_type(7'b0000111, 5'd3, 5'd4, 3'b010, 12'd200),
            32'd200, ALU_ADD,
            1'b1, 1'b1, 1'b0, 1'b1, 1'b1, 1'b0, 1'b0,
            1'b1, 1'b0, 1'b1, 1'b0, 1'b0,  // fp_op=1, fp_reg_write=1
            "FLW f3, 200(x4)"
        );

        // ====================================================================
        // Test Category 4: Store Instructions
        // ====================================================================
        $display("\n--- Test Category 4: Store Instructions ---");

        // SW x5, 100(x6)
        check_decode(
            encode_s_type(7'b0100011, 5'd6, 5'd5, 3'b010, 12'd100),
            32'd100, ALU_ADD,
            1'b0, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0, 1'b0,  // mem_write=1, reg_write=0
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
            "SW x5, 100(x6)"
        );

        // FSW f7, 200(x8) - FP store
        check_decode(
            encode_s_type(7'b0100111, 5'd8, 5'd7, 3'b010, 12'd200),
            32'd200, ALU_ADD,
            1'b0, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0, 1'b0,
            1'b1, 1'b0, 1'b0, 1'b0, 1'b0,  // fp_op=1
            "FSW f7, 200(x8)"
        );

        // ====================================================================
        // Test Category 5: Branch Instructions
        // ====================================================================
        $display("\n--- Test Category 5: Branch Instructions ---");

        // BEQ x1, x2, offset=16
        check_decode(
            encode_b_type(7'b1100011, 5'd1, 5'd2, 3'b000, 13'd16),
            32'd16, ALU_SUB,
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0,  // branch=1
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
            "BEQ x1, x2, 16"
        );

        // BNE x3, x4, offset=-32 (sign extended)
        check_decode(
            encode_b_type(7'b1100011, 5'd3, 5'd4, 3'b001, 13'h1FE0),  // -32 in 13-bit
            32'hFFFFFFE0, ALU_SUB,
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0,
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
            "BNE x3, x4, -32"
        );

        // BLT x5, x6, offset=100
        check_decode(
            encode_b_type(7'b1100011, 5'd5, 5'd6, 3'b100, 13'd100),
            32'd100, ALU_SUB,
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0,
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
            "BLT x5, x6, 100"
        );

        // ====================================================================
        // Test Category 6: Jump Instructions
        // ====================================================================
        $display("\n--- Test Category 6: Jump Instructions ---");

        // JAL x1, offset=2048
        check_decode(
            encode_j_type(7'b1101111, 5'd1, 21'd2048),
            32'd2048, ALU_ADD,
            1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1,  // jump=1, reg_write=1
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
            "JAL x1, 2048"
        );

        // JALR x3, x4, 100
        check_decode(
            encode_i_type(7'b1100111, 5'd3, 5'd4, 3'b000, 12'd100),
            32'd100, ALU_ADD,
            1'b1, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b1,  // jump=1, alu_src=1
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
            "JALR x3, x4, 100"
        );

        // ====================================================================
        // Test Category 7: U-Type Instructions
        // ====================================================================
        $display("\n--- Test Category 7: U-Type Instructions ---");

        // LUI x5, 0x12345
        check_decode(
            encode_u_type(7'b0110111, 5'd5, 20'h12345),
            32'h12345000, ALU_LUI,
            1'b1, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
            "LUI x5, 0x12345"
        );

        // AUIPC x7, 0xABCDE
        check_decode(
            encode_u_type(7'b0010111, 5'd7, 20'hABCDE),
            32'hABCDE000, ALU_AUIPC,
            1'b1, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
            "AUIPC x7, 0xABCDE"
        );

        // ====================================================================
        // Test Category 8: Floating-Point Instructions
        // ====================================================================
        $display("\n--- Test Category 8: Floating-Point Instructions ---");

        // FADD.S f1, f2, f3
        check_decode(
            encode_r_type(7'b1010011, 5'd1, 5'd2, 5'd3, 3'b000, 7'b0000000),
            32'd0, ALU_ADD,
            1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
            1'b1, 1'b0, 1'b1, 1'b0, 1'b0,  // fp_op=1, fp_reg_write=1
            "FADD.S f1, f2, f3"
        );

        // FMADD.S f5, f6, f7, f8 (FMA operation)
        check_decode(
            {5'd8, 2'b00, 5'd7, 5'd6, 3'b000, 5'd5, 7'b1010011},  // R4-type
            32'd0, ALU_ADD,
            1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
            1'b1, 1'b0, 1'b1, 1'b1, 1'b0,  // fma_op=1
            "FMADD.S f5, f6, f7, f8"
        );

        // ====================================================================
        // Test Category 9: Shift Instructions with funct7
        // ====================================================================
        $display("\n--- Test Category 9: Shift Instructions ---");

        // SLLI x1, x2, 5
        check_decode(
            encode_i_type(7'b0010011, 5'd1, 5'd2, 3'b001, {7'b0000000, 5'd5}),
            {{27{1'b0}}, 5'd5}, ALU_SLL,
            1'b1, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
            "SLLI x1, x2, 5"
        );

        // SRLI x3, x4, 10
        check_decode(
            encode_i_type(7'b0010011, 5'd3, 5'd4, 3'b101, {7'b0000000, 5'd10}),
            {{27{1'b0}}, 5'd10}, ALU_SRL,
            1'b1, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
            "SRLI x3, x4, 10"
        );

        // SRAI x5, x6, 15
        check_decode(
            encode_i_type(7'b0010011, 5'd5, 5'd6, 3'b101, {7'b0100000, 5'd15}),
            {{27{1'b0}}, 5'd15}, ALU_SRA,
            1'b1, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
            "SRAI x5, x6, 15"
        );

        // ====================================================================
        // Test Category 10: Register File Testing
        // ====================================================================
        $display("\n--- Test Category 10: Register File Operations ---");

        // Write to integer register x10
        wb_reg_write = 1'b1;
        wb_fp_reg_write = 1'b0;
        wb_rd = 5'd10;
        wb_data = 32'hDEADBEEF;
        @(posedge clk);

        // Read from x10 (ADDI x11, x10, 0)
        instr = encode_i_type(7'b0010011, 5'd11, 5'd10, 3'b000, 12'd0);
        @(posedge clk);
        #1;
        if (rs1_data === 32'hDEADBEEF) begin
            $display("[PASS] Integer register read: x10 = 0xDEADBEEF");
            pass_count = pass_count + 1;
            test_count = test_count + 1;
        end else begin
            $display("[FAIL] Integer register read: Expected 0xDEADBEEF, Got %h", rs1_data);
            fail_count = fail_count + 1;
            test_count = test_count + 1;
        end

        // Write to FP register f5
        wb_reg_write = 1'b1;
        wb_fp_reg_write = 1'b1;
        wb_rd = 5'd5;
        wb_data = 32'h3F800000;  // 1.0
        @(posedge clk);

        // Read from f5 (FADD.S f6, f5, f0)
        instr = encode_r_type(7'b1010011, 5'd6, 5'd5, 5'd0, 3'b000, 7'b0000000);
        @(posedge clk);
        #1;
        if (fp_rs1_data === 32'h3F800000) begin
            $display("[PASS] FP register read: f5 = 0x3F800000 (1.0)");
            pass_count = pass_count + 1;
            test_count = test_count + 1;
        end else begin
            $display("[FAIL] FP register read: Expected 0x3F800000, Got %h", fp_rs1_data);
            fail_count = fail_count + 1;
            test_count = test_count + 1;
        end

        // Disable writeback
        wb_reg_write = 1'b0;
        wb_fp_reg_write = 1'b0;

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

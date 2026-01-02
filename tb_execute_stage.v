// ============================================================================
// Testbench for Execute Stage
// Tests ALU operations, branch evaluation, integer forwarding
// Verifies operand selection and forwarding multiplexers
// Note: FPU and FFT testing simplified (submodules already tested)
// Self-checking with comprehensive test cases
// ============================================================================

`timescale 1ns / 1ps

module tb_execute_stage;

    // ========================================================================
    // Clock and Reset
    // ========================================================================

    reg clk;
    reg rst_n;

    // ========================================================================
    // DUT Signals - ID/EX Register Inputs
    // ========================================================================

    reg  [31:0] pc_ex;
    reg  [31:0] rs1_data_ex;
    reg  [31:0] rs2_data_ex;
    reg  [31:0] imm_ex;
    reg  [4:0]  rs1_ex;
    reg  [4:0]  rs2_ex;
    reg  [2:0]  funct3_ex;
    reg  [6:0]  funct7_ex;
    reg         alu_src_ex;
    reg         branch_ex;
    reg         jump_ex;
    reg  [3:0]  alu_op_ex;
    reg         fp_op_ex;
    reg         fft_op_ex;

    // FPU inputs
    reg  [31:0] fp_rs1_data_ex;
    reg  [31:0] fp_rs2_data_ex;
    reg  [31:0] fp_rs3_data_ex;
    reg  [4:0]  fp_rs3_ex;

    // Integer forwarding inputs
    reg  [1:0]  forward_a;
    reg  [1:0]  forward_b;
    reg  [31:0] alu_result_mem;
    reg  [31:0] wb_data;

    // FPU forwarding inputs
    reg  [4:0]  rd_mem;
    reg  [4:0]  rd_wb;
    reg         fp_reg_write_mem;
    reg         fp_reg_write_wb;
    reg  [31:0] fpu_result_mem;
    reg  [31:0] fpu_result_wb;
    reg  [1:0]  rs1_stage_fpu;
    reg  [1:0]  rs2_stage_fpu;
    reg  [1:0]  rs3_stage_fpu;

    // CSR input
    reg  [2:0]  frm_csr;

    // Outputs
    wire [31:0] alu_result;
    wire [31:0] fpu_result;
    wire [4:0]  fpu_flags;
    wire [2:0]  fpu_latency;
    wire [31:0] rs2_data_fwd;
    wire [31:0] branch_target;
    wire        branch_taken;
    wire        zero;

    // ========================================================================
    // DUT Instantiation
    // ========================================================================

    execute_stage dut (
        .clk(clk),
        .rst_n(rst_n),
        .pc_ex(pc_ex),
        .rs1_data_ex(rs1_data_ex),
        .rs2_data_ex(rs2_data_ex),
        .imm_ex(imm_ex),
        .rs1_ex(rs1_ex),
        .rs2_ex(rs2_ex),
        .funct3_ex(funct3_ex),
        .funct7_ex(funct7_ex),
        .alu_src_ex(alu_src_ex),
        .branch_ex(branch_ex),
        .jump_ex(jump_ex),
        .alu_op_ex(alu_op_ex),
        .fp_op_ex(fp_op_ex),
        .fft_op_ex(fft_op_ex),
        .fp_rs1_data_ex(fp_rs1_data_ex),
        .fp_rs2_data_ex(fp_rs2_data_ex),
        .fp_rs3_data_ex(fp_rs3_data_ex),
        .fp_rs3_ex(fp_rs3_ex),
        .forward_a(forward_a),
        .forward_b(forward_b),
        .alu_result_mem(alu_result_mem),
        .wb_data(wb_data),
        .rd_mem(rd_mem),
        .rd_wb(rd_wb),
        .fp_reg_write_mem(fp_reg_write_mem),
        .fp_reg_write_wb(fp_reg_write_wb),
        .fpu_result_mem(fpu_result_mem),
        .fpu_result_wb(fpu_result_wb),
        .rs1_stage_fpu(rs1_stage_fpu),
        .rs2_stage_fpu(rs2_stage_fpu),
        .rs3_stage_fpu(rs3_stage_fpu),
        .frm_csr(frm_csr),
        .alu_result(alu_result),
        .fpu_result(fpu_result),
        .fpu_flags(fpu_flags),
        .fpu_latency(fpu_latency),
        .rs2_data_fwd(rs2_data_fwd),
        .branch_target(branch_target),
        .branch_taken(branch_taken),
        .zero(zero)
    );

    // ========================================================================
    // ALU Operation Encodings
    // ========================================================================

    localparam ALU_ADD  = 4'b0000;
    localparam ALU_SUB  = 4'b0001;
    localparam ALU_AND  = 4'b0010;
    localparam ALU_OR   = 4'b0011;
    localparam ALU_XOR  = 4'b0100;
    localparam ALU_SLL  = 4'b0101;
    localparam ALU_SRL  = 4'b0110;
    localparam ALU_SRA  = 4'b0111;
    localparam ALU_SLT  = 4'b1000;
    localparam ALU_SLTU = 4'b1001;
    localparam ALU_AUIPC = 4'b1011;

    // Branch function codes
    localparam FUNCT3_BEQ  = 3'b000;
    localparam FUNCT3_BNE  = 3'b001;
    localparam FUNCT3_BLT  = 3'b100;
    localparam FUNCT3_BGE  = 3'b101;
    localparam FUNCT3_BLTU = 3'b110;
    localparam FUNCT3_BGEU = 3'b111;

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
            pc_ex = 32'h00001000;
            rs1_data_ex = 32'd0;
            rs2_data_ex = 32'd0;
            imm_ex = 32'd0;
            rs1_ex = 5'd0;
            rs2_ex = 5'd0;
            funct3_ex = 3'd0;
            funct7_ex = 7'd0;
            alu_src_ex = 1'b0;
            branch_ex = 1'b0;
            jump_ex = 1'b0;
            alu_op_ex = ALU_ADD;
            fp_op_ex = 1'b0;
            fft_op_ex = 1'b0;
            fp_rs1_data_ex = 32'd0;
            fp_rs2_data_ex = 32'd0;
            fp_rs3_data_ex = 32'd0;
            fp_rs3_ex = 5'd0;
            forward_a = 2'b00;
            forward_b = 2'b00;
            alu_result_mem = 32'd0;
            wb_data = 32'd0;
            rd_mem = 5'd0;
            rd_wb = 5'd0;
            fp_reg_write_mem = 1'b0;
            fp_reg_write_wb = 1'b0;
            fpu_result_mem = 32'd0;
            fpu_result_wb = 32'd0;
            rs1_stage_fpu = 2'b00;
            rs2_stage_fpu = 2'b00;
            rs3_stage_fpu = 2'b00;
            frm_csr = 3'b000;
        end
    endtask

    task check_alu;
        input [31:0] exp_result;
        input        exp_zero;
        input [200:0] description;
        begin
            test_count = test_count + 1;
            #1;

            if (alu_result === exp_result && zero === exp_zero) begin
                $display("[PASS] Test %0d: %s", test_count, description);
                $display("       alu_result=0x%h, zero=%b", alu_result, zero);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] Test %0d: %s", test_count, description);
                $display("       Expected: result=0x%h, zero=%b", exp_result, exp_zero);
                $display("       Got:      result=0x%h, zero=%b", alu_result, zero);
                fail_count = fail_count + 1;
            end
        end
    endtask

    task check_branch;
        input [31:0] exp_target;
        input        exp_taken;
        input [200:0] description;
        begin
            test_count = test_count + 1;
            #1;

            if (branch_target === exp_target && branch_taken === exp_taken) begin
                $display("[PASS] Test %0d: %s", test_count, description);
                $display("       target=0x%h, taken=%b", branch_target, branch_taken);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] Test %0d: %s", test_count, description);
                $display("       Expected: target=0x%h, taken=%b", exp_target, exp_taken);
                $display("       Got:      target=0x%h, taken=%b", branch_target, branch_taken);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // ========================================================================
    // Test Stimulus
    // ========================================================================

    initial begin
        $display("\n========================================");
        $display("Execute Stage Testbench");
        $display("========================================\n");

        // Initialize
        rst_n = 0;
        reset_inputs();

        repeat(3) @(posedge clk);
        rst_n = 1;
        @(posedge clk);

        // ====================================================================
        // Test Category 1: ALU Operations (No Forwarding)
        // ====================================================================
        $display("\n--- Test Category 1: ALU Operations (No Forwarding) ---");

        // ADD
        reset_inputs();
        rs1_data_ex = 32'd100;
        rs2_data_ex = 32'd50;
        alu_src_ex = 1'b0;
        alu_op_ex = ALU_ADD;
        check_alu(32'd150, 1'b0, "ADD: 100 + 50 = 150");

        // ADD with immediate
        reset_inputs();
        rs1_data_ex = 32'd100;
        imm_ex = 32'd50;
        alu_src_ex = 1'b1;
        alu_op_ex = ALU_ADD;
        check_alu(32'd150, 1'b0, "ADDI: 100 + 50 = 150");

        // SUB
        reset_inputs();
        rs1_data_ex = 32'd100;
        rs2_data_ex = 32'd50;
        alu_src_ex = 1'b0;
        alu_op_ex = ALU_SUB;
        check_alu(32'd50, 1'b0, "SUB: 100 - 50 = 50");

        // AND
        reset_inputs();
        rs1_data_ex = 32'hFFFF0000;
        rs2_data_ex = 32'h0000FFFF;
        alu_src_ex = 1'b0;
        alu_op_ex = ALU_AND;
        check_alu(32'h00000000, 1'b1, "AND: 0xFFFF0000 & 0x0000FFFF = 0 (zero=1)");

        // OR
        reset_inputs();
        rs1_data_ex = 32'hFFFF0000;
        rs2_data_ex = 32'h0000FFFF;
        alu_src_ex = 1'b0;
        alu_op_ex = ALU_OR;
        check_alu(32'hFFFFFFFF, 1'b0, "OR: 0xFFFF0000 | 0x0000FFFF = 0xFFFFFFFF");

        // XOR
        reset_inputs();
        rs1_data_ex = 32'hAAAAAAAA;
        rs2_data_ex = 32'hAAAAAAAA;
        alu_src_ex = 1'b0;
        alu_op_ex = ALU_XOR;
        check_alu(32'h00000000, 1'b1, "XOR: 0xAAAAAAAA ^ 0xAAAAAAAA = 0 (zero=1)");

        // SLL (Shift Left Logical)
        reset_inputs();
        rs1_data_ex = 32'h00000001;
        rs2_data_ex = 32'd4;
        alu_src_ex = 1'b0;
        alu_op_ex = ALU_SLL;
        check_alu(32'h00000010, 1'b0, "SLL: 1 << 4 = 16");

        // SRL (Shift Right Logical)
        reset_inputs();
        rs1_data_ex = 32'h00000010;
        rs2_data_ex = 32'd4;
        alu_src_ex = 1'b0;
        alu_op_ex = ALU_SRL;
        check_alu(32'h00000001, 1'b0, "SRL: 16 >> 4 = 1");

        // SLT (Set Less Than)
        reset_inputs();
        rs1_data_ex = 32'hFFFFFFF0;  // -16
        rs2_data_ex = 32'd10;
        alu_src_ex = 1'b0;
        alu_op_ex = ALU_SLT;
        check_alu(32'h00000001, 1'b0, "SLT: -16 < 10 = 1");

        // SLTU (Set Less Than Unsigned)
        reset_inputs();
        rs1_data_ex = 32'd10;
        rs2_data_ex = 32'd100;
        alu_src_ex = 1'b0;
        alu_op_ex = ALU_SLTU;
        check_alu(32'h00000001, 1'b0, "SLTU: 10 < 100 = 1");

        // ====================================================================
        // Test Category 2: AUIPC (PC-relative addition)
        // ====================================================================
        $display("\n--- Test Category 2: AUIPC (PC-relative) ---");

        reset_inputs();
        pc_ex = 32'h00001000;
        imm_ex = 32'h00002000;
        alu_src_ex = 1'b1;
        alu_op_ex = ALU_AUIPC;
        check_alu(32'h00003000, 1'b0, "AUIPC: PC + imm = 0x1000 + 0x2000");

        reset_inputs();
        pc_ex = 32'h80000000;
        imm_ex = 32'h00001000;
        alu_src_ex = 1'b1;
        alu_op_ex = ALU_AUIPC;
        check_alu(32'h80001000, 1'b0, "AUIPC: High address calculation");

        // ====================================================================
        // Test Category 3: Integer Forwarding from MEM Stage
        // ====================================================================
        $display("\n--- Test Category 3: Integer Forwarding from MEM ---");

        reset_inputs();
        rs1_data_ex = 32'd100;
        rs2_data_ex = 32'd50;
        alu_result_mem = 32'd999;  // Forward this value
        forward_a = 2'b10;  // Forward from MEM to operand A
        forward_b = 2'b00;  // No forwarding for B
        alu_src_ex = 1'b0;
        alu_op_ex = ALU_ADD;
        check_alu(32'd1049, 1'b0, "Forward MEM to A: 999 + 50 = 1049");

        reset_inputs();
        rs1_data_ex = 32'd100;
        rs2_data_ex = 32'd50;
        alu_result_mem = 32'd777;  // Forward this value
        forward_a = 2'b00;
        forward_b = 2'b10;  // Forward from MEM to operand B
        alu_src_ex = 1'b0;
        alu_op_ex = ALU_ADD;
        check_alu(32'd877, 1'b0, "Forward MEM to B: 100 + 777 = 877");

        reset_inputs();
        rs1_data_ex = 32'd100;
        rs2_data_ex = 32'd50;
        alu_result_mem = 32'd555;
        forward_a = 2'b10;
        forward_b = 2'b10;  // Forward to both
        alu_src_ex = 1'b0;
        alu_op_ex = ALU_ADD;
        check_alu(32'd1110, 1'b0, "Forward MEM to both: 555 + 555 = 1110");

        // ====================================================================
        // Test Category 4: Integer Forwarding from WB Stage
        // ====================================================================
        $display("\n--- Test Category 4: Integer Forwarding from WB ---");

        reset_inputs();
        rs1_data_ex = 32'd100;
        rs2_data_ex = 32'd50;
        wb_data = 32'd888;
        forward_a = 2'b01;  // Forward from WB to A
        forward_b = 2'b00;
        alu_src_ex = 1'b0;
        alu_op_ex = ALU_ADD;
        check_alu(32'd938, 1'b0, "Forward WB to A: 888 + 50 = 938");

        reset_inputs();
        rs1_data_ex = 32'd100;
        rs2_data_ex = 32'd50;
        wb_data = 32'd222;
        forward_a = 2'b00;
        forward_b = 2'b01;  // Forward from WB to B
        alu_src_ex = 1'b0;
        alu_op_ex = ALU_SUB;
        check_alu(32'hFFFFFF62, 1'b0, "Forward WB to B: 100 - 222 = -122");

        // ====================================================================
        // Test Category 5: Forwarding Priority (MEM vs WB)
        // ====================================================================
        $display("\n--- Test Category 5: Forwarding Priority ---");

        reset_inputs();
        rs1_data_ex = 32'd100;
        alu_result_mem = 32'd500;  // MEM stage value
        wb_data = 32'd300;         // WB stage value
        forward_a = 2'b10;         // MEM has priority
        alu_src_ex = 1'b1;
        imm_ex = 32'd10;
        alu_op_ex = ALU_ADD;
        check_alu(32'd510, 1'b0, "MEM priority: 500 + 10 = 510");

        // ====================================================================
        // Test Category 6: rs2_data_fwd for Store Instructions
        // ====================================================================
        $display("\n--- Test Category 6: rs2_data_fwd Output ---");

        reset_inputs();
        rs2_data_ex = 32'hDEADBEEF;
        forward_b = 2'b00;
        #1;
        test_count = test_count + 1;
        if (rs2_data_fwd === 32'hDEADBEEF) begin
            $display("[PASS] Test %0d: rs2_data_fwd = rs2_data_ex (no fwd)",
                     test_count);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Test %0d: rs2_data_fwd incorrect", test_count);
            fail_count = fail_count + 1;
        end

        reset_inputs();
        rs2_data_ex = 32'd0;
        alu_result_mem = 32'hCAFEBABE;
        forward_b = 2'b10;
        #1;
        test_count = test_count + 1;
        if (rs2_data_fwd === 32'hCAFEBABE) begin
            $display("[PASS] Test %0d: rs2_data_fwd forwarded from MEM",
                     test_count);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Test %0d: rs2_data_fwd forward failed", test_count);
            fail_count = fail_count + 1;
        end

        // ====================================================================
        // Test Category 7: Branch Evaluation - BEQ
        // ====================================================================
        $display("\n--- Test Category 7: Branch BEQ (Branch if Equal) ---");

        reset_inputs();
        pc_ex = 32'h00001000;
        rs1_data_ex = 32'd100;
        rs2_data_ex = 32'd100;
        imm_ex = 32'h00000100;
        funct3_ex = FUNCT3_BEQ;
        branch_ex = 1'b1;
        jump_ex = 1'b0;
        alu_src_ex = 1'b0;
        check_branch(32'h00001100, 1'b1, "BEQ: 100 == 100, taken");

        reset_inputs();
        pc_ex = 32'h00001000;
        rs1_data_ex = 32'd100;
        rs2_data_ex = 32'd50;
        imm_ex = 32'h00000100;
        funct3_ex = FUNCT3_BEQ;
        branch_ex = 1'b1;
        jump_ex = 1'b0;
        alu_src_ex = 1'b0;
        check_branch(32'h00001100, 1'b0, "BEQ: 100 != 50, not taken");

        // ====================================================================
        // Test Category 8: Branch Evaluation - BNE
        // ====================================================================
        $display("\n--- Test Category 8: Branch BNE (Branch if Not Equal) ---");

        reset_inputs();
        pc_ex = 32'h00002000;
        rs1_data_ex = 32'd100;
        rs2_data_ex = 32'd50;
        imm_ex = 32'h00000200;
        funct3_ex = FUNCT3_BNE;
        branch_ex = 1'b1;
        jump_ex = 1'b0;
        check_branch(32'h00002200, 1'b1, "BNE: 100 != 50, taken");

        reset_inputs();
        pc_ex = 32'h00002000;
        rs1_data_ex = 32'd100;
        rs2_data_ex = 32'd100;
        imm_ex = 32'h00000200;
        funct3_ex = FUNCT3_BNE;
        branch_ex = 1'b1;
        jump_ex = 1'b0;
        check_branch(32'h00002200, 1'b0, "BNE: 100 == 100, not taken");

        // ====================================================================
        // Test Category 9: Branch Evaluation - BLT/BGE
        // ====================================================================
        $display("\n--- Test Category 9: Branch BLT/BGE (Signed) ---");

        reset_inputs();
        pc_ex = 32'h00003000;
        rs1_data_ex = 32'hFFFFFFF0;  // -16
        rs2_data_ex = 32'd10;
        imm_ex = 32'hFFFFFFF0;  // -16 (backward branch)
        funct3_ex = FUNCT3_BLT;
        branch_ex = 1'b1;
        check_branch(32'h00002FF0, 1'b1, "BLT: -16 < 10, taken (backward)");

        reset_inputs();
        pc_ex = 32'h00003000;
        rs1_data_ex = 32'd100;
        rs2_data_ex = 32'd50;
        imm_ex = 32'h00000100;
        funct3_ex = FUNCT3_BGE;
        branch_ex = 1'b1;
        check_branch(32'h00003100, 1'b1, "BGE: 100 >= 50, taken");

        // ====================================================================
        // Test Category 10: Jump (JAL/JALR)
        // ====================================================================
        $display("\n--- Test Category 10: Jump Instructions ---");

        reset_inputs();
        pc_ex = 32'h00004000;
        imm_ex = 32'h00001000;
        funct3_ex = 3'b000;
        branch_ex = 1'b0;
        jump_ex = 1'b1;
        alu_src_ex = 1'b1;
        check_branch(32'h00005000, 1'b1, "JAL: PC + offset");

        reset_inputs();
        pc_ex = 32'h00004000;
        rs1_data_ex = 32'h00008000;
        imm_ex = 32'h00000100;
        funct3_ex = 3'b000;
        branch_ex = 1'b0;
        jump_ex = 1'b1;
        alu_src_ex = 1'b1;
        check_branch(32'h00008100, 1'b1, "JALR: rs1 + offset");

        // ====================================================================
        // Test Category 11: Branch with Forwarding
        // ====================================================================
        $display("\n--- Test Category 11: Branch with Forwarding ---");

        reset_inputs();
        pc_ex = 32'h00005000;
        rs1_data_ex = 32'd0;  // Will be forwarded
        rs2_data_ex = 32'd100;
        alu_result_mem = 32'd100;  // Forward to match rs2
        forward_a = 2'b10;
        imm_ex = 32'h00000400;
        funct3_ex = FUNCT3_BEQ;
        branch_ex = 1'b1;
        check_branch(32'h00005400, 1'b1, "BEQ with forwarding: 100 == 100");

        reset_inputs();
        pc_ex = 32'h00006000;
        rs1_data_ex = 32'd100;
        rs2_data_ex = 32'd0;  // Will be forwarded
        wb_data = 32'd50;
        forward_b = 2'b01;  // Forward from WB
        imm_ex = 32'h00000300;
        funct3_ex = FUNCT3_BNE;
        branch_ex = 1'b1;
        check_branch(32'h00006300, 1'b1, "BNE with forwarding: 100 != 50");

        // ====================================================================
        // Test Category 12: Zero Flag
        // ====================================================================
        $display("\n--- Test Category 12: Zero Flag Detection ---");

        reset_inputs();
        rs1_data_ex = 32'd100;
        rs2_data_ex = 32'd100;
        alu_op_ex = ALU_SUB;
        check_alu(32'h00000000, 1'b1, "Zero flag: 100 - 100 = 0");

        reset_inputs();
        rs1_data_ex = 32'hFFFFFFFF;
        rs2_data_ex = 32'h00000001;
        alu_op_ex = ALU_ADD;
        check_alu(32'h00000000, 1'b1, "Zero flag: overflow to zero");

        // ====================================================================
        // Test Category 13: Realistic Instruction Sequences
        // ====================================================================
        $display("\n--- Test Category 13: Realistic Sequences ---");

        // ADD with immediate (ADDI)
        reset_inputs();
        rs1_data_ex = 32'h00001000;
        imm_ex = 32'h00000FF0;
        alu_src_ex = 1'b1;
        alu_op_ex = ALU_ADD;
        check_alu(32'h00001FF0, 1'b0, "ADDI: base + offset");

        // Load address calculation
        reset_inputs();
        rs1_data_ex = 32'h80000000;
        imm_ex = 32'd100;
        alu_src_ex = 1'b1;
        alu_op_ex = ALU_ADD;
        check_alu(32'h80000064, 1'b0, "Load addr: base + offset");

        // Store with forwarding
        reset_inputs();
        rs1_data_ex = 32'h00002000;
        rs2_data_ex = 32'hDEADBEEF;
        alu_result_mem = 32'h00003000;  // Forward base address
        forward_a = 2'b10;
        forward_b = 2'b00;
        imm_ex = 32'd16;
        alu_src_ex = 1'b1;
        alu_op_ex = ALU_ADD;
        check_alu(32'h00003010, 1'b0, "Store addr with forwarding");
        #1;
        test_count = test_count + 1;
        if (rs2_data_fwd === 32'hDEADBEEF) begin
            $display("[PASS] Test %0d: Store data forwarded correctly",
                     test_count);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Test %0d: Store data incorrect", test_count);
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
        $display("\nNote: FPU and FFT integration not tested (submodules already verified)");

        if (fail_count == 0) begin
            $display("\n*** ALL TESTS PASSED ***\n");
        end else begin
            $display("\n*** SOME TESTS FAILED ***\n");
        end

        $finish;
    end

endmodule

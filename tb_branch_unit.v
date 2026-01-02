// ============================================================================
// Testbench for Branch Unit
// Tests all branch conditions and jump target calculations
// Self-checking with comprehensive test cases
// ============================================================================

`timescale 1ns / 1ps

module tb_branch_unit;

    // ========================================================================
    // DUT Signals
    // ========================================================================

    reg  [31:0] rs1_data;
    reg  [31:0] rs2_data;
    reg  [31:0] pc;
    reg  [31:0] imm;
    reg  [2:0]  funct3;
    reg         branch;
    reg         jump;
    reg         alu_src;

    wire [31:0] branch_target;
    wire        branch_taken;

    // ========================================================================
    // DUT Instantiation
    // ========================================================================

    branch_unit dut (
        .rs1_data(rs1_data),
        .rs2_data(rs2_data),
        .pc(pc),
        .imm(imm),
        .funct3(funct3),
        .branch(branch),
        .jump(jump),
        .alu_src(alu_src),
        .branch_target(branch_target),
        .branch_taken(branch_taken)
    );

    // ========================================================================
    // Test Infrastructure
    // ========================================================================

    integer test_count = 0;
    integer pass_count = 0;
    integer fail_count = 0;

    // Branch function codes
    localparam BEQ  = 3'b000;
    localparam BNE  = 3'b001;
    localparam BLT  = 3'b100;
    localparam BGE  = 3'b101;
    localparam BLTU = 3'b110;
    localparam BGEU = 3'b111;
    localparam JALR = 3'b000;  // JALR uses funct3=000 (like BEQ)

    // ========================================================================
    // Test Task
    // ========================================================================

    task check_branch;
        input [31:0] test_rs1, test_rs2, test_pc, test_imm;
        input [2:0]  test_funct3;
        input        test_branch, test_jump, test_alu_src;
        input [31:0] exp_target;
        input        exp_taken;
        input [200:0] description;

        begin
            test_count = test_count + 1;

            rs1_data = test_rs1;
            rs2_data = test_rs2;
            pc = test_pc;
            imm = test_imm;
            funct3 = test_funct3;
            branch = test_branch;
            jump = test_jump;
            alu_src = test_alu_src;

            #10;

            if (branch_target === exp_target && branch_taken === exp_taken) begin
                $display("[PASS] Test %0d: %s", test_count, description);
                $display("       Target: %h, Taken: %b", branch_target, branch_taken);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] Test %0d: %s", test_count, description);
                $display("       Expected: Target=%h Taken=%b", exp_target, exp_taken);
                $display("       Got:      Target=%h Taken=%b", branch_target, branch_taken);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // ========================================================================
    // Test Stimulus
    // ========================================================================

    initial begin
        $display("\n========================================");
        $display("Branch Unit Testbench");
        $display("========================================\n");

        // ====================================================================
        // Test Category 1: BEQ (Branch if Equal)
        // ====================================================================
        $display("\n--- Test Category 1: BEQ (Branch if Equal) ---");

        check_branch(
            32'd10, 32'd10, 32'h1000, 32'h100,
            BEQ, 1'b1, 1'b0, 1'b0,
            32'h1100, 1'b1,
            "BEQ: Equal values (10 == 10) → Taken"
        );

        check_branch(
            32'd5, 32'd10, 32'h1000, 32'h100,
            BEQ, 1'b1, 1'b0, 1'b0,
            32'h1100, 1'b0,
            "BEQ: Not equal (5 != 10) → Not taken"
        );

        check_branch(
            32'hFFFFFFFF, 32'hFFFFFFFF, 32'h2000, 32'h200,
            BEQ, 1'b1, 1'b0, 1'b0,
            32'h2200, 1'b1,
            "BEQ: Equal negative (-1 == -1) → Taken"
        );

        check_branch(
            32'h0, 32'h0, 32'h3000, 32'h50,
            BEQ, 1'b1, 1'b0, 1'b0,
            32'h3050, 1'b1,
            "BEQ: Both zero (0 == 0) → Taken"
        );

        // ====================================================================
        // Test Category 2: BNE (Branch if Not Equal)
        // ====================================================================
        $display("\n--- Test Category 2: BNE (Branch if Not Equal) ---");

        check_branch(
            32'd5, 32'd10, 32'h1000, 32'h100,
            BNE, 1'b1, 1'b0, 1'b0,
            32'h1100, 1'b1,
            "BNE: Not equal (5 != 10) → Taken"
        );

        check_branch(
            32'd10, 32'd10, 32'h1000, 32'h100,
            BNE, 1'b1, 1'b0, 1'b0,
            32'h1100, 1'b0,
            "BNE: Equal values (10 == 10) → Not taken"
        );

        check_branch(
            32'hFFFFFFFF, 32'h00000001, 32'h2000, 32'h200,
            BNE, 1'b1, 1'b0, 1'b0,
            32'h2200, 1'b1,
            "BNE: -1 != 1 → Taken"
        );

        // ====================================================================
        // Test Category 3: BLT (Branch if Less Than - Signed)
        // ====================================================================
        $display("\n--- Test Category 3: BLT (Branch if Less Than) ---");

        check_branch(
            32'd5, 32'd10, 32'h1000, 32'h100,
            BLT, 1'b1, 1'b0, 1'b0,
            32'h1100, 1'b1,
            "BLT: 5 < 10 → Taken"
        );

        check_branch(
            32'd10, 32'd5, 32'h1000, 32'h100,
            BLT, 1'b1, 1'b0, 1'b0,
            32'h1100, 1'b0,
            "BLT: 10 < 5 → Not taken"
        );

        check_branch(
            32'd10, 32'd10, 32'h1000, 32'h100,
            BLT, 1'b1, 1'b0, 1'b0,
            32'h1100, 1'b0,
            "BLT: 10 < 10 → Not taken (equal)"
        );

        // Signed comparison
        check_branch(
            32'hFFFFFFFF, 32'd1, 32'h2000, 32'h200,  // -1 < 1
            BLT, 1'b1, 1'b0, 1'b0,
            32'h2200, 1'b1,
            "BLT: -1 < 1 → Taken (signed)"
        );

        check_branch(
            32'd1, 32'hFFFFFFFF, 32'h2000, 32'h200,  // 1 < -1
            BLT, 1'b1, 1'b0, 1'b0,
            32'h2200, 1'b0,
            "BLT: 1 < -1 → Not taken (signed)"
        );

        check_branch(
            32'h80000000, 32'd0, 32'h3000, 32'h300,  // MIN_INT < 0
            BLT, 1'b1, 1'b0, 1'b0,
            32'h3300, 1'b1,
            "BLT: MIN_INT < 0 → Taken"
        );

        // ====================================================================
        // Test Category 4: BGE (Branch if Greater or Equal - Signed)
        // ====================================================================
        $display("\n--- Test Category 4: BGE (Branch if Greater or Equal) ---");

        check_branch(
            32'd10, 32'd5, 32'h1000, 32'h100,
            BGE, 1'b1, 1'b0, 1'b0,
            32'h1100, 1'b1,
            "BGE: 10 >= 5 → Taken"
        );

        check_branch(
            32'd10, 32'd10, 32'h1000, 32'h100,
            BGE, 1'b1, 1'b0, 1'b0,
            32'h1100, 1'b1,
            "BGE: 10 >= 10 → Taken (equal)"
        );

        check_branch(
            32'd5, 32'd10, 32'h1000, 32'h100,
            BGE, 1'b1, 1'b0, 1'b0,
            32'h1100, 1'b0,
            "BGE: 5 >= 10 → Not taken"
        );

        // Signed comparison
        check_branch(
            32'd1, 32'hFFFFFFFF, 32'h2000, 32'h200,  // 1 >= -1
            BGE, 1'b1, 1'b0, 1'b0,
            32'h2200, 1'b1,
            "BGE: 1 >= -1 → Taken (signed)"
        );

        check_branch(
            32'hFFFFFFFF, 32'd1, 32'h2000, 32'h200,  // -1 >= 1
            BGE, 1'b1, 1'b0, 1'b0,
            32'h2200, 1'b0,
            "BGE: -1 >= 1 → Not taken (signed)"
        );

        // ====================================================================
        // Test Category 5: BLTU (Branch if Less Than - Unsigned)
        // ====================================================================
        $display("\n--- Test Category 5: BLTU (Branch if Less Than Unsigned) ---");

        check_branch(
            32'd5, 32'd10, 32'h1000, 32'h100,
            BLTU, 1'b1, 1'b0, 1'b0,
            32'h1100, 1'b1,
            "BLTU: 5 < 10 → Taken (unsigned)"
        );

        check_branch(
            32'd10, 32'd5, 32'h1000, 32'h100,
            BLTU, 1'b1, 1'b0, 1'b0,
            32'h1100, 1'b0,
            "BLTU: 10 < 5 → Not taken"
        );

        // Unsigned comparison (different from signed)
        check_branch(
            32'hFFFFFFFF, 32'd1, 32'h2000, 32'h200,
            BLTU, 1'b1, 1'b0, 1'b0,
            32'h2200, 1'b0,
            "BLTU: 0xFFFFFFFF < 1 → Not taken (unsigned large)"
        );

        check_branch(
            32'd1, 32'hFFFFFFFF, 32'h2000, 32'h200,
            BLTU, 1'b1, 1'b0, 1'b0,
            32'h2200, 1'b1,
            "BLTU: 1 < 0xFFFFFFFF → Taken (unsigned)"
        );

        check_branch(
            32'h80000000, 32'd0, 32'h3000, 32'h300,
            BLTU, 1'b1, 1'b0, 1'b0,
            32'h3300, 1'b0,
            "BLTU: 0x80000000 < 0 → Not taken (unsigned)"
        );

        // ====================================================================
        // Test Category 6: BGEU (Branch if Greater or Equal - Unsigned)
        // ====================================================================
        $display("\n--- Test Category 6: BGEU (Branch if Greater or Equal Unsigned) ---");

        check_branch(
            32'd10, 32'd5, 32'h1000, 32'h100,
            BGEU, 1'b1, 1'b0, 1'b0,
            32'h1100, 1'b1,
            "BGEU: 10 >= 5 → Taken"
        );

        check_branch(
            32'd10, 32'd10, 32'h1000, 32'h100,
            BGEU, 1'b1, 1'b0, 1'b0,
            32'h1100, 1'b1,
            "BGEU: 10 >= 10 → Taken (equal)"
        );

        check_branch(
            32'hFFFFFFFF, 32'd1, 32'h2000, 32'h200,
            BGEU, 1'b1, 1'b0, 1'b0,
            32'h2200, 1'b1,
            "BGEU: 0xFFFFFFFF >= 1 → Taken (unsigned large)"
        );

        check_branch(
            32'd1, 32'hFFFFFFFF, 32'h2000, 32'h200,
            BGEU, 1'b1, 1'b0, 1'b0,
            32'h2200, 1'b0,
            "BGEU: 1 >= 0xFFFFFFFF → Not taken"
        );

        // ====================================================================
        // Test Category 7: JAL (Jump and Link - Unconditional)
        // ====================================================================
        $display("\n--- Test Category 7: JAL (Unconditional Jump) ---");

        check_branch(
            32'd0, 32'd0, 32'h1000, 32'h100,
            3'b000, 1'b0, 1'b1, 1'b0,  // jump=1, alu_src=0
            32'h1100, 1'b1,
            "JAL: PC + imm (0x1000 + 0x100)"
        );

        check_branch(
            32'd0, 32'd0, 32'h2000, 32'hFFFFFF00,  // Negative offset
            3'b000, 1'b0, 1'b1, 1'b0,
            32'h1F00, 1'b1,
            "JAL: Backward jump (negative offset)"
        );

        check_branch(
            32'd123, 32'd456, 32'hABCD, 32'h1234,
            3'b000, 1'b0, 1'b1, 1'b0,
            32'hBE01, 1'b1,
            "JAL: Always taken (ignores rs1/rs2)"
        );

        // ====================================================================
        // Test Category 8: JALR (Jump and Link Register)
        // ====================================================================
        $display("\n--- Test Category 8: JALR (Jump Register) ---");

        check_branch(
            32'h1000, 32'd0, 32'h2000, 32'h100,
            3'b000, 1'b0, 1'b1, 1'b1,  // jump=1, alu_src=1
            32'h1100, 1'b1,
            "JALR: (rs1 + imm) & ~1 (0x1000 + 0x100)"
        );

        check_branch(
            32'h2000, 32'd0, 32'h5000, 32'h0FF,
            3'b000, 1'b0, 1'b1, 1'b1,
            32'h20FE, 1'b1,
            "JALR: LSB cleared (0x2000 + 0xFF = 0x20FF → 0x20FE)"
        );

        check_branch(
            32'hABCD, 32'd0, 32'h1234, 32'h5678,
            3'b000, 1'b0, 1'b1, 1'b1,
            32'h10244, 1'b1,
            "JALR: Large offset with LSB clearing"
        );

        check_branch(
            32'h1001, 32'd0, 32'h2000, 32'h100,
            3'b000, 1'b0, 1'b1, 1'b1,
            32'h1100, 1'b1,
            "JALR: Odd address cleared (0x1001 + 0x100 = 0x1101 → 0x1100)"
        );

        // ====================================================================
        // Test Category 9: No Branch/Jump
        // ====================================================================
        $display("\n--- Test Category 9: No Branch/Jump ---");

        check_branch(
            32'd10, 32'd5, 32'h1000, 32'h100,
            BEQ, 1'b0, 1'b0, 1'b0,  // branch=0, jump=0
            32'h1100, 1'b0,
            "No operation: branch=0, jump=0 → Not taken"
        );

        check_branch(
            32'd10, 32'd10, 32'h1000, 32'h100,
            BEQ, 1'b0, 1'b0, 1'b0,  // Even though equal, branch=0
            32'h1100, 1'b0,
            "No operation: Equal but branch disabled"
        );

        // ====================================================================
        // Test Category 10: Edge Cases
        // ====================================================================
        $display("\n--- Test Category 10: Edge Cases ---");

        check_branch(
            32'h00000000, 32'h00000000, 32'h0, 32'h0,
            BEQ, 1'b1, 1'b0, 1'b0,
            32'h0, 1'b1,
            "Edge: All zeros → Taken"
        );

        check_branch(
            32'hFFFFFFFF, 32'hFFFFFFFF, 32'hFFFFFFFF, 32'hFFFFFFFF,
            BEQ, 1'b1, 1'b0, 1'b0,
            32'hFFFFFFFE, 1'b1,
            "Edge: All ones BEQ"
        );

        check_branch(
            32'h7FFFFFFF, 32'h80000000, 32'h1000, 32'h100,
            BLT, 1'b1, 1'b0, 1'b0,
            32'h1100, 1'b0,
            "Edge: MAX_INT < MIN_INT → Not taken (signed)"
        );

        check_branch(
            32'h7FFFFFFF, 32'h80000000, 32'h1000, 32'h100,
            BLTU, 1'b1, 1'b0, 1'b0,
            32'h1100, 1'b1,
            "Edge: MAX_INT < MIN_INT → Taken (unsigned)"
        );

        check_branch(
            32'hFFFFFFFF, 32'd0, 32'h1000, 32'h8,
            JALR, 1'b0, 1'b1, 1'b1,
            32'h6, 1'b1,
            "Edge: JALR wrap around and clear LSB"
        );

        // ====================================================================
        // Test Summary
        // ====================================================================
        #10;
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

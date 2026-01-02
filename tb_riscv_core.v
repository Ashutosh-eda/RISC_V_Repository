// ============================================================================
// Testbench for RISC-V 5-Stage Pipelined Processor Core
// Tests complete processor with instruction sequences
// Verifies: Pipeline operation, hazard detection, forwarding, branches
// Self-checking with register file inspection
// ============================================================================

`timescale 1ns / 1ps

module tb_riscv_core;

    // ========================================================================
    // DUT Signals
    // ========================================================================

    reg         clk;
    reg         rst_n;

    // Instruction Memory Interface
    wire [31:0] imem_addr;
    reg  [31:0] imem_rdata;
    wire        imem_req;

    // Data Memory Interface
    wire [31:0] dmem_addr;
    wire [31:0] dmem_wdata;
    reg  [31:0] dmem_rdata;
    wire        dmem_we;
    wire [3:0]  dmem_be;
    wire        dmem_req;

    // External Interrupt
    reg         ext_irq;

    // Debug/Status
    wire        halted;

    // ========================================================================
    // DUT Instantiation
    // ========================================================================

    riscv_core dut (
        .clk        (clk),
        .rst_n      (rst_n),
        .imem_addr  (imem_addr),
        .imem_rdata (imem_rdata),
        .imem_req   (imem_req),
        .dmem_addr  (dmem_addr),
        .dmem_wdata (dmem_wdata),
        .dmem_rdata (dmem_rdata),
        .dmem_we    (dmem_we),
        .dmem_be    (dmem_be),
        .dmem_req   (dmem_req),
        .ext_irq    (ext_irq),
        .halted     (halted)
    );

    // ========================================================================
    // Clock Generation
    // ========================================================================

    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 10ns period, 100MHz
    end

    // ========================================================================
    // Memory Models
    // ========================================================================

    // Instruction Memory (4KB)
    reg [31:0] imem [0:1023];

    // Data Memory (4KB)
    reg [31:0] dmem [0:1023];

    // Instruction Memory Read
    always @(*) begin
        if (imem_req) begin
            imem_rdata = imem[imem_addr[11:2]];
        end else begin
            imem_rdata = 32'h00000013;  // NOP (ADDI x0, x0, 0)
        end
    end

    // Data Memory Read/Write
    always @(posedge clk) begin
        if (dmem_req) begin
            if (dmem_we) begin
                // Write with byte enable
                if (dmem_be[0]) dmem[dmem_addr[11:2]][7:0]   <= dmem_wdata[7:0];
                if (dmem_be[1]) dmem[dmem_addr[11:2]][15:8]  <= dmem_wdata[15:8];
                if (dmem_be[2]) dmem[dmem_addr[11:2]][23:16] <= dmem_wdata[23:16];
                if (dmem_be[3]) dmem[dmem_addr[11:2]][31:24] <= dmem_wdata[31:24];
            end
            dmem_rdata <= dmem[dmem_addr[11:2]];
        end else begin
            dmem_rdata <= 32'd0;
        end
    end

    // ========================================================================
    // Test Infrastructure
    // ========================================================================

    integer test_count = 0;
    integer pass_count = 0;
    integer fail_count = 0;
    integer cycle_count = 0;

    // ========================================================================
    // RISC-V Instruction Encoding Helper Functions
    // ========================================================================

    // R-type: opcode[6:0] | rd[11:7] | funct3[14:12] | rs1[19:15] | rs2[24:20] | funct7[31:25]
    function [31:0] encode_r_type;
        input [6:0] opcode;
        input [4:0] rd, rs1, rs2;
        input [2:0] funct3;
        input [6:0] funct7;
        begin
            encode_r_type = {funct7, rs2, rs1, funct3, rd, opcode};
        end
    endfunction

    // I-type: opcode[6:0] | rd[11:7] | funct3[14:12] | rs1[19:15] | imm[31:20]
    function [31:0] encode_i_type;
        input [6:0] opcode;
        input [4:0] rd, rs1;
        input [2:0] funct3;
        input [11:0] imm;
        begin
            encode_i_type = {imm, rs1, funct3, rd, opcode};
        end
    endfunction

    // S-type: opcode[6:0] | imm[11:7] | funct3[14:12] | rs1[19:15] | rs2[24:20] | imm[31:25]
    function [31:0] encode_s_type;
        input [6:0] opcode;
        input [4:0] rs1, rs2;
        input [2:0] funct3;
        input [11:0] imm;
        begin
            encode_s_type = {imm[11:5], rs2, rs1, funct3, imm[4:0], opcode};
        end
    endfunction

    // B-type: opcode[6:0] | imm[11] | imm[4:1] | funct3[14:12] | rs1[19:15] | rs2[24:20] | imm[10:5] | imm[12]
    function [31:0] encode_b_type;
        input [6:0] opcode;
        input [4:0] rs1, rs2;
        input [2:0] funct3;
        input [12:0] imm;
        begin
            encode_b_type = {imm[12], imm[10:5], rs2, rs1, funct3, imm[4:1], imm[11], opcode};
        end
    endfunction

    // U-type: opcode[6:0] | rd[11:7] | imm[31:12]
    function [31:0] encode_u_type;
        input [6:0] opcode;
        input [4:0] rd;
        input [19:0] imm;
        begin
            encode_u_type = {imm, rd, opcode};
        end
    endfunction

    // J-type: opcode[6:0] | rd[11:7] | imm[19:12] | imm[11] | imm[10:1] | imm[20]
    function [31:0] encode_j_type;
        input [6:0] opcode;
        input [4:0] rd;
        input [20:0] imm;
        begin
            encode_j_type = {imm[20], imm[10:1], imm[11], imm[19:12], rd, opcode};
        end
    endfunction

    // ========================================================================
    // RISC-V Opcodes
    // ========================================================================

    localparam OP_LUI    = 7'b0110111;
    localparam OP_AUIPC  = 7'b0010111;
    localparam OP_JAL    = 7'b1101111;
    localparam OP_JALR   = 7'b1100111;
    localparam OP_BRANCH = 7'b1100011;
    localparam OP_LOAD   = 7'b0000011;
    localparam OP_STORE  = 7'b0100011;
    localparam OP_IMM    = 7'b0010011;
    localparam OP_REG    = 7'b0110011;
    localparam OP_FENCE  = 7'b0001111;
    localparam OP_SYSTEM = 7'b1110011;

    // ========================================================================
    // Common Instructions
    // ========================================================================

    function [31:0] NOP;
        begin
            NOP = encode_i_type(OP_IMM, 5'd0, 5'd0, 3'b000, 12'd0);  // ADDI x0, x0, 0
        end
    endfunction

    function [31:0] ADDI;
        input [4:0] rd, rs1;
        input [11:0] imm;
        begin
            ADDI = encode_i_type(OP_IMM, rd, rs1, 3'b000, imm);
        end
    endfunction

    function [31:0] ADD;
        input [4:0] rd, rs1, rs2;
        begin
            ADD = encode_r_type(OP_REG, rd, rs1, rs2, 3'b000, 7'b0000000);
        end
    endfunction

    function [31:0] SUB;
        input [4:0] rd, rs1, rs2;
        begin
            SUB = encode_r_type(OP_REG, rd, rs1, rs2, 3'b000, 7'b0100000);
        end
    endfunction

    function [31:0] AND_INST;
        input [4:0] rd, rs1, rs2;
        begin
            AND_INST = encode_r_type(OP_REG, rd, rs1, rs2, 3'b111, 7'b0000000);
        end
    endfunction

    function [31:0] OR_INST;
        input [4:0] rd, rs1, rs2;
        begin
            OR_INST = encode_r_type(OP_REG, rd, rs1, rs2, 3'b110, 7'b0000000);
        end
    endfunction

    function [31:0] XOR_INST;
        input [4:0] rd, rs1, rs2;
        begin
            XOR_INST = encode_r_type(OP_REG, rd, rs1, rs2, 3'b100, 7'b0000000);
        end
    endfunction

    function [31:0] SLL;
        input [4:0] rd, rs1, rs2;
        begin
            SLL = encode_r_type(OP_REG, rd, rs1, rs2, 3'b001, 7'b0000000);
        end
    endfunction

    function [31:0] SRL;
        input [4:0] rd, rs1, rs2;
        begin
            SRL = encode_r_type(OP_REG, rd, rs1, rs2, 3'b101, 7'b0000000);
        end
    endfunction

    function [31:0] SRA;
        input [4:0] rd, rs1, rs2;
        begin
            SRA = encode_r_type(OP_REG, rd, rs1, rs2, 3'b101, 7'b0100000);
        end
    endfunction

    function [31:0] LW;
        input [4:0] rd, rs1;
        input [11:0] offset;
        begin
            LW = encode_i_type(OP_LOAD, rd, rs1, 3'b010, offset);
        end
    endfunction

    function [31:0] SW;
        input [4:0] rs1, rs2;
        input [11:0] offset;
        begin
            SW = encode_s_type(OP_STORE, rs1, rs2, 3'b010, offset);
        end
    endfunction

    function [31:0] BEQ;
        input [4:0] rs1, rs2;
        input [12:0] offset;
        begin
            BEQ = encode_b_type(OP_BRANCH, rs1, rs2, 3'b000, offset);
        end
    endfunction

    function [31:0] BNE;
        input [4:0] rs1, rs2;
        input [12:0] offset;
        begin
            BNE = encode_b_type(OP_BRANCH, rs1, rs2, 3'b001, offset);
        end
    endfunction

    function [31:0] LUI_INST;
        input [4:0] rd;
        input [19:0] imm;
        begin
            LUI_INST = encode_u_type(OP_LUI, rd, imm);
        end
    endfunction

    // ========================================================================
    // Test Tasks
    // ========================================================================

    // Task: Load test program into instruction memory
    task load_program;
        integer i;
        begin
            // Initialize all instruction memory to NOPs
            for (i = 0; i < 1024; i = i + 1) begin
                imem[i] = NOP();
            end
        end
    endtask

    // Task: Run for N cycles
    task run_cycles;
        input integer n;
        integer i;
        begin
            for (i = 0; i < n; i = i + 1) begin
                @(posedge clk);
                cycle_count = cycle_count + 1;
            end
        end
    endtask

    // Task: Check register value (via internal path)
    task check_register;
        input [4:0] reg_num;
        input [31:0] expected;
        input [200:0] description;
        reg [31:0] actual;
        begin
            test_count = test_count + 1;

            // Access register file through hierarchy
            actual = dut.decode.rf.registers[reg_num];

            if (actual === expected) begin
                $display("[PASS] Test %0d: %s", test_count, description);
                $display("       x%0d = 0x%08h", reg_num, actual);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] Test %0d: %s", test_count, description);
                $display("       Expected: x%0d = 0x%08h", reg_num, expected);
                $display("       Got:      x%0d = 0x%08h", reg_num, actual);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // Task: Check memory value
    task check_memory;
        input [31:0] addr;
        input [31:0] expected;
        input [200:0] description;
        reg [31:0] actual;
        begin
            test_count = test_count + 1;
            actual = dmem[addr[11:2]];

            if (actual === expected) begin
                $display("[PASS] Test %0d: %s", test_count, description);
                $display("       MEM[0x%08h] = 0x%08h", addr, actual);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] Test %0d: %s", test_count, description);
                $display("       Expected: MEM[0x%08h] = 0x%08h", addr, expected);
                $display("       Got:      MEM[0x%08h] = 0x%08h", addr, actual);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // ========================================================================
    // Test Programs
    // ========================================================================

    initial begin
        $display("\n========================================");
        $display("RISC-V Core Integration Testbench");
        $display("========================================\n");

        // Initialize
        rst_n = 0;
        ext_irq = 0;
        cycle_count = 0;

        // Initialize memories
        load_program();

        // Reset sequence
        repeat(5) @(posedge clk);
        rst_n = 1;
        $display("Reset complete. Starting tests...\n");

        // ====================================================================
        // Test Program 1: Basic Arithmetic (No Hazards)
        // ====================================================================
        $display("\n--- Test Program 1: Basic Arithmetic (No Hazards) ---");

        // Program:
        // x1 = 5
        // x2 = 3
        // x3 = x1 + x2  (8)
        // x4 = x1 - x2  (2)
        // x5 = x3 & x4  (0)
        // x6 = x3 | x4  (10)

        imem[0] = ADDI(5'd1, 5'd0, 12'd5);      // x1 = 5
        imem[1] = ADDI(5'd2, 5'd0, 12'd3);      // x2 = 3
        imem[2] = NOP();                         // Avoid hazard
        imem[3] = ADD(5'd3, 5'd1, 5'd2);        // x3 = x1 + x2
        imem[4] = SUB(5'd4, 5'd1, 5'd2);        // x4 = x1 - x2
        imem[5] = NOP();                         // Avoid hazard
        imem[6] = AND_INST(5'd5, 5'd3, 5'd4);   // x5 = x3 & x4
        imem[7] = OR_INST(5'd6, 5'd3, 5'd4);    // x6 = x3 | x4
        imem[8] = NOP();
        imem[9] = NOP();

        run_cycles(15);  // Run through pipeline

        check_register(1, 32'd5, "x1 = 5");
        check_register(2, 32'd3, "x2 = 3");
        check_register(3, 32'd8, "x3 = x1 + x2 = 8");
        check_register(4, 32'd2, "x4 = x1 - x2 = 2");
        check_register(5, 32'd0, "x5 = x3 & x4 = 0");
        check_register(6, 32'd10, "x6 = x3 | x4 = 10");

        // ====================================================================
        // Test Program 2: Data Forwarding (EX-to-EX)
        // ====================================================================
        $display("\n--- Test Program 2: Data Forwarding ---");

        // Reset and load new program
        load_program();

        // Program with back-to-back dependencies:
        // x7 = 10
        // x8 = x7 + 5   (forward from EX)
        // x9 = x8 + 2   (forward from MEM)
        // x10 = x9 + 1  (forward from WB)

        imem[0] = ADDI(5'd7, 5'd0, 12'd10);     // x7 = 10
        imem[1] = ADDI(5'd8, 5'd7, 12'd5);      // x8 = x7 + 5 (needs forwarding!)
        imem[2] = ADDI(5'd9, 5'd8, 12'd2);      // x9 = x8 + 2 (needs forwarding!)
        imem[3] = ADDI(5'd10, 5'd9, 12'd1);     // x10 = x9 + 1 (needs forwarding!)
        imem[4] = NOP();

        run_cycles(10);

        check_register(7, 32'd10, "x7 = 10");
        check_register(8, 32'd15, "x8 = x7 + 5 = 15 (with forwarding)");
        check_register(9, 32'd17, "x9 = x8 + 2 = 17 (with forwarding)");
        check_register(10, 32'd18, "x10 = x9 + 1 = 18 (with forwarding)");

        // ====================================================================
        // Test Program 3: Load-Use Hazard (Stall Required)
        // ====================================================================
        $display("\n--- Test Program 3: Load-Use Hazard ---");

        load_program();
        dmem[0] = 32'd100;  // Initialize memory location

        // Program:
        // Store 100 to memory
        // Load from memory
        // Use loaded value (causes stall)

        imem[0] = ADDI(5'd11, 5'd0, 12'd100);   // x11 = 100
        imem[1] = SW(5'd0, 5'd11, 12'd0);       // MEM[0] = x11
        imem[2] = LW(5'd12, 5'd0, 12'd0);       // x12 = MEM[0]
        imem[3] = ADDI(5'd13, 5'd12, 12'd5);    // x13 = x12 + 5 (STALL!)
        imem[4] = NOP();

        run_cycles(15);  // Extra cycles for stall

        check_register(11, 32'd100, "x11 = 100");
        check_register(12, 32'd100, "x12 = MEM[0] = 100");
        check_register(13, 32'd105, "x13 = x12 + 5 = 105 (after stall)");

        // ====================================================================
        // Test Program 4: Branch Not Taken
        // ====================================================================
        $display("\n--- Test Program 4: Branch Not Taken ---");

        load_program();

        // Program:
        // x14 = 5
        // x15 = 10
        // if (x14 == x15) skip next instruction
        // x16 = 20  (should execute)

        imem[0] = ADDI(5'd14, 5'd0, 12'd5);     // x14 = 5
        imem[1] = ADDI(5'd15, 5'd0, 12'd10);    // x15 = 10
        imem[2] = BEQ(5'd14, 5'd15, 13'd8);     // if (x14 == x15) PC += 8 (NOT taken)
        imem[3] = ADDI(5'd16, 5'd0, 12'd20);    // x16 = 20 (should execute)
        imem[4] = NOP();

        run_cycles(12);

        check_register(14, 32'd5, "x14 = 5");
        check_register(15, 32'd10, "x15 = 10");
        check_register(16, 32'd20, "x16 = 20 (branch not taken)");

        // ====================================================================
        // Test Program 5: Branch Taken (Flush Pipeline)
        // ====================================================================
        $display("\n--- Test Program 5: Branch Taken ---");

        load_program();

        // Program:
        // x17 = 5
        // x18 = 5
        // if (x17 == x18) skip to imem[5]
        // x19 = 30 (should NOT execute - flushed)
        // x20 = 40 (should NOT execute - flushed)
        // x21 = 50 (branch target - should execute)

        imem[0] = ADDI(5'd17, 5'd0, 12'd5);     // x17 = 5
        imem[1] = ADDI(5'd18, 5'd0, 12'd5);     // x18 = 5
        imem[2] = BEQ(5'd17, 5'd18, 13'd8);     // if (x17 == x18) PC += 8 (TAKEN!)
        imem[3] = ADDI(5'd19, 5'd0, 12'd30);    // x19 = 30 (FLUSHED)
        imem[4] = ADDI(5'd20, 5'd0, 12'd40);    // x20 = 40 (FLUSHED)
        imem[5] = ADDI(5'd21, 5'd0, 12'd50);    // x21 = 50 (branch target)
        imem[6] = NOP();

        run_cycles(12);

        check_register(17, 32'd5, "x17 = 5");
        check_register(18, 32'd5, "x18 = 5");
        check_register(19, 32'd0, "x19 = 0 (instruction flushed)");
        check_register(20, 32'd0, "x20 = 0 (instruction flushed)");
        check_register(21, 32'd50, "x21 = 50 (branch target executed)");

        // ====================================================================
        // Test Program 6: Complex Forwarding Scenario
        // ====================================================================
        $display("\n--- Test Program 6: Complex Forwarding ---");

        load_program();

        // Program with multiple forwarding paths:
        // x22 = 1
        // x23 = 2
        // x24 = x22 + x23  (3, no forwarding needed)
        // x25 = x24 + x22  (4, forward x24 from MEM, x22 from WB)
        // x26 = x25 + x24  (7, forward x25 from MEM, x24 from WB)

        imem[0] = ADDI(5'd22, 5'd0, 12'd1);     // x22 = 1
        imem[1] = ADDI(5'd23, 5'd0, 12'd2);     // x23 = 2
        imem[2] = ADD(5'd24, 5'd22, 5'd23);     // x24 = x22 + x23 = 3
        imem[3] = ADD(5'd25, 5'd24, 5'd22);     // x25 = x24 + x22 = 4 (forward x24)
        imem[4] = ADD(5'd26, 5'd25, 5'd24);     // x26 = x25 + x24 = 7 (forward both)
        imem[5] = NOP();

        run_cycles(12);

        check_register(22, 32'd1, "x22 = 1");
        check_register(23, 32'd2, "x23 = 2");
        check_register(24, 32'd3, "x24 = 3");
        check_register(25, 32'd4, "x25 = 4 (with forwarding)");
        check_register(26, 32'd7, "x26 = 7 (with dual forwarding)");

        // ====================================================================
        // Test Program 7: Memory Operations
        // ====================================================================
        $display("\n--- Test Program 7: Memory Operations ---");

        load_program();

        // Program:
        // Write multiple values to memory
        // Read them back and verify

        imem[0] = ADDI(5'd27, 5'd0, 12'd123);   // x27 = 123
        imem[1] = ADDI(5'd28, 5'd0, 12'd4);     // x28 = 4 (address offset)
        imem[2] = SW(5'd0, 5'd27, 12'd0);       // MEM[0] = 123
        imem[3] = SW(5'd28, 5'd27, 12'd0);      // MEM[4] = 123
        imem[4] = NOP();
        imem[5] = LW(5'd29, 5'd0, 12'd0);       // x29 = MEM[0]
        imem[6] = LW(5'd30, 5'd28, 12'd0);      // x30 = MEM[4]
        imem[7] = NOP();

        run_cycles(15);

        check_register(27, 32'd123, "x27 = 123");
        check_register(29, 32'd123, "x29 = MEM[0] = 123");
        check_register(30, 32'd123, "x30 = MEM[4] = 123");
        check_memory(32'd0, 32'd123, "MEM[0] = 123");
        check_memory(32'd4, 32'd123, "MEM[4] = 123");

        // ====================================================================
        // Test Summary
        // ====================================================================
        run_cycles(5);

        $display("\n========================================");
        $display("Test Summary");
        $display("========================================");
        $display("Total Tests:  %0d", test_count);
        $display("Passed:       %0d", pass_count);
        $display("Failed:       %0d", fail_count);
        $display("Total Cycles: %0d", cycle_count);

        if (fail_count == 0) begin
            $display("\n*** ALL TESTS PASSED ***\n");
        end else begin
            $display("\n*** SOME TESTS FAILED ***\n");
        end

        $finish;
    end

    // ========================================================================
    // Pipeline Monitoring (Optional Debug)
    // ========================================================================

    always @(posedge clk) begin
        if (rst_n) begin
            $display("Cycle %0d: PC=0x%08h, Instr=0x%08h",
                     cycle_count, imem_addr, imem_rdata);
        end
    end

endmodule

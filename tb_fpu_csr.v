// ============================================================================
// Testbench for FPU CSR Module
// Tests RISC-V FP CSRs: fflags, frm, fcsr
// Verifies CSR operations: write, set, clear
// Tests sticky flag accumulation from FPU
// Self-checking with comprehensive test cases
// ============================================================================

`timescale 1ns / 1ps

module tb_fpu_csr;

    // ========================================================================
    // Clock and Reset
    // ========================================================================

    reg clk;
    reg rst_n;

    // ========================================================================
    // DUT Signals
    // ========================================================================

    // CSR access
    reg        csr_write;
    reg [11:0] csr_addr;
    reg [31:0] csr_wdata;
    reg [1:0]  csr_op;
    wire [31:0] csr_rdata;

    // FPU flags
    reg [4:0]  fpu_flags;
    reg        fpu_flags_valid;

    // Outputs
    wire [2:0]  frm_out;
    wire [4:0]  fflags_out;

    // ========================================================================
    // DUT Instantiation
    // ========================================================================

    fpu_csr dut (
        .clk(clk),
        .rst_n(rst_n),
        .csr_write(csr_write),
        .csr_addr(csr_addr),
        .csr_wdata(csr_wdata),
        .csr_op(csr_op),
        .csr_rdata(csr_rdata),
        .fpu_flags(fpu_flags),
        .fpu_flags_valid(fpu_flags_valid),
        .frm_out(frm_out),
        .fflags_out(fflags_out)
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

    // CSR addresses
    localparam CSR_FFLAGS = 12'h001;
    localparam CSR_FRM    = 12'h002;
    localparam CSR_FCSR   = 12'h003;

    // CSR operations
    localparam OP_WRITE = 2'b00;  // CSRRW
    localparam OP_SET   = 2'b01;  // CSRRS
    localparam OP_CLEAR = 2'b10;  // CSRRC

    // Exception flag bits
    localparam NV = 4;  // Invalid
    localparam DZ = 3;  // Divide by Zero
    localparam OF = 2;  // Overflow
    localparam UF = 1;  // Underflow
    localparam NX = 0;  // Inexact

    // ========================================================================
    // Test Tasks
    // ========================================================================

    task wait_cycle;
        begin
            @(posedge clk);
        end
    endtask

    task reset_inputs;
        begin
            csr_write = 1'b0;
            csr_addr = 12'd0;
            csr_wdata = 32'd0;
            csr_op = 2'b00;
            fpu_flags = 5'b00000;
            fpu_flags_valid = 1'b0;
        end
    endtask

    task write_csr;
        input [11:0] addr;
        input [31:0] data;
        input [1:0]  op;
        begin
            csr_write = 1'b1;
            csr_addr = addr;
            csr_wdata = data;
            csr_op = op;
            @(posedge clk);
            csr_write = 1'b0;
        end
    endtask

    task read_csr;
        input [11:0] addr;
        begin
            csr_addr = addr;
            #1;
        end
    endtask

    task check_csr;
        input [11:0]  addr;
        input [31:0]  exp_data;
        input [200:0] description;
        begin
            test_count = test_count + 1;
            read_csr(addr);

            if (csr_rdata === exp_data) begin
                $display("[PASS] Test %0d: %s", test_count, description);
                $display("       CSR[0x%h] = 0x%h", addr, csr_rdata);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] Test %0d: %s", test_count, description);
                $display("       Expected: CSR[0x%h] = 0x%h", addr, exp_data);
                $display("       Got:      CSR[0x%h] = 0x%h", addr, csr_rdata);
                fail_count = fail_count + 1;
            end
        end
    endtask

    task apply_fpu_flags;
        input [4:0] flags;
        begin
            fpu_flags = flags;
            fpu_flags_valid = 1'b1;
            @(posedge clk);
            fpu_flags_valid = 1'b0;
        end
    endtask

    // ========================================================================
    // Test Stimulus
    // ========================================================================

    initial begin
        $display("\n========================================");
        $display("FPU CSR Testbench");
        $display("========================================\n");

        // Initialize
        rst_n = 0;
        reset_inputs();

        repeat(3) @(posedge clk);
        rst_n = 1;
        @(posedge clk);

        // ====================================================================
        // Test Category 1: Reset Values
        // ====================================================================
        $display("\n--- Test Category 1: Reset Values ---");

        check_csr(
            CSR_FFLAGS, 32'h00000000,
            "Reset: fflags = 0x00000000"
        );

        check_csr(
            CSR_FRM, 32'h00000000,
            "Reset: frm = 0x00000000 (RNE mode)"
        );

        check_csr(
            CSR_FCSR, 32'h00000000,
            "Reset: fcsr = 0x00000000"
        );

        test_count = test_count + 1;
        if (frm_out === 3'b000 && fflags_out === 5'b00000) begin
            $display("[PASS] Test %0d: Output signals: frm=0, fflags=0", test_count);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Test %0d: Output signals incorrect", test_count);
            fail_count = fail_count + 1;
        end

        // ====================================================================
        // Test Category 2: Write FFLAGS (CSRRW)
        // ====================================================================
        $display("\n--- Test Category 2: Write FFLAGS ---");

        write_csr(CSR_FFLAGS, 32'h0000001F, OP_WRITE);  // All flags set
        check_csr(
            CSR_FFLAGS, 32'h0000001F,
            "CSRRW fflags: Write 0x1F (all flags)"
        );

        write_csr(CSR_FFLAGS, 32'h00000010, OP_WRITE);  // Only NV
        check_csr(
            CSR_FFLAGS, 32'h00000010,
            "CSRRW fflags: Write 0x10 (NV only)"
        );

        write_csr(CSR_FFLAGS, 32'h00000000, OP_WRITE);  // Clear all
        check_csr(
            CSR_FFLAGS, 32'h00000000,
            "CSRRW fflags: Write 0x00 (clear all)"
        );

        // ====================================================================
        // Test Category 3: Set FFLAGS (CSRRS)
        // ====================================================================
        $display("\n--- Test Category 3: Set FFLAGS Bits ---");

        write_csr(CSR_FFLAGS, 32'h00000000, OP_WRITE);  // Start clean
        write_csr(CSR_FFLAGS, 32'h00000004, OP_SET);    // Set OF
        check_csr(
            CSR_FFLAGS, 32'h00000004,
            "CSRRS fflags: Set OF (0x04)"
        );

        write_csr(CSR_FFLAGS, 32'h00000001, OP_SET);    // Set NX
        check_csr(
            CSR_FFLAGS, 32'h00000005,
            "CSRRS fflags: Set NX, now OF|NX (0x05)"
        );

        write_csr(CSR_FFLAGS, 32'h00000010, OP_SET);    // Set NV
        check_csr(
            CSR_FFLAGS, 32'h00000015,
            "CSRRS fflags: Set NV, now NV|OF|NX (0x15)"
        );

        // ====================================================================
        // Test Category 4: Clear FFLAGS (CSRRC)
        // ====================================================================
        $display("\n--- Test Category 4: Clear FFLAGS Bits ---");

        write_csr(CSR_FFLAGS, 32'h0000001F, OP_WRITE);  // All flags set
        write_csr(CSR_FFLAGS, 32'h00000004, OP_CLEAR);  // Clear OF
        check_csr(
            CSR_FFLAGS, 32'h0000001B,
            "CSRRC fflags: Clear OF, now 0x1B"
        );

        write_csr(CSR_FFLAGS, 32'h00000011, OP_CLEAR);  // Clear NV and NX
        check_csr(
            CSR_FFLAGS, 32'h0000000A,
            "CSRRC fflags: Clear NV|NX, now 0x0A (DZ|UF)"
        );

        write_csr(CSR_FFLAGS, 32'h0000001F, OP_CLEAR);  // Clear all
        check_csr(
            CSR_FFLAGS, 32'h00000000,
            "CSRRC fflags: Clear all, now 0x00"
        );

        // ====================================================================
        // Test Category 5: Write FRM (Rounding Mode)
        // ====================================================================
        $display("\n--- Test Category 5: Write FRM ---");

        write_csr(CSR_FRM, 32'h00000000, OP_WRITE);  // RNE
        check_csr(
            CSR_FRM, 32'h00000000,
            "CSRRW frm: RNE (0x0)"
        );

        write_csr(CSR_FRM, 32'h00000001, OP_WRITE);  // RTZ
        check_csr(
            CSR_FRM, 32'h00000001,
            "CSRRW frm: RTZ (0x1)"
        );

        write_csr(CSR_FRM, 32'h00000002, OP_WRITE);  // RDN
        check_csr(
            CSR_FRM, 32'h00000002,
            "CSRRW frm: RDN (0x2)"
        );

        write_csr(CSR_FRM, 32'h00000003, OP_WRITE);  // RUP
        check_csr(
            CSR_FRM, 32'h00000003,
            "CSRRW frm: RUP (0x3)"
        );

        write_csr(CSR_FRM, 32'h00000004, OP_WRITE);  // RMM
        check_csr(
            CSR_FRM, 32'h00000004,
            "CSRRW frm: RMM (0x4)"
        );

        // ====================================================================
        // Test Category 6: FRM Set and Clear Operations
        // ====================================================================
        $display("\n--- Test Category 6: FRM Set/Clear ---");

        write_csr(CSR_FRM, 32'h00000000, OP_WRITE);  // Start 000
        write_csr(CSR_FRM, 32'h00000003, OP_SET);    // Set bits 0,1
        check_csr(
            CSR_FRM, 32'h00000003,
            "CSRRS frm: Set bits, now 0x3"
        );

        write_csr(CSR_FRM, 32'h00000001, OP_CLEAR);  // Clear bit 0
        check_csr(
            CSR_FRM, 32'h00000002,
            "CSRRC frm: Clear bit 0, now 0x2"
        );

        // ====================================================================
        // Test Category 7: Write FCSR (Combined Register)
        // ====================================================================
        $display("\n--- Test Category 7: Write FCSR ---");

        write_csr(CSR_FCSR, 32'h000000E5, OP_WRITE);  // frm=0x7, fflags=0x05
        check_csr(
            CSR_FCSR, 32'h000000E5,
            "CSRRW fcsr: Write 0xE5 (frm=7, fflags=5)"
        );

        check_csr(
            CSR_FRM, 32'h00000007,
            "After FCSR write: frm = 0x7"
        );

        check_csr(
            CSR_FFLAGS, 32'h00000005,
            "After FCSR write: fflags = 0x05"
        );

        write_csr(CSR_FCSR, 32'h00000042, OP_WRITE);  // frm=0x2, fflags=0x02
        check_csr(
            CSR_FCSR, 32'h00000042,
            "CSRRW fcsr: Write 0x42 (frm=2, fflags=2)"
        );

        // ====================================================================
        // Test Category 8: FCSR Set and Clear
        // ====================================================================
        $display("\n--- Test Category 8: FCSR Set/Clear ---");

        write_csr(CSR_FCSR, 32'h00000000, OP_WRITE);  // Clear
        write_csr(CSR_FCSR, 32'h00000085, OP_SET);    // Set frm[2], fflags[2,0]
        check_csr(
            CSR_FCSR, 32'h00000085,
            "CSRRS fcsr: Set bits, now 0x85"
        );

        write_csr(CSR_FCSR, 32'h00000005, OP_CLEAR);  // Clear frm[0], fflags[2,0]
        check_csr(
            CSR_FCSR, 32'h00000080,
            "CSRRC fcsr: Clear bits, now 0x80"
        );

        // ====================================================================
        // Test Category 9: FPU Flag Accumulation (Sticky)
        // ====================================================================
        $display("\n--- Test Category 9: FPU Flag Accumulation ---");

        write_csr(CSR_FFLAGS, 32'h00000000, OP_WRITE);  // Clear flags

        apply_fpu_flags(5'b00001);  // NX (inexact)
        wait_cycle();
        check_csr(
            CSR_FFLAGS, 32'h00000001,
            "FPU flags: First operation sets NX"
        );

        apply_fpu_flags(5'b00100);  // OF (overflow)
        wait_cycle();
        check_csr(
            CSR_FFLAGS, 32'h00000005,
            "FPU flags: Second operation adds OF (sticky OR)"
        );

        apply_fpu_flags(5'b10000);  // NV (invalid)
        wait_cycle();
        check_csr(
            CSR_FFLAGS, 32'h00000015,
            "FPU flags: Third operation adds NV"
        );

        apply_fpu_flags(5'b00001);  // NX again (already set)
        wait_cycle();
        check_csr(
            CSR_FFLAGS, 32'h00000015,
            "FPU flags: Re-setting NX doesn't change (0x15)"
        );

        // ====================================================================
        // Test Category 10: FPU Flags Priority Over CSR Write
        // ====================================================================
        $display("\n--- Test Category 10: FPU Flags and CSR Write ---");

        write_csr(CSR_FFLAGS, 32'h00000000, OP_WRITE);
        apply_fpu_flags(5'b00010);  // UF
        wait_cycle();

        write_csr(CSR_FFLAGS, 32'h00000004, OP_SET);  // Set OF
        wait_cycle();
        check_csr(
            CSR_FFLAGS, 32'h00000006,
            "FPU flags + CSR: Both UF and OF set (0x06)"
        );

        // ====================================================================
        // Test Category 11: All Five Exception Flags
        // ====================================================================
        $display("\n--- Test Category 11: All Exception Flags ---");

        write_csr(CSR_FFLAGS, 32'h00000000, OP_WRITE);

        apply_fpu_flags(5'b10000);  // NV
        wait_cycle();
        apply_fpu_flags(5'b01000);  // DZ
        wait_cycle();
        apply_fpu_flags(5'b00100);  // OF
        wait_cycle();
        apply_fpu_flags(5'b00010);  // UF
        wait_cycle();
        apply_fpu_flags(5'b00001);  // NX
        wait_cycle();

        check_csr(
            CSR_FFLAGS, 32'h0000001F,
            "All five flags set: NV|DZ|OF|UF|NX (0x1F)"
        );

        // ====================================================================
        // Test Category 12: Invalid CSR Address
        // ====================================================================
        $display("\n--- Test Category 12: Invalid CSR Address ---");

        write_csr(12'hFFF, 32'hDEADBEEF, OP_WRITE);  // Invalid address
        check_csr(
            12'hFFF, 32'h00000000,
            "Invalid CSR read returns 0x00000000"
        );

        // Verify other CSRs unchanged
        check_csr(
            CSR_FFLAGS, 32'h0000001F,
            "After invalid write: fflags unchanged"
        );

        // ====================================================================
        // Test Category 13: Output Signal Verification
        // ====================================================================
        $display("\n--- Test Category 13: Output Signals ---");

        write_csr(CSR_FRM, 32'h00000003, OP_WRITE);
        write_csr(CSR_FFLAGS, 32'h0000000A, OP_WRITE);
        wait_cycle();

        test_count = test_count + 1;
        if (frm_out === 3'b011 && fflags_out === 5'b01010) begin
            $display("[PASS] Test %0d: Outputs: frm=0x3, fflags=0x0A", test_count);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Test %0d: Output signals incorrect", test_count);
            $display("       Expected: frm=0x3, fflags=0x0A");
            $display("       Got:      frm=0x%h, fflags=0x%h", frm_out, fflags_out);
            fail_count = fail_count + 1;
        end

        // ====================================================================
        // Test Category 14: Reset During Operation
        // ====================================================================
        $display("\n--- Test Category 14: Reset During Operation ---");

        write_csr(CSR_FCSR, 32'h000000FF, OP_WRITE);
        wait_cycle();

        rst_n = 0;
        @(posedge clk);
        rst_n = 1;
        @(posedge clk);

        check_csr(
            CSR_FCSR, 32'h00000000,
            "After reset: fcsr cleared to 0x00000000"
        );

        test_count = test_count + 1;
        if (frm_out === 3'b000 && fflags_out === 5'b00000) begin
            $display("[PASS] Test %0d: After reset: outputs cleared", test_count);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Test %0d: After reset: outputs not cleared", test_count);
            fail_count = fail_count + 1;
        end

        // ====================================================================
        // Test Category 15: Realistic Sequence
        // ====================================================================
        $display("\n--- Test Category 15: Realistic Sequence ---");

        // Setup rounding mode
        write_csr(CSR_FRM, 32'h00000001, OP_WRITE);  // RTZ

        // FPU operation causes overflow and inexact
        apply_fpu_flags(5'b00101);  // OF | NX
        wait_cycle();

        check_csr(
            CSR_FFLAGS, 32'h00000005,
            "Realistic: FPU overflow+inexact"
        );

        // Another operation causes underflow
        apply_fpu_flags(5'b00010);  // UF
        wait_cycle();

        check_csr(
            CSR_FFLAGS, 32'h00000007,
            "Realistic: Accumulated OF|UF|NX"
        );

        // Software clears flags
        write_csr(CSR_FFLAGS, 32'h00000000, OP_WRITE);
        check_csr(
            CSR_FFLAGS, 32'h00000000,
            "Realistic: Software clears flags"
        );

        check_csr(
            CSR_FRM, 32'h00000001,
            "Realistic: frm unchanged (RTZ)"
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

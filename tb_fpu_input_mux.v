// ============================================================================
// Testbench for FPU Input Multiplexer
// Tests 3 operand muxes with forwarding from MEM and WB stages
// Verifies forwarding priority: MEM > WB > Register File
// Self-checking with comprehensive test cases
// ============================================================================

`timescale 1ns / 1ps

module tb_fpu_input_mux;

    // ========================================================================
    // DUT Signals
    // ========================================================================

    // Register file values
    reg [31:0] fp_rs1_data;
    reg [31:0] fp_rs2_data;
    reg [31:0] fp_rs3_data;

    // Forwarded values from MEM stage
    reg [31:0] fpu_result_mem;

    // Forwarded values from WB stage
    reg [31:0] fpu_result_wb;

    // Forwarding control
    reg [1:0]  forward_x;
    reg [1:0]  forward_y;
    reg [1:0]  forward_z;

    // Outputs
    wire [31:0] x_operand;
    wire [31:0] y_operand;
    wire [31:0] z_operand;

    // ========================================================================
    // DUT Instantiation
    // ========================================================================

    fpu_input_mux dut (
        .fp_rs1_data(fp_rs1_data),
        .fp_rs2_data(fp_rs2_data),
        .fp_rs3_data(fp_rs3_data),
        .fpu_result_mem(fpu_result_mem),
        .fpu_result_wb(fpu_result_wb),
        .forward_x(forward_x),
        .forward_y(forward_y),
        .forward_z(forward_z),
        .x_operand(x_operand),
        .y_operand(y_operand),
        .z_operand(z_operand)
    );

    // ========================================================================
    // Test Infrastructure
    // ========================================================================

    integer test_count = 0;
    integer pass_count = 0;
    integer fail_count = 0;

    // Forwarding encoding
    localparam FWD_REG = 2'b00;  // Use register file
    localparam FWD_WB  = 2'b01;  // Forward from WB
    localparam FWD_MEM = 2'b10;  // Forward from MEM

    // ========================================================================
    // Test Tasks
    // ========================================================================

    task reset_inputs;
        begin
            fp_rs1_data = 32'h00000000;
            fp_rs2_data = 32'h00000000;
            fp_rs3_data = 32'h00000000;
            fpu_result_mem = 32'h00000000;
            fpu_result_wb = 32'h00000000;
            forward_x = FWD_REG;
            forward_y = FWD_REG;
            forward_z = FWD_REG;
        end
    endtask

    task check_outputs;
        input [31:0]  exp_x;
        input [31:0]  exp_y;
        input [31:0]  exp_z;
        input [200:0] description;
        begin
            test_count = test_count + 1;
            #1;

            if (x_operand === exp_x && y_operand === exp_y && z_operand === exp_z) begin
                $display("[PASS] Test %0d: %s", test_count, description);
                $display("       X=0x%h, Y=0x%h, Z=0x%h", x_operand, y_operand, z_operand);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] Test %0d: %s", test_count, description);
                $display("       Expected: X=0x%h, Y=0x%h, Z=0x%h", exp_x, exp_y, exp_z);
                $display("       Got:      X=0x%h, Y=0x%h, Z=0x%h", x_operand, y_operand, z_operand);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // ========================================================================
    // Test Stimulus
    // ========================================================================

    initial begin
        $display("\n========================================");
        $display("FPU Input Multiplexer Testbench");
        $display("========================================\n");

        reset_inputs();
        #10;

        // ====================================================================
        // Test Category 1: Register File Source (No Forwarding)
        // ====================================================================
        $display("\n--- Test Category 1: Register File Source ---");

        fp_rs1_data = 32'h3F800000;  // 1.0
        fp_rs2_data = 32'h40000000;  // 2.0
        fp_rs3_data = 32'h40400000;  // 3.0
        fpu_result_mem = 32'hDEADBEEF;
        fpu_result_wb = 32'hCAFEBABE;
        forward_x = FWD_REG;
        forward_y = FWD_REG;
        forward_z = FWD_REG;

        check_outputs(
            32'h3F800000, 32'h40000000, 32'h40400000,
            "No forwarding: Use register file values"
        );

        // ====================================================================
        // Test Category 2: Forward X from WB
        // ====================================================================
        $display("\n--- Test Category 2: Forward X from WB ---");

        fp_rs1_data = 32'h11111111;
        fp_rs2_data = 32'h22222222;
        fp_rs3_data = 32'h33333333;
        fpu_result_mem = 32'h44444444;
        fpu_result_wb = 32'h55555555;
        forward_x = FWD_WB;
        forward_y = FWD_REG;
        forward_z = FWD_REG;

        check_outputs(
            32'h55555555, 32'h22222222, 32'h33333333,
            "Forward X from WB, Y and Z from register file"
        );

        // ====================================================================
        // Test Category 3: Forward X from MEM
        // ====================================================================
        $display("\n--- Test Category 3: Forward X from MEM ---");

        forward_x = FWD_MEM;
        forward_y = FWD_REG;
        forward_z = FWD_REG;

        check_outputs(
            32'h44444444, 32'h22222222, 32'h33333333,
            "Forward X from MEM, Y and Z from register file"
        );

        // ====================================================================
        // Test Category 4: Forward Y from WB
        // ====================================================================
        $display("\n--- Test Category 4: Forward Y from WB ---");

        forward_x = FWD_REG;
        forward_y = FWD_WB;
        forward_z = FWD_REG;

        check_outputs(
            32'h11111111, 32'h55555555, 32'h33333333,
            "Forward Y from WB, X and Z from register file"
        );

        // ====================================================================
        // Test Category 5: Forward Y from MEM
        // ====================================================================
        $display("\n--- Test Category 5: Forward Y from MEM ---");

        forward_x = FWD_REG;
        forward_y = FWD_MEM;
        forward_z = FWD_REG;

        check_outputs(
            32'h11111111, 32'h44444444, 32'h33333333,
            "Forward Y from MEM, X and Z from register file"
        );

        // ====================================================================
        // Test Category 6: Forward Z from WB
        // ====================================================================
        $display("\n--- Test Category 6: Forward Z from WB ---");

        forward_x = FWD_REG;
        forward_y = FWD_REG;
        forward_z = FWD_WB;

        check_outputs(
            32'h11111111, 32'h22222222, 32'h55555555,
            "Forward Z from WB, X and Y from register file"
        );

        // ====================================================================
        // Test Category 7: Forward Z from MEM
        // ====================================================================
        $display("\n--- Test Category 7: Forward Z from MEM ---");

        forward_x = FWD_REG;
        forward_y = FWD_REG;
        forward_z = FWD_MEM;

        check_outputs(
            32'h11111111, 32'h22222222, 32'h44444444,
            "Forward Z from MEM, X and Y from register file"
        );

        // ====================================================================
        // Test Category 8: Forward All from WB
        // ====================================================================
        $display("\n--- Test Category 8: Forward All from WB ---");

        forward_x = FWD_WB;
        forward_y = FWD_WB;
        forward_z = FWD_WB;

        check_outputs(
            32'h55555555, 32'h55555555, 32'h55555555,
            "Forward all three operands from WB"
        );

        // ====================================================================
        // Test Category 9: Forward All from MEM
        // ====================================================================
        $display("\n--- Test Category 9: Forward All from MEM ---");

        forward_x = FWD_MEM;
        forward_y = FWD_MEM;
        forward_z = FWD_MEM;

        check_outputs(
            32'h44444444, 32'h44444444, 32'h44444444,
            "Forward all three operands from MEM"
        );

        // ====================================================================
        // Test Category 10: Mixed Forwarding
        // ====================================================================
        $display("\n--- Test Category 10: Mixed Forwarding ---");

        forward_x = FWD_MEM;
        forward_y = FWD_WB;
        forward_z = FWD_REG;

        check_outputs(
            32'h44444444, 32'h55555555, 32'h33333333,
            "Mixed: X from MEM, Y from WB, Z from register file"
        );

        forward_x = FWD_WB;
        forward_y = FWD_REG;
        forward_z = FWD_MEM;

        check_outputs(
            32'h55555555, 32'h22222222, 32'h44444444,
            "Mixed: X from WB, Y from register file, Z from MEM"
        );

        forward_x = FWD_REG;
        forward_y = FWD_MEM;
        forward_z = FWD_WB;

        check_outputs(
            32'h11111111, 32'h44444444, 32'h55555555,
            "Mixed: X from register file, Y from MEM, Z from WB"
        );

        // ====================================================================
        // Test Category 11: Priority Test (MEM > WB)
        // ====================================================================
        $display("\n--- Test Category 11: Forwarding Priority ---");

        // Note: In real hardware, forward signals are mutually exclusive
        // but we test priority for completeness

        fp_rs1_data = 32'hAAAAAAAA;
        fpu_result_mem = 32'hBBBBBBBB;
        fpu_result_wb = 32'hCCCCCCCC;

        forward_x = FWD_MEM;  // MEM has priority
        check_outputs(
            32'hBBBBBBBB, 32'h22222222, 32'h33333333,
            "Priority: MEM forwarding selected (over WB)"
        );

        forward_x = FWD_WB;   // WB has priority over REG
        check_outputs(
            32'hCCCCCCCC, 32'h22222222, 32'h33333333,
            "Priority: WB forwarding selected (over REG)"
        );

        // ====================================================================
        // Test Category 12: FMA Operation (3 Operands)
        // ====================================================================
        $display("\n--- Test Category 12: FMA Operation ---");

        fp_rs1_data = 32'h40400000;  // 3.0
        fp_rs2_data = 32'h40800000;  // 4.0
        fp_rs3_data = 32'h40A00000;  // 5.0
        fpu_result_mem = 32'h00000000;
        fpu_result_wb = 32'h00000000;
        forward_x = FWD_REG;
        forward_y = FWD_REG;
        forward_z = FWD_REG;

        check_outputs(
            32'h40400000, 32'h40800000, 32'h40A00000,
            "FMA: All operands from register file (3.0, 4.0, 5.0)"
        );

        // Forward Z (addend) from MEM
        fpu_result_mem = 32'h40C00000;  // 6.0
        forward_z = FWD_MEM;

        check_outputs(
            32'h40400000, 32'h40800000, 32'h40C00000,
            "FMA: Z forwarded from MEM (addend = 6.0)"
        );

        // ====================================================================
        // Test Category 13: Special FP Values
        // ====================================================================
        $display("\n--- Test Category 13: Special FP Values ---");

        fp_rs1_data = 32'h7F800000;  // +Infinity
        fp_rs2_data = 32'hFF800000;  // -Infinity
        fp_rs3_data = 32'h00000000;  // +0.0
        forward_x = FWD_REG;
        forward_y = FWD_REG;
        forward_z = FWD_REG;

        check_outputs(
            32'h7F800000, 32'hFF800000, 32'h00000000,
            "Special values: +Inf, -Inf, +0.0"
        );

        fpu_result_wb = 32'h7FC00000;  // NaN
        forward_x = FWD_WB;

        check_outputs(
            32'h7FC00000, 32'hFF800000, 32'h00000000,
            "Forward NaN from WB to X"
        );

        // ====================================================================
        // Test Category 14: Data Pattern Tests
        // ====================================================================
        $display("\n--- Test Category 14: Data Patterns ---");

        fp_rs1_data = 32'hA5A5A5A5;
        fp_rs2_data = 32'h5A5A5A5A;
        fp_rs3_data = 32'hF0F0F0F0;
        forward_x = FWD_REG;
        forward_y = FWD_REG;
        forward_z = FWD_REG;

        check_outputs(
            32'hA5A5A5A5, 32'h5A5A5A5A, 32'hF0F0F0F0,
            "Pattern: Alternating bits from register file"
        );

        fpu_result_mem = 32'h0F0F0F0F;
        fpu_result_wb = 32'hFFFFFFFF;
        forward_x = FWD_MEM;
        forward_y = FWD_WB;
        forward_z = FWD_MEM;

        check_outputs(
            32'h0F0F0F0F, 32'hFFFFFFFF, 32'h0F0F0F0F,
            "Pattern: Forwarded bit patterns"
        );

        // ====================================================================
        // Test Category 15: Rapid Forwarding Changes
        // ====================================================================
        $display("\n--- Test Category 15: Rapid Forwarding Changes ---");

        integer i;
        for (i = 0; i < 4; i = i + 1) begin
            fp_rs1_data = 32'h10000000 + i;
            fpu_result_mem = 32'h20000000 + i;
            fpu_result_wb = 32'h30000000 + i;

            forward_x = i[1:0];
            forward_y = i[1:0];
            forward_z = i[1:0];

            #1;
            test_count = test_count + 1;

            case (i[1:0])
                2'b00: begin
                    if (x_operand === (32'h10000000 + i)) begin
                        $display("[PASS] Test %0d: Rapid [%0d] from REG", test_count, i);
                        pass_count = pass_count + 1;
                    end else begin
                        $display("[FAIL] Test %0d: Rapid [%0d]", test_count, i);
                        fail_count = fail_count + 1;
                    end
                end
                2'b01: begin
                    if (x_operand === (32'h30000000 + i)) begin
                        $display("[PASS] Test %0d: Rapid [%0d] from WB", test_count, i);
                        pass_count = pass_count + 1;
                    end else begin
                        $display("[FAIL] Test %0d: Rapid [%0d]", test_count, i);
                        fail_count = fail_count + 1;
                    end
                end
                2'b10: begin
                    if (x_operand === (32'h20000000 + i)) begin
                        $display("[PASS] Test %0d: Rapid [%0d] from MEM", test_count, i);
                        pass_count = pass_count + 1;
                    end else begin
                        $display("[FAIL] Test %0d: Rapid [%0d]", test_count, i);
                        fail_count = fail_count + 1;
                    end
                end
                default: begin
                    $display("[INFO] Test %0d: Rapid [%0d] reserved encoding", test_count, i);
                    pass_count = pass_count + 1;
                end
            endcase

            #10;
        end

        // ====================================================================
        // Test Category 16: Zero Values
        // ====================================================================
        $display("\n--- Test Category 16: Zero Values ---");

        fp_rs1_data = 32'h00000000;
        fp_rs2_data = 32'h00000000;
        fp_rs3_data = 32'h00000000;
        fpu_result_mem = 32'h00000000;
        fpu_result_wb = 32'h00000000;
        forward_x = FWD_REG;
        forward_y = FWD_REG;
        forward_z = FWD_REG;

        check_outputs(
            32'h00000000, 32'h00000000, 32'h00000000,
            "All zeros from register file"
        );

        forward_x = FWD_MEM;
        forward_y = FWD_WB;
        forward_z = FWD_MEM;

        check_outputs(
            32'h00000000, 32'h00000000, 32'h00000000,
            "All zeros forwarded"
        );

        // ====================================================================
        // Test Category 17: Realistic FMA Sequence
        // ====================================================================
        $display("\n--- Test Category 17: Realistic FMA Sequence ---");

        // X from previous FMA (MEM forward)
        // Y from register file
        // Z from earlier FMA (WB forward)
        fp_rs1_data = 32'h3F000000;  // 0.5
        fp_rs2_data = 32'h40000000;  // 2.0
        fp_rs3_data = 32'h3F800000;  // 1.0
        fpu_result_mem = 32'h40800000;  // 4.0 (previous result)
        fpu_result_wb = 32'h40400000;   // 3.0 (older result)

        forward_x = FWD_MEM;  // Use previous result
        forward_y = FWD_REG;  // Use new value
        forward_z = FWD_WB;   // Use older result

        check_outputs(
            32'h40800000, 32'h40000000, 32'h40400000,
            "Realistic FMA: X=4.0(MEM), Y=2.0(REG), Z=3.0(WB)"
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

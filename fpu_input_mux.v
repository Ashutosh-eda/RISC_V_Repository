// ============================================================================
// FPU Input Multiplexer with Forwarding
// Selects between register file values and forwarded values from MEM/WB stages
// Implements 4:1 muxes for each of the three FPU operands (X, Y, Z)
// ============================================================================

module fpu_input_mux (
    // Values from FP register file (default source)
    input  wire [31:0] fp_rs1_data,
    input  wire [31:0] fp_rs2_data,
    input  wire [31:0] fp_rs3_data,

    // Forwarded values from MEM stage
    input  wire [31:0] fpu_result_mem,

    // Forwarded values from WB stage
    input  wire [31:0] fpu_result_wb,

    // Forwarding control signals
    input  wire [1:0]  forward_x,
    input  wire [1:0]  forward_y,
    input  wire [1:0]  forward_z,

    // Output: Selected operands for FPU
    output wire [31:0] x_operand,
    output wire [31:0] y_operand,
    output wire [31:0] z_operand
);

    // ========================================================================
    // Forwarding Multiplexer Encoding
    // ========================================================================
    // 00: Use FP register file value
    // 01: Forward from WB stage
    // 10: Forward from MEM stage
    // 11: Reserved (should not occur)

    // ========================================================================
    // X Operand Mux (rs1)
    // ========================================================================
    assign x_operand = (forward_x == 2'b10) ? fpu_result_mem :  // MEM forward
                       (forward_x == 2'b01) ? fpu_result_wb  :  // WB forward
                                              fp_rs1_data;      // Register file

    // ========================================================================
    // Y Operand Mux (rs2)
    // ========================================================================
    assign y_operand = (forward_y == 2'b10) ? fpu_result_mem :
                       (forward_y == 2'b01) ? fpu_result_wb  :
                                              fp_rs2_data;

    // ========================================================================
    // Z Operand Mux (rs3)
    // ========================================================================
    assign z_operand = (forward_z == 2'b10) ? fpu_result_mem :
                       (forward_z == 2'b01) ? fpu_result_wb  :
                                              fp_rs3_data;

endmodule

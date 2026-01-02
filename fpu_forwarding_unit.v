// ============================================================================
// FPU Forwarding Unit
// Controls forwarding of FPU results from MEM and WB stages back to EX stage
// Similar to integer forwarding, but for floating-point operations
// Reduces pipeline stalls by allowing early use of FPU results
// ============================================================================

module fpu_forwarding_unit (
    // Source register addresses (from ID/EX register)
    input  wire [4:0]  rs1_ex,
    input  wire [4:0]  rs2_ex,
    input  wire [4:0]  rs3_ex,

    // Destination registers in later stages
    input  wire [4:0]  rd_mem,
    input  wire [4:0]  rd_wb,

    // FP register write enables
    input  wire        fp_reg_write_mem,
    input  wire        fp_reg_write_wb,

    // Stage information from scoreboard
    input  wire [1:0]  rs1_stage,
    input  wire [1:0]  rs2_stage,
    input  wire [1:0]  rs3_stage,

    // Forwarding control outputs
    output wire [1:0]  forward_x,  // Forwarding control for X (rs1)
    output wire [1:0]  forward_y,  // Forwarding control for Y (rs2)
    output wire [1:0]  forward_z   // Forwarding control for Z (rs3)
);

    // ========================================================================
    // Forwarding Control Encoding
    // ========================================================================
    // 00: Use value from FP register file (no forwarding)
    // 01: Forward from WB stage
    // 10: Forward from MEM stage
    // 11: Reserved (should not occur - would mean still in EX, should stall)

    // ========================================================================
    // Forwarding Logic for X (rs1)
    // ========================================================================
    // Priority: MEM > WB > Register File

    wire rs1_match_mem = (rs1_ex == rd_mem) && fp_reg_write_mem && (rs1_ex != 5'd0);
    wire rs1_match_wb  = (rs1_ex == rd_wb)  && fp_reg_write_wb  && (rs1_ex != 5'd0);

    assign forward_x = rs1_match_mem ? 2'b10 :  // Forward from MEM
                       rs1_match_wb  ? 2'b01 :  // Forward from WB
                                       2'b00;   // Use register file

    // ========================================================================
    // Forwarding Logic for Y (rs2)
    // ========================================================================

    wire rs2_match_mem = (rs2_ex == rd_mem) && fp_reg_write_mem && (rs2_ex != 5'd0);
    wire rs2_match_wb  = (rs2_ex == rd_wb)  && fp_reg_write_wb  && (rs2_ex != 5'd0);

    assign forward_y = rs2_match_mem ? 2'b10 :
                       rs2_match_wb  ? 2'b01 :
                                       2'b00;

    // ========================================================================
    // Forwarding Logic for Z (rs3)
    // ========================================================================

    wire rs3_match_mem = (rs3_ex == rd_mem) && fp_reg_write_mem && (rs3_ex != 5'd0);
    wire rs3_match_wb  = (rs3_ex == rd_wb)  && fp_reg_write_wb  && (rs3_ex != 5'd0);

    assign forward_z = rs3_match_mem ? 2'b10 :
                       rs3_match_wb  ? 2'b01 :
                                       2'b00;

endmodule

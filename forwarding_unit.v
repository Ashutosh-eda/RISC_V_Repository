// ============================================================================
// Forwarding Unit
// - Detects data hazards that can be resolved by forwarding
// - Generates forwarding control signals for EX stage
// - Forward paths: EX→EX (from MEM), MEM→EX (from WB)
// ============================================================================

module forwarding_unit (
    // From ID/EX Register
    input  wire [4:0]  rs1_ex,
    input  wire [4:0]  rs2_ex,

    // From EX/MEM Register
    input  wire [4:0]  rd_mem,
    input  wire        reg_write_mem,

    // From MEM/WB Register
    input  wire [4:0]  rd_wb,
    input  wire        reg_write_wb,

    // Forwarding Control Signals
    output reg  [1:0]  forward_a,    // For rs1
    output reg  [1:0]  forward_b     // For rs2
);

    // ========================================================================
    // Forwarding Encoding
    // 00: No forwarding (use value from ID/EX)
    // 01: Forward from WB stage (MEM/WB)
    // 10: Forward from MEM stage (EX/MEM)
    // ========================================================================

    // ========================================================================
    // Forward A (rs1) Logic
    // ========================================================================

    always @(*) begin
        // Priority: EX hazard (MEM) > MEM hazard (WB) > No hazard
        if (reg_write_mem && (rd_mem != 5'd0) && (rd_mem == rs1_ex)) begin
            // EX hazard: Forward from MEM stage
            forward_a = 2'b10;
        end
        else if (reg_write_wb && (rd_wb != 5'd0) && (rd_wb == rs1_ex)) begin
            // MEM hazard: Forward from WB stage
            forward_a = 2'b01;
        end
        else begin
            // No hazard
            forward_a = 2'b00;
        end
    end

    // ========================================================================
    // Forward B (rs2) Logic
    // ========================================================================

    always @(*) begin
        // Priority: EX hazard (MEM) > MEM hazard (WB) > No hazard
        if (reg_write_mem && (rd_mem != 5'd0) && (rd_mem == rs2_ex)) begin
            // EX hazard: Forward from MEM stage
            forward_b = 2'b10;
        end
        else if (reg_write_wb && (rd_wb != 5'd0) && (rd_wb == rs2_ex)) begin
            // MEM hazard: Forward from WB stage
            forward_b = 2'b01;
        end
        else begin
            // No hazard
            forward_b = 2'b00;
        end
    end

endmodule

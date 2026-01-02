// ============================================================================
// Writeback Stage (WB)
// - Selects final data to write back to register file
// - Multiplexes between ALU result, memory data, and FPU result
// ============================================================================

module writeback_stage (
    // From MEM/WB Register
    input  wire [31:0] alu_result_wb,
    input  wire [31:0] mem_rdata_wb,
    input  wire [31:0] fpu_result_wb,
    input  wire        mem_to_reg_wb,
    input  wire        fp_op_wb,

    // Output to register files
    output reg  [31:0] wb_data
);

    // ========================================================================
    // Writeback Data Selection
    // Priority: Memory > FPU > ALU
    // ========================================================================

    always @(*) begin
        if (mem_to_reg_wb) begin
            // Load instruction - use memory data
            wb_data = mem_rdata_wb;
        end
        else if (fp_op_wb) begin
            // FP instruction - use FPU result
            wb_data = fpu_result_wb;
        end
        else begin
            // ALU instruction - use ALU result
            wb_data = alu_result_wb;
        end
    end

endmodule

// ============================================================================
// Hazard Detection Unit
// - Detects pipeline hazards (RAW, control)
// - Generates stall and flush signals
// - Handles load-use hazards
// - Handles branch/jump hazards
// - Handles FPU hazards (from FPU scoreboard)
// ============================================================================

module hazard_unit (
    // From Decode Stage
    input  wire [4:0]  rs1_id,
    input  wire [4:0]  rs2_id,

    // From Execute Stage
    input  wire [4:0]  rd_ex,
    input  wire        mem_read_ex,
    input  wire        reg_write_ex,

    // From Memory Stage
    input  wire [4:0]  rd_mem,
    input  wire        reg_write_mem,

    // From Writeback Stage
    input  wire [4:0]  rd_wb,
    input  wire        reg_write_wb,

    // Branch/Jump Control
    input  wire        branch_taken,

    // FPU Hazard (from FPU Scoreboard)
    input  wire        stall_fpu,

    // Hazard Control Outputs
    output reg         stall_if,
    output reg         stall_id,
    output reg         flush_id,
    output reg         flush_ex
);

    // ========================================================================
    // Load-Use Hazard Detection
    // Occurs when an instruction tries to use data from a preceding load
    // before the load completes (data not available until MEM stage)
    // ========================================================================

    wire load_use_hazard;

    assign load_use_hazard = mem_read_ex &&
                             ((rd_ex == rs1_id && rs1_id != 5'd0) ||
                              (rd_ex == rs2_id && rs2_id != 5'd0));

    // ========================================================================
    // Control Hazard (Branch/Jump)
    // When a branch/jump is taken, flush instructions in IF and ID stages
    // ========================================================================

    // ========================================================================
    // Stall Control
    // Stall if: load-use hazard OR FPU hazard
    // ========================================================================

    always @(*) begin
        if (load_use_hazard || stall_fpu) begin
            // Stall IF and ID stages for one cycle
            stall_if = 1'b1;
            stall_id = 1'b1;
        end
        else begin
            stall_if = 1'b0;
            stall_id = 1'b0;
        end
    end

    // ========================================================================
    // Flush Control
    // ========================================================================

    always @(*) begin
        if (branch_taken) begin
            // Flush IF/ID and ID/EX registers (convert to NOPs)
            flush_id = 1'b1;
            flush_ex = 1'b1;
        end
        else if (load_use_hazard || stall_fpu) begin
            // Insert bubble in EX stage (flush ID/EX)
            flush_id = 1'b0;
            flush_ex = 1'b1;
        end
        else begin
            flush_id = 1'b0;
            flush_ex = 1'b0;
        end
    end

endmodule

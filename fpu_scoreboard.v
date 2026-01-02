// ============================================================================
// FPU Scoreboard with Forwarding Support
// Tracks which FP registers are busy and which pipeline stage has the result
// Supports forwarding from MEM and WB stages
// Only stalls if result is still in EX stage (too early to forward)
// ============================================================================

module fpu_scoreboard (
    input  wire        clk,
    input  wire        rst_n,

    // From Decode Stage
    input  wire        fp_op_id,      // FP operation in ID stage
    input  wire [4:0]  rs1_id,        // Source register 1
    input  wire [4:0]  rs2_id,        // Source register 2
    input  wire [4:0]  rs3_id,        // Source register 3 (for FMA)
    input  wire        fma_op_id,     // FMA operation (uses rs3)

    // From Execute Stage
    input  wire        fp_op_ex,      // FP operation entering pipeline
    input  wire [4:0]  rd_ex,         // Destination register
    input  wire [2:0]  latency_ex,    // Operation latency (4/5/6 cycles)
    input  wire        flush_ex,      // Pipeline flush

    // From Memory Stage (for forwarding check)
    input  wire [4:0]  rd_mem,        // Destination register in MEM
    input  wire        fp_reg_write_mem, // FP register write in MEM

    // From Writeback Stage (for forwarding check)
    input  wire [4:0]  rd_wb,         // Destination register in WB
    input  wire        fp_reg_write_wb,  // FP register write in WB

    // Output: Hazard Detection
    output wire        stall_fpu,     // Stall due to FPU hazard
    output wire [1:0]  rs1_stage,     // Which stage has rs1 result (for forwarding unit)
    output wire [1:0]  rs2_stage,     // Which stage has rs2 result
    output wire [1:0]  rs3_stage      // Which stage has rs3 result
);

    // ========================================================================
    // Scoreboard: Busy Bits and Latency Counters
    // ========================================================================
    reg [31:0] fp_busy;               // 1 bit per FP register (f0-f31)
    reg [2:0]  fp_latency [0:31];     // Remaining cycles until ready

    integer i;

    // ========================================================================
    // Update Scoreboard
    // ========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fp_busy <= 32'd0;
            for (i = 0; i < 32; i = i + 1) begin
                fp_latency[i] <= 3'd0;
            end
        end
        else begin
            // Start new FP operation
            if (fp_op_ex && !flush_ex) begin
                fp_busy[rd_ex] <= 1'b1;
                fp_latency[rd_ex] <= latency_ex;
            end

            // Decrement latency counters and clear busy bits
            for (i = 0; i < 32; i = i + 1) begin
                if (fp_busy[i]) begin
                    if (fp_latency[i] == 3'd1) begin
                        // Operation completes next cycle
                        fp_busy[i] <= 1'b0;
                        fp_latency[i] <= 3'd0;
                    end
                    else begin
                        fp_latency[i] <= fp_latency[i] - 3'd1;
                    end
                end
            end
        end
    end

    // ========================================================================
    // Stage Detection Logic
    // ========================================================================
    // Determine which pipeline stage has each source register's result
    // Stage encoding: 00 = None (use reg file), 01 = WB, 10 = MEM, 11 = EX

    // Helper wires for checking dependencies
    wire rs1_in_ex  = fp_op_id && fp_busy[rs1_id] && (rs1_id == rd_ex) && fp_op_ex;
    wire rs1_in_mem = fp_op_id && (rs1_id == rd_mem) && fp_reg_write_mem;
    wire rs1_in_wb  = fp_op_id && (rs1_id == rd_wb) && fp_reg_write_wb;

    wire rs2_in_ex  = fp_op_id && fp_busy[rs2_id] && (rs2_id == rd_ex) && fp_op_ex;
    wire rs2_in_mem = fp_op_id && (rs2_id == rd_mem) && fp_reg_write_mem;
    wire rs2_in_wb  = fp_op_id && (rs2_id == rd_wb) && fp_reg_write_wb;

    wire rs3_in_ex  = fma_op_id && fp_busy[rs3_id] && (rs3_id == rd_ex) && fp_op_ex;
    wire rs3_in_mem = fma_op_id && (rs3_id == rd_mem) && fp_reg_write_mem;
    wire rs3_in_wb  = fma_op_id && (rs3_id == rd_wb) && fp_reg_write_wb;

    // Stage assignment (priority: EX > MEM > WB > None)
    assign rs1_stage = rs1_in_ex  ? 2'b11 :
                       rs1_in_mem ? 2'b10 :
                       rs1_in_wb  ? 2'b01 :
                                    2'b00;

    assign rs2_stage = rs2_in_ex  ? 2'b11 :
                       rs2_in_mem ? 2'b10 :
                       rs2_in_wb  ? 2'b01 :
                                    2'b00;

    assign rs3_stage = rs3_in_ex  ? 2'b11 :
                       rs3_in_mem ? 2'b10 :
                       rs3_in_wb  ? 2'b01 :
                                    2'b00;

    // ========================================================================
    // Hazard Detection with Forwarding Support
    // ========================================================================
    // Only stall if result is in EX stage (can't forward yet)
    // If result is in MEM or WB, forwarding unit will handle it

    wire rs1_hazard = rs1_in_ex;  // Stall only if in EX
    wire rs2_hazard = rs2_in_ex;
    wire rs3_hazard = rs3_in_ex;

    assign stall_fpu = rs1_hazard | rs2_hazard | rs3_hazard;

endmodule

// ============================================================================
// MEM/WB Pipeline Register
// - Stores memory results and control signals
// - Passes data to writeback stage
// ============================================================================

module mem_wb_reg (
    input  wire        clk,
    input  wire        rst_n,

    // Data inputs from Memory Stage
    input  wire [31:0] alu_result_mem,
    input  wire [31:0] mem_rdata_mem,
    input  wire [31:0] fpu_result_mem,
    input  wire [4:0]  rd_mem,

    // Control inputs from Memory Stage
    input  wire        reg_write_mem,
    input  wire        mem_to_reg_mem,
    input  wire        fp_op_mem,
    input  wire        fp_reg_write_mem,

    // Data outputs to Writeback Stage
    output reg  [31:0] alu_result_wb,
    output reg  [31:0] mem_rdata_wb,
    output reg  [31:0] fpu_result_wb,
    output reg  [4:0]  rd_wb,

    // Control outputs to Writeback Stage
    output reg         reg_write_wb,
    output reg         mem_to_reg_wb,
    output reg         fp_op_wb,
    output reg         fp_reg_write_wb
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            alu_result_wb <= 32'd0;
            mem_rdata_wb  <= 32'd0;
            fpu_result_wb <= 32'd0;
            rd_wb         <= 5'd0;
            reg_write_wb  <= 1'b0;
            mem_to_reg_wb <= 1'b0;
            fp_op_wb      <= 1'b0;
            fp_reg_write_wb <= 1'b0;
        end
        else begin
            alu_result_wb <= alu_result_mem;
            mem_rdata_wb  <= mem_rdata_mem;
            fpu_result_wb <= fpu_result_mem;
            rd_wb         <= rd_mem;
            reg_write_wb  <= reg_write_mem;
            mem_to_reg_wb <= mem_to_reg_mem;
            fp_op_wb      <= fp_op_mem;
            fp_reg_write_wb <= fp_reg_write_mem;
        end
    end

endmodule

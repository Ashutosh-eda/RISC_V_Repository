// ============================================================================
// EX/MEM Pipeline Register
// - Stores execution results and control signals
// - Passes data to memory stage
// ============================================================================

module ex_mem_reg (
    input  wire        clk,
    input  wire        rst_n,

    // Data inputs from Execute Stage
    input  wire [31:0] alu_result_ex,
    input  wire [31:0] rs2_data_ex,      // For store instructions
    input  wire [31:0] fpu_result_ex,
    input  wire [4:0]  rd_ex,
    input  wire [2:0]  funct3_ex,

    // Control inputs from Execute Stage
    input  wire        reg_write_ex,
    input  wire        mem_read_ex,
    input  wire        mem_write_ex,
    input  wire        mem_to_reg_ex,
    input  wire        fp_op_ex,
    input  wire        fp_reg_write_ex,

    // Data outputs to Memory Stage
    output reg  [31:0] alu_result_mem,
    output reg  [31:0] rs2_data_mem,
    output reg  [31:0] fpu_result_mem,
    output reg  [4:0]  rd_mem,
    output reg  [2:0]  funct3_mem,

    // Control outputs to Memory Stage
    output reg         reg_write_mem,
    output reg         mem_read_mem,
    output reg         mem_write_mem,
    output reg         mem_to_reg_mem,
    output reg         fp_op_mem,
    output reg         fp_reg_write_mem
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            alu_result_mem <= 32'd0;
            rs2_data_mem   <= 32'd0;
            fpu_result_mem <= 32'd0;
            rd_mem         <= 5'd0;
            funct3_mem     <= 3'd0;
            reg_write_mem  <= 1'b0;
            mem_read_mem   <= 1'b0;
            mem_write_mem  <= 1'b0;
            mem_to_reg_mem <= 1'b0;
            fp_op_mem      <= 1'b0;
            fp_reg_write_mem <= 1'b0;
        end
        else begin
            alu_result_mem <= alu_result_ex;
            rs2_data_mem   <= rs2_data_ex;
            fpu_result_mem <= fpu_result_ex;
            rd_mem         <= rd_ex;
            funct3_mem     <= funct3_ex;
            reg_write_mem  <= reg_write_ex;
            mem_read_mem   <= mem_read_ex;
            mem_write_mem  <= mem_write_ex;
            mem_to_reg_mem <= mem_to_reg_ex;
            fp_op_mem      <= fp_op_ex;
            fp_reg_write_mem <= fp_reg_write_ex;
        end
    end

endmodule

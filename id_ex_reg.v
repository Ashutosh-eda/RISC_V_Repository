// ============================================================================
// ID/EX Pipeline Register
// - Stores decoded instruction data and control signals
// - Supports flush operation for branch misprediction
// ============================================================================

module id_ex_reg (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        flush,

    // Data inputs from Decode Stage
    input  wire [31:0] pc_id,
    input  wire [31:0] rs1_data_id,
    input  wire [31:0] rs2_data_id,
    input  wire [31:0] imm_id,
    input  wire [4:0]  rd_id,
    input  wire [4:0]  rs1_id,
    input  wire [4:0]  rs2_id,
    input  wire [2:0]  funct3_id,
    input  wire [6:0]  funct7_id,

    // FPU data inputs
    input  wire [31:0] fp_rs1_data_id,
    input  wire [31:0] fp_rs2_data_id,
    input  wire [31:0] fp_rs3_data_id,
    input  wire [4:0]  fp_rs3_id,      // rs3 address for FMA

    // Control inputs from Decode Stage
    input  wire        reg_write_id,
    input  wire        mem_read_id,
    input  wire        mem_write_id,
    input  wire        mem_to_reg_id,
    input  wire        alu_src_id,
    input  wire        branch_id,
    input  wire        jump_id,
    input  wire [3:0]  alu_op_id,
    input  wire        fp_op_id,
    input  wire        fft_op_id,
    input  wire        fp_reg_write_id,  // FP register write enable
    input  wire        fma_op_id,        // FMA operation (uses rs3)

    // Data outputs to Execute Stage
    output reg  [31:0] pc_ex,
    output reg  [31:0] rs1_data_ex,
    output reg  [31:0] rs2_data_ex,
    output reg  [31:0] imm_ex,
    output reg  [4:0]  rd_ex,
    output reg  [4:0]  rs1_ex,
    output reg  [4:0]  rs2_ex,
    output reg  [2:0]  funct3_ex,
    output reg  [6:0]  funct7_ex,

    // FPU data outputs
    output reg  [31:0] fp_rs1_data_ex,
    output reg  [31:0] fp_rs2_data_ex,
    output reg  [31:0] fp_rs3_data_ex,
    output reg  [4:0]  fp_rs3_ex,

    // Control outputs to Execute Stage
    output reg         reg_write_ex,
    output reg         mem_read_ex,
    output reg         mem_write_ex,
    output reg         mem_to_reg_ex,
    output reg         alu_src_ex,
    output reg         branch_ex,
    output reg         jump_ex,
    output reg  [3:0]  alu_op_ex,
    output reg         fp_op_ex,
    output reg         fft_op_ex,
    output reg         fp_reg_write_ex,
    output reg         fma_op_ex
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Data
            pc_ex         <= 32'd0;
            rs1_data_ex   <= 32'd0;
            rs2_data_ex   <= 32'd0;
            imm_ex        <= 32'd0;
            rd_ex         <= 5'd0;
            rs1_ex        <= 5'd0;
            rs2_ex        <= 5'd0;
            funct3_ex     <= 3'd0;
            funct7_ex     <= 7'd0;

            // FPU Data
            fp_rs1_data_ex <= 32'd0;
            fp_rs2_data_ex <= 32'd0;
            fp_rs3_data_ex <= 32'd0;
            fp_rs3_ex      <= 5'd0;

            // Control
            reg_write_ex  <= 1'b0;
            mem_read_ex   <= 1'b0;
            mem_write_ex  <= 1'b0;
            mem_to_reg_ex <= 1'b0;
            alu_src_ex    <= 1'b0;
            branch_ex     <= 1'b0;
            jump_ex       <= 1'b0;
            alu_op_ex     <= 4'd0;
            fp_op_ex      <= 1'b0;
            fft_op_ex     <= 1'b0;
            fp_reg_write_ex <= 1'b0;
            fma_op_ex     <= 1'b0;
        end
        else if (flush) begin
            // Insert bubble - zero out control signals
            pc_ex         <= 32'd0;
            rs1_data_ex   <= 32'd0;
            rs2_data_ex   <= 32'd0;
            imm_ex        <= 32'd0;
            rd_ex         <= 5'd0;
            rs1_ex        <= 5'd0;
            rs2_ex        <= 5'd0;
            funct3_ex     <= 3'd0;
            funct7_ex     <= 7'd0;

            fp_rs1_data_ex <= 32'd0;
            fp_rs2_data_ex <= 32'd0;
            fp_rs3_data_ex <= 32'd0;
            fp_rs3_ex      <= 5'd0;

            reg_write_ex  <= 1'b0;
            mem_read_ex   <= 1'b0;
            mem_write_ex  <= 1'b0;
            mem_to_reg_ex <= 1'b0;
            alu_src_ex    <= 1'b0;
            branch_ex     <= 1'b0;
            jump_ex       <= 1'b0;
            alu_op_ex     <= 4'd0;
            fp_op_ex      <= 1'b0;
            fft_op_ex     <= 1'b0;
            fp_reg_write_ex <= 1'b0;
            fma_op_ex     <= 1'b0;
        end
        else begin
            // Normal operation
            pc_ex         <= pc_id;
            rs1_data_ex   <= rs1_data_id;
            rs2_data_ex   <= rs2_data_id;
            imm_ex        <= imm_id;
            rd_ex         <= rd_id;
            rs1_ex        <= rs1_id;
            rs2_ex        <= rs2_id;
            funct3_ex     <= funct3_id;
            funct7_ex     <= funct7_id;

            fp_rs1_data_ex <= fp_rs1_data_id;
            fp_rs2_data_ex <= fp_rs2_data_id;
            fp_rs3_data_ex <= fp_rs3_data_id;
            fp_rs3_ex      <= fp_rs3_id;

            reg_write_ex  <= reg_write_id;
            mem_read_ex   <= mem_read_id;
            mem_write_ex  <= mem_write_id;
            mem_to_reg_ex <= mem_to_reg_id;
            alu_src_ex    <= alu_src_id;
            branch_ex     <= branch_id;
            jump_ex       <= jump_id;
            alu_op_ex     <= alu_op_id;
            fp_op_ex      <= fp_op_id;
            fft_op_ex     <= fft_op_id;
            fp_reg_write_ex <= fp_reg_write_id;
            fma_op_ex     <= fma_op_id;
        end
    end

endmodule

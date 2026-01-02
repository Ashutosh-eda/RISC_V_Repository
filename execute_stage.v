// ============================================================================
// Execute Stage (EX)
// - ALU operations
// - Branch/Jump evaluation
// - FPU operations with forwarding (Phase 2 complete)
// - FFT coprocessor operations (Phase 3 complete - 8-point FFT)
// - Data forwarding from later stages (integer + FPU)
// ============================================================================

module execute_stage (
    input  wire        clk,
    input  wire        rst_n,

    // From ID/EX Register
    input  wire [31:0] pc_ex,
    input  wire [31:0] rs1_data_ex,
    input  wire [31:0] rs2_data_ex,
    input  wire [31:0] imm_ex,
    input  wire [4:0]  rs1_ex,
    input  wire [4:0]  rs2_ex,
    input  wire [2:0]  funct3_ex,
    input  wire [6:0]  funct7_ex,
    input  wire        alu_src_ex,
    input  wire        branch_ex,
    input  wire        jump_ex,
    input  wire [3:0]  alu_op_ex,
    input  wire        fp_op_ex,
    input  wire        fft_op_ex,

    // FPU inputs from ID/EX Register
    input  wire [31:0] fp_rs1_data_ex,
    input  wire [31:0] fp_rs2_data_ex,
    input  wire [31:0] fp_rs3_data_ex,
    input  wire [4:0]  fp_rs3_ex,

    // Integer forwarding inputs
    input  wire [1:0]  forward_a,
    input  wire [1:0]  forward_b,
    input  wire [31:0] alu_result_mem,
    input  wire [31:0] wb_data,

    // FPU forwarding inputs
    input  wire [4:0]  rd_mem,
    input  wire [4:0]  rd_wb,
    input  wire        fp_reg_write_mem,
    input  wire        fp_reg_write_wb,
    input  wire [31:0] fpu_result_mem,
    input  wire [31:0] fpu_result_wb,
    input  wire [1:0]  rs1_stage_fpu,
    input  wire [1:0]  rs2_stage_fpu,
    input  wire [1:0]  rs3_stage_fpu,

    // CSR input (rounding mode)
    input  wire [2:0]  frm_csr,

    // Outputs
    output wire [31:0] alu_result,
    output wire [31:0] fpu_result,
    output wire [4:0]  fpu_flags,
    output wire [2:0]  fpu_latency,
    output wire [31:0] rs2_data_fwd,   // Forwarded rs2 for store instructions
    output wire [31:0] branch_target,
    output wire        branch_taken,
    output wire        zero
);

    // ========================================================================
    // Forwarding Multiplexers
    // ========================================================================

    reg [31:0] forward_a_data;
    reg [31:0] forward_b_data;

    // Forward A (rs1)
    always @(*) begin
        case (forward_a)
            2'b00:   forward_a_data = rs1_data_ex;      // No forwarding
            2'b01:   forward_a_data = wb_data;          // Forward from WB
            2'b10:   forward_a_data = alu_result_mem;   // Forward from MEM
            default: forward_a_data = rs1_data_ex;
        endcase
    end

    // Forward B (rs2)
    always @(*) begin
        case (forward_b)
            2'b00:   forward_b_data = rs2_data_ex;      // No forwarding
            2'b01:   forward_b_data = wb_data;          // Forward from WB
            2'b10:   forward_b_data = alu_result_mem;   // Forward from MEM
            default: forward_b_data = rs2_data_ex;
        endcase
    end

    assign rs2_data_fwd = forward_b_data;

    // ========================================================================
    // ALU Operand Selection
    // ========================================================================

    wire [31:0] alu_operand_a;
    wire [31:0] alu_operand_b;

    // Operand A: rs1 or PC (for AUIPC)
    assign alu_operand_a = (alu_op_ex == 4'b1011) ? pc_ex : forward_a_data;  // AUIPC uses PC

    // Operand B: rs2 or immediate
    assign alu_operand_b = alu_src_ex ? imm_ex : forward_b_data;

    // ========================================================================
    // ALU
    // ========================================================================

    alu main_alu (
        .operand_a (alu_operand_a),
        .operand_b (alu_operand_b),
        .alu_op    (alu_op_ex),
        .result    (alu_result),
        .zero      (zero)
    );

    // ========================================================================
    // Branch Unit
    // ========================================================================

    branch_unit branch (
        .rs1_data      (forward_a_data),
        .rs2_data      (forward_b_data),
        .pc            (pc_ex),
        .imm           (imm_ex),
        .funct3        (funct3_ex),
        .branch        (branch_ex),
        .jump          (jump_ex),
        .alu_src       (alu_src_ex),
        .branch_target (branch_target),
        .branch_taken  (branch_taken)
    );

    // ========================================================================
    // FPU with Forwarding
    // ========================================================================

    // FPU Forwarding Unit
    wire [1:0] forward_x, forward_y, forward_z;

    fpu_forwarding_unit fpu_fwd (
        .rs1_ex           (rs1_ex),
        .rs2_ex           (rs2_ex),
        .rs3_ex           (fp_rs3_ex),
        .rd_mem           (rd_mem),
        .rd_wb            (rd_wb),
        .fp_reg_write_mem (fp_reg_write_mem),
        .fp_reg_write_wb  (fp_reg_write_wb),
        .rs1_stage        (rs1_stage_fpu),
        .rs2_stage        (rs2_stage_fpu),
        .rs3_stage        (rs3_stage_fpu),
        .forward_x        (forward_x),
        .forward_y        (forward_y),
        .forward_z        (forward_z)
    );

    // FPU Input Multiplexers
    wire [31:0] fpu_x_operand, fpu_y_operand, fpu_z_operand;

    fpu_input_mux fpu_mux (
        .fp_rs1_data    (fp_rs1_data_ex),
        .fp_rs2_data    (fp_rs2_data_ex),
        .fp_rs3_data    (fp_rs3_data_ex),
        .fpu_result_mem (fpu_result_mem),
        .fpu_result_wb  (fpu_result_wb),
        .forward_x      (forward_x),
        .forward_y      (forward_y),
        .forward_z      (forward_z),
        .x_operand      (fpu_x_operand),
        .y_operand      (fpu_y_operand),
        .z_operand      (fpu_z_operand)
    );

    // FPU Instance
    wire        fpu_ready;

    fpu main_fpu (
        .clk       (clk),
        .rst_n     (rst_n),
        .rs1_data  (fpu_x_operand),
        .rs2_data  (fpu_y_operand),
        .rs3_data  (fpu_z_operand),
        .funct7    (funct7_ex),
        .funct3    (funct3_ex),
        .fp_op     (fp_op_ex),
        .frm       (frm_csr),
        .result    (fpu_result),
        .flags     (fpu_flags),
        .ready     (fpu_ready),
        .latency   (fpu_latency)
    );

    // ========================================================================
    // FFT Coprocessor (Phase 3 - 8-Point FFT)
    // ========================================================================

    wire [31:0] fft_data_out_real, fft_data_out_imag;
    wire        fft_busy, fft_ready;

    // Extract address from funct7 [2:0]
    wire [2:0] fft_addr = funct7_ex[2:0];

    fft_coprocessor_8pt fft_cop (
        .clk           (clk),
        .rst_n         (rst_n),
        .cmd           (funct3_ex),           // Command from funct3
        .addr          (fft_addr),            // Address from funct7[2:0]
        .data_in_real  (fpu_x_operand),       // Real data from FP register
        .data_in_imag  (fpu_y_operand),       // Imag data from FP register
        .data_out_real (fft_data_out_real),   // Output real part
        .data_out_imag (fft_data_out_imag),   // Output imag part
        .busy          (fft_busy),            // FFT computation in progress
        .ready         (fft_ready)            // Ready for commands
    );

endmodule

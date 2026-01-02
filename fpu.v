// ============================================================================
// Top-Level Floating-Point Unit (FPU)
// Supports single-precision (32-bit) operations:
//   - FADD, FSUB, FMUL
//   - FMADD, FMSUB, FNMADD, FNMSUB
// ============================================================================

module fpu (
    input  wire        clk,
    input  wire        rst_n,

    // Operands
    input  wire [31:0] rs1_data,      // Source 1 (X)
    input  wire [31:0] rs2_data,      // Source 2 (Y)
    input  wire [31:0] rs3_data,      // Source 3 (Z, for FMA)

    // Control
    input  wire [6:0]  funct7,        // FP operation encoding
    input  wire [2:0]  funct3,        // Rounding mode (if not DYN)
    input  wire        fp_op,         // FP operation enable
    input  wire [2:0]  frm,           // Rounding mode from CSR

    // Outputs
    output wire [31:0] result,
    output wire [4:0]  flags,         // Exception flags {NV, DZ, OF, UF, NX}
    output wire        ready,         // Operation complete (6 cycles later)
    output wire [2:0]  latency        // Cycles until ready
);

    // ========================================================================
    // Decode FP Operation
    // ========================================================================
    // funct7[6:2] encodes the FP operation type
    // funct7[1:0] for FMA variants

    wire [4:0] fp_opcode = funct7[6:2];
    wire [1:0] fma_variant = funct7[1:0];

    // Operation types
    localparam FP_ADD     = 5'b00000;
    localparam FP_SUB     = 5'b00001;
    localparam FP_MUL     = 5'b00010;
    localparam FP_MADD    = 5'b10000;  // FMA family (check fma_variant)

    wire is_add    = (fp_opcode == FP_ADD);
    wire is_sub    = (fp_opcode == FP_SUB);
    wire is_mul    = (fp_opcode == FP_MUL);
    wire is_fmadd  = (fp_opcode == FP_MADD) && (fma_variant == 2'b00);
    wire is_fmsub  = (fp_opcode == FP_MADD) && (fma_variant == 2'b01);
    wire is_fnmadd = (fp_opcode == FP_MADD) && (fma_variant == 2'b10);
    wire is_fnmsub = (fp_opcode == FP_MADD) && (fma_variant == 2'b11);

    // ========================================================================
    // Map to Internal Operation Type
    // ========================================================================
    reg [2:0] op_type;

    localparam OP_ADD    = 3'b000;
    localparam OP_SUB    = 3'b001;
    localparam OP_MUL    = 3'b010;
    localparam OP_FMA    = 3'b011;
    localparam OP_FMS    = 3'b100;
    localparam OP_FNMADD = 3'b101;
    localparam OP_FNMSUB = 3'b110;

    always @(*) begin
        if (is_add)         op_type = OP_ADD;
        else if (is_sub)    op_type = OP_SUB;
        else if (is_mul)    op_type = OP_MUL;
        else if (is_fmadd)  op_type = OP_FMA;
        else if (is_fmsub)  op_type = OP_FMS;
        else if (is_fnmadd) op_type = OP_FNMADD;
        else if (is_fnmsub) op_type = OP_FNMSUB;
        else                op_type = OP_ADD;  // Default
    end

    // ========================================================================
    // Rounding Mode Selection
    // ========================================================================
    // If funct3 = 111 (DYN), use frm from CSR
    // Otherwise, use funct3 directly

    wire [2:0] rounding_mode;
    assign rounding_mode = (funct3 == 3'b111) ? frm : funct3;

    // ========================================================================
    // Operand Preparation
    // ========================================================================
    // For ADD/SUB: X=1.0, Y=rs1, Z=rs2 (computes 1.0*rs1 +/- rs2 = rs1 +/- rs2)
    // For MUL:     X=rs1, Y=rs2, Z=0   (computes rs1*rs2 + 0 = rs1*rs2)
    // For FMA:     X=rs1, Y=rs2, Z=rs3 (computes rs1*rs2 + rs3)

    wire [31:0] x_operand;
    wire [31:0] y_operand;
    wire [31:0] z_operand;

    wire [31:0] one_point_zero = 32'h3F800000;  // IEEE 754 for 1.0

    assign x_operand = (is_add | is_sub) ? one_point_zero : rs1_data;
    assign y_operand = (is_add | is_sub) ? rs1_data : rs2_data;
    assign z_operand = (is_add | is_sub) ? rs2_data :
                       (is_fmadd | is_fmsub | is_fnmadd | is_fnmsub) ? rs3_data :
                       32'h00000000;  // Zero for MUL

    // ========================================================================
    // FMA Pipeline Instance
    // ========================================================================
    wire [31:0] fma_result;
    wire [4:0]  fma_flags;
    wire        fma_valid;

    fpu_fma fma_unit (
        .clk      (clk),
        .rst_n    (rst_n),
        .x_in     (x_operand),
        .y_in     (y_operand),
        .z_in     (z_operand),
        .op_type  (op_type),
        .rm       (rounding_mode),
        .start    (fp_op),
        .result   (fma_result),
        .flags    (fma_flags),
        .valid    (fma_valid)
    );

    // ========================================================================
    // Output Assignment
    // ========================================================================
    assign result = fma_result;
    assign flags  = fma_flags;
    assign ready  = fma_valid;

    // ========================================================================
    // Latency Reporting
    // ========================================================================
    // FADD/FSUB: 4 cycles
    // FMUL:      5 cycles
    // FMA:       6 cycles

    assign latency = (is_add | is_sub) ? 3'd4 :
                     (is_mul)          ? 3'd5 :
                                         3'd6;

endmodule

// ============================================================================
// FPU FMA (Fused Multiply-Add) Pipeline
// 6-stage pipeline implementing FMA and all derived operations
// Handles: FMA, FMS, FNMADD, FNMSUB, FMUL, FADD, FSUB
// ============================================================================

module fpu_fma (
    input  wire        clk,
    input  wire        rst_n,

    // Inputs
    input  wire [31:0] x_in,          // Operand X
    input  wire [31:0] y_in,          // Operand Y
    input  wire [31:0] z_in,          // Operand Z (addend)
    input  wire [2:0]  op_type,       // Operation type
    input  wire [2:0]  rm,            // Rounding mode
    input  wire        start,         // Start operation

    // Outputs
    output reg  [31:0] result,
    output reg  [4:0]  flags,         // {NV, DZ, OF, UF, NX}
    output reg         valid          // Result valid
);

    // ========================================================================
    // Operation Types
    // ========================================================================
    localparam OP_ADD    = 3'b000;
    localparam OP_SUB    = 3'b001;
    localparam OP_MUL    = 3'b010;
    localparam OP_FMA    = 3'b011;
    localparam OP_FMS    = 3'b100;
    localparam OP_FNMADD = 3'b101;
    localparam OP_FNMSUB = 3'b110;

    // ========================================================================
    // Stage 1: Unpack and Classify
    // ========================================================================
    reg [31:0] x_s1, y_s1, z_s1;
    reg [2:0]  op_s1, rm_s1;
    reg        valid_s1;

    wire       xs, ys, zs;
    wire [7:0] xe, ye, ze;
    wire [23:0] xm, ym, zm;
    wire x_zero, y_zero, z_zero;
    wire x_inf, y_inf, z_inf;
    wire x_nan, y_nan, z_nan;
    wire x_qnan, y_qnan, z_qnan;
    wire x_snan, y_snan, z_snan;
    wire x_subnormal, y_subnormal, z_subnormal;

    fpu_classify classify (
        .x_in(x_s1), .y_in(y_s1), .z_in(z_s1),
        .xs(xs), .xe(xe), .xm(xm),
        .x_zero(x_zero), .x_inf(x_inf), .x_nan(x_nan),
        .x_qnan(x_qnan), .x_snan(x_snan), .x_subnormal(x_subnormal),
        .ys(ys), .ye(ye), .ym(ym),
        .y_zero(y_zero), .y_inf(y_inf), .y_nan(y_nan),
        .y_qnan(y_qnan), .y_snan(y_snan), .y_subnormal(y_subnormal),
        .zs(zs), .ze(ze), .zm(zm),
        .z_zero(z_zero), .z_inf(z_inf), .z_nan(z_nan),
        .z_qnan(z_qnan), .z_snan(z_snan), .z_subnormal(z_subnormal)
    );

    wire prod_sign_s1, result_sign_s1;
    fpu_sign_logic sign_logic (
        .xs(xs), .ys(ys), .zs(zs),
        .op_type(op_s1),
        .prod_sign(prod_sign_s1),
        .result_sign(result_sign_s1)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x_s1 <= 32'd0;
            y_s1 <= 32'd0;
            z_s1 <= 32'd0;
            op_s1 <= 3'd0;
            rm_s1 <= 3'd0;
            valid_s1 <= 1'b0;
        end else begin
            x_s1 <= x_in;
            y_s1 <= y_in;
            z_s1 <= z_in;
            op_s1 <= op_type;
            rm_s1 <= rm;
            valid_s1 <= start;
        end
    end

    // ========================================================================
    // Stage 2: Multiply
    // ========================================================================
    reg [47:0] product_s2;
    reg [8:0]  prod_exp_s2;
    reg        prod_sign_s2, result_sign_s2;
    reg [23:0] zm_s2;
    reg [7:0]  ze_s2;
    reg        zs_s2;
    reg [2:0]  op_s2, rm_s2;
    reg        valid_s2;

    // Store classification flags for later stages
    reg x_zero_s2, y_zero_s2, z_zero_s2;
    reg x_inf_s2, y_inf_s2, z_inf_s2;
    reg x_nan_s2, y_nan_s2, z_nan_s2;
    reg x_snan_s2, y_snan_s2, z_snan_s2;

    wire [47:0] mult_product;
    fpu_multiplier mult (
        .multiplicand(xm),
        .multiplier(ym),
        .product(mult_product)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            product_s2 <= 48'd0;
            prod_exp_s2 <= 9'd0;
            prod_sign_s2 <= 1'b0;
            result_sign_s2 <= 1'b0;
            zm_s2 <= 24'd0;
            ze_s2 <= 8'd0;
            zs_s2 <= 1'b0;
            op_s2 <= 3'd0;
            rm_s2 <= 3'd0;
            valid_s2 <= 1'b0;
            x_zero_s2 <= 1'b0; y_zero_s2 <= 1'b0; z_zero_s2 <= 1'b0;
            x_inf_s2 <= 1'b0; y_inf_s2 <= 1'b0; z_inf_s2 <= 1'b0;
            x_nan_s2 <= 1'b0; y_nan_s2 <= 1'b0; z_nan_s2 <= 1'b0;
            x_snan_s2 <= 1'b0; y_snan_s2 <= 1'b0; z_snan_s2 <= 1'b0;
        end else begin
            product_s2 <= mult_product;
            // Product exponent: xe + ye - BIAS (127)
            prod_exp_s2 <= {1'b0, xe} + {1'b0, ye} - 9'd127;
            prod_sign_s2 <= prod_sign_s1;
            result_sign_s2 <= result_sign_s1;
            zm_s2 <= zm;
            ze_s2 <= ze;
            zs_s2 <= zs;
            op_s2 <= op_s1;
            rm_s2 <= rm_s1;
            valid_s2 <= valid_s1;
            x_zero_s2 <= x_zero; y_zero_s2 <= y_zero; z_zero_s2 <= z_zero;
            x_inf_s2 <= x_inf; y_inf_s2 <= y_inf; z_inf_s2 <= z_inf;
            x_nan_s2 <= x_nan; y_nan_s2 <= y_nan; z_nan_s2 <= z_nan;
            x_snan_s2 <= x_snan; y_snan_s2 <= y_snan; z_snan_s2 <= z_snan;
        end
    end

    // ========================================================================
    // Stage 3: Align Addend
    // ========================================================================
    reg [47:0] product_s3;
    reg [47:0] addend_aligned_s3;
    reg [8:0]  result_exp_s3;
    reg        effective_sub_s3;
    reg        sticky_s3;
    reg        prod_sign_s3, result_sign_s3;
    reg [2:0]  op_s3, rm_s3;
    reg        valid_s3;
    reg x_zero_s3, y_zero_s3, z_zero_s3;
    reg x_inf_s3, y_inf_s3, z_inf_s3;
    reg x_nan_s3, y_nan_s3, z_nan_s3;
    reg x_snan_s3, y_snan_s3, z_snan_s3;

    wire [47:0] aligned_addend;
    wire [8:0]  align_exp;
    wire        eff_sub;
    wire        align_sticky;

    fpu_addend_align aligner (
        .product(product_s2),
        .product_exp(prod_exp_s2),
        .addend(zm_s2),
        .addend_exp(ze_s2),
        .addend_sign(zs_s2),
        .prod_sign(prod_sign_s2),
        .op_type(op_s2),
        .addend_aligned(aligned_addend),
        .result_exp(align_exp),
        .effective_sub(eff_sub),
        .sticky(align_sticky)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            product_s3 <= 48'd0;
            addend_aligned_s3 <= 48'd0;
            result_exp_s3 <= 9'd0;
            effective_sub_s3 <= 1'b0;
            sticky_s3 <= 1'b0;
            prod_sign_s3 <= 1'b0;
            result_sign_s3 <= 1'b0;
            op_s3 <= 3'd0;
            rm_s3 <= 3'd0;
            valid_s3 <= 1'b0;
            x_zero_s3 <= 1'b0; y_zero_s3 <= 1'b0; z_zero_s3 <= 1'b0;
            x_inf_s3 <= 1'b0; y_inf_s3 <= 1'b0; z_inf_s3 <= 1'b0;
            x_nan_s3 <= 1'b0; y_nan_s3 <= 1'b0; z_nan_s3 <= 1'b0;
            x_snan_s3 <= 1'b0; y_snan_s3 <= 1'b0; z_snan_s3 <= 1'b0;
        end else begin
            product_s3 <= product_s2;
            addend_aligned_s3 <= aligned_addend;
            result_exp_s3 <= align_exp;
            effective_sub_s3 <= eff_sub;
            sticky_s3 <= align_sticky;
            prod_sign_s3 <= prod_sign_s2;
            result_sign_s3 <= result_sign_s2;
            op_s3 <= op_s2;
            rm_s3 <= rm_s2;
            valid_s3 <= valid_s2;
            x_zero_s3 <= x_zero_s2; y_zero_s3 <= y_zero_s2; z_zero_s3 <= z_zero_s2;
            x_inf_s3 <= x_inf_s2; y_inf_s3 <= y_inf_s2; z_inf_s3 <= z_inf_s2;
            x_nan_s3 <= x_nan_s2; y_nan_s3 <= y_nan_s2; z_nan_s3 <= z_nan_s2;
            x_snan_s3 <= x_snan_s2; y_snan_s3 <= y_snan_s2; z_snan_s3 <= z_snan_s2;
        end
    end

    // ========================================================================
    // Stage 4: Add + LZA
    // ========================================================================
    reg [48:0] sum_s4;
    reg [5:0]  lza_count_s4;
    reg [8:0]  result_exp_s4;
    reg        sum_sign_s4;
    reg        guard_s4, round_s4, sticky_s4;
    reg        effective_sub_s4;
    reg [2:0]  rm_s4;
    reg        valid_s4;
    reg x_zero_s4, y_zero_s4, z_zero_s4;
    reg x_inf_s4, y_inf_s4, z_inf_s4;
    reg x_nan_s4, y_nan_s4, z_nan_s4;
    reg x_snan_s4, y_snan_s4, z_snan_s4;

    wire [48:0] adder_sum;
    wire        adder_sign;
    wire        g_bit, r_bit, s_bit;

    fpu_adder adder (
        .operand_a(product_s3),
        .operand_b(addend_aligned_s3),
        .effective_sub(effective_sub_s3),
        .sticky_in(sticky_s3),
        .sum(adder_sum),
        .result_sign(adder_sign),
        .guard(g_bit),
        .round(r_bit),
        .sticky(s_bit)
    );

    wire [5:0] lza_pred;
    fpu_lza lza (
        .operand_a(product_s3),
        .operand_b(addend_aligned_s3),
        .cin(effective_sub_s3),
        .is_sub(effective_sub_s3),
        .lza_count(lza_pred),
        .lza_error()
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sum_s4 <= 49'd0;
            lza_count_s4 <= 6'd0;
            result_exp_s4 <= 9'd0;
            sum_sign_s4 <= 1'b0;
            guard_s4 <= 1'b0;
            round_s4 <= 1'b0;
            sticky_s4 <= 1'b0;
            effective_sub_s4 <= 1'b0;
            rm_s4 <= 3'd0;
            valid_s4 <= 1'b0;
            x_zero_s4 <= 1'b0; y_zero_s4 <= 1'b0; z_zero_s4 <= 1'b0;
            x_inf_s4 <= 1'b0; y_inf_s4 <= 1'b0; z_inf_s4 <= 1'b0;
            x_nan_s4 <= 1'b0; y_nan_s4 <= 1'b0; z_nan_s4 <= 1'b0;
            x_snan_s4 <= 1'b0; y_snan_s4 <= 1'b0; z_snan_s4 <= 1'b0;
        end else begin
            sum_s4 <= adder_sum;
            lza_count_s4 <= lza_pred;
            result_exp_s4 <= result_exp_s3;
            // For ADD/SUB: use adder_sign directly (no XOR)
            // For MUL/FMA: combine with XOR
            sum_sign_s4 <= ((op_s3 == 3'b000) || (op_s3 == 3'b001)) ? adder_sign : (adder_sign ^ result_sign_s3);
            guard_s4 <= g_bit;
            round_s4 <= r_bit;
            sticky_s4 <= s_bit;
            effective_sub_s4 <= effective_sub_s3;
            rm_s4 <= rm_s3;
            valid_s4 <= valid_s3;
            x_zero_s4 <= x_zero_s3; y_zero_s4 <= y_zero_s3; z_zero_s4 <= z_zero_s3;
            x_inf_s4 <= x_inf_s3; y_inf_s4 <= y_inf_s3; z_inf_s4 <= z_inf_s3;
            x_nan_s4 <= x_nan_s3; y_nan_s4 <= y_nan_s3; z_nan_s4 <= z_nan_s3;
            x_snan_s4 <= x_snan_s3; y_snan_s4 <= y_snan_s3; z_snan_s4 <= z_snan_s3;
        end
    end

    // ========================================================================
    // Stage 5: Normalize
    // ========================================================================
    reg [47:0] norm_sum_s5;
    reg [8:0]  norm_exp_s5;
    reg        norm_sign_s5;
    reg        overflow_s5, underflow_s5;
    reg        guard_s5, round_s5, sticky_s5;
    reg [2:0]  rm_s5;
    reg        valid_s5;
    reg x_zero_s5, y_zero_s5, z_zero_s5;
    reg x_inf_s5, y_inf_s5, z_inf_s5;
    reg x_nan_s5, y_nan_s5, z_nan_s5;
    reg x_snan_s5, y_snan_s5, z_snan_s5;

    wire [47:0] shifted_sum;
    wire [8:0]  shifted_exp;
    wire        of_flag, uf_flag;

    fpu_norm_shift normalizer (
        .sum(sum_s4),
        .lza_count(lza_count_s4),
        .sum_exp(result_exp_s4),
        .effective_sub(effective_sub_s4),
        .shifted_sum(shifted_sum),
        .norm_exp(shifted_exp),
        .overflow(of_flag),
        .underflow(uf_flag)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            norm_sum_s5 <= 48'd0;
            norm_exp_s5 <= 9'd0;
            norm_sign_s5 <= 1'b0;
            overflow_s5 <= 1'b0;
            underflow_s5 <= 1'b0;
            guard_s5 <= 1'b0;
            round_s5 <= 1'b0;
            sticky_s5 <= 1'b0;
            rm_s5 <= 3'd0;
            valid_s5 <= 1'b0;
            x_zero_s5 <= 1'b0; y_zero_s5 <= 1'b0; z_zero_s5 <= 1'b0;
            x_inf_s5 <= 1'b0; y_inf_s5 <= 1'b0; z_inf_s5 <= 1'b0;
            x_nan_s5 <= 1'b0; y_nan_s5 <= 1'b0; z_nan_s5 <= 1'b0;
            x_snan_s5 <= 1'b0; y_snan_s5 <= 1'b0; z_snan_s5 <= 1'b0;
        end else begin
            norm_sum_s5 <= shifted_sum;
            norm_exp_s5 <= shifted_exp;
            norm_sign_s5 <= sum_sign_s4;
            overflow_s5 <= of_flag;
            underflow_s5 <= uf_flag;
            guard_s5 <= guard_s4;
            round_s5 <= round_s4;
            sticky_s5 <= sticky_s4;
            rm_s5 <= rm_s4;
            valid_s5 <= valid_s4;
            x_zero_s5 <= x_zero_s4; y_zero_s5 <= y_zero_s4; z_zero_s5 <= z_zero_s4;
            x_inf_s5 <= x_inf_s4; y_inf_s5 <= y_inf_s4; z_inf_s5 <= z_inf_s4;
            x_nan_s5 <= x_nan_s4; y_nan_s5 <= y_nan_s4; z_nan_s5 <= z_nan_s4;
            x_snan_s5 <= x_snan_s4; y_snan_s5 <= y_snan_s4; z_snan_s5 <= z_snan_s4;
        end
    end

    // ========================================================================
    // Stage 6: Round and Pack
    // ========================================================================
    wire [22:0] rounded_mantissa;
    wire [7:0]  rounded_exp;
    wire        inexact_flag, overflow_flag;

    fpu_rounder rounder (
        .mantissa(norm_sum_s5),
        .exponent(norm_exp_s5),
        .sign(norm_sign_s5),
        .guard(guard_s5),
        .round(round_s5),
        .sticky(sticky_s5),
        .rm(rm_s5),
        .mantissa_rounded(rounded_mantissa),
        .exponent_rounded(rounded_exp),
        .inexact(inexact_flag),
        .overflow(overflow_flag)
    );

    wire [31:0] packed_result;
    fpu_pack packer (
        .sign(norm_sign_s5),
        .exponent(rounded_exp),
        .mantissa(rounded_mantissa),
        .ieee_out(packed_result)
    );

    wire [31:0] final_result;
    fpu_special_case special (
        .normal_result(packed_result),
        .normal_sign(norm_sign_s5),
        .x_nan(x_nan_s5), .y_nan(y_nan_s5), .z_nan(z_nan_s5),
        .x_snan(x_snan_s5), .y_snan(y_snan_s5), .z_snan(z_snan_s5),
        .x_inf(x_inf_s5), .y_inf(y_inf_s5), .z_inf(z_inf_s5),
        .x_zero(x_zero_s5), .y_zero(y_zero_s5), .z_zero(z_zero_s5),
        .overflow(overflow_s5 | overflow_flag),
        .underflow(underflow_s5),
        .invalid_op(1'b0),  // Calculated separately
        .op_type(3'b0),
        .rm(rm_s5),
        .result(final_result)
    );

    wire [4:0] exception_flags;
    fpu_exception_flags exc_flags (
        .result_overflow(overflow_s5 | overflow_flag),
        .result_underflow(underflow_s5),
        .result_inexact(inexact_flag),
        .result_invalid(1'b0),
        .x_nan(x_nan_s5), .y_nan(y_nan_s5), .z_nan(z_nan_s5),
        .x_snan(x_snan_s5), .y_snan(y_snan_s5), .z_snan(z_snan_s5),
        .x_inf(x_inf_s5), .y_inf(y_inf_s5), .z_inf(z_inf_s5),
        .x_zero(x_zero_s5), .y_zero(y_zero_s5), .z_zero(z_zero_s5),
        .op_type(3'b0),
        .flags(exception_flags)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 32'd0;
            flags <= 5'd0;
            valid <= 1'b0;
        end else begin
            result <= final_result;
            flags <= exception_flags;
            valid <= valid_s5;
        end
    end

endmodule

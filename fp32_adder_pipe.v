// ============================================================================
// IEEE 754 Single-Precision Floating-Point Adder/Subtracter (Pipelined)
// - 4-stage pipeline: Unpack → Align → Add → Normalize/Round
// - Handles special cases (NaN, Inf, Zero)
// - sub=0 for addition, sub=1 for subtraction
// - For use in FFT coprocessor
// ============================================================================

module fp32_adder_pipe (
    input  wire        clk,
    input  wire        rst_n,

    input  wire [31:0] x,        // Operand X
    input  wire [31:0] y,        // Operand Y
    input  wire        sub,      // 0=add, 1=subtract
    input  wire [2:0]  rm,       // Rounding mode

    output reg  [31:0] sum,      // Result
    output reg  [4:0]  flags     // {NV, DZ, OF, UF, NX}
);

    // ========================================================================
    // Stage 1: Unpack and Classify
    // ========================================================================
    reg [31:0] x_s1, y_s1;
    reg        sub_s1;
    reg [2:0]  rm_s1;

    wire       xs, ys;
    wire [7:0] xe, ye;
    wire [23:0] xm, ym;
    wire x_zero, y_zero;
    wire x_inf, y_inf;
    wire x_nan, y_nan;

    fpu_unpack unpack_x (
        .ieee_in     (x_s1),
        .sign        (xs),
        .exponent    (xe),
        .significand (xm),
        .is_zero     (x_zero),
        .is_inf      (x_inf),
        .is_nan      (x_nan),
        .is_qnan     (),
        .is_snan     (),
        .is_subnormal()
    );

    fpu_unpack unpack_y (
        .ieee_in     (y_s1),
        .sign        (ys),
        .exponent    (ye),
        .significand (ym),
        .is_zero     (y_zero),
        .is_inf      (y_inf),
        .is_nan      (y_nan),
        .is_qnan     (),
        .is_snan     (),
        .is_subnormal()
    );

    // Effective operation
    wire eff_sub_s1 = xs ^ ys ^ sub_s1;

    // Special case detection
    wire is_special_s1 = x_nan | y_nan | x_inf | y_inf;
    wire result_nan_s1 = x_nan | y_nan | (x_inf & y_inf & eff_sub_s1);
    wire result_inf_s1 = (x_inf | y_inf) & !result_nan_s1;
    wire result_sign_inf_s1 = x_inf ? xs : (ys ^ sub_s1);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x_s1 <= 32'd0;
            y_s1 <= 32'd0;
            sub_s1 <= 1'b0;
            rm_s1 <= 3'd0;
        end else begin
            x_s1 <= x;
            y_s1 <= y;
            sub_s1 <= sub;
            rm_s1 <= rm;
        end
    end

    // ========================================================================
    // Stage 2: Align Significands
    // ========================================================================
    reg [47:0] xm_aligned_s2, ym_aligned_s2;
    reg [8:0]  larger_exp_s2;
    reg        xs_s2, ys_s2, eff_sub_s2;
    reg        is_special_s2, result_nan_s2, result_inf_s2;
    reg        result_sign_inf_s2;
    reg [2:0]  rm_s2;

    wire [47:0] xm_ext = {xm, 24'd0};
    wire [47:0] ym_ext = {ym, 24'd0};
    wire [7:0] exp_diff = (xe > ye) ? (xe - ye) : (ye - xe);
    wire x_larger = (xe >= ye);

    wire [47:0] xm_aligned_wire = x_larger ? xm_ext : (xm_ext >> exp_diff);
    wire [47:0] ym_aligned_wire = x_larger ? (ym_ext >> exp_diff) : ym_ext;
    wire [8:0]  larger_exp_wire = x_larger ? {1'b0, xe} : {1'b0, ye};

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            xm_aligned_s2 <= 48'd0;
            ym_aligned_s2 <= 48'd0;
            larger_exp_s2 <= 9'd0;
            xs_s2 <= 1'b0;
            ys_s2 <= 1'b0;
            eff_sub_s2 <= 1'b0;
            is_special_s2 <= 1'b0;
            result_nan_s2 <= 1'b0;
            result_inf_s2 <= 1'b0;
            result_sign_inf_s2 <= 1'b0;
            rm_s2 <= 3'd0;
        end else begin
            xm_aligned_s2 <= xm_aligned_wire;
            ym_aligned_s2 <= ym_aligned_wire;
            larger_exp_s2 <= larger_exp_wire;
            xs_s2 <= xs;
            ys_s2 <= ys ^ sub_s1;
            eff_sub_s2 <= eff_sub_s1;
            is_special_s2 <= is_special_s1;
            result_nan_s2 <= result_nan_s1;
            result_inf_s2 <= result_inf_s1;
            result_sign_inf_s2 <= result_sign_inf_s1;
            rm_s2 <= rm_s1;
        end
    end

    // ========================================================================
    // Stage 3: Add/Subtract
    // ========================================================================
    reg [48:0] raw_sum_s3;
    reg        result_sign_s3;
    reg [8:0]  exp_s3;
    reg        is_special_s3, result_nan_s3, result_inf_s3;
    reg        result_sign_inf_s3;
    reg [2:0]  rm_s3;

    wire [48:0] sum_result;
    wire        sum_sign;

    fpu_adder adder (
        .operand_a    (xm_aligned_s2),
        .operand_b    (ym_aligned_s2),
        .effective_sub(eff_sub_s2),
        .sticky_in    (1'b0),
        .sum          (sum_result),
        .result_sign  (sum_sign),
        .guard        (),
        .round        (),
        .sticky       ()
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            raw_sum_s3 <= 49'd0;
            result_sign_s3 <= 1'b0;
            exp_s3 <= 9'd0;
            is_special_s3 <= 1'b0;
            result_nan_s3 <= 1'b0;
            result_inf_s3 <= 1'b0;
            result_sign_inf_s3 <= 1'b0;
            rm_s3 <= 3'd0;
        end else begin
            raw_sum_s3 <= sum_result;
            result_sign_s3 <= xs_s2 ^ sum_sign;
            exp_s3 <= larger_exp_s2;
            is_special_s3 <= is_special_s2;
            result_nan_s3 <= result_nan_s2;
            result_inf_s3 <= result_inf_s2;
            result_sign_inf_s3 <= result_sign_inf_s2;
            rm_s3 <= rm_s2;
        end
    end

    // ========================================================================
    // Stage 4: Normalize, Round, and Pack
    // ========================================================================

    // Leading zero count
    wire [5:0] lzc;
    fpu_lzc lzc_inst (
        .data_in (raw_sum_s3[48:1]),
        .count   (lzc)
    );

    // Normalize
    wire [48:0] normalized = raw_sum_s3 << lzc;
    wire [8:0]  normalized_exp = exp_s3 - {3'd0, lzc};

    // Round
    wire [22:0] mantissa_rounded;
    wire [7:0]  exponent_rounded;
    wire        inexact;
    wire        round_overflow;

    fpu_rounder rounder (
        .mantissa         (normalized[48:1]),
        .exponent         (normalized_exp),
        .sign             (result_sign_s3),
        .guard            (normalized[24]),
        .round            (normalized[23]),
        .sticky           (|normalized[22:0]),
        .rm               (rm_s3),
        .mantissa_rounded (mantissa_rounded),
        .exponent_rounded (exponent_rounded),
        .inexact          (inexact),
        .overflow         (round_overflow)
    );

    // Overflow/Underflow detection
    wire overflow_detected = (exponent_rounded == 8'd255);
    wire underflow_detected = (normalized_exp[8] == 1'b1) || (normalized_exp == 9'd0);
    wire is_zero = (raw_sum_s3 == 49'd0);

    // Pack
    wire [31:0] normal_result;
    fpu_pack packer (
        .sign        (result_sign_s3),
        .exponent    (exponent_rounded),
        .mantissa    (mantissa_rounded),
        .ieee_out    (normal_result)
    );

    // Handle special cases
    wire [31:0] special_result = result_nan_s3      ? 32'h7FC00000 :  // QNaN
                                  result_inf_s3      ? {result_sign_inf_s3, 8'hFF, 23'd0} :  // Inf
                                  is_zero            ? {result_sign_s3, 31'd0} :  // Zero
                                  overflow_detected  ? {result_sign_s3, 8'hFF, 23'd0} :  // Inf
                                  underflow_detected ? {result_sign_s3, 31'd0} :  // Zero
                                                       normal_result;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sum <= 32'd0;
            flags <= 5'd0;
        end else begin
            sum <= special_result;
            flags <= {result_nan_s3, 1'b0, overflow_detected, underflow_detected, inexact};
        end
    end

endmodule

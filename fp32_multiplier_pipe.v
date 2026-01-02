// ============================================================================
// IEEE 754 Single-Precision Floating-Point Multiplier (Pipelined)
// - 3-stage pipeline: Unpack → Multiply → Pack/Round
// - Handles special cases (NaN, Inf, Zero)
// - For use in FFT coprocessor
// ============================================================================

module fp32_multiplier_pipe (
    input  wire        clk,
    input  wire        rst_n,

    input  wire [31:0] x,        // Operand X
    input  wire [31:0] y,        // Operand Y
    input  wire [2:0]  rm,       // Rounding mode

    output reg  [31:0] product,  // Result
    output reg  [4:0]  flags     // {NV, DZ, OF, UF, NX}
);

    // ========================================================================
    // Stage 1: Unpack and Classify
    // ========================================================================
    reg [31:0] x_s1, y_s1;
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

    // Special case detection
    wire is_special_s1 = x_nan | y_nan | x_inf | y_inf | x_zero | y_zero;
    wire result_nan_s1 = x_nan | y_nan | (x_inf & y_zero) | (y_inf & x_zero);
    wire result_inf_s1 = (x_inf | y_inf) & !result_nan_s1;
    wire result_zero_s1 = (x_zero | y_zero) & !result_nan_s1;
    wire result_sign_s1 = xs ^ ys;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x_s1 <= 32'd0;
            y_s1 <= 32'd0;
            rm_s1 <= 3'd0;
        end else begin
            x_s1 <= x;
            y_s1 <= y;
            rm_s1 <= rm;
        end
    end

    // ========================================================================
    // Stage 2: Multiply Significands
    // ========================================================================
    reg [47:0] product_s2;
    reg [8:0]  prod_exp_s2;
    reg        prod_sign_s2;
    reg        is_special_s2, result_nan_s2, result_inf_s2, result_zero_s2;
    reg [2:0]  rm_s2;

    wire [47:0] mult_result;
    fpu_multiplier mul (
        .multiplicand (xm),
        .multiplier   (ym),
        .product      (mult_result)
    );

    // Exponent calculation: exp = (xe - 127) + (ye - 127) + 127 = xe + ye - 127
    wire [8:0] exp_sum = {1'b0, xe} + {1'b0, ye} - 9'd127;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            product_s2 <= 48'd0;
            prod_exp_s2 <= 9'd0;
            prod_sign_s2 <= 1'b0;
            is_special_s2 <= 1'b0;
            result_nan_s2 <= 1'b0;
            result_inf_s2 <= 1'b0;
            result_zero_s2 <= 1'b0;
            rm_s2 <= 3'd0;
        end else begin
            product_s2 <= mult_result;
            prod_exp_s2 <= exp_sum;
            prod_sign_s2 <= result_sign_s1;
            is_special_s2 <= is_special_s1;
            result_nan_s2 <= result_nan_s1;
            result_inf_s2 <= result_inf_s1;
            result_zero_s2 <= result_zero_s1;
            rm_s2 <= rm_s1;
        end
    end

    // ========================================================================
    // Stage 3: Normalize, Round, and Pack
    // ========================================================================

    // Normalization
    wire [47:0] normalized_sig;  // Changed to 48-bit to match actual module
    wire [8:0]  normalized_exp;
    wire        guard_bit, round_bit, sticky_bit;

    fpu_shift_correction shift_corr (
        .shifted_sum    (product_s2),
        .norm_exp       (prod_exp_s2),
        .guard_in       (1'b0),  // No guard in from multiplier
        .round_in       (1'b0),  // No round in from multiplier
        .sticky_in      (1'b0),  // No sticky in from multiplier
        .corrected_sum  (normalized_sig),
        .corrected_exp  (normalized_exp),
        .guard          (guard_bit),
        .round          (round_bit),
        .sticky         (sticky_bit)
    );

    // Rounding
    wire [22:0] rounded_mantissa;
    wire [7:0]  rounded_exp;
    wire        inexact;
    wire        round_overflow;

    fpu_rounder rounder (
        .mantissa        (normalized_sig),
        .exponent        (normalized_exp),
        .sign            (prod_sign_s2),
        .guard           (guard_bit),
        .round           (round_bit),
        .sticky          (sticky_bit),
        .rm              (rm_s2),
        .mantissa_rounded(rounded_mantissa),
        .exponent_rounded(rounded_exp),
        .inexact         (inexact),
        .overflow        (round_overflow)
    );

    // Final exponent (use rounder's output directly)
    wire [8:0] final_exp = {1'b0, rounded_exp};

    // Overflow/Underflow detection
    wire overflow = round_overflow || (rounded_exp == 8'd255);
    wire underflow = (final_exp[8] == 1'b1) || (rounded_exp == 8'd0);

    // Pack result
    wire [31:0] normal_result;
    fpu_pack packer (
        .sign        (prod_sign_s2),
        .exponent    (rounded_exp),
        .mantissa    (rounded_mantissa),
        .ieee_out    (normal_result)
    );

    // Handle special cases (prioritize input special cases over computed overflow/underflow)
    wire [31:0] special_result = is_special_s2 ? (
                                    result_nan_s2   ? 32'h7FC00000 :  // QNaN
                                    result_inf_s2   ? {prod_sign_s2, 8'hFF, 23'd0} :  // Inf
                                    result_zero_s2  ? {prod_sign_s2, 31'd0} :  // Zero
                                                      normal_result
                                  ) : (
                                    overflow        ? {prod_sign_s2, 8'hFF, 23'd0} :  // Inf
                                    underflow       ? {prod_sign_s2, 31'd0} :  // Zero
                                                      normal_result
                                  );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            product <= 32'd0;
            flags <= 5'd0;
        end else begin
            product <= special_result;
            flags <= {result_nan_s2, 1'b0, overflow, underflow, inexact};
        end
    end

endmodule

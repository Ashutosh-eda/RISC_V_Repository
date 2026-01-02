// ============================================================================
// FPU Classify Module
// Combines unpacking and classification for all three operands (X, Y, Z)
// Used for FMA operations where we need to classify all inputs
// ============================================================================

module fpu_classify (
    input  wire [31:0] x_in,
    input  wire [31:0] y_in,
    input  wire [31:0] z_in,

    // X operand unpacked
    output wire        xs,
    output wire [7:0]  xe,
    output wire [23:0] xm,
    output wire        x_zero,
    output wire        x_inf,
    output wire        x_nan,
    output wire        x_qnan,
    output wire        x_snan,
    output wire        x_subnormal,

    // Y operand unpacked
    output wire        ys,
    output wire [7:0]  ye,
    output wire [23:0] ym,
    output wire        y_zero,
    output wire        y_inf,
    output wire        y_nan,
    output wire        y_qnan,
    output wire        y_snan,
    output wire        y_subnormal,

    // Z operand unpacked
    output wire        zs,
    output wire [7:0]  ze,
    output wire [23:0] zm,
    output wire        z_zero,
    output wire        z_inf,
    output wire        z_nan,
    output wire        z_qnan,
    output wire        z_snan,
    output wire        z_subnormal
);

    // ========================================================================
    // Unpack X Operand
    // ========================================================================
    fpu_unpack unpack_x (
        .ieee_in     (x_in),
        .sign        (xs),
        .exponent    (xe),
        .significand (xm),
        .is_zero     (x_zero),
        .is_inf      (x_inf),
        .is_nan      (x_nan),
        .is_qnan     (x_qnan),
        .is_snan     (x_snan),
        .is_subnormal(x_subnormal)
    );

    // ========================================================================
    // Unpack Y Operand
    // ========================================================================
    fpu_unpack unpack_y (
        .ieee_in     (y_in),
        .sign        (ys),
        .exponent    (ye),
        .significand (ym),
        .is_zero     (y_zero),
        .is_inf      (y_inf),
        .is_nan      (y_nan),
        .is_qnan     (y_qnan),
        .is_snan     (y_snan),
        .is_subnormal(y_subnormal)
    );

    // ========================================================================
    // Unpack Z Operand
    // ========================================================================
    fpu_unpack unpack_z (
        .ieee_in     (z_in),
        .sign        (zs),
        .exponent    (ze),
        .significand (zm),
        .is_zero     (z_zero),
        .is_inf      (z_inf),
        .is_nan      (z_nan),
        .is_qnan     (z_qnan),
        .is_snan     (z_snan),
        .is_subnormal(z_subnormal)
    );

endmodule

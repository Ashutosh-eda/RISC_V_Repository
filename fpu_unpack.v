// ============================================================================
// IEEE 754 Single-Precision Unpacker
// Converts IEEE 754 format to internal expanded format
//
// IEEE 754 Single-Precision Format (32 bits):
//   [31]    : Sign bit
//   [30:23] : Exponent (8 bits, biased by 127)
//   [22:0]  : Mantissa/Fraction (23 bits, implicit leading 1)
// ============================================================================

module fpu_unpack (
    input  wire [31:0] ieee_in,

    // Unpacked components
    output wire        sign,
    output wire [7:0]  exponent,
    output wire [23:0] significand,    // 24 bits (1.mantissa)

    // Classification outputs
    output wire        is_zero,
    output wire        is_inf,
    output wire        is_nan,
    output wire        is_qnan,        // Quiet NaN
    output wire        is_snan,        // Signaling NaN
    output wire        is_subnormal
);

    // ========================================================================
    // Extract IEEE 754 Fields
    // ========================================================================
    assign sign     = ieee_in[31];
    assign exponent = ieee_in[30:23];
    wire [22:0] fraction = ieee_in[22:0];

    // ========================================================================
    // Classification
    // ========================================================================

    // Zero: exponent = 0, fraction = 0
    assign is_zero = (exponent == 8'd0) && (fraction == 23'd0);

    // Infinity: exponent = 255, fraction = 0
    assign is_inf = (exponent == 8'd255) && (fraction == 23'd0);

    // NaN: exponent = 255, fraction != 0
    assign is_nan = (exponent == 8'd255) && (fraction != 23'd0);

    // Quiet NaN: MSB of fraction is 1
    assign is_qnan = is_nan && fraction[22];

    // Signaling NaN: MSB of fraction is 0
    assign is_snan = is_nan && ~fraction[22];

    // Subnormal: exponent = 0, fraction != 0
    assign is_subnormal = (exponent == 8'd0) && (fraction != 23'd0);

    // ========================================================================
    // Significand with Implicit Leading Bit
    // ========================================================================

    // For normal numbers: 1.fraction (implicit 1)
    // For subnormal: 0.fraction (no implicit 1)
    // For zero/inf/NaN: handled separately in special case logic
    assign significand = is_subnormal ? {1'b0, fraction} :
                         is_zero      ? 24'd0 :
                         is_nan       ? {1'b1, fraction} :
                         is_inf       ? 24'd0 :
                                        {1'b1, fraction};  // Normal number

endmodule

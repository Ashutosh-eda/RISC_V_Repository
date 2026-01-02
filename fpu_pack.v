// ============================================================================
// IEEE 754 Packer
// Converts internal format back to IEEE 754 single-precision
// Assembles sign, exponent, and mantissa into 32-bit float
// ============================================================================

module fpu_pack (
    input  wire        sign,
    input  wire [7:0]  exponent,
    input  wire [22:0] mantissa,      // 23-bit mantissa (without implicit 1)

    output wire [31:0] ieee_out
);

    // ========================================================================
    // Pack into IEEE 754 Format
    // ========================================================================
    // [31]    : Sign
    // [30:23] : Exponent
    // [22:0]  : Mantissa

    assign ieee_out = {sign, exponent, mantissa};

endmodule

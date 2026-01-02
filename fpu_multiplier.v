// ============================================================================
// FPU Multiplier
// Performs 24×24 significand multiplication
// Output is 48 bits (1.xxx × 1.yyy = 1x.xxxxxx or 01.xxxxxx)
// ============================================================================

module fpu_multiplier (
    input  wire [23:0] multiplicand,  // X significand
    input  wire [23:0] multiplier,    // Y significand

    output wire [47:0] product        // 48-bit product
);

    // ========================================================================
    // Unsigned Multiplication
    // ========================================================================
    // 24-bit × 24-bit = 48-bit result
    // Uses synthesis tool's built-in multiplier inference

    assign product = multiplicand * multiplier;

    // ========================================================================
    // Product Range Analysis
    // ========================================================================
    // For normalized inputs (1.xxx format):
    //   Minimum: 1.0 × 1.0 = 1.0        (product[47:46] = 01)
    //   Maximum: 1.111... × 1.111... ≈ 4.0  (product[47:46] = 11, but < 4.0)
    //
    // Therefore, product is in range [1.0, 4.0)
    // Product[47] = 1 when result ≥ 2.0 (needs right shift)
    // Product[47] = 0 when result < 2.0 (already normalized)

endmodule

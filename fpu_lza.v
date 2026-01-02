// ============================================================================
// Leading Zero Anticipation (LZA)
// Predicts the number of leading zeros in the sum BEFORE addition completes
// Based on Wally's implementation of Schmookler & Nowka algorithm
// Reference: CORE-V-WALLY https://github.com/openhwgroup/cvw
// Paper: Schmookler & Nowka, "Leading zero anticipation and detection",
//        IEEE Symposium on Computer Arithmetic, 2001
// Can be off by ±1, corrected in normalization stage
// ============================================================================

module fpu_lza (
    input  wire [47:0] operand_a,     // First operand (A)
    input  wire [47:0] operand_b,     // Second operand (B, pre-inverted for sub)
    input  wire        cin,           // Carry-in (for subtraction: A + ~B + cin)
    input  wire        is_sub,        // 1=subtraction, 0=addition

    output wire [5:0]  lza_count,     // Predicted leading zero count
    output wire        lza_error      // Potential error flag
);

    // ========================================================================
    // Schmookler & Nowka Full LZA Algorithm (Wally Implementation)
    // ========================================================================
    // P = propagate (A XOR B)
    // G = generate (A AND B)
    // K = kill (~A AND ~B)
    //
    // Formula predicts leading pattern F where:
    // F[i] = (P_{i+1} & (G_i & ~K_{i-1} | K_i & ~G_{i-1})) |
    //        (~P_{i+1} & (K_i & ~K_{i-1} | G_i & ~G_{i-1}))

    wire [47:0] p;   // Propagate: XOR
    wire [47:0] g;   // Generate: AND
    wire [47:0] k;   // Kill: NOR

    wire [47:0] pp1;  // P shifted right by 1 (P_{i+1})
    wire [47:0] gm1;  // G shifted left by 1 (G_{i-1})
    wire [47:0] km1;  // K shifted left by 1 (K_{i-1})

    wire [48:0] f;    // Leading pattern (49 bits)

    // ========================================================================
    // Step 1: Calculate P, G, K
    // ========================================================================
    // NOTE: operand_b should already be inverted for subtraction by caller
    // (This matches Wally's approach where AmInv is passed in)

    assign p = operand_a ^ operand_b;
    assign g = operand_a & operand_b;
    assign k = ~operand_a & ~operand_b;

    // ========================================================================
    // Step 2: Create Shifted Versions
    // ========================================================================
    // pp1: Shift P right by 1 (to get P_{i+1})
    //      MSB gets 'sub' flag (Wally's trick for subtraction handling)
    assign pp1 = {is_sub, p[47:1]};

    // gm1: Shift G left by 1 (to get G_{i-1})
    //      LSB gets cin (carry-in from two's complement)
    assign gm1 = {g[46:0], cin};

    // km1: Shift K left by 1 (to get K_{i-1})
    //      LSB gets ~cin
    assign km1 = {k[46:0], ~cin};

    // ========================================================================
    // Step 3: Apply Schmookler Formula
    // ========================================================================
    // F[WIDTH] (MSB): Special handling for subtraction
    // For addition: F[48] = P[47]
    // For subtraction: F[48] = 0 (sub flag suppresses it)
    assign f[48] = ~is_sub & p[47];

    // F[WIDTH-1:0]: Main Schmookler formula
    // This is the key prediction logic that accounts for carry propagation
    assign f[47:0] = (pp1 & (g & ~km1 | k & ~gm1)) |
                     (~pp1 & (k & ~km1 | g & ~gm1));

    // ========================================================================
    // Step 4: Count Leading Zeros in Prediction Pattern
    // ========================================================================
    // We need a 49-bit LZC, but our fpu_lzc is 48-bit
    // Solution: Check MSB separately

    wire        f_msb_is_one;
    wire [47:0] f_lower;
    wire [5:0]  lzc_lower;

    assign f_msb_is_one = f[48];
    assign f_lower = f[47:0];

    fpu_lzc lzc_inst (
        .data_in (f_lower),
        .count   (lzc_lower)
    );

    // If MSB of f is 1, we have 0 leading zeros
    // Otherwise, add 1 to the count from lower 48 bits
    assign lza_count = f_msb_is_one ? 6'd0 : (lzc_lower + 6'd1);

    // ========================================================================
    // LZA Error Detection
    // ========================================================================
    // LZA can be off by ±1 due to carry propagation
    // Actual correction happens in normalization/shift correction stage
    // (See Wally's shiftcorrection.sv for post-correction logic)
    assign lza_error = 1'b0;  // Placeholder

endmodule

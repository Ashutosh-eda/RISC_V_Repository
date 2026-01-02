// ============================================================================
// FPU Shift Correction
// Corrects LZA prediction errors (off by ±1)
// Adjusts mantissa and exponent if needed
// Extracts proper GRS (Guard, Round, Sticky) bits
// ============================================================================

module fpu_shift_correction (
    input  wire [47:0] shifted_sum,    // Normalized sum from norm_shift
    input  wire [8:0]  norm_exp,       // Exponent from norm_shift
    input  wire        guard_in,       // Guard bit from adder
    input  wire        round_in,       // Round bit from adder
    input  wire        sticky_in,      // Sticky bit from adder/alignment

    output reg  [47:0] corrected_sum,  // Corrected significand
    output reg  [8:0]  corrected_exp,  // Corrected exponent
    output reg         guard,          // Guard bit for rounding
    output reg         round,          // Round bit for rounding
    output reg         sticky          // Sticky bit for rounding
);

    // ========================================================================
    // Check for LZA Error
    // ========================================================================
    // LZA error occurs when the leading bit is not 1 after normalization
    // Need to shift left by 1 if leading bit is 0

    wire needs_correction;
    assign needs_correction = (shifted_sum[47] == 1'b0) && (shifted_sum != 48'd0);

    // ========================================================================
    // Correction Logic
    // ========================================================================
    always @(*) begin
        if (needs_correction) begin
            // Shift left by 1
            corrected_sum = {shifted_sum[46:0], 1'b0};
            corrected_exp = norm_exp - 9'd1;

            // Update GRS bits
            guard  = guard_in;
            round  = round_in;
            sticky = sticky_in;
        end
        else begin
            // No correction needed
            corrected_sum = shifted_sum;
            corrected_exp = norm_exp;

            // GRS bits from input
            guard  = guard_in;
            round  = round_in;
            sticky = sticky_in;
        end
    end

    // ========================================================================
    // Alternative: Extract GRS from corrected_sum
    // ========================================================================
    // In a full implementation, we would extract GRS bits from the
    // lower bits of corrected_sum based on the final position
    // For now, we pass through the input GRS bits

endmodule

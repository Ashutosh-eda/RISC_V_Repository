// ============================================================================
// FPU Normalization Shifter
// Shifts the sum to normalize it (leading bit = 1)
// Uses LZA prediction to determine shift amount
// Handles both left shift (for cancellation) and right shift (for overflow)
// ============================================================================

module fpu_norm_shift (
    input  wire [48:0] sum,            // Sum from adder (49 bits)
    input  wire [5:0]  lza_count,      // Predicted shift amount
    input  wire [8:0]  sum_exp,        // Exponent before normalization
    input  wire        effective_sub,  // Effective operation type

    output reg  [47:0] shifted_sum,    // Normalized sum (48 bits)
    output reg  [8:0]  norm_exp,       // Normalized exponent
    output reg         overflow,       // Exponent overflow
    output reg         underflow       // Exponent underflow
);

    // ========================================================================
    // Determine Shift Direction and Amount
    // ========================================================================
    reg [5:0] shift_amount;
    reg shift_right;

    always @(*) begin
        if (sum[48]) begin
            // Sum overflowed (carry out) - need right shift by 1
            shift_right = 1'b1;
            shift_amount = 6'd1;
        end
        else if (effective_sub && (lza_count > 0)) begin
            // Subtraction caused cancellation - need left shift
            shift_right = 1'b0;
            shift_amount = lza_count;
        end
        else begin
            // No shift needed or minimal adjustment
            shift_right = 1'b0;
            shift_amount = 6'd0;
        end
    end

    // ========================================================================
    // Perform Shift
    // ========================================================================
    always @(*) begin
        if (shift_right) begin
            // Right shift by 1 (overflow case)
            shifted_sum = sum[48:1];  // Take upper 48 bits (shift right by 1)
            norm_exp = sum_exp + 9'd1;
        end
        else if (shift_amount > 0) begin
            // Left shift (normalization after cancellation)
            if (shift_amount >= 6'd48) begin
                // Shift too large - result is zero
                shifted_sum = 48'd0;
                norm_exp = 9'd0;
            end
            else begin
                shifted_sum = sum[47:0] << shift_amount;
                norm_exp = sum_exp - {3'd0, shift_amount};
            end
        end
        else begin
            // No shift
            shifted_sum = sum[47:0];
            norm_exp = sum_exp;
        end
    end

    // ========================================================================
    // Overflow/Underflow Detection
    // ========================================================================
    always @(*) begin
        // Overflow: exponent >= 255
        overflow = (norm_exp >= 9'd255);

        // Underflow: exponent <= 0
        underflow = (norm_exp[8] == 1'b1) || (norm_exp == 9'd0);
    end

endmodule

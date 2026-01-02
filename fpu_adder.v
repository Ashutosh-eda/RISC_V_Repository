// ============================================================================
// FPU Adder
// Performs addition or subtraction of aligned significands
// Handles effective subtraction and sign determination
// Output includes guard, round, and sticky bits for rounding
// ============================================================================

module fpu_adder (
    input  wire [47:0] operand_a,      // Product or larger operand
    input  wire [47:0] operand_b,      // Aligned addend
    input  wire        effective_sub,  // 1=subtract, 0=add
    input  wire        sticky_in,      // Sticky bit from alignment

    output reg  [48:0] sum,            // 49-bit sum (extra bit for overflow)
    output reg         result_sign,    // Sign of result
    output wire        guard,          // Guard bit
    output wire        round,          // Round bit
    output wire        sticky          // Sticky bit
);

    // ========================================================================
    // Addition/Subtraction
    // ========================================================================
    reg [48:0] extended_a;
    reg [48:0] extended_b;
    reg [48:0] raw_sum;

    always @(*) begin
        // Extend to 49 bits
        extended_a = {1'b0, operand_a};
        extended_b = {1'b0, operand_b};

        if (effective_sub) begin
            // Subtraction
            raw_sum = extended_a - extended_b;

            // Check if result is negative (need to swap and negate)
            if (raw_sum[48]) begin  // MSB = 1 means negative (2's complement)
                raw_sum = -raw_sum;
                result_sign = 1'b1;
            end
            else begin
                result_sign = 1'b0;
            end
        end
        else begin
            // Addition
            raw_sum = extended_a + extended_b;
            result_sign = 1'b0;  // Positive result
        end

        sum = raw_sum;
    end

    // ========================================================================
    // Extract GRS (Guard, Round, Sticky) Bits for Rounding
    // ========================================================================
    // After normalization, we'll need these bits
    // For now, we extract them based on current sum position

    // Guard bit: bit 2 of sum
    assign guard = sum[2];

    // Round bit: bit 1 of sum
    assign round = sum[1];

    // Sticky bit: bit 0 of sum OR sticky from alignment
    assign sticky = sum[0] | sticky_in;

endmodule

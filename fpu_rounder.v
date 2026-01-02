// ============================================================================
// FPU Rounder
// Implements all 5 IEEE 754 rounding modes
// Handles rounding and exponent adjustment
// ============================================================================

module fpu_rounder (
    input  wire [47:0] mantissa,      // Normalized mantissa
    input  wire [8:0]  exponent,      // Normalized exponent
    input  wire        sign,          // Result sign
    input  wire        guard,         // Guard bit
    input  wire        round,         // Round bit
    input  wire        sticky,        // Sticky bit
    input  wire [2:0]  rm,            // Rounding mode

    output reg  [22:0] mantissa_rounded,  // Rounded 23-bit mantissa
    output reg  [7:0]  exponent_rounded,  // Rounded exponent
    output wire        inexact,           // Inexact flag
    output wire        overflow           // Overflow flag
);

    // ========================================================================
    // Rounding Modes
    // ========================================================================
    localparam RNE = 3'b000;  // Round to Nearest, ties to Even
    localparam RTZ = 3'b001;  // Round Toward Zero
    localparam RDN = 3'b010;  // Round Down (-Inf)
    localparam RUP = 3'b011;  // Round Up (+Inf)
    localparam RMM = 3'b100;  // Round to Nearest, ties to Max Magnitude

    // ========================================================================
    // Extract LSB and GRS bits
    // ========================================================================
    wire lsb = mantissa[24];  // Least significant bit of result

    // ========================================================================
    // Rounding Decision
    // ========================================================================
    reg round_up;

    always @(*) begin
        case (rm)
            RNE: begin
                // Round to nearest, ties to even
                // Round up if: G=1 AND (R=1 OR S=1 OR LSB=1)
                round_up = guard & (round | sticky | lsb);
            end

            RTZ: begin
                // Round toward zero (truncate)
                round_up = 1'b0;
            end

            RDN: begin
                // Round down (toward -Inf)
                // Round up only if negative and there are non-zero bits
                round_up = sign & (guard | round | sticky);
            end

            RUP: begin
                // Round up (toward +Inf)
                // Round up only if positive and there are non-zero bits
                round_up = ~sign & (guard | round | sticky);
            end

            RMM: begin
                // Round to nearest, ties to max magnitude
                // Always round up on ties (G=1, R=0, S=0)
                round_up = guard;
            end

            default: begin
                round_up = 1'b0;
            end
        endcase
    end

    // ========================================================================
    // Perform Rounding
    // ========================================================================
    reg [24:0] mantissa_inc;  // 25 bits to detect overflow
    reg [23:0] mantissa_pre_round;

    always @(*) begin
        // Extract the upper 24 bits (1.mantissa format)
        mantissa_pre_round = mantissa[47:24];

        if (round_up) begin
            // Increment mantissa (use 25 bits to detect overflow)
            mantissa_inc = {1'b0, mantissa_pre_round} + 25'd1;

            if (mantissa_inc[24]) begin
                // Overflow: carry into bit 24 - need to shift right and increment exponent
                mantissa_rounded = mantissa_inc[23:1];
                exponent_rounded = exponent[7:0] + 8'd1;
            end
            else begin
                // No overflow in mantissa
                mantissa_rounded = mantissa_inc[22:0];
                exponent_rounded = exponent[7:0];
            end
        end
        else begin
            // No rounding (truncate)
            mantissa_rounded = mantissa_pre_round[22:0];
            exponent_rounded = exponent[7:0];
        end
    end

    // ========================================================================
    // Exception Flags
    // ========================================================================

    // Inexact: any of GRS bits is set
    assign inexact = guard | round | sticky;

    // Overflow: exponent = 255 (Inf)
    assign overflow = (exponent_rounded == 8'd255);

endmodule

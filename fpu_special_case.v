// ============================================================================
// FPU Special Case Handler
// Handles all IEEE 754 special cases:
//   - NaN (quiet and signaling)
//   - Infinity
//   - Zero
//   - Overflow
//   - Underflow
// Determines final result based on priority
// ============================================================================

module fpu_special_case (
    // Normal result
    input  wire [31:0] normal_result,
    input  wire        normal_sign,

    // Input classification
    input  wire        x_nan,
    input  wire        y_nan,
    input  wire        z_nan,
    input  wire        x_snan,
    input  wire        y_snan,
    input  wire        z_snan,
    input  wire        x_inf,
    input  wire        y_inf,
    input  wire        z_inf,
    input  wire        x_zero,
    input  wire        y_zero,
    input  wire        z_zero,

    // Exception conditions
    input  wire        overflow,
    input  wire        underflow,
    input  wire        invalid_op,

    // Operation type
    input  wire [2:0]  op_type,
    input  wire [2:0]  rm,            // Rounding mode for overflow

    // Final result
    output reg  [31:0] result
);

    // ========================================================================
    // IEEE 754 Constants
    // ========================================================================
    localparam QNAN_POS    = 32'h7FC00000;  // Canonical quiet NaN (+)
    localparam QNAN_NEG    = 32'hFFC00000;  // Canonical quiet NaN (-)
    localparam INF_POS     = 32'h7F800000;  // +Infinity
    localparam INF_NEG     = 32'hFF800000;  // -Infinity
    localparam ZERO_POS    = 32'h00000000;  // +0.0
    localparam ZERO_NEG    = 32'h80000000;  // -0.0
    localparam MAX_NORMAL  = 32'h7F7FFFFF;  // Largest normal number
    localparam MIN_NORMAL  = 32'h00800000;  // Smallest normal number

    // ========================================================================
    // Operation Types
    // ========================================================================
    localparam OP_ADD    = 3'b000;
    localparam OP_SUB    = 3'b001;
    localparam OP_MUL    = 3'b010;
    localparam OP_FMA    = 3'b011;
    localparam OP_FMS    = 3'b100;

    // ========================================================================
    // Rounding Modes
    // ========================================================================
    localparam RNE = 3'b000;
    localparam RTZ = 3'b001;
    localparam RDN = 3'b010;
    localparam RUP = 3'b011;
    localparam RMM = 3'b100;

    // ========================================================================
    // Special Case Detection and Handling
    // ========================================================================

    always @(*) begin
        // Priority (IEEE 754 standard):
        // 1. Signaling NaN → convert to quiet NaN
        // 2. Quiet NaN → propagate
        // 3. Invalid operation → generate NaN
        // 4. Infinity
        // 5. Overflow
        // 6. Underflow
        // 7. Normal result

        if (x_snan || y_snan || z_snan) begin
            // Signaling NaN detected - convert to quiet NaN
            result = QNAN_POS;
        end
        else if (x_nan) begin
            // Propagate X's NaN (make it quiet)
            result = {1'b0, 8'hFF, 1'b1, 22'd0};  // Quietize
        end
        else if (y_nan) begin
            // Propagate Y's NaN
            result = {1'b0, 8'hFF, 1'b1, 22'd0};
        end
        else if (z_nan) begin
            // Propagate Z's NaN
            result = {1'b0, 8'hFF, 1'b1, 22'd0};
        end
        else if (invalid_op) begin
            // Invalid operation (e.g., Inf - Inf, 0 × Inf)
            result = QNAN_POS;
        end
        else if (x_inf || y_inf || z_inf) begin
            // Handle infinity cases
            case (op_type)
                OP_MUL: begin
                    // Inf × anything (except 0) = Inf
                    if (x_zero || y_zero)
                        result = QNAN_POS;  // 0 × Inf = NaN
                    else
                        result = normal_sign ? INF_NEG : INF_POS;
                end

                OP_ADD, OP_SUB: begin
                    // Inf + Inf = Inf, Inf - Inf = NaN
                    if (x_inf && y_inf && (x_nan != y_nan))
                        result = QNAN_POS;  // Inf - Inf
                    else
                        result = normal_sign ? INF_NEG : INF_POS;
                end

                OP_FMA, OP_FMS: begin
                    // FMA with infinity
                    if ((x_zero && y_inf) || (x_inf && y_zero))
                        result = QNAN_POS;  // 0 × Inf
                    else
                        result = normal_sign ? INF_NEG : INF_POS;
                end

                default: result = normal_sign ? INF_NEG : INF_POS;
            endcase
        end
        else if (overflow) begin
            // Overflow - return Inf or max based on rounding mode
            case (rm)
                RTZ: result = normal_sign ? {1'b1, MAX_NORMAL[30:0]} : MAX_NORMAL;
                RDN: result = normal_sign ? INF_NEG : MAX_NORMAL;
                RUP: result = normal_sign ? {1'b1, MAX_NORMAL[30:0]} : INF_POS;
                default: result = normal_sign ? INF_NEG : INF_POS;  // RNE, RMM
            endcase
        end
        else if (underflow) begin
            // Underflow - return zero (or subnormal in full implementation)
            result = normal_sign ? ZERO_NEG : ZERO_POS;
        end
        else begin
            // Normal result
            result = normal_result;
        end
    end

endmodule

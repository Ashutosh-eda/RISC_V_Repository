// ============================================================================
// FPU Exception Flags Generator
// Generates the 5 IEEE 754 exception flags:
//   NV - Invalid Operation
//   DZ - Divide by Zero (not used in our FPU)
//   OF - Overflow
//   UF - Underflow
//   NX - Inexact
// ============================================================================

module fpu_exception_flags (
    // Result classification
    input  wire        result_overflow,
    input  wire        result_underflow,
    input  wire        result_inexact,
    input  wire        result_invalid,

    // Special case inputs
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

    // Operation type
    input  wire [2:0]  op_type,  // 000=ADD, 001=SUB, 010=MUL, 011=FMA, 100=FMS

    // Output flags
    output reg  [4:0]  flags     // {NV, DZ, OF, UF, NX}
);

    // ========================================================================
    // Flag Bit Positions
    // ========================================================================
    localparam NV = 4;  // Invalid Operation
    localparam DZ = 3;  // Divide by Zero (unused)
    localparam OF = 2;  // Overflow
    localparam UF = 1;  // Underflow
    localparam NX = 0;  // Inexact

    // ========================================================================
    // Operation Types
    // ========================================================================
    localparam OP_ADD = 3'b000;
    localparam OP_SUB = 3'b001;
    localparam OP_MUL = 3'b010;
    localparam OP_FMA = 3'b011;
    localparam OP_FMS = 3'b100;

    // ========================================================================
    // Invalid Operation Detection
    // ========================================================================
    reg invalid_op;

    always @(*) begin
        invalid_op = 1'b0;

        // Signaling NaN always causes invalid
        if (x_snan || y_snan || z_snan)
            invalid_op = 1'b1;

        // Invalid operations per IEEE 754
        case (op_type)
            OP_ADD, OP_SUB: begin
                // Inf - Inf or Inf + (-Inf) is invalid
                if (x_inf && y_inf)
                    invalid_op = 1'b1;
            end

            OP_MUL: begin
                // 0 × Inf or Inf × 0 is invalid
                if ((x_zero && y_inf) || (x_inf && y_zero))
                    invalid_op = 1'b1;
            end

            OP_FMA, OP_FMS: begin
                // 0 × Inf is invalid
                if ((x_zero && y_inf) || (x_inf && y_zero))
                    invalid_op = 1'b1;
                // Inf - Inf from product and addend
                // (More complex check - simplified here)
            end

            default: invalid_op = 1'b0;
        endcase

        // If result_invalid is explicitly set
        if (result_invalid)
            invalid_op = 1'b1;
    end

    // ========================================================================
    // Flag Generation
    // ========================================================================

    always @(*) begin
        flags = 5'b00000;

        // NV: Invalid Operation
        flags[NV] = invalid_op;

        // DZ: Divide by Zero (unused in our FPU)
        flags[DZ] = 1'b0;

        // OF: Overflow
        // Set when result exceeds maximum normal number
        flags[OF] = result_overflow;

        // UF: Underflow
        // Set when result is subnormal or underflows to zero
        flags[UF] = result_underflow;

        // NX: Inexact
        // Set when result cannot be represented exactly
        // Also set when overflow or underflow occurs
        flags[NX] = result_inexact || result_overflow || result_underflow;
    end

endmodule

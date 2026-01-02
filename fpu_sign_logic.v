// ============================================================================
// FPU Sign Logic
// Determines the sign of the result based on operation type
// Handles: ADD, SUB, MUL, FMA, FMS, FNMADD, FNMSUB
// ============================================================================

module fpu_sign_logic (
    input  wire       xs,          // X sign
    input  wire       ys,          // Y sign
    input  wire       zs,          // Z sign
    input  wire [2:0] op_type,     // Operation type

    output reg        prod_sign,   // Sign of X×Y
    output reg        result_sign  // Sign of final result
);

    // ========================================================================
    // Operation Type Encoding
    // ========================================================================
    localparam OP_ADD    = 3'b000;
    localparam OP_SUB    = 3'b001;
    localparam OP_MUL    = 3'b010;
    localparam OP_FMA    = 3'b011;  // (X×Y) + Z
    localparam OP_FMS    = 3'b100;  // (X×Y) - Z
    localparam OP_FNMADD = 3'b101;  // -((X×Y) + Z)
    localparam OP_FNMSUB = 3'b110;  // -((X×Y) - Z)

    // ========================================================================
    // Product Sign Calculation
    // ========================================================================
    // Product sign is XOR of X and Y signs
    always @(*) begin
        prod_sign = xs ^ ys;
    end

    // ========================================================================
    // Result Sign Logic
    // ========================================================================
    always @(*) begin
        case (op_type)
            OP_ADD: begin
                // For addition, sign depends on operands
                // This is preliminary; actual sign determined after addition
                result_sign = xs;  // Placeholder, actual logic in adder
            end

            OP_SUB: begin
                // For subtraction: X - Y = X + (-Y)
                result_sign = xs;  // Placeholder
            end

            OP_MUL: begin
                // Multiplication: sign is XOR of inputs
                result_sign = xs ^ ys;
            end

            OP_FMA: begin
                // (X×Y) + Z
                // Sign determined after addition
                // Preliminary: use product sign
                result_sign = prod_sign;  // Updated after addition
            end

            OP_FMS: begin
                // (X×Y) - Z
                result_sign = prod_sign;  // Updated after subtraction
            end

            OP_FNMADD: begin
                // -((X×Y) + Z)
                // Negate the FMA result
                result_sign = ~prod_sign;  // Will be negated after addition
            end

            OP_FNMSUB: begin
                // -((X×Y) - Z)
                result_sign = ~prod_sign;  // Will be negated after subtraction
            end

            default: begin
                result_sign = 1'b0;
            end
        endcase
    end

endmodule

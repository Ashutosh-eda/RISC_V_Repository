// ============================================================================
// FPU Addend Alignment
// Aligns the addend (Z) to match the exponent of the product (X×Y)
// Performs right shift based on exponent difference
// Computes sticky bit from shifted-out bits
// ============================================================================

module fpu_addend_align (
    input  wire [47:0] product,         // Product significand
    input  wire [8:0]  product_exp,     // Product exponent (9 bits for overflow)
    input  wire [23:0] addend,          // Addend significand (Z)
    input  wire [7:0]  addend_exp,      // Addend exponent
    input  wire        addend_sign,     // Addend sign
    input  wire        prod_sign,       // Product sign
    input  wire [2:0]  op_type,         // Operation type

    output reg  [47:0] addend_aligned,  // Aligned addend
    output reg  [8:0]  result_exp,      // Result exponent
    output reg         effective_sub,   // 1=subtraction, 0=addition
    output wire        sticky            // Sticky bit from alignment
);

    // ========================================================================
    // Operation Types
    // ========================================================================
    localparam OP_ADD    = 3'b000;
    localparam OP_SUB    = 3'b001;
    localparam OP_MUL    = 3'b010;
    localparam OP_FMA    = 3'b011;
    localparam OP_FMS    = 3'b100;
    localparam OP_FNMADD = 3'b101;
    localparam OP_FNMSUB = 3'b110;

    // ========================================================================
    // Exponent Difference Calculation
    // ========================================================================
    wire signed [9:0] exp_diff;
    wire [8:0] abs_exp_diff;
    wire product_larger;

    assign exp_diff = $signed({1'b0, product_exp}) - $signed({1'b0, addend_exp});
    assign product_larger = (exp_diff >= 0);
    assign abs_exp_diff = product_larger ? exp_diff[8:0] : -exp_diff[8:0];

    // ========================================================================
    // Determine Effective Operation (Add or Subtract)
    // ========================================================================
    always @(*) begin
        case (op_type)
            OP_ADD:    effective_sub = (addend_sign != prod_sign);
            OP_SUB:    effective_sub = (addend_sign == prod_sign);
            OP_FMA:    effective_sub = (addend_sign != prod_sign);
            OP_FMS:    effective_sub = (addend_sign == prod_sign);
            OP_FNMADD: effective_sub = (addend_sign == prod_sign);
            OP_FNMSUB: effective_sub = (addend_sign != prod_sign);
            default:   effective_sub = 1'b0;
        endcase
    end

    // ========================================================================
    // Alignment Shift
    // ========================================================================
    reg [71:0] extended_addend;  // Extended for shift with sticky tracking
    reg [71:0] shifted_addend;
    reg [71:0] sticky_bits;      // Changed to 72 bits to hold full mask

    always @(*) begin
        // Extend addend to 72 bits (24 integer + 48 fractional bits)
        extended_addend = {addend, 48'd0};

        if (abs_exp_diff >= 9'd72) begin
            // Shift amount >= 72 bits - addend becomes negligible
            shifted_addend = 72'd0;
            sticky_bits = |addend;  // All bits contribute to sticky
        end
        else begin
            // Perform right shift
            shifted_addend = extended_addend >> abs_exp_diff;

            // Extract shifted-out bits for sticky
            if (abs_exp_diff > 0) begin
                sticky_bits = extended_addend & ((72'd1 << abs_exp_diff) - 1);
            end
            else begin
                sticky_bits = 72'd0;
            end
        end

        // Take upper 48 bits as aligned addend
        addend_aligned = shifted_addend[71:24];

        // Result exponent is the larger exponent
        result_exp = product_larger ? product_exp : {1'b0, addend_exp};
    end

    // Sticky bit is OR of all shifted-out bits
    assign sticky = |sticky_bits;

endmodule

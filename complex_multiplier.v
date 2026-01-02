// ============================================================================
// Complex Multiplier
// - Computes (a + jb) × (c + jd) = (ac - bd) + j(ad + bc)
// - Uses 4 parallel FP multipliers + 2 FP adders
// - Latency: 7 cycles (3 for mul + 4 for add)
// ============================================================================

module complex_multiplier (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        enable,

    // First complex number (a + jb)
    input  wire [31:0] a_real,
    input  wire [31:0] a_imag,

    // Second complex number (c + jd)
    input  wire [31:0] c_real,
    input  wire [31:0] c_imag,

    // Result: (ac - bd) + j(ad + bc)
    output wire [31:0] result_real,
    output wire [31:0] result_imag,
    output wire        valid
);

    // ========================================================================
    // Stage 1-3: Four parallel multiplications (3 cycles each)
    // ========================================================================

    wire [31:0] ac, bd, ad, bc;

    // ac = a_real × c_real
    fp32_multiplier_pipe mul_ac (
        .clk     (clk),
        .rst_n   (rst_n),
        .x       (a_real),
        .y       (c_real),
        .rm      (3'b000),  // RNE rounding
        .product (ac),
        .flags   ()  // Ignore flags for now
    );

    // bd = a_imag × c_imag
    fp32_multiplier_pipe mul_bd (
        .clk     (clk),
        .rst_n   (rst_n),
        .x       (a_imag),
        .y       (c_imag),
        .rm      (3'b000),
        .product (bd),
        .flags   ()
    );

    // ad = a_real × c_imag
    fp32_multiplier_pipe mul_ad (
        .clk     (clk),
        .rst_n   (rst_n),
        .x       (a_real),
        .y       (c_imag),
        .rm      (3'b000),
        .product (ad),
        .flags   ()
    );

    // bc = a_imag × c_real
    fp32_multiplier_pipe mul_bc (
        .clk     (clk),
        .rst_n   (rst_n),
        .x       (a_imag),
        .y       (c_real),
        .rm      (3'b000),
        .product (bc),
        .flags   ()
    );

    // ========================================================================
    // Stage 4-7: Two parallel additions/subtractions (4 cycles each)
    // ========================================================================

    // Real part: ac - bd
    fp32_adder_pipe add_real (
        .clk    (clk),
        .rst_n  (rst_n),
        .x      (ac),
        .y      (bd),
        .sub    (1'b1),      // Subtraction
        .rm     (3'b000),
        .sum    (result_real),
        .flags  ()
    );

    // Imaginary part: ad + bc
    fp32_adder_pipe add_imag (
        .clk    (clk),
        .rst_n  (rst_n),
        .x      (ad),
        .y      (bc),
        .sub    (1'b0),      // Addition
        .rm     (3'b000),
        .sum    (result_imag),
        .flags  ()
    );

    // ========================================================================
    // Valid signal generation (7-cycle delay: 3 mul + 4 add)
    // ========================================================================

    reg [6:0] valid_shift;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            valid_shift <= 7'b0;
        else
            valid_shift <= {valid_shift[5:0], enable};
    end

    assign valid = valid_shift[6];

endmodule

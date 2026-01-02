// ============================================================================
// Radix-2 FFT Butterfly Unit (11-stage pipelined)
// - Computes: Out0 = X + (Y × W), Out1 = X - (Y × W)
// - Used for both DIF and DIT algorithms
// - Latency: 7 cycles (complex multiply) + 4 cycles (add/sub) = 11 cycles
// ============================================================================

module fft_butterfly_radix2 (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        enable,

    // Complex inputs X and Y
    input  wire [31:0] x_real,
    input  wire [31:0] x_imag,
    input  wire [31:0] y_real,
    input  wire [31:0] y_imag,

    // Twiddle factor W
    input  wire [31:0] w_real,
    input  wire [31:0] w_imag,

    // Complex outputs
    output reg  [31:0] out0_real,
    output reg  [31:0] out0_imag,
    output reg  [31:0] out1_real,
    output reg  [31:0] out1_imag,
    output wire        valid
);

    // ========================================================================
    // Stage 1-7: Complex Multiplication Y × W (7 cycles)
    // ========================================================================

    wire [31:0] yw_real, yw_imag;
    wire        cmul_valid;

    complex_multiplier cmul (
        .clk         (clk),
        .rst_n       (rst_n),
        .enable      (enable),
        .a_real      (y_real),
        .a_imag      (y_imag),
        .c_real      (w_real),
        .c_imag      (w_imag),
        .result_real (yw_real),
        .result_imag (yw_imag),
        .valid       (cmul_valid)
    );

    // ========================================================================
    // X Delay Pipeline (11 stages to match total butterfly latency)
    // ========================================================================

    reg [31:0] x_real_d [0:10];
    reg [31:0] x_imag_d [0:10];
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 11; i = i + 1) begin
                x_real_d[i] <= 32'h0;
                x_imag_d[i] <= 32'h0;
            end
        end else if (enable) begin
            x_real_d[0] <= x_real;
            x_imag_d[0] <= x_imag;
            for (i = 1; i < 11; i = i + 1) begin
                x_real_d[i] <= x_real_d[i-1];
                x_imag_d[i] <= x_imag_d[i-1];
            end
        end
    end

    // ========================================================================
    // Stage 8-11: Complex Addition and Subtraction (4 cycles each)
    // ========================================================================

    wire [31:0] add_real_out, add_imag_out;
    wire [31:0] sub_real_out, sub_imag_out;

    // Out0 = X + (Y×W) - Real part
    fp32_adder_pipe add_out0_real (
        .clk    (clk),
        .rst_n  (rst_n),
        .x      (x_real_d[6]),   // Use delayed X from stage 7
        .y      (yw_real),
        .sub    (1'b0),          // Addition
        .rm     (3'b000),
        .sum    (add_real_out),
        .flags  ()
    );

    // Out0 = X + (Y×W) - Imaginary part
    fp32_adder_pipe add_out0_imag (
        .clk    (clk),
        .rst_n  (rst_n),
        .x      (x_imag_d[6]),   // Use delayed X from stage 7
        .y      (yw_imag),
        .sub    (1'b0),          // Addition
        .rm     (3'b000),
        .sum    (add_imag_out),
        .flags  ()
    );

    // Out1 = X - (Y×W) - Real part
    fp32_adder_pipe sub_out1_real (
        .clk    (clk),
        .rst_n  (rst_n),
        .x      (x_real_d[6]),   // Use delayed X from stage 7
        .y      (yw_real),
        .sub    (1'b1),          // Subtraction
        .rm     (3'b000),
        .sum    (sub_real_out),
        .flags  ()
    );

    // Out1 = X - (Y×W) - Imaginary part
    fp32_adder_pipe sub_out1_imag (
        .clk    (clk),
        .rst_n  (rst_n),
        .x      (x_imag_d[6]),   // Use delayed X from stage 7
        .y      (yw_imag),
        .sub    (1'b1),          // Subtraction
        .rm     (3'b000),
        .sum    (sub_imag_out),
        .flags  ()
    );

    // ========================================================================
    // Output registers
    // ========================================================================

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out0_real <= 32'h0;
            out0_imag <= 32'h0;
            out1_real <= 32'h0;
            out1_imag <= 32'h0;
        end else begin
            out0_real <= add_real_out;
            out0_imag <= add_imag_out;
            out1_real <= sub_real_out;
            out1_imag <= sub_imag_out;
        end
    end

    // ========================================================================
    // Valid signal (11 cycles total: 7 for cmul + 4 for add/sub)
    // ========================================================================

    reg [10:0] valid_shift;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            valid_shift <= 11'b0;
        else
            valid_shift <= {valid_shift[9:0], enable};
    end

    assign valid = valid_shift[10];

endmodule

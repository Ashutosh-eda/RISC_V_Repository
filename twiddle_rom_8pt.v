// ============================================================================
// Twiddle Factor ROM for 8-Point FFT
// - Pre-computed complex exponentials: W_N^k = e^(-j2πk/N)
// - Only 4 unique twiddle factors needed for N=8
// - IEEE 754 single-precision format
// ============================================================================

module twiddle_rom_8pt (
    input  wire        clk,
    input  wire [1:0]  addr,      // 0-3 (only 4 twiddles needed)
    output reg  [31:0] w_real,    // cos(-2πk/8)
    output reg  [31:0] w_imag     // sin(-2πk/8)
);

    // Pre-computed twiddle factors for N=8
    // W[k] = cos(-2πk/8) + j*sin(-2πk/8)

    always @(posedge clk) begin
        case (addr)
            2'b00: begin  // W^0 = 1.0 + j*0.0
                w_real <= 32'h3F800000;  // 1.0
                w_imag <= 32'h00000000;  // 0.0
            end

            2'b01: begin  // W^1 = cos(-π/4) + j*sin(-π/4) = 0.707 - j*0.707
                w_real <= 32'h3F3504F3;  // 0.7071067811865476
                w_imag <= 32'hBF3504F3;  // -0.7071067811865476
            end

            2'b10: begin  // W^2 = cos(-π/2) + j*sin(-π/2) = 0.0 - j*1.0
                w_real <= 32'h00000000;  // 0.0
                w_imag <= 32'hBF800000;  // -1.0
            end

            2'b11: begin  // W^3 = cos(-3π/4) + j*sin(-3π/4) = -0.707 - j*0.707
                w_real <= 32'hBF3504F3;  // -0.7071067811865476
                w_imag <= 32'hBF3504F3;  // -0.7071067811865476
            end

            default: begin  // Default to W^0 (should never happen)
                w_real <= 32'h3F800000;  // 1.0
                w_imag <= 32'h00000000;  // 0.0
            end
        endcase
    end

endmodule

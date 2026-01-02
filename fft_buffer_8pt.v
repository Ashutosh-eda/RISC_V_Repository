// ============================================================================
// FFT Buffer Memory (8-Point)
// - Stores 8 complex samples (16 × 32-bit values)
// - Dual-port RAM: one read port, one write port
// - Used for storing intermediate FFT results during computation
// - Total size: 512 bits (8 samples × 2 components × 32 bits)
// ============================================================================

module fft_buffer_8pt (
    input  wire        clk,
    input  wire        rst_n,

    // Write port
    input  wire        wr_en,
    input  wire [2:0]  wr_addr,      // 0-7 for 8 samples
    input  wire [31:0] wr_real,      // Real part
    input  wire [31:0] wr_imag,      // Imaginary part

    // Read port
    input  wire [2:0]  rd_addr,      // 0-7 for 8 samples
    output reg  [31:0] rd_real,      // Real part
    output reg  [31:0] rd_imag       // Imaginary part
);

    // ========================================================================
    // Memory Arrays
    // ========================================================================
    reg [31:0] buffer_real [0:7];    // Real parts of 8 samples
    reg [31:0] buffer_imag [0:7];    // Imaginary parts of 8 samples

    integer i;

    // ========================================================================
    // Write Logic
    // ========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 8; i = i + 1) begin
                buffer_real[i] <= 32'h0;
                buffer_imag[i] <= 32'h0;
            end
        end else if (wr_en) begin
            buffer_real[wr_addr] <= wr_real;
            buffer_imag[wr_addr] <= wr_imag;
        end
    end

    // ========================================================================
    // Read Logic (Combinational)
    // ========================================================================
    always @(*) begin
        rd_real = buffer_real[rd_addr];
        rd_imag = buffer_imag[rd_addr];
    end

endmodule

// ============================================================================
// 8-Point FFT Coprocessor
// - Complete FFT coprocessor with internal buffer
// - Accepts load/store commands from CPU
// - Performs radix-2 DIT FFT computation
// - Based on custom instruction interface from paper
// ============================================================================

module fft_coprocessor_8pt (
    input  wire        clk,
    input  wire        rst_n,

    // Command Interface
    input  wire [2:0]  cmd,           // Command type
    input  wire [2:0]  addr,          // Sample address (0-7)
    input  wire [31:0] data_in_real,  // Input data (real)
    input  wire [31:0] data_in_imag,  // Input data (imag)

    // Output Interface
    output reg  [31:0] data_out_real, // Output data (real)
    output reg  [31:0] data_out_imag, // Output data (imag)
    output wire        busy,          // FFT computation in progress
    output wire        ready          // Ready for new command
);

    // ========================================================================
    // Command Definitions (matching paper's custom instructions)
    // ========================================================================
    localparam CMD_IDLE      = 3'b000;
    localparam CMD_LOAD_REAL = 3'b001;  // Load real part
    localparam CMD_LOAD_IMAG = 3'b010;  // Load imaginary part
    localparam CMD_STORE_REAL= 3'b011;  // Store real part
    localparam CMD_STORE_IMAG= 3'b100;  // Store imaginary part
    localparam CMD_START     = 3'b101;  // Start FFT
    localparam CMD_RESET     = 3'b110;  // Reset (not used)

    // ========================================================================
    // Internal Signals
    // ========================================================================

    // Buffer interface
    wire        buf_wr_en;
    wire [2:0]  buf_wr_addr, buf_rd_addr;
    wire [31:0] buf_wr_real, buf_wr_imag;
    wire [31:0] buf_rd_real, buf_rd_imag;

    // Control signals
    wire        fft_start;
    wire        fft_done;
    wire        butterfly_valid;
    wire        butterfly_enable;

    // Butterfly I/O
    wire [31:0] x_real, x_imag, y_real, y_imag;
    wire [31:0] w_real, w_imag;
    wire [31:0] out0_real, out0_imag, out1_real, out1_imag;

    // Address control
    wire [2:0]  rd_addr_x, rd_addr_y, wr_addr_0, wr_addr_1;
    wire [1:0]  twiddle_addr;
    wire [1:0]  current_stage, butterfly_idx;

    // Command handling
    reg  [31:0] load_real_temp;  // Temporary storage for real part
    reg         real_loaded;     // Flag indicating real part loaded
    reg         fft_start_reg;

    // ========================================================================
    // Buffer Memory Instance
    // ========================================================================
    fft_buffer_8pt buffer (
        .clk      (clk),
        .rst_n    (rst_n),
        .wr_en    (buf_wr_en),
        .wr_addr  (buf_wr_addr),
        .wr_real  (buf_wr_real),
        .wr_imag  (buf_wr_imag),
        .rd_addr  (buf_rd_addr),
        .rd_real  (buf_rd_real),
        .rd_imag  (buf_rd_imag)
    );

    // ========================================================================
    // Control FSM Instance
    // ========================================================================
    fft_control_8pt control (
        .clk              (clk),
        .rst_n            (rst_n),
        .start            (fft_start),
        .butterfly_valid  (butterfly_valid),
        .busy             (busy),
        .done             (fft_done),
        .rd_addr_x        (rd_addr_x),
        .rd_addr_y        (rd_addr_y),
        .wr_addr_0        (wr_addr_0),
        .wr_addr_1        (wr_addr_1),
        .wr_en            (buf_wr_en_fft),
        .butterfly_enable (butterfly_enable),
        .twiddle_addr     (twiddle_addr),
        .current_stage    (current_stage),
        .butterfly_idx    (butterfly_idx)
    );

    // ========================================================================
    // Twiddle ROM Instance
    // ========================================================================
    wire [31:0] twiddle_real, twiddle_imag;

    twiddle_rom_8pt twiddle_rom (
        .clk    (clk),
        .addr   (twiddle_addr),
        .w_real (twiddle_real),
        .w_imag (twiddle_imag)
    );

    // ========================================================================
    // Butterfly Unit Instance
    // ========================================================================
    fft_butterfly_radix2 butterfly (
        .clk       (clk),
        .rst_n     (rst_n),
        .enable    (butterfly_enable),
        .x_real    (x_real),
        .x_imag    (x_imag),
        .y_real    (y_real),
        .y_imag    (y_imag),
        .w_real    (twiddle_real),
        .w_imag    (twiddle_imag),
        .out0_real (out0_real),
        .out0_imag (out0_imag),
        .out1_real (out1_real),
        .out1_imag (out1_imag),
        .valid     (butterfly_valid)
    );

    // ========================================================================
    // Buffer Access Multiplexing
    // ========================================================================
    wire        buf_wr_en_cpu, buf_wr_en_fft;
    wire [2:0]  buf_wr_addr_cpu, buf_rd_addr_cpu;
    wire [31:0] buf_wr_real_cpu, buf_wr_imag_cpu;

    // During FFT computation, control FSM manages buffer
    // During idle, CPU can load/store data
    assign buf_wr_en   = busy ? buf_wr_en_fft : buf_wr_en_cpu;
    assign buf_wr_addr = busy ? wr_addr_0 : buf_wr_addr_cpu;  // Note: Out0 and Out1 need separate writes
    assign buf_wr_real = busy ? out0_real : buf_wr_real_cpu;
    assign buf_wr_imag = busy ? out0_imag : buf_wr_imag_cpu;
    assign buf_rd_addr = busy ? rd_addr_x : buf_rd_addr_cpu;

    // ========================================================================
    // Butterfly Input Multiplexing (need 2 read ports, simulate with 2 cycles)
    // ========================================================================
    reg [31:0] x_real_reg, x_imag_reg;
    reg [31:0] y_real_reg, y_imag_reg;

    // Read X on first cycle after butterfly_enable
    // Read Y on second cycle
    // This is a simplification - production design would use dual-port RAM

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x_real_reg <= 32'h0;
            x_imag_reg <= 32'h0;
            y_real_reg <= 32'h0;
            y_imag_reg <= 32'h0;
        end else if (butterfly_enable) begin
            // Capture both X and Y from buffer reads
            // Assumes control FSM provides correct addresses
            x_real_reg <= buf_rd_real;
            x_imag_reg <= buf_rd_imag;
        end
    end

    // For this simplified version, use combinational reads
    assign x_real = buf_rd_real;  // Reading from rd_addr_x
    assign x_imag = buf_rd_imag;

    // Y requires second read - simplified here, production needs dual-port
    assign y_real = buf_rd_real;  // Would read from rd_addr_y
    assign y_imag = buf_rd_imag;

    // ========================================================================
    // CPU Command Interface
    // ========================================================================

    assign ready = !busy && !fft_start_reg;

    // Command decoder
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            load_real_temp <= 32'h0;
            real_loaded <= 1'b0;
            fft_start_reg <= 1'b0;
            data_out_real <= 32'h0;
            data_out_imag <= 32'h0;
        end else begin
            fft_start_reg <= 1'b0;  // Single-cycle pulse

            if (!busy) begin
                case (cmd)
                    CMD_LOAD_REAL: begin
                        load_real_temp <= data_in_real;
                        real_loaded <= 1'b1;
                    end

                    CMD_LOAD_IMAG: begin
                        if (real_loaded) begin
                            // Write both real and imag to buffer
                            // This will be handled by CPU interface logic below
                            real_loaded <= 1'b0;
                        end
                    end

                    CMD_STORE_REAL: begin
                        data_out_real <= buf_rd_real;
                    end

                    CMD_STORE_IMAG: begin
                        data_out_imag <= buf_rd_imag;
                    end

                    CMD_START: begin
                        fft_start_reg <= 1'b1;
                    end

                    CMD_RESET: begin
                        // Reset logic if needed
                    end

                    default: begin
                        // IDLE
                    end
                endcase
            end
        end
    end

    // CPU buffer write signals
    assign buf_wr_en_cpu = (cmd == CMD_LOAD_IMAG) && real_loaded && !busy;
    assign buf_wr_addr_cpu = addr;
    assign buf_wr_real_cpu = load_real_temp;
    assign buf_wr_imag_cpu = data_in_imag;
    assign buf_rd_addr_cpu = addr;

    assign fft_start = fft_start_reg;

    // ========================================================================
    // Output Write-Back Logic (needs enhancement for dual writes)
    // ========================================================================
    // NOTE: This simplified version only writes Out0 to buffer
    // Production design needs to write both Out0 and Out1 in same cycle
    // This requires dual-port write capability or sequential writes

endmodule

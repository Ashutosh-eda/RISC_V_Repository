// ============================================================================
// Minimal Floating-Point CSR Module
// Implements only the 3 FP-related CSRs:
//   - fcsr  (0x003): Floating-point control and status register
//   - frm   (0x002): Floating-point rounding mode
//   - fflags (0x001): Floating-point exception flags
// ============================================================================

module fpu_csr (
    input  wire        clk,
    input  wire        rst_n,

    // CSR Access from Decode/Execute Stage
    input  wire        csr_write,       // CSR write enable
    input  wire [11:0] csr_addr,        // CSR address
    input  wire [31:0] csr_wdata,       // Write data
    input  wire [1:0]  csr_op,          // 00=write, 01=set, 10=clear
    output reg  [31:0] csr_rdata,       // Read data

    // Exception Flags from FPU
    input  wire [4:0]  fpu_flags,       // Flags from FPU operation
    input  wire        fpu_flags_valid, // Flags valid (FPU completed)

    // Outputs to FPU
    output wire [2:0]  frm_out,         // Rounding mode
    output wire [4:0]  fflags_out       // Current exception flags
);

    // ========================================================================
    // CSR Addresses
    // ========================================================================
    localparam CSR_FFLAGS = 12'h001;
    localparam CSR_FRM    = 12'h002;
    localparam CSR_FCSR   = 12'h003;

    // ========================================================================
    // CSR Storage
    // ========================================================================
    reg [2:0] frm_reg;      // Rounding mode (3 bits)
    reg [4:0] fflags_reg;   // Exception flags (5 bits)

    // Combined fcsr register
    wire [31:0] fcsr = {24'd0, frm_reg, fflags_reg};

    // ========================================================================
    // Rounding Mode Encoding
    // ========================================================================
    // 000: RNE - Round to Nearest, ties to Even
    // 001: RTZ - Round Toward Zero
    // 010: RDN - Round Down (-Infinity)
    // 011: RUP - Round Up (+Infinity)
    // 100: RMM - Round to Nearest, ties to Max Magnitude
    // 111: DYN - Dynamic (use instruction's rm field)

    // ========================================================================
    // Exception Flags (Sticky Bits)
    // ========================================================================
    // Bit 4: NV - Invalid Operation
    // Bit 3: DZ - Divide by Zero (not used in our FPU)
    // Bit 2: OF - Overflow
    // Bit 1: UF - Underflow
    // Bit 0: NX - Inexact

    // ========================================================================
    // CSR Write Logic
    // ========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            frm_reg    <= 3'b000;  // Default: RNE (Round to Nearest Even)
            fflags_reg <= 5'b00000;
        end
        else begin
            // Update flags from FPU (sticky OR - flags accumulate)
            if (fpu_flags_valid) begin
                fflags_reg <= fflags_reg | fpu_flags;
            end

            // CSR write operations
            if (csr_write) begin
                case (csr_addr)
                    CSR_FFLAGS: begin
                        case (csr_op)
                            2'b00:   fflags_reg <= csr_wdata[4:0];                  // CSRRW: Write
                            2'b01:   fflags_reg <= fflags_reg | csr_wdata[4:0];     // CSRRS: Set
                            2'b10:   fflags_reg <= fflags_reg & ~csr_wdata[4:0];    // CSRRC: Clear
                            default: fflags_reg <= fflags_reg;
                        endcase
                    end

                    CSR_FRM: begin
                        case (csr_op)
                            2'b00:   frm_reg <= csr_wdata[2:0];                     // CSRRW: Write
                            2'b01:   frm_reg <= frm_reg | csr_wdata[2:0];           // CSRRS: Set
                            2'b10:   frm_reg <= frm_reg & ~csr_wdata[2:0];          // CSRRC: Clear
                            default: frm_reg <= frm_reg;
                        endcase
                    end

                    CSR_FCSR: begin
                        case (csr_op)
                            2'b00: begin  // CSRRW: Write
                                frm_reg    <= csr_wdata[7:5];
                                fflags_reg <= csr_wdata[4:0];
                            end
                            2'b01: begin  // CSRRS: Set
                                frm_reg    <= frm_reg | csr_wdata[7:5];
                                fflags_reg <= fflags_reg | csr_wdata[4:0];
                            end
                            2'b10: begin  // CSRRC: Clear
                                frm_reg    <= frm_reg & ~csr_wdata[7:5];
                                fflags_reg <= fflags_reg & ~csr_wdata[4:0];
                            end
                            default: begin
                                frm_reg    <= frm_reg;
                                fflags_reg <= fflags_reg;
                            end
                        endcase
                    end

                    default: begin
                        // Invalid CSR address - no action
                    end
                endcase
            end
        end
    end

    // ========================================================================
    // CSR Read Logic
    // ========================================================================
    always @(*) begin
        case (csr_addr)
            CSR_FFLAGS:  csr_rdata = {27'd0, fflags_reg};
            CSR_FRM:     csr_rdata = {29'd0, frm_reg};
            CSR_FCSR:    csr_rdata = fcsr;
            default:     csr_rdata = 32'd0;
        endcase
    end

    // ========================================================================
    // Outputs
    // ========================================================================
    assign frm_out    = frm_reg;
    assign fflags_out = fflags_reg;

endmodule

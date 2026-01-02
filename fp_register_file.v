// ============================================================================
// Floating-Point Register File (f0-f31)
// - 32 registers of 32-bit width (single-precision)
// - All registers are usable (no hardwired zero like integer x0)
// - Three read ports (rs1, rs2, rs3 for FMA), single write port
// - Write occurs on rising clock edge
// ============================================================================

module fp_register_file (
    input  wire        clk,
    input  wire        rst_n,

    // Read ports
    input  wire [4:0]  rs1_addr,
    input  wire [4:0]  rs2_addr,
    input  wire [4:0]  rs3_addr,     // Third port for FMA operations
    output wire [31:0] rs1_data,
    output wire [31:0] rs2_data,
    output wire [31:0] rs3_data,

    // Write port
    input  wire [4:0]  rd_addr,
    input  wire [31:0] wr_data,
    input  wire        wr_en
);

    // Register array (f0-f31)
    reg [31:0] registers [0:31];

    integer i;

    // Reset registers to +0.0 (32'h0000_0000)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 32; i = i + 1) begin
                registers[i] <= 32'h0000_0000;
            end
        end
        else if (wr_en) begin
            registers[rd_addr] <= wr_data;
        end
    end

    // Read logic (3 read ports)
    assign rs1_data = registers[rs1_addr];
    assign rs2_data = registers[rs2_addr];
    assign rs3_data = registers[rs3_addr];

endmodule

// ============================================================================
// Integer Register File (x0-x31)
// - 32 registers of 32-bit width
// - x0 is hardwired to zero
// - Dual read ports, single write port
// - Write occurs on rising clock edge
// ============================================================================

module register_file (
    input  wire        clk,
    input  wire        rst_n,

    // Read ports
    input  wire [4:0]  rs1_addr,
    input  wire [4:0]  rs2_addr,
    output wire [31:0] rs1_data,
    output wire [31:0] rs2_data,

    // Write port
    input  wire [4:0]  rd_addr,
    input  wire [31:0] wr_data,
    input  wire        wr_en
);

    // Register array (x1-x31, x0 is always 0)
    reg [31:0] registers [1:31];

    integer i;

    // Reset registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 1; i < 32; i = i + 1) begin
                registers[i] <= 32'd0;
            end
        end
        else if (wr_en && (rd_addr != 5'd0)) begin
            registers[rd_addr] <= wr_data;
        end
    end

    // Read logic (x0 always returns 0)
    assign rs1_data = (rs1_addr == 5'd0) ? 32'd0 : registers[rs1_addr];
    assign rs2_data = (rs2_addr == 5'd0) ? 32'd0 : registers[rs2_addr];

endmodule

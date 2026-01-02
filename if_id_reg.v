// ============================================================================
// IF/ID Pipeline Register
// - Stores fetched instruction and PC
// - Supports stall and flush operations
// ============================================================================

module if_id_reg (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        stall,
    input  wire        flush,

    // Inputs from Fetch Stage
    input  wire [31:0] pc_if,
    input  wire [31:0] instr_if,
    input  wire [31:0] pc_plus4_if,

    // Outputs to Decode Stage
    output reg  [31:0] pc_id,
    output reg  [31:0] instr_id,
    output reg  [31:0] pc_plus4_id
);

    // NOP instruction (ADDI x0, x0, 0)
    localparam NOP = 32'h0000_0013;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc_id       <= 32'd0;
            instr_id    <= NOP;
            pc_plus4_id <= 32'd0;
        end
        else if (flush) begin
            // Insert bubble (NOP)
            pc_id       <= 32'd0;
            instr_id    <= NOP;
            pc_plus4_id <= 32'd0;
        end
        else if (!stall) begin
            pc_id       <= pc_if;
            instr_id    <= instr_if;
            pc_plus4_id <= pc_plus4_if;
        end
        // If stall, retain current values
    end

endmodule

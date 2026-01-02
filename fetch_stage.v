// ============================================================================
// Fetch Stage (IF)
// - Program Counter (PC) management
// - Instruction fetch from memory
// - PC+4 calculation for sequential execution
// - Branch target handling
// ============================================================================

module fetch_stage (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        stall,           // From hazard unit
    input  wire        branch_taken,    // From execute stage
    input  wire [31:0] branch_target,   // From execute stage

    output reg  [31:0] pc_out,
    output wire [31:0] pc_plus4,
    output wire [31:0] imem_addr,
    output wire        imem_req
);

    // ========================================================================
    // Internal Signals
    // ========================================================================

    reg  [31:0] pc_reg;
    wire [31:0] pc_next;

    // ========================================================================
    // PC Logic
    // ========================================================================

    // PC+4 adder
    assign pc_plus4 = pc_reg + 32'd4;

    // Next PC selection
    // Priority: Branch > Stall > Sequential
    assign pc_next = branch_taken ? branch_target :
                     stall        ? pc_reg :
                                    pc_plus4;

    // PC register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            pc_reg <= 32'h0000_0000;  // Reset vector
        else
            pc_reg <= pc_next;
    end

    // ========================================================================
    // Outputs
    // ========================================================================

    assign imem_addr = pc_reg;
    assign imem_req  = 1'b1;  // Always requesting (can be gated by valid signal)

    always @(*) begin
        pc_out = pc_reg;
    end

endmodule

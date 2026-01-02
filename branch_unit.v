// ============================================================================
// Branch Unit
// - Evaluates branch conditions
// - Calculates branch/jump targets
// - Generates branch_taken signal
// ============================================================================

module branch_unit (
    input  wire [31:0] rs1_data,
    input  wire [31:0] rs2_data,
    input  wire [31:0] pc,
    input  wire [31:0] imm,
    input  wire [2:0]  funct3,
    input  wire        branch,
    input  wire        jump,
    input  wire        alu_src,      // For JALR

    output reg  [31:0] branch_target,
    output reg         branch_taken
);

    // Branch function codes
    localparam BEQ  = 3'b000;
    localparam BNE  = 3'b001;
    localparam BLT  = 3'b100;
    localparam BGE  = 3'b101;
    localparam BLTU = 3'b110;
    localparam BGEU = 3'b111;

    // Comparison results
    wire eq   = (rs1_data == rs2_data);
    wire ne   = ~eq;
    wire lt   = ($signed(rs1_data) < $signed(rs2_data));
    wire ge   = ~lt;
    wire ltu  = (rs1_data < rs2_data);
    wire geu  = ~ltu;

    // Branch condition evaluation
    reg branch_cond;

    always @(*) begin
        case (funct3)
            BEQ:     branch_cond = eq;
            BNE:     branch_cond = ne;
            BLT:     branch_cond = lt;
            BGE:     branch_cond = ge;
            BLTU:    branch_cond = ltu;
            BGEU:    branch_cond = geu;
            default: branch_cond = 1'b0;
        endcase
    end

    // Branch target calculation
    // JAL/Branch: PC + imm
    // JALR: (rs1 + imm) & ~1
    always @(*) begin
        if (alu_src && jump) begin
            // JALR: (rs1 + imm) & ~1
            branch_target = (rs1_data + imm) & 32'hFFFF_FFFE;
        end
        else begin
            // JAL/Branch: PC + imm
            branch_target = pc + imm;
        end
    end

    // Branch taken logic
    always @(*) begin
        if (jump)
            branch_taken = 1'b1;  // JAL or JALR always taken
        else if (branch)
            branch_taken = branch_cond;
        else
            branch_taken = 1'b0;
    end

endmodule

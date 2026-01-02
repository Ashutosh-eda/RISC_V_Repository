// ============================================================================
// Arithmetic Logic Unit (ALU)
// - Performs all integer arithmetic and logical operations
// - Supports RV32I base instruction set
// ============================================================================

module alu (
    input  wire [31:0] operand_a,
    input  wire [31:0] operand_b,
    input  wire [3:0]  alu_op,
    output reg  [31:0] result,
    output wire        zero
);

    // ALU operation encodings
    localparam ALU_ADD   = 4'b0000;
    localparam ALU_SUB   = 4'b0001;
    localparam ALU_SLL   = 4'b0010;
    localparam ALU_SLT   = 4'b0011;
    localparam ALU_SLTU  = 4'b0100;
    localparam ALU_XOR   = 4'b0101;
    localparam ALU_SRL   = 4'b0110;
    localparam ALU_SRA   = 4'b0111;
    localparam ALU_OR    = 4'b1000;
    localparam ALU_AND   = 4'b1001;
    localparam ALU_LUI   = 4'b1010;
    localparam ALU_AUIPC = 4'b1011;

    // Shift amount (lower 5 bits of operand_b)
    wire [4:0] shamt = operand_b[4:0];

    // Signed comparison
    wire signed_lt = ($signed(operand_a) < $signed(operand_b));

    // Unsigned comparison
    wire unsigned_lt = (operand_a < operand_b);

    always @(*) begin
        case (alu_op)
            ALU_ADD:   result = operand_a + operand_b;
            ALU_SUB:   result = operand_a - operand_b;
            ALU_SLL:   result = operand_a << shamt;
            ALU_SLT:   result = {31'd0, signed_lt};
            ALU_SLTU:  result = {31'd0, unsigned_lt};
            ALU_XOR:   result = operand_a ^ operand_b;
            ALU_SRL:   result = operand_a >> shamt;
            ALU_SRA:   result = $signed(operand_a) >>> shamt;
            ALU_OR:    result = operand_a | operand_b;
            ALU_AND:   result = operand_a & operand_b;
            ALU_LUI:   result = operand_b;  // LUI: just pass immediate
            ALU_AUIPC: result = operand_a + operand_b;  // PC + imm
            default:   result = 32'd0;
        endcase
    end

    assign zero = (result == 32'd0);

endmodule

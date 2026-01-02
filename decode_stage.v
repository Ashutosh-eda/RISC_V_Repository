// ============================================================================
// Decode Stage (ID)
// - Instruction decoding
// - Register file reads (Integer + Floating-Point)
// - Immediate generation
// - Control signal generation
// ============================================================================

module decode_stage (
    input  wire        clk,
    input  wire        rst_n,

    // From IF/ID Register
    input  wire [31:0] instr,
    input  wire [31:0] pc,

    // From Writeback Stage
    input  wire [31:0] wb_data,
    input  wire [4:0]  wb_rd,
    input  wire        wb_reg_write,
    input  wire        wb_fp_reg_write,

    // Register File Outputs (Integer)
    output wire [31:0] rs1_data,
    output wire [31:0] rs2_data,

    // FP Register File Outputs
    output wire [31:0] fp_rs1_data,
    output wire [31:0] fp_rs2_data,
    output wire [31:0] fp_rs3_data,

    // Decoded Fields
    output wire [31:0] imm,
    output wire [4:0]  rd,
    output wire [4:0]  rs1,
    output wire [4:0]  rs2,
    output wire [4:0]  rs3,           // For FMA instructions
    output wire [2:0]  funct3,
    output wire [6:0]  funct7,

    // Control Signals
    output wire        reg_write,
    output wire        mem_read,
    output wire        mem_write,
    output wire        mem_to_reg,
    output wire        alu_src,
    output wire        branch,
    output wire        jump,
    output wire [3:0]  alu_op,
    output wire        fp_op,
    output wire        fft_op,
    output wire        fp_reg_write,  // FP register write enable
    output wire        fma_op,        // FMA operation (uses rs3)
    output wire        csr_op         // CSR instruction
);

    // ========================================================================
    // Instruction Field Extraction
    // ========================================================================

    wire [6:0] opcode = instr[6:0];
    assign     rd      = instr[11:7];
    assign     funct3  = instr[14:12];
    assign     rs1     = instr[19:15];
    assign     rs2     = instr[24:20];
    assign     rs3     = instr[31:27];  // rs3 field for FMA (R4-type)
    assign     funct7  = instr[31:25];

    // ========================================================================
    // Opcode Definitions (RV32I + RV32F)
    // ========================================================================

    localparam OP_LOAD      = 7'b0000011;  // I-type loads
    localparam OP_LOAD_FP   = 7'b0000111;  // FLW
    localparam OP_CUSTOM_0  = 7'b0001011;  // Custom-0 (FFT instructions)
    localparam OP_MISC_MEM  = 7'b0001111;  // FENCE
    localparam OP_OP_IMM    = 7'b0010011;  // I-type ALU
    localparam OP_AUIPC     = 7'b0010111;  // AUIPC
    localparam OP_STORE     = 7'b0100011;  // S-type stores
    localparam OP_STORE_FP  = 7'b0100111;  // FSW
    localparam OP_OP        = 7'b0110011;  // R-type ALU
    localparam OP_LUI       = 7'b0110111;  // LUI
    localparam OP_FP        = 7'b1010011;  // Floating-point ops
    localparam OP_BRANCH    = 7'b1100011;  // Branches
    localparam OP_JALR      = 7'b1100111;  // JALR
    localparam OP_JAL       = 7'b1101111;  // JAL
    localparam OP_SYSTEM    = 7'b1110011;  // ECALL, EBREAK, CSR

    // ========================================================================
    // Immediate Generation
    // ========================================================================

    reg [31:0] imm_gen;

    always @(*) begin
        case (opcode)
            // I-type: imm[11:0] = instr[31:20]
            OP_LOAD, OP_LOAD_FP, OP_OP_IMM, OP_JALR, OP_SYSTEM:
                imm_gen = {{20{instr[31]}}, instr[31:20]};

            // S-type: imm[11:0] = {instr[31:25], instr[11:7]}
            OP_STORE, OP_STORE_FP:
                imm_gen = {{20{instr[31]}}, instr[31:25], instr[11:7]};

            // B-type: imm[12:0] = {instr[31], instr[7], instr[30:25], instr[11:8], 1'b0}
            OP_BRANCH:
                imm_gen = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};

            // U-type: imm[31:12] = instr[31:12]
            OP_LUI, OP_AUIPC:
                imm_gen = {instr[31:12], 12'b0};

            // J-type: imm[20:0] = {instr[31], instr[19:12], instr[20], instr[30:21], 1'b0}
            OP_JAL:
                imm_gen = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};

            default:
                imm_gen = 32'd0;
        endcase
    end

    assign imm = imm_gen;

    // ========================================================================
    // Control Unit
    // ========================================================================

    control_unit ctrl (
        .opcode       (opcode),
        .funct3       (funct3),
        .funct7       (funct7),
        .reg_write    (reg_write),
        .mem_read     (mem_read),
        .mem_write    (mem_write),
        .mem_to_reg   (mem_to_reg),
        .alu_src      (alu_src),
        .branch       (branch),
        .jump         (jump),
        .alu_op       (alu_op),
        .fp_op        (fp_op),
        .fft_op       (fft_op),
        .fp_reg_write (fp_reg_write),
        .fma_op       (fma_op),
        .csr_op       (csr_op)
    );

    // ========================================================================
    // Integer Register File (x0-x31)
    // ========================================================================

    wire [31:0] int_rs1_data;
    wire [31:0] int_rs2_data;
    wire        int_wr_en = wb_reg_write & ~wb_fp_reg_write;

    register_file int_regfile (
        .clk      (clk),
        .rst_n    (rst_n),
        .rs1_addr (rs1),
        .rs2_addr (rs2),
        .rd_addr  (wb_rd),
        .wr_data  (wb_data),
        .wr_en    (int_wr_en),
        .rs1_data (int_rs1_data),
        .rs2_data (int_rs2_data)
    );

    // ========================================================================
    // Floating-Point Register File (f0-f31)
    // ========================================================================

    wire [31:0] fp_rs1_data_internal;
    wire [31:0] fp_rs2_data_internal;
    wire [31:0] fp_rs3_data_internal;

    fp_register_file fp_regfile (
        .clk      (clk),
        .rst_n    (rst_n),
        .rs1_addr (rs1),
        .rs2_addr (rs2),
        .rs3_addr (rs3),        // Third read port for FMA
        .rd_addr  (wb_rd),
        .wr_data  (wb_data),
        .wr_en    (wb_fp_reg_write),
        .rs1_data (fp_rs1_data_internal),
        .rs2_data (fp_rs2_data_internal),
        .rs3_data (fp_rs3_data_internal)
    );

    // Export FP register file outputs
    assign fp_rs1_data = fp_rs1_data_internal;
    assign fp_rs2_data = fp_rs2_data_internal;
    assign fp_rs3_data = fp_rs3_data_internal;

    // ========================================================================
    // Register File Output Selection
    // FP instructions read from FP register file, others from integer RF
    // ========================================================================

    assign rs1_data = fp_op ? fp_rs1_data_internal : int_rs1_data;
    assign rs2_data = fp_op ? fp_rs2_data_internal : int_rs2_data;

endmodule


// ============================================================================
// Control Unit
// Generates all control signals based on opcode and function fields
// ============================================================================

module control_unit (
    input  wire [6:0] opcode,
    input  wire [2:0] funct3,
    input  wire [6:0] funct7,

    output reg        reg_write,
    output reg        mem_read,
    output reg        mem_write,
    output reg        mem_to_reg,
    output reg        alu_src,
    output reg        branch,
    output reg        jump,
    output reg  [3:0] alu_op,
    output reg        fp_op,
    output reg        fft_op,
    output reg        fp_reg_write,  // FP register write enable
    output reg        fma_op,        // FMA operation
    output reg        csr_op         // CSR instruction
);

    // Opcode definitions
    localparam OP_LOAD      = 7'b0000011;
    localparam OP_LOAD_FP   = 7'b0000111;
    localparam OP_CUSTOM_0  = 7'b0001011;
    localparam OP_OP_IMM    = 7'b0010011;
    localparam OP_AUIPC     = 7'b0010111;
    localparam OP_STORE     = 7'b0100011;
    localparam OP_STORE_FP  = 7'b0100111;
    localparam OP_OP        = 7'b0110011;
    localparam OP_LUI       = 7'b0110111;
    localparam OP_FP        = 7'b1010011;
    localparam OP_BRANCH    = 7'b1100011;
    localparam OP_JALR      = 7'b1100111;
    localparam OP_JAL       = 7'b1101111;
    localparam OP_SYSTEM    = 7'b1110011;

    // ALU operation encodings
    localparam ALU_ADD  = 4'b0000;
    localparam ALU_SUB  = 4'b0001;
    localparam ALU_SLL  = 4'b0010;
    localparam ALU_SLT  = 4'b0011;
    localparam ALU_SLTU = 4'b0100;
    localparam ALU_XOR  = 4'b0101;
    localparam ALU_SRL  = 4'b0110;
    localparam ALU_SRA  = 4'b0111;
    localparam ALU_OR   = 4'b1000;
    localparam ALU_AND  = 4'b1001;
    localparam ALU_LUI  = 4'b1010;
    localparam ALU_AUIPC= 4'b1011;

    always @(*) begin
        // Default values
        reg_write  = 1'b0;
        mem_read   = 1'b0;
        mem_write  = 1'b0;
        mem_to_reg = 1'b0;
        alu_src    = 1'b0;
        branch     = 1'b0;
        jump       = 1'b0;
        alu_op     = ALU_ADD;
        fp_op      = 1'b0;
        fft_op     = 1'b0;
        fp_reg_write = 1'b0;
        fma_op     = 1'b0;
        csr_op     = 1'b0;

        case (opcode)
            OP_LOAD: begin
                reg_write  = 1'b1;
                mem_read   = 1'b1;
                mem_to_reg = 1'b1;
                alu_src    = 1'b1;  // Use immediate
                alu_op     = ALU_ADD;
            end

            OP_LOAD_FP: begin
                reg_write  = 1'b1;
                mem_read   = 1'b1;
                mem_to_reg = 1'b1;
                alu_src    = 1'b1;
                alu_op     = ALU_ADD;
                fp_op      = 1'b1;
                fp_reg_write = 1'b1;
            end

            OP_OP_IMM: begin
                reg_write  = 1'b1;
                alu_src    = 1'b1;  // Use immediate
                case (funct3)
                    3'b000:  alu_op = ALU_ADD;   // ADDI
                    3'b010:  alu_op = ALU_SLT;   // SLTI
                    3'b011:  alu_op = ALU_SLTU;  // SLTIU
                    3'b100:  alu_op = ALU_XOR;   // XORI
                    3'b110:  alu_op = ALU_OR;    // ORI
                    3'b111:  alu_op = ALU_AND;   // ANDI
                    3'b001:  alu_op = ALU_SLL;   // SLLI
                    3'b101:  alu_op = (funct7[5]) ? ALU_SRA : ALU_SRL;  // SRAI/SRLI
                    default: alu_op = ALU_ADD;
                endcase
            end

            OP_AUIPC: begin
                reg_write  = 1'b1;
                alu_src    = 1'b1;
                alu_op     = ALU_AUIPC;
            end

            OP_STORE: begin
                mem_write  = 1'b1;
                alu_src    = 1'b1;  // Use immediate
                alu_op     = ALU_ADD;
            end

            OP_STORE_FP: begin
                mem_write  = 1'b1;
                alu_src    = 1'b1;
                alu_op     = ALU_ADD;
                fp_op      = 1'b1;
            end

            OP_OP: begin
                reg_write  = 1'b1;
                case (funct3)
                    3'b000:  alu_op = (funct7[5]) ? ALU_SUB : ALU_ADD;  // SUB/ADD
                    3'b001:  alu_op = ALU_SLL;   // SLL
                    3'b010:  alu_op = ALU_SLT;   // SLT
                    3'b011:  alu_op = ALU_SLTU;  // SLTU
                    3'b100:  alu_op = ALU_XOR;   // XOR
                    3'b101:  alu_op = (funct7[5]) ? ALU_SRA : ALU_SRL;  // SRA/SRL
                    3'b110:  alu_op = ALU_OR;    // OR
                    3'b111:  alu_op = ALU_AND;   // AND
                    default: alu_op = ALU_ADD;
                endcase
            end

            OP_LUI: begin
                reg_write  = 1'b1;
                alu_src    = 1'b1;
                alu_op     = ALU_LUI;
            end

            OP_CUSTOM_0: begin
                // FFT custom instructions (opcode = 7'b0001011)
                // funct3 encodes the command type
                // funct7 encodes the sample address or other parameters
                fft_op     = 1'b1;
                fp_op      = 1'b1;  // Uses FP register file

                // Store commands write to FP registers
                if (funct3 == 3'b011 || funct3 == 3'b100) begin  // STORE_REAL or STORE_IMAG
                    reg_write = 1'b1;
                    fp_reg_write = 1'b1;
                end
            end

            OP_FP: begin
                reg_write  = 1'b1;
                fp_op      = 1'b1;
                fp_reg_write = 1'b1;

                // Check for FMA operations (opcode bits [1:0] from funct7)
                // FMADD/FMSUB/FNMADD/FNMSUB use R4-type format with rs3
                if (funct7[6:2] == 5'b10000)  // FMA family
                    fma_op = 1'b1;
            end

            OP_BRANCH: begin
                branch     = 1'b1;
                alu_op     = ALU_SUB;  // For comparison
            end

            OP_JALR: begin
                reg_write  = 1'b1;
                jump       = 1'b1;
                alu_src    = 1'b1;
                alu_op     = ALU_ADD;
            end

            OP_JAL: begin
                reg_write  = 1'b1;
                jump       = 1'b1;
            end

            OP_SYSTEM: begin
                // CSR instructions (CSRRW, CSRRS, CSRRC, CSRRWI, CSRRSI, CSRRCI)
                // funct3[2] = 1 for immediate variants
                // funct3[1:0]: 01=RW, 10=RS, 11=RC
                if (funct3 != 3'b000) begin  // Not ECALL/EBREAK
                    reg_write  = 1'b1;
                    csr_op     = 1'b1;
                end
            end

            default: begin
                // NOP
            end
        endcase
    end

endmodule

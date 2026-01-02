// ============================================================================
// RISC-V 5-Stage Pipelined Processor Core
// Top-Level Module
// Supports: RV32I + RV32F (Single-Precision FPU) + 8-Point FFT Coprocessor
// ============================================================================

module riscv_core (
    input  wire        clk,
    input  wire        rst_n,

    // Instruction Memory Interface
    output wire [31:0] imem_addr,
    input  wire [31:0] imem_rdata,
    output wire        imem_req,

    // Data Memory Interface
    output wire [31:0] dmem_addr,
    output wire [31:0] dmem_wdata,
    input  wire [31:0] dmem_rdata,
    output wire        dmem_we,
    output wire [3:0]  dmem_be,      // Byte enable
    output wire        dmem_req,

    // External Interrupt
    input  wire        ext_irq,

    // Debug/Status
    output wire        halted
);

    // ========================================================================
    // Pipeline Stage Signals
    // ========================================================================

    // Fetch Stage (IF)
    wire [31:0] pc_if;
    wire [31:0] instr_if;
    wire [31:0] pc_plus4_if;

    // Decode Stage (ID)
    wire [31:0] pc_id;
    wire [31:0] instr_id;
    wire [31:0] pc_plus4_id;
    wire [31:0] rs1_data_id;
    wire [31:0] rs2_data_id;
    wire [31:0] imm_id;
    wire [4:0]  rd_id;
    wire [4:0]  rs1_id;
    wire [4:0]  rs2_id;

    // Execute Stage (EX)
    wire [31:0] pc_ex;
    wire [31:0] alu_result_ex;
    wire [31:0] rs2_data_ex;
    wire [31:0] fpu_result_ex;
    wire [31:0] branch_target_ex;
    wire        branch_taken_ex;
    wire        zero_ex;
    wire [4:0]  rd_ex;

    // Memory Stage (MEM)
    wire [31:0] alu_result_mem;
    wire [31:0] mem_rdata_mem;
    wire [31:0] fpu_result_mem;
    wire [4:0]  rd_mem;

    // Writeback Stage (WB)
    wire [31:0] wb_data_wb;
    wire [4:0]  rd_wb;
    wire        reg_write_wb;
    wire        fp_reg_write_wb;

    // ========================================================================
    // Control Signals
    // ========================================================================

    // Decode Stage Control
    wire        reg_write_id;
    wire        mem_read_id;
    wire        mem_write_id;
    wire        mem_to_reg_id;
    wire        alu_src_id;
    wire        branch_id;
    wire        jump_id;
    wire [3:0]  alu_op_id;
    wire        fp_op_id;
    wire        fft_op_id;
    wire [2:0]  funct3_id;
    wire [6:0]  funct7_id;

    // Execute Stage Control
    wire        reg_write_ex;
    wire        mem_read_ex;
    wire        mem_write_ex;
    wire        mem_to_reg_ex;
    wire        fp_op_ex;
    wire        fft_op_ex;

    // Memory Stage Control
    wire        reg_write_mem;
    wire        mem_to_reg_mem;
    wire        fp_op_mem;

    // ========================================================================
    // Hazard Detection & Forwarding
    // ========================================================================

    wire        stall_if;
    wire        stall_id;
    wire        flush_id;
    wire        flush_ex;
    wire [1:0]  forward_a_ex;
    wire [1:0]  forward_b_ex;

    // ========================================================================
    // Module Instantiations
    // ========================================================================

    // Fetch Stage
    fetch_stage fetch (
        .clk            (clk),
        .rst_n          (rst_n),
        .stall          (stall_if),
        .branch_taken   (branch_taken_ex),
        .branch_target  (branch_target_ex),
        .pc_out         (pc_if),
        .pc_plus4       (pc_plus4_if),
        .imem_addr      (imem_addr),
        .imem_req       (imem_req)
    );

    // IF/ID Pipeline Register
    if_id_reg if_id (
        .clk            (clk),
        .rst_n          (rst_n),
        .stall          (stall_id),
        .flush          (flush_id | branch_taken_ex),
        .pc_if          (pc_if),
        .instr_if       (imem_rdata),
        .pc_plus4_if    (pc_plus4_if),
        .pc_id          (pc_id),
        .instr_id       (instr_id),
        .pc_plus4_id    (pc_plus4_id)
    );

    // Decode Stage
    decode_stage decode (
        .clk            (clk),
        .rst_n          (rst_n),
        .instr          (instr_id),
        .pc             (pc_id),
        .wb_data        (wb_data_wb),
        .wb_rd          (rd_wb),
        .wb_reg_write   (reg_write_wb),
        .wb_fp_reg_write(fp_reg_write_wb),
        .rs1_data       (rs1_data_id),
        .rs2_data       (rs2_data_id),
        .imm            (imm_id),
        .rd             (rd_id),
        .rs1            (rs1_id),
        .rs2            (rs2_id),
        .funct3         (funct3_id),
        .funct7         (funct7_id),
        .reg_write      (reg_write_id),
        .mem_read       (mem_read_id),
        .mem_write      (mem_write_id),
        .mem_to_reg     (mem_to_reg_id),
        .alu_src        (alu_src_id),
        .branch         (branch_id),
        .jump           (jump_id),
        .alu_op         (alu_op_id),
        .fp_op          (fp_op_id),
        .fft_op         (fft_op_id)
    );

    // ID/EX Pipeline Register
    id_ex_reg id_ex (
        .clk            (clk),
        .rst_n          (rst_n),
        .flush          (flush_ex),
        .pc_id          (pc_id),
        .rs1_data_id    (rs1_data_id),
        .rs2_data_id    (rs2_data_id),
        .imm_id         (imm_id),
        .rd_id          (rd_id),
        .rs1_id         (rs1_id),
        .rs2_id         (rs2_id),
        .funct3_id      (funct3_id),
        .funct7_id      (funct7_id),
        .reg_write_id   (reg_write_id),
        .mem_read_id    (mem_read_id),
        .mem_write_id   (mem_write_id),
        .mem_to_reg_id  (mem_to_reg_id),
        .alu_src_id     (alu_src_id),
        .branch_id      (branch_id),
        .jump_id        (jump_id),
        .alu_op_id      (alu_op_id),
        .fp_op_id       (fp_op_id),
        .fft_op_id      (fft_op_id),
        .pc_ex          (pc_ex),
        .rs1_data_ex    (),  // Connected in execute stage
        .rs2_data_ex    (rs2_data_ex),
        .imm_ex         (),  // Connected in execute stage
        .rd_ex          (rd_ex),
        .rs1_ex         (),  // Connected in hazard unit
        .rs2_ex         (),  // Connected in hazard unit
        .funct3_ex      (),  // Connected in execute stage
        .funct7_ex      (),  // Connected in execute stage
        .reg_write_ex   (reg_write_ex),
        .mem_read_ex    (mem_read_ex),
        .mem_write_ex   (mem_write_ex),
        .mem_to_reg_ex  (mem_to_reg_ex),
        .alu_src_ex     (),  // Connected in execute stage
        .branch_ex      (),  // Connected in execute stage
        .jump_ex        (),  // Connected in execute stage
        .alu_op_ex      (),  // Connected in execute stage
        .fp_op_ex       (fp_op_ex),
        .fft_op_ex      (fft_op_ex)
    );

    // Execute Stage
    execute_stage execute (
        .clk            (clk),
        .rst_n          (rst_n),
        // Inputs from ID/EX register handled by id_ex module
        .alu_result     (alu_result_ex),
        .fpu_result     (fpu_result_ex),
        .branch_target  (branch_target_ex),
        .branch_taken   (branch_taken_ex),
        .zero           (zero_ex)
    );

    // EX/MEM Pipeline Register
    ex_mem_reg ex_mem (
        .clk            (clk),
        .rst_n          (rst_n),
        .alu_result_ex  (alu_result_ex),
        .rs2_data_ex    (rs2_data_ex),
        .fpu_result_ex  (fpu_result_ex),
        .rd_ex          (rd_ex),
        .reg_write_ex   (reg_write_ex),
        .mem_read_ex    (mem_read_ex),
        .mem_write_ex   (mem_write_ex),
        .mem_to_reg_ex  (mem_to_reg_ex),
        .fp_op_ex       (fp_op_ex),
        .alu_result_mem (alu_result_mem),
        .rs2_data_mem   (),  // Connected to memory stage
        .fpu_result_mem (fpu_result_mem),
        .rd_mem         (rd_mem),
        .reg_write_mem  (reg_write_mem),
        .mem_read_mem   (),  // Connected to memory stage
        .mem_write_mem  (),  // Connected to memory stage
        .mem_to_reg_mem (mem_to_reg_mem),
        .fp_op_mem      (fp_op_mem)
    );

    // Memory Stage
    memory_stage memory (
        .clk            (clk),
        .rst_n          (rst_n),
        .dmem_addr      (dmem_addr),
        .dmem_wdata     (dmem_wdata),
        .dmem_rdata     (dmem_rdata),
        .dmem_we        (dmem_we),
        .dmem_be        (dmem_be),
        .dmem_req       (dmem_req),
        .mem_rdata      (mem_rdata_mem)
    );

    // MEM/WB Pipeline Register
    mem_wb_reg mem_wb (
        .clk            (clk),
        .rst_n          (rst_n),
        .alu_result_mem (alu_result_mem),
        .mem_rdata_mem  (mem_rdata_mem),
        .fpu_result_mem (fpu_result_mem),
        .rd_mem         (rd_mem),
        .reg_write_mem  (reg_write_mem),
        .mem_to_reg_mem (mem_to_reg_mem),
        .fp_op_mem      (fp_op_mem),
        .alu_result_wb  (),  // Connected to writeback stage
        .mem_rdata_wb   (),  // Connected to writeback stage
        .fpu_result_wb  (),  // Connected to writeback stage
        .rd_wb          (rd_wb),
        .reg_write_wb   (reg_write_wb),
        .mem_to_reg_wb  (),  // Connected to writeback stage
        .fp_op_wb       (fp_reg_write_wb)
    );

    // Writeback Stage
    writeback_stage writeback (
        .wb_data        (wb_data_wb)
    );

    // Hazard Detection Unit
    hazard_unit hazard (
        .rs1_id         (rs1_id),
        .rs2_id         (rs2_id),
        .rd_ex          (rd_ex),
        .rd_mem         (rd_mem),
        .rd_wb          (rd_wb),
        .mem_read_ex    (mem_read_ex),
        .reg_write_ex   (reg_write_ex),
        .reg_write_mem  (reg_write_mem),
        .reg_write_wb   (reg_write_wb),
        .branch_taken   (branch_taken_ex),
        .stall_if       (stall_if),
        .stall_id       (stall_id),
        .flush_id       (flush_id),
        .flush_ex       (flush_ex)
    );

    // Forwarding Unit
    forwarding_unit forward (
        .rs1_ex         (),  // Connected from ID/EX
        .rs2_ex         (),  // Connected from ID/EX
        .rd_mem         (rd_mem),
        .rd_wb          (rd_wb),
        .reg_write_mem  (reg_write_mem),
        .reg_write_wb   (reg_write_wb),
        .forward_a      (forward_a_ex),
        .forward_b      (forward_b_ex)
    );

    // Halt signal (for simulation/debug)
    assign halted = 1'b0;  // Can be connected to EBREAK detection

endmodule

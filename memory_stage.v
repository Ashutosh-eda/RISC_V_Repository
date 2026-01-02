// ============================================================================
// Memory Stage (MEM)
// - Data memory interface
// - Handles loads and stores
// - Supports byte, halfword, and word operations
// - Sign extension for loads
// ============================================================================

module memory_stage (
    input  wire        clk,
    input  wire        rst_n,

    // From EX/MEM Register
    input  wire [31:0] alu_result_mem,
    input  wire [31:0] rs2_data_mem,
    input  wire [2:0]  funct3_mem,
    input  wire        mem_read_mem,
    input  wire        mem_write_mem,

    // Data Memory Interface
    output wire [31:0] dmem_addr,
    output wire [31:0] dmem_wdata,
    input  wire [31:0] dmem_rdata,
    output wire        dmem_we,
    output wire [3:0]  dmem_be,       // Byte enable
    output wire        dmem_req,

    // Output to MEM/WB
    output reg  [31:0] mem_rdata
);

    // ========================================================================
    // Load/Store Function Codes
    // ========================================================================

    localparam FUNCT3_LB  = 3'b000;  // Load Byte
    localparam FUNCT3_LH  = 3'b001;  // Load Halfword
    localparam FUNCT3_LW  = 3'b010;  // Load Word
    localparam FUNCT3_LBU = 3'b100;  // Load Byte Unsigned
    localparam FUNCT3_LHU = 3'b101;  // Load Halfword Unsigned
    localparam FUNCT3_SB  = 3'b000;  // Store Byte
    localparam FUNCT3_SH  = 3'b001;  // Store Halfword
    localparam FUNCT3_SW  = 3'b010;  // Store Word

    // ========================================================================
    // Memory Address and Control
    // ========================================================================

    assign dmem_addr = alu_result_mem;
    assign dmem_we   = mem_write_mem;
    assign dmem_req  = mem_read_mem | mem_write_mem;

    // ========================================================================
    // Byte Enable Generation (for stores)
    // ========================================================================

    reg [3:0] byte_enable;

    always @(*) begin
        if (mem_write_mem) begin
            case (funct3_mem)
                FUNCT3_SB: begin  // Store Byte
                    case (alu_result_mem[1:0])
                        2'b00: byte_enable = 4'b0001;
                        2'b01: byte_enable = 4'b0010;
                        2'b10: byte_enable = 4'b0100;
                        2'b11: byte_enable = 4'b1000;
                    endcase
                end
                FUNCT3_SH: begin  // Store Halfword
                    case (alu_result_mem[1])
                        1'b0: byte_enable = 4'b0011;
                        1'b1: byte_enable = 4'b1100;
                    endcase
                end
                FUNCT3_SW: begin  // Store Word
                    byte_enable = 4'b1111;
                end
                default: byte_enable = 4'b0000;
            endcase
        end
        else begin
            byte_enable = 4'b1111;  // For loads, read all bytes
        end
    end

    assign dmem_be = byte_enable;

    // ========================================================================
    // Store Data Alignment
    // ========================================================================

    reg [31:0] aligned_wdata;

    always @(*) begin
        case (funct3_mem)
            FUNCT3_SB: begin  // Store Byte
                case (alu_result_mem[1:0])
                    2'b00: aligned_wdata = {24'd0, rs2_data_mem[7:0]};
                    2'b01: aligned_wdata = {16'd0, rs2_data_mem[7:0], 8'd0};
                    2'b10: aligned_wdata = {8'd0, rs2_data_mem[7:0], 16'd0};
                    2'b11: aligned_wdata = {rs2_data_mem[7:0], 24'd0};
                endcase
            end
            FUNCT3_SH: begin  // Store Halfword
                case (alu_result_mem[1])
                    1'b0: aligned_wdata = {16'd0, rs2_data_mem[15:0]};
                    1'b1: aligned_wdata = {rs2_data_mem[15:0], 16'd0};
                endcase
            end
            FUNCT3_SW: begin  // Store Word
                aligned_wdata = rs2_data_mem;
            end
            default: aligned_wdata = rs2_data_mem;
        endcase
    end

    assign dmem_wdata = aligned_wdata;

    // ========================================================================
    // Load Data Alignment and Sign Extension
    // ========================================================================

    always @(*) begin
        if (mem_read_mem) begin
            case (funct3_mem)
                FUNCT3_LB: begin  // Load Byte (signed)
                    case (alu_result_mem[1:0])
                        2'b00: mem_rdata = {{24{dmem_rdata[7]}}, dmem_rdata[7:0]};
                        2'b01: mem_rdata = {{24{dmem_rdata[15]}}, dmem_rdata[15:8]};
                        2'b10: mem_rdata = {{24{dmem_rdata[23]}}, dmem_rdata[23:16]};
                        2'b11: mem_rdata = {{24{dmem_rdata[31]}}, dmem_rdata[31:24]};
                    endcase
                end
                FUNCT3_LH: begin  // Load Halfword (signed)
                    case (alu_result_mem[1])
                        1'b0: mem_rdata = {{16{dmem_rdata[15]}}, dmem_rdata[15:0]};
                        1'b1: mem_rdata = {{16{dmem_rdata[31]}}, dmem_rdata[31:16]};
                    endcase
                end
                FUNCT3_LW: begin  // Load Word
                    mem_rdata = dmem_rdata;
                end
                FUNCT3_LBU: begin  // Load Byte Unsigned
                    case (alu_result_mem[1:0])
                        2'b00: mem_rdata = {24'd0, dmem_rdata[7:0]};
                        2'b01: mem_rdata = {24'd0, dmem_rdata[15:8]};
                        2'b10: mem_rdata = {24'd0, dmem_rdata[23:16]};
                        2'b11: mem_rdata = {24'd0, dmem_rdata[31:24]};
                    endcase
                end
                FUNCT3_LHU: begin  // Load Halfword Unsigned
                    case (alu_result_mem[1])
                        1'b0: mem_rdata = {16'd0, dmem_rdata[15:0]};
                        1'b1: mem_rdata = {16'd0, dmem_rdata[31:16]};
                    endcase
                end
                default: mem_rdata = 32'd0;
            endcase
        end
        else begin
            mem_rdata = 32'd0;
        end
    end

endmodule

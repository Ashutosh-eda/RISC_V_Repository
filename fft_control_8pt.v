// ============================================================================
// FFT Control Unit for 8-Point FFT
// - FSM to control 3-stage radix-2 DIT FFT computation
// - Manages butterfly operations sequentially
// - Controls buffer read/write operations
// - Selects appropriate twiddle factors
// ============================================================================

module fft_control_8pt (
    input  wire        clk,
    input  wire        rst_n,

    // Control inputs
    input  wire        start,         // Start FFT computation
    input  wire        butterfly_valid, // Butterfly result ready

    // Status outputs
    output reg         busy,          // FFT in progress
    output reg         done,          // FFT complete

    // Buffer control
    output reg  [2:0]  rd_addr_x,     // Read address for X input
    output reg  [2:0]  rd_addr_y,     // Read address for Y input
    output reg  [2:0]  wr_addr_0,     // Write address for Out0
    output reg  [2:0]  wr_addr_1,     // Write address for Out1
    output reg         wr_en,         // Write enable for buffer

    // Butterfly control
    output reg         butterfly_enable, // Enable butterfly computation
    output reg  [1:0]  twiddle_addr,  // Twiddle factor address (0-3)

    // Stage tracking
    output reg  [1:0]  current_stage, // Current FFT stage (0-2)
    output reg  [1:0]  butterfly_idx  // Current butterfly index (0-3)
);

    // ========================================================================
    // FSM States
    // ========================================================================
    localparam IDLE       = 3'b000;
    localparam LOAD_DATA  = 3'b001;
    localparam COMPUTE    = 3'b010;
    localparam WAIT_VALID = 3'b011;
    localparam WRITE_BACK = 3'b100;
    localparam DONE_STATE = 3'b101;

    reg [2:0] state, next_state;

    // ========================================================================
    // Butterfly Configuration for Each Stage
    // ========================================================================
    // Stage 0: 4 butterflies with stride=4, twiddle W^0 only
    // Stage 1: 4 butterflies with stride=2, twiddles W^0, W^2
    // Stage 2: 4 butterflies with stride=1, twiddles W^0, W^1, W^2, W^3

    reg [3:0] wait_counter;  // Counter for butterfly latency (11 cycles)

    // ========================================================================
    // State Register
    // ========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= next_state;
    end

    // ========================================================================
    // Next State Logic
    // ========================================================================
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start)
                    next_state = LOAD_DATA;
            end

            LOAD_DATA: begin
                next_state = COMPUTE;
            end

            COMPUTE: begin
                next_state = WAIT_VALID;
            end

            WAIT_VALID: begin
                if (butterfly_valid) begin
                    next_state = WRITE_BACK;
                end
            end

            WRITE_BACK: begin
                // Check if all butterflies in current stage are done
                if (butterfly_idx == 2'b11 && current_stage == 2'b10) begin
                    // All stages complete
                    next_state = DONE_STATE;
                end else begin
                    // More butterflies to process
                    next_state = LOAD_DATA;
                end
            end

            DONE_STATE: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // ========================================================================
    // Stage and Butterfly Counters
    // ========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_stage <= 2'b00;
            butterfly_idx <= 2'b00;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        current_stage <= 2'b00;
                        butterfly_idx <= 2'b00;
                    end
                end

                WRITE_BACK: begin
                    if (butterfly_idx == 2'b11) begin
                        // Move to next stage
                        butterfly_idx <= 2'b00;
                        if (current_stage != 2'b10)
                            current_stage <= current_stage + 1;
                    end else begin
                        // Next butterfly in same stage
                        butterfly_idx <= butterfly_idx + 1;
                    end
                end
            endcase
        end
    end

    // ========================================================================
    // Address Generation Logic
    // ========================================================================
    always @(*) begin
        // Default values
        rd_addr_x = 3'b000;
        rd_addr_y = 3'b000;
        wr_addr_0 = 3'b000;
        wr_addr_1 = 3'b000;
        twiddle_addr = 2'b00;

        case (current_stage)
            2'b00: begin  // Stage 0: stride=4, W^0 only
                case (butterfly_idx)
                    2'b00: begin rd_addr_x = 3'd0; rd_addr_y = 3'd4; wr_addr_0 = 3'd0; wr_addr_1 = 3'd4; twiddle_addr = 2'b00; end
                    2'b01: begin rd_addr_x = 3'd1; rd_addr_y = 3'd5; wr_addr_0 = 3'd1; wr_addr_1 = 3'd5; twiddle_addr = 2'b00; end
                    2'b10: begin rd_addr_x = 3'd2; rd_addr_y = 3'd6; wr_addr_0 = 3'd2; wr_addr_1 = 3'd6; twiddle_addr = 2'b00; end
                    2'b11: begin rd_addr_x = 3'd3; rd_addr_y = 3'd7; wr_addr_0 = 3'd3; wr_addr_1 = 3'd7; twiddle_addr = 2'b00; end
                endcase
            end

            2'b01: begin  // Stage 1: stride=2, W^0 and W^2
                case (butterfly_idx)
                    2'b00: begin rd_addr_x = 3'd0; rd_addr_y = 3'd2; wr_addr_0 = 3'd0; wr_addr_1 = 3'd2; twiddle_addr = 2'b00; end  // W^0
                    2'b01: begin rd_addr_x = 3'd1; rd_addr_y = 3'd3; wr_addr_0 = 3'd1; wr_addr_1 = 3'd3; twiddle_addr = 2'b10; end  // W^2
                    2'b10: begin rd_addr_x = 3'd4; rd_addr_y = 3'd6; wr_addr_0 = 3'd4; wr_addr_1 = 3'd6; twiddle_addr = 2'b00; end  // W^0
                    2'b11: begin rd_addr_x = 3'd5; rd_addr_y = 3'd7; wr_addr_0 = 3'd5; wr_addr_1 = 3'd7; twiddle_addr = 2'b10; end  // W^2
                endcase
            end

            2'b10: begin  // Stage 2: stride=1, W^0, W^1, W^2, W^3
                case (butterfly_idx)
                    2'b00: begin rd_addr_x = 3'd0; rd_addr_y = 3'd1; wr_addr_0 = 3'd0; wr_addr_1 = 3'd1; twiddle_addr = 2'b00; end  // W^0
                    2'b01: begin rd_addr_x = 3'd2; rd_addr_y = 3'd3; wr_addr_0 = 3'd2; wr_addr_1 = 3'd3; twiddle_addr = 2'b01; end  // W^1
                    2'b10: begin rd_addr_x = 3'd4; rd_addr_y = 3'd5; wr_addr_0 = 3'd4; wr_addr_1 = 3'd5; twiddle_addr = 2'b10; end  // W^2
                    2'b11: begin rd_addr_x = 3'd6; rd_addr_y = 3'd7; wr_addr_0 = 3'd6; wr_addr_1 = 3'd7; twiddle_addr = 2'b11; end  // W^3
                endcase
            end

            default: begin
                rd_addr_x = 3'b000;
                rd_addr_y = 3'b000;
            end
        endcase
    end

    // ========================================================================
    // Control Signals
    // ========================================================================
    always @(*) begin
        busy = (state != IDLE) && (state != DONE_STATE);
        done = (state == DONE_STATE);
        butterfly_enable = (state == COMPUTE);
        wr_en = (state == WRITE_BACK);
    end

endmodule

module output_stationary_arbiter #(
    parameter NUM_CORES = 4
) (
    input wire clk,
    input wire reset,
    input wire [NUM_CORES-1:0] req_w,
    output reg [NUM_CORES-1:0] grant,
    output reg [5:0] burst,    // 6-bit burst size
    output reg add_en,         // Add enable bit
    output reg unload_en,      // Unload enable bit
    output reg rw,
    output reg [5:0] addr
);

    // State definitions
    localparam RESET = 3'd0;
    localparam WAIT = 3'd1;
    localparam REQ_LOCK = 3'd2;
    localparam ARBITRATE = 3'd3;
    localparam TRANSFER = 3'd4;

    // Internal registers
    reg [2:0] state;
    reg [NUM_CORES-1:0] req_reg;
    reg [NUM_CORES-1:0] L;     // Load register
    reg [5:0] Q;              // Counter for states
    reg [5:0] M, N;           // Burst lengths

    // Find first non-zero MSB function
    function [1:0] find_msb;
        input [NUM_CORES-1:0] value;
        integer i;
        begin
            find_msb = 0;
            for (i = NUM_CORES-1; i >= 0; i = i - 1) begin
                if (value[i]) begin
                    find_msb = i[1:0];
                    break;
                end
            end
        end
    endfunction

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= RESET;
            req_reg <= 0;
            L <= 0;
            grant <= 0;
            burst <= 'z;
            add_en <= 0;
            unload_en <= 0;
            rw <= 'z;
            addr <= 'z;
            Q <= 0;
        end else begin
            case (state)
                RESET: begin
                    // Q=-1
                    L <= 0;
                    grant <= 0;
                    burst <= 'z;
                    rw <= 'z;
                    addr <= 'z;
                    state <= WAIT;
                end

                WAIT: begin
                    // Q=0
                    grant <= 0;
                    burst <= 'z;
                    rw <= 'z;
                    addr <= 'z;
                    if (req_w != 0) begin
                        req_reg <= req_w;
                        state <= REQ_LOCK;
                    end
                end

                REQ_LOCK: begin
                    state <= ARBITRATE;
                end

                ARBITRATE: begin
                    if (req_reg != 0) begin
                        reg [1:0] selected_core;
                        selected_core = find_msb(req_reg);
                        grant <= (1 << selected_core);
                        L[selected_core] <= ~L[selected_core];
                        state <= TRANSFER;
                        // Set burst size based on L value
                        burst <= L[selected_core] ? N : M;
                        add_en <= ~L[selected_core];
                        unload_en <= L[selected_core];
                    end
                end

                TRANSFER: begin
                    if (Q < burst) begin
                        rw <= L[find_msb(grant)];
                        addr <= addr + 1;
                        Q <= Q + 1;
                    end else begin
                        state <= WAIT;
                        Q <= 0;
                        req_reg <= req_reg & ~grant;
                    end
                end

                default: state <= RESET;
            endcase
        end
    end

endmodule

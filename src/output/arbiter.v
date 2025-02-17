/*
 * Copyright (c) 2024 WAT.ai Chip Team
 * Author: Mariam El-Sahhar
 * SPDX-License-Identifier: Apache-2.0
 * Implements arbiter for data bus shared among PE cores
 * Spec: https://docs.google.com/document/d/1bwynsWdD87AS_AJQEDSaEcCtV5cUac0pMMwL_9xpX6k/edit?tab=t.0#heading=h.qnfirgtr5osr
 */

`include "parameters.vh"

module arbiter #(
    parameter NUM_CORES      = `OUT_ARB_NUM_CORES,         // Sets req/grant data width
    parameter CORE_BIT_WIDTH = $clog2(NUM_CORES),
    parameter BURST_WIDTH    = `OUT_ARB_BURST_WIDTH,       // Burst signal data width
    parameter ADDR_WIDTH     = `OUT_ARB_ADDR_WIDTH,        // Address signal data width   
    parameter BURST_WRITE    = `OUT_ARB_FIXED_BURST_WRITE, // Fixed read/write size
    parameter BURST_READ     = `OUT_ARB_FIXED_BURST_READ
) (
    input  wire                     w_clock,    // Clock input
    input  wire                     w_ready,    // Active high ready
    input  wire [NUM_CORES-1:0]     w_req,      // Request from each core
    output reg  [NUM_CORES-1:0]     r_grant,    // Grants to each core
    output wire [BURST_WIDTH-1:0]   w_burst,    // Burst size for data transfer
    output wire                   w_rw,       // Read/write signal for main mem
    output wire [ADDR_WIDTH-1:0]    w_addr      // Address for main mem
);

    // State definitions
    localparam RESET     = 3'd0;
    localparam IDLE      = 3'd1;
    localparam LOCK      = 3'd2;
    localparam ARBITRATE = 3'd3;
    localparam TRANSFER  = 3'd4;

    // Internal registers
    reg                      r_rw;         // Read/write register
    reg [ADDR_WIDTH-1:0]     r_addr;       // Address register
    reg [BURST_WIDTH-1:0]    r_burst;      // Burst size register
    reg                      r_load_next;  // Next value for load register

    reg [2:0]              r_state;       // State register
    reg [NUM_CORES-1:0]    r_req;         // Sampled requests register
    reg [NUM_CORES-1:0]    r_load;        // Load register (tracks which cores have been served)
    reg [BURST_WIDTH-1:0]  r_count;       // Counter for transfer state
    reg                    r_burst_done;  // Flag: burst transfer complete
    reg [CORE_BIT_WIDTH-1:0] r_sel;       // Selected core

    // Helper function: find first non-zero bit from MSB to LSB
    function [CORE_BIT_WIDTH-1:0] find_msb;
        input [NUM_CORES-1:0] value;
        integer i;
        begin : find_msb_loop
            find_msb = 0;
            for (i = NUM_CORES-1; i >= 0; i = i - 1) begin
                if (value[i]) begin
                    find_msb = i;
                    disable find_msb_loop; // exit early once found
                end
            end
        end
    endfunction

    // State machine
    always @(posedge w_clock) begin
        if (~w_ready)
            r_state <= RESET;
        else begin
            case (r_state)
                RESET:     if (w_ready) r_state <= IDLE;
                IDLE:      if (w_req != 0) r_state <= LOCK;
                LOCK:      if (r_req != 0) r_state <= ARBITRATE;
                           else if (w_req == 0) r_state <= IDLE;
                ARBITRATE: r_state <= TRANSFER;
                TRANSFER:  if (r_burst_done && r_req == 0) r_state <= LOCK; 
                           else if (r_burst_done) r_state <= ARBITRATE;
                default:   r_state <= RESET;
            endcase
        end
    end

    // Register assignments
    always @(posedge w_clock) begin
         case (r_state)
            RESET: begin
                r_load       <= 0;
                r_req        <= 0;
                r_grant      <= 0;
                r_burst      <= 0;
                r_rw         <= 0;
                r_addr       <= 0;
                r_count      <= 0;
                r_burst_done <= 0;
                r_sel        <= 0;
            end
            IDLE: begin
                // Maintain current load; clear sampled request and outputs.
                r_load       <= r_load;
                r_req        <= 0;
                r_grant      <= 0;
                r_burst      <= 0;
                r_rw         <= 0;
                r_addr       <= 0;
                r_count      <= 0;
                r_burst_done <= 0;
            end
            LOCK: begin
                // Capture new requests.
                r_load       <= r_load;
                r_req        <= w_req;
                r_grant      <= 0;
                r_burst      <= 0;
                r_rw         <= 0;
                r_addr       <= 0;
                r_count      <= 0;
                r_burst_done <= 0;
            end
            ARBITRATE: begin
            reg [CORE_BIT_WIDTH-1:0] next_sel;
            reg [NUM_CORES-1:0] next_mask;
            reg next_burst;

            //the changes made track the next selection, load and burst size (currently not working)
            
            // First priority: service loaded cores (unloading)
            if (|(r_req & r_load)) begin
                next_mask = r_req & r_load;
                next_sel = find_msb(next_mask);
                r_load_next = 0;  // Unloading this core
                next_burst = BURST_READ;  // Reading when unloading
            end 
            // Second priority: service unloaded cores (loading)
            else begin
                next_mask = r_req & ~r_load;
                if (|next_mask) begin
                    next_sel = find_msb(next_mask);
                    r_load_next = 1;  // Loading this core
                end else begin
                    next_sel = find_msb(r_req);
                    r_load_next = 1;  // Loading this core (fallback case)
                end
                next_burst = BURST_WRITE;  // Writing when loading
            end
            
            // Update all registers synchronously
            r_sel <= next_sel;
            r_load[next_sel] <= r_load_next;
            r_grant <= (1 << next_sel);
            r_burst <= next_burst;  // Use computed burst value
            r_rw <= ~r_load_next;  // RW is opposite of load_next (0=write, 1=read)
            r_addr <= 0;
            r_count <= 0;
            r_burst_done <= 0;
        end
            TRANSFER: begin
                // Maintain transfer state: increment count and address.
                r_count <= r_count + 1;
                r_addr  <= r_addr + 1;
                // Use current load state for read/write decision.
                r_rw <= r_load[find_msb(r_grant)];
                if (r_count < r_burst) begin
                    r_req <= r_req;
                    r_burst_done <= 0;
                end else begin
                    // End of burst: remove the granted request.
                    r_req <= r_req ^ r_grant;
                    r_burst_done <= 1;
                end
            end
         endcase
    end

    // Output assignments (drive outputs only during TRANSFER or ARBITRATE).
    assign w_rw    = (r_state == TRANSFER) ? r_rw : 1'bz;
    assign w_addr  = (r_state == TRANSFER) ? r_addr : {ADDR_WIDTH{1'bz}};
    assign w_burst = ((r_state == ARBITRATE) || (r_state == TRANSFER)) ? r_burst : {BURST_WIDTH{1'bz}};

endmodule

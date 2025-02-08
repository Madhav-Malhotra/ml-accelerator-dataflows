/*
 * Copyright (c) 2024 WAT.ai Chip Team
 * Author: Mariam El-Sahhar
 * SPDX-License-Identifier: Apache-2.0
 * Implements arbiter for data bus shared among PE cores
 * Spec: https://docs.google.com/document/d/1bwynsWdD87AS_AJQEDSaEcCtV5cUac0pMMwL_9xpX6k/edit?tab=t.0#heading=h.qnfirgtr5osr
 */

`include "parameters.vh"

module arbiter #(
    parameter NUM_CORES = `OUT_ARB_NUM_CORES,               // Sets req/grant data width
    parameter CORE_BIT_WIDTH = $clog2(NUM_CORES),
    parameter BURST_WIDTH = `OUT_ARB_BURST_WIDTH,           // Burst signal data width
    parameter ADDR_WIDTH = `OUT_ARB_ADDR_WIDTH,             // Address signal data width   
    parameter BURST_WRITE = `OUT_ARB_FIXED_BURST_WRITE,     // Fixed read/write size
    parameter BURST_READ = `OUT_ARB_FIXED_BURST_READ
) (
    input wire w_clock,                     // Clock input
    input wire w_ready,                     // Active high ready
    input wire [NUM_CORES-1:0] w_req,       // Request from each core
    output reg [NUM_CORES-1:0] r_grant,     // Grants to each core (don't need to gate so reg)
    output wire [BURST_WIDTH-1:0] w_burst,   // Burst size for data transfer
    output wire w_rw,                       // Read/write signal for main mem
    output wire [ADDR_WIDTH-1:0] w_addr     // Address for main mem
);

    // State definitions
    localparam RESET = 3'd0;
    localparam IDLE = 3'd1;
    localparam LOCK = 3'd2;
    localparam ARBITRATE = 3'd3;
    localparam TRANSFER = 3'd4;

    // Internal registers
    reg r_rw;                       // Read/write register
    reg [ADDR_WIDTH-1:0] r_addr;    // Address register
    reg [BURST_WIDTH-1:0] r_burst;  // Burst size register

    reg [2:0] r_state;              // State register
    reg [NUM_CORES-1:0] r_req;      // Sampled requests register
    reg [NUM_CORES-1:0] r_load;     // Load register
    reg [BURST_WIDTH-1:0] r_count;  // Counter for transfer state
    reg r_burst_done;               // Burst transfer done flag

    // Helper function to find first non-zero MSB
    function [CORE_BIT_WIDTH-1:0] find_msb;
        input [NUM_CORES-1:0] value;
        integer i;
        begin
            find_msb = 0;
            for (i = NUM_CORES-1; i >= 0; i = i - 1) begin
                if (value[i]) begin
                    find_msb = i[CORE_BIT_WIDTH-1:0];
                end
            end
        end
    endfunction

    // State machine
    always @(posedge w_clock) begin
        // Reset state
        if (~w_ready) begin
            r_state <= RESET;
        end else if (w_ready) begin
            case (r_state)
                // wait for ready before going to idle
                RESET: if (w_ready) r_state <= IDLE;
                // wait for request before going to lock
                IDLE: if (w_req != 0) r_state <= LOCK;
                // wait for locked request before going to arbitrate
                LOCK: if (r_req != 0) r_state <= ARBITRATE;
                      else if (w_req == 0) r_state <= IDLE;
                // continue after choosing selected core
                ARBITRATE:  r_state <= TRANSFER;
                // Wait for burst transfer to finish, then handle remaining 
                // requests or wait for more requests
                TRANSFER: if (r_burst_done && r_req == 0) r_state <= LOCK; 
                          else if (r_burst_done) r_state <= ARBITRATE;
                default: r_state <= RESET;
            endcase
        end
    end

    // Register assignments
    always @(posedge w_clock) begin
         case (r_state)
            RESET: begin
                r_load <= 0;
                r_req <= 0;
                r_grant <= 0;
                r_burst <= 0;
                r_rw <= 0;
                r_addr <= 0;
                r_count <= 0;
                r_burst_done <= 0;
            end
            IDLE: begin
                r_load <= r_load;
                r_req <= 0;
                r_grant <= 0;
                r_burst <= 0;
                r_rw <= 0;
                r_addr <= 0;
                r_count <= 0;
                r_burst_done <= 0;
            end
            LOCK: begin
                r_load <= r_load;
                r_req <= w_req;
                r_grant <= 0;
                r_burst <= 0;
                r_rw <= 0;
                r_addr <= 0;
                r_count <= 0;
                r_burst_done <= 0;
            end
            ARBITRATE: begin
                reg [CORE_BIT_WIDTH-1:0] sel;
                sel = find_msb(r_req);

                r_load[sel] <= ~r_load[sel];
                r_grant <= (1 << sel);
                r_burst <= (!r_load[sel]) ? BURST_WRITE : BURST_READ;
                r_rw <= 0;
                r_addr <= 0;
                r_count <= 0;
                r_burst_done <= 0;
            end
            TRANSFER: begin
                // Just maintaining state
                r_load <= r_load;
                r_grant <= r_grant;
                r_burst <= r_burst;

                // Logical transfer assignments
                r_rw <= r_load[find_msb(r_grant)];
                r_count <= r_count + 1;
                r_addr <= r_addr + 1;

                if (r_count < r_burst) begin
                    r_req <= r_req;
                    r_burst_done <= 0;
                end else begin
                    r_req <= r_req ^ r_grant;
                    r_burst_done <= 1;
                end
            end
         endcase
            
    end

    // Assign gated outputs, except for grant (no gating needed)
    assign w_rw = (r_state == TRANSFER) ? r_rw : 1'bz;
    assign w_addr = (r_state == TRANSFER) ? r_addr : {ADDR_WIDTH{1'bz}};
    assign w_burst = (r_state == ARBITRATE) ? r_burst : {BURST_WIDTH{1'bz}};

endmodule
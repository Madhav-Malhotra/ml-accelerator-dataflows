/*
 * Copyright (c) 2024 WAT.ai Chip Team
 * Author: Mariam El-Sahhar
 * SPDX-License-Identifier: Apache-2.0
 * Implements arbiter for data bus shared among PE cores
 * Spec: https://docs.google.com/document/d/1bwynsWdD87AS_AJQEDSaEcCtV5cUac0pMMwL_9xpX6k/edit?tab=t.0#heading=h.qnfirgtr5osr
 */

`include "parameters.vh"

module output_stationary_arbiter #(
    parameter NUM_CORES = `OUT_ARB_NUM_CORES
) (
    input wire w_clock,                     //
    input wire w_ready,                     //
    input wire [NUM_CORES-1:0] w_req,       //
    output reg [NUM_CORES-1:0] grant,       // 
    output reg [5:0] burst,                 // 6-bit burst size
    output reg add_en,                      // Add enable bit
    output reg unload_en,                   // Unload enable bit
    output reg rw,                          // 
    output reg [5:0] addr                   // 
);

    // State definitions
    localparam RESET = 3'd0;
    localparam WAIT = 3'd1;
    localparam REQ_LOCK = 3'd2;
    localparam ARBITRATE = 3'd3;
    localparam TRANSFER = 3'd4;

    // Internal registers
    reg [2:0] r_state;
    reg [NUM_CORES-1:0] r_req;
    reg [NUM_CORES-1:0] r_load;     // Load register
    reg [5:0] r_count;              // Counter for states
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
                end
            end
        end
    endfunction

    always @(posedge w_clock) begin
        if (!w_ready) begin
            r_state <= RESET;
            r_req <= 0;
            r_load <= 0;
            grant <= 0;
            burst <= 'z;
            add_en <= 0;
            unload_en <= 0;
            rw <= 'z;
            addr <= 'z;
            r_count <= 0;
        end else begin
            case (r_state)
                RESET: begin
                    // r_count=-1
                    r_load <= 0;
                    grant <= 0;
                    burst <= 'z;
                    rw <= 'z;
                    addr <= 'z;
                    r_state <= WAIT;
                end

                WAIT: begin
                    // r_count=0
                    grant <= 0;
                    burst <= 'z;
                    rw <= 'z;
                    addr <= 'z;
                    if (w_req != 0) begin
                        r_req <= w_req;
                        r_state <= REQ_LOCK;
                    end
                end

                REQ_LOCK: begin
                    r_state <= ARBITRATE;
                end

                ARBITRATE: begin
                    if (r_req != 0) begin
                        reg [1:0] selected_core;
                        selected_core = find_msb(r_req);
                        grant <= (1 << selected_core);
                        r_load[selected_core] <= ~r_load[selected_core];
                        r_state <= TRANSFER;
                        // Set burst size based on r_load value
                        burst <= r_load[selected_core] ? N : M;
                        add_en <= ~r_load[selected_core];
                        unload_en <= r_load[selected_core];
                    end
                end

                TRANSFER: begin
                    if (r_count < burst) begin
                        rw <= r_load[find_msb(grant)];
                        addr <= addr + 1;
                        r_count <= r_count + 1;
                    end else begin
                        r_state <= WAIT;
                        r_count <= 0;
                        r_req <= r_req & ~grant;
                    end
                end

                default: r_state <= RESET;
            endcase
        end
    end

endmodule

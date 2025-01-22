/*
 * Copyright (c) 2024 WAT.ai Chip Team
 * Author: Madhav Malhotra
 * SPDX-License-Identifier: Apache-2.0
 * Implements cached arbiter for output stationary dataflow
 * (spec: https://docs.google.com/document/d/1bwynsWdD87AS_AJQEDSaEcCtV5cUac0pMMwL_9xpX6k/edit?tab=t.0#heading=h.onnj5tjg6vwi)
 */

module arbiter_cached #(
    parameter MAIN_MEM_ADDR_WIDTH = 32,             // Main memory address width
    parameter NUM_CORES = 4,                        // Number of PE array cores
    parameter BURST_WIDTH = 6,                      // Burst length bit width
    parameter CONFIG_LEN = 8                        // Number of config items
)(
    input wire w_clock,                             // Clock
    input wire w_ready,                             // Active high enable
    input wire [NUM_CORES-1:0] w_req,               // Request from each PE core
    output wire [MAIN_MEM_ADDR_WIDTH-1:0] w_addr,   // Main mem address input
    output wire w_rw,                               // Main mem read/write
    output wire [NUM_CORES-1:0] w_grant,            // Grant to each PE core
    output wire [BURST_WIDTH-1:0] w_burst,          // Burst length for data bus
);

    // Output signals (raw before tristate buffers)
    reg [NUM_CORES-1:0] r_grant;
    reg [BURST_WIDTH-1:0] r_burst;
    reg [MAIN_MEM_ADDR_WIDTH-1:0] r_addr;
    reg r_rw;

    // Internal signals
    reg [NUM_CORES-1:0] r_req;                      // Current captured requests
    reg [NUM_CORES-1:0] r_load;                     // To load or unload cores
    reg [2:0] r_state;                              // State machine state
    integer sel;                                    // Selected core index

    // Hardcoded arbiter config (CONFIG_LEN burst lengths, memory addresses)
    reg [CONFIG_LEN-1:0] r_config_burst_psum [NUM_CORES-1:0];
    reg [CONFIG_LEN-1:0] r_config_addr_psum [NUM_CORES-1:0];
    reg [CONFIG_LEN-1:0] r_config_burst_core_config [NUM_CORES-1:0];
    reg [CONFIG_LEN-1:0] r_config_addr_core_config [NUM_CORES-1:0];
    reg [CONFIG_LEN-1:0] r_config_burst_core_weights [NUM_CORES-1:0];
    reg [CONFIG_LEN-1:0] r_config_addr_core_weights [NUM_CORES-1:0];
    reg [CONFIG_LEN-1:0] r_config_burst_core_act [NUM_CORES-1:0];
    reg [CONFIG_LEN-1:0] r_config_addr_core_act [NUM_CORES-1:0];


    // State machine
    always @(posedge w_clock) begin
        if (w_ready) begin
            // Req idle state (waiting on requests)
            if (w_req == 0) begin
                r_state <= 1;
            
            // Req lock state (captured request into reg)
            end else begin
                r_state <= 2;

                // Arbitrate state (select one request)
                if (r_reg != 0) begin
                    r_state <= 3;

                    // r_state == 3 occurs next clock cycle when sel is set
                    if (r_state == 3) begin
                        // Core write state (core writes to mem)
                        if (r_load[sel]) begin
                            r_state <= 4;
                        
                        // Core read state (core reads from mem) 
                        end else if (!r_load[sel]) begin
                            r_state <= 5;
                        end 
                    end
                end
            end

        // Reset state
        end else begin
            r_state <= 0;
        end
    end

    // Register assignments based on state
    always @(posedge w_clock) begin
        // Reset state
        r_req <= 0;
        r_load <= 0;
        r_grant <= 0;
        r_burst <= 0;
        r_addr <= 0;
        r_rw <= 0;

        // Req idle state
        if else (r_state == 1) begin
            r_load <= r_load;

        // Req lock state
        end else (r_state == 2) begin
            r_req <= w_req;
            r_load <= r_load;

        // Arbitrate state
        end else (r_state == 3) begin
            sel = 0;
            for (i = 0; i < NUM_CORES; i = i + 1) begin
                if (r_req[i]) begin
                    sel = i;
                end
            end
            r_grant[sel] <= 1;
            r_load[sel] <= ~r_load[sel];

        // Core write state
        end else (r_state == 4) begin
            

        // Core read state
        end else (r_state == 5) begin

        end
    end

    // Combinational assignment based on state

endmodule
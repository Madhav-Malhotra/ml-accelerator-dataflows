/*
 * Copyright (c) 2024 WAT.ai Chip Team
 * Author: Madhav Malhotra
 * SPDX-License-Identifier: Apache-2.0
 * Implements cached arbiter for output stationary dataflow
 * (spec: https://docs.google.com/document/d/1bwynsWdD87AS_AJQEDSaEcCtV5cUac0pMMwL_9xpX6k/edit?tab=t.0#heading=h.onnj5tjg6vwi)
 * WARNING: Hardcoded config data for now. Replace with FIFO lookup later
 */

module arbiter_cached #(
    parameter MAIN_MEM_ADDR_WIDTH = 32,             // Main memory address width
    parameter NUM_CORES = 4,                        // Number of PE array cores
    parameter BURST_WIDTH = 6,                       // Burst length bit width
    parameter CONFIG_WIDTH = 16                     // Config data bit width
)(
    input wire w_clock,                             // Clock
    input wire w_ready,                             // Active high enable
    input wire [NUM_CORES-1:0] w_req,               // Request from each PE core
    output wire [MAIN_MEM_ADDR_WIDTH-1:0] w_addr,   // Main mem address input
    output wire w_rw,                               // Main mem read/write
    output wire [NUM_CORES-1:0] w_grant,            // Grant to each PE core
    output wire [BURST_WIDTH-1:0] w_burst           // Burst length for data bus
                                                    // Add FIFO inputs later
);
    // State localparams
    localparam RESET = 0, IDLE = 1, LOCK = 2, ARBITRATE = 3, WRITE = 4, READ = 5;

    // Output signals (raw before tristate buffers)
    reg [NUM_CORES-1:0] r_grant;
    reg [BURST_WIDTH-1:0] r_burst;
    reg [MAIN_MEM_ADDR_WIDTH-1:0] r_addr;
    reg r_rw;

    // Internal signals
    reg [NUM_CORES-1:0] r_req;                      // Current captured requests
    reg [NUM_CORES-1:0] r_load;                     // To load or unload cores
    reg [2:0] r_state;                              // State machine state
    reg [2:0] r_read_stage;                         // Read config, wgts, or acts
    reg [CONFIG_WIDTH-1:0] r_count;                 // Burst counter
    integer sel;                                    // Selected core index
    integer i;                                      // Generic counter
    reg r_burst_done;                                 // Burst transfer done flag

    // These hold config data (burst lengths, memory addresses)
    // They need to be read from a FIFO in the arbitrate state. 
    // For now, they're hardcoded
    reg [CONFIG_WIDTH-1:0] r_config_burst_psum;
    reg [CONFIG_WIDTH-1:0] r_config_addr_psum;

    reg [CONFIG_WIDTH-1:0] r_config_burst_config;
    reg [CONFIG_WIDTH-1:0] r_config_addr_config;

    reg [CONFIG_WIDTH-1:0] r_config_burst_weights;
    reg [CONFIG_WIDTH-1:0] r_config_addr_weights;

    reg [CONFIG_WIDTH-1:0] r_config_burst_act;
    reg [CONFIG_WIDTH-1:0] r_config_addr_act;


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
                // figure out whether core wants to write or read
                ARBITRATE:  if (r_load[sel]) r_state <= WRITE;
                            else r_state <= READ;
                // Wait for burst transfer to finish, then handle remaining 
                // requests or wait for more requests
                WRITE:  if (r_burst_done && r_req == 0) r_state <= LOCK; 
                        else if (r_burst_done) r_state <= ARBITRATE;
                READ:   if (r_burst_done && r_req == 0) r_state <= LOCK;
                        else if (r_burst_done) r_state <= ARBITRATE;
                default: r_state <= RESET;
            endcase
        end
    end

    // Register assignments based on state
    always @(posedge w_clock) begin
        // Reset state
        if (r_state == 0) begin
            r_req <= 0;
            r_load <= 0;
            r_grant <= 0;
            r_burst <= 0;
            r_burst_done <= 0;
            r_addr <= 0;
            r_rw <= 0;
            r_count <= 0;
            sel = 0;
            r_read_stage <= 0;

            // Hardcoded config data for now.
            r_config_burst_psum <= 16;
            r_config_addr_psum <= 0;

            r_config_burst_config <= 16;
            r_config_addr_config <= 0;

            r_config_burst_weights <= 16;
            r_config_addr_weights <= 0;

            r_config_burst_act <= 16;
            r_config_addr_act <= 0;

        // Req idle state
        end else if (r_state == 1) begin
            r_req <= 0;
            r_load <= r_load;
            
        // Req lock state
        end else if (r_state == 2) begin
            r_req <= w_req;
            r_load <= r_load;
            r_grant <= 0;
            r_burst <= 0;
            r_addr <= 0;
            r_rw <= 0;
            r_count <= 0;
            r_read_stage <= 0;

        // Arbitrate state
        end else if (r_state == 3) begin
            sel = 0;
            for (i = 0; i < NUM_CORES; i = i + 1) begin
                if (r_req[i]) begin
                    sel = i;
                end
            end
            r_grant[sel] <= 1;
            r_load[sel] <= ~r_load[sel];
            r_rw <= 0;
            r_read_stage <= 0;
            r_count <= 0;

            // Hardcoded config data for now. Replace with FIFO lookup later
            r_config_burst_psum <= 16;
            r_config_addr_psum <= 0;

            r_config_burst_config <= 16;
            r_config_addr_config <= 0;

            r_config_burst_weights <= 16;
            r_config_addr_weights <= 0;

            r_config_burst_act <= 16;
            r_config_addr_act <= 0;

        // Core write state
        end else if (r_state == 4) begin
            r_read_stage <= 3;
            if (r_read_stage == 3) begin
                handle_burst_transfer(r_config_burst_psum, r_config_addr_psum, 1'b0, r_read_stage);
            end

        // Core read state
        end else if (r_state == 5) begin
            if (r_read_stage == 0) begin
                handle_burst_transfer(r_config_burst_config, r_config_addr_config, 1'b1, r_read_stage);
            end else if (r_read_stage == 1) begin
                handle_burst_transfer(r_config_burst_weights, r_config_addr_weights, 1'b1, r_read_stage);
            end else if (r_read_stage == 2) begin
                handle_burst_transfer(r_config_burst_act, r_config_addr_act, 1'b1, r_read_stage);
            end
            
        end
    end

    // Combinational assignment based on state
    // Basically, we add tristate buffers to the data bus outputs when not used
    assign w_burst = ( (r_state == 4 || r_state == 5) && r_count == 0) ? r_burst : {BURST_WIDTH{1'bz}};
    assign w_addr = ( (r_state == 4 || r_state == 5) && r_count != 0) ? r_addr : {MAIN_MEM_ADDR_WIDTH{1'bz}};
    assign w_rw = ( (r_state == 4 || r_state == 5) && r_count != 0) ? r_rw : 1'bz;
    assign w_grant = r_grant; // not a data bus output so no tristate buffer needed

    // Reusable code to handle a data transfer with a specified address/burst
    task handle_burst_transfer;
        input [CONFIG_WIDTH-1:0] config_burst;
        input [MAIN_MEM_ADDR_WIDTH-1:0] config_addr;
        input rw;
        inout r_read_stage;
        begin
            // Handle data transfer
            if (r_count < config_burst + 1) begin
                r_count <= r_count + 1;
                r_load <= r_load;
                r_grant <= r_grant;
                r_rw <= rw;

                // First step (sending burst info)
                if (r_count == 0) begin
                    r_req <= r_req;
                    r_burst <= config_burst;
                    r_burst_done <= 0;
                    r_addr <= config_addr - 1;
                // Ending step
                end else if (r_count == config_burst) begin
                    // If last stage of read or write (encoded as 3),
                    // then toggle the request signal as handled
                    if (r_read_stage == 2 || r_read_stage == 3) begin
                        r_req[sel] <= ~r_req[sel];
                    end else begin
                        r_req <= r_req;
                    end
                    r_burst <= 0;
                    r_addr <= r_addr + 1;
                // Intermediate steps (just transferring one address after next)
                end else begin
                    r_req <= r_req;
                    r_burst <= 0;
                    r_addr <= r_addr + 1;
                end
            
            // After transfer is done, figure out next state
            end else if (r_count == config_burst + 1) begin
                r_count <= 0;
                
                // After read, go to next read stage
                if (r_read_stage == 0 || r_read_stage == 1) begin
                    r_read_stage <= r_read_stage + 1;
                end

                // After write/last read, go to next state
                if (r_read_stage == 3 || r_read_stage == 2) begin
                    r_burst_done <= 1;
                end
            end
        end
    endtask

endmodule


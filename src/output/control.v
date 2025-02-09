/*
 * Copyright (c) 2024 WAT.ai Chip Team
 * Author: Madhav Malhotra
 * SPDX-License-Identifier: Apache-2.0
 * Implements non-cached controller for PE array
 * Spec: https://docs.google.com/document/d/1bwynsWdD87AS_AJQEDSaEcCtV5cUac0pMMwL_9xpX6k/edit?tab=t.0#heading=h.2psj995hbk8u
 */

`include "parameters.vh"

// Helper macros to reset memories, GLBs, and PEs
`define RESET_MEMS(i) \
    r_mem_weight_rw[i] <= 0; \
    r_mem_weight_addr[i] <= 0; \
    r_mem_weight_ready[i] <= 0; \
    r_mem_input_rw[i] <= 0; \
    r_mem_input_addr[i] <= 0; \
    r_mem_input_ready[i] <= 0;

`define RESET_GLBS(i) \
    r_glb_rw[i] <= 0; \
    r_glb_addr[i] <= 0; \
    r_glb_ready[i] <= 0;

`define RESET_PES(i) \ 
    w_pe_ready[i] <= 0; \
    w_pe_rw[i] <= 0; \
    w_pe_stream[i] <= 0;


module controller #(
    parameter NUM_MEMS = `OUT_CTL_NUM_MEMS,                                     // Number of memories feeding the array       
    parameter NUM_PES = NUM_MEMS * NUM_MEMS,                                    // Number of PEs in the array
    parameter BURST_WIDTH = `OUT_ARB_BURST_WIDTH,                               // Burst signal data width
    parameter MEM_ADDR_WIDTH = $clog2(`OUT_MEM_NUM_ROWS),                       // Address width for memories
    parameter GLB_ADDR_WIDTH = $clog2(`OUT_GLB_NUM_ROWS),                       // Address width for global buffers
) (
    input wire w_clock,                                                         // Clock input
    input wire w_ready,                                                         // Active high ready
    input wire [BURST_WIDTH-1:0] w_burst,                                       // Burst size for data transfer
    input wire w_grant,                                                         // Grant signal from the arbiter
    
    output reg r_req,                                                           // Request signal to the arbiter
    
    output wire [NUM_MEMS-1:0] w_mem_weight_rw                                  // Weight memory read/write signals
    output reg [MEM_ADDR_WIDTH-1:0] r_mem_weight_addr [NUM_MEMS-1:0]            // Weight memory address signals
    output reg [NUM_MEMS-1:0] r_mem_weight_ready                                // Weight memory ready signals

    output wire [NUM_MEMS-1:0] w_mem_input_rw                                   // Input memory read/write signals
    output reg [MEM_ADDR_WIDTH-1:0] r_mem_input_addr [NUM_MEMS-1:0]             // Input memory address signals
    output reg [NUM_MEMS-1:0] r_mem_input_ready                                 // Input memory ready signals

    output wire [NUM_MEMS-1:0] w_glb_rw                                         // GLB read/write signals
    output reg [GLB_ADDR_WIDTH-1:0] r_glb_addr [NUM_MEMS-1:0]                   // GLB address signals
    output reg [NUM_MEMS-1:0] r_glb_ready                                       // GLB ready signals

    output wire [NUM_PES-1:0] w_pe_ready                                        // PE ready signals
    output wire [NUM_PES-1:0] w_pe_rw                                           // Read data from mem or pass forward
    output wire [NUM_PES-1:0] w_pe_stream                                       // Stream forwarded data or own data
);

    // State definitions
    localparam RESET = 3'd0;
    localparam LOAD = 3'd1;
    localparam DISTRIBUTE = 3'd2;
    localparam COMPUTE = 3'd3;
    localparam CLEANUP = 3'd4;
    localparam UNLOAD = 3'd5;

    // Internal registers
    reg [3:0] r_state;
    reg r_transfer_done;
    reg [BURST_WIDTH:0] r_count;            // Intentionally oversized to handle overflow 

    // State machine
    always @(posedge w_clock) begin
        // Reset state
        if (~w_ready) begin
            r_state <= RESET;
        end else if (w_ready) begin
            case (r_state)
                // wait for grant before loading memories
                RESET: if (w_grant) r_state <= LOAD;
                // Finish loading memories before distributing data
                LOAD: if (r_transfer_done) r_state <= DISTRIBUTE;
                // Finish distributing data to last PE before computing
                DISTRIBUTE: if (r_transfer_done) r_state <= COMPUTE;
                // Finish computing in earliest PE before cleanup
                COMPUTE: if (r_transfer_done) r_state <= CLEANUP;
                // Finish cleanup for all PEs before unloading GLBs
                CLEANUP: if (r_transfer_done) r_state <= UNLOAD;
                // Finish unloading GLBs before resetting
                UNLOAD: if (r_transfer_done) r_state <= RESET;
                default: r_state <= RESET;
            endcase
        end
    end

    // Register assignments
    always @(posedge w_clock) begin
         case (r_state)
            RESET: begin
                integer i;
                // Reset all memory and GLB addresses and ready signals
                for (i = 0; i < NUM_MEMS; i = i + 1) begin
                    `RESET_MEMS(i)
                    `RESET_GLBS(i)
                end

                // Reset all PEs
                integer j;
                for (j = 0; j < NUM_PES; j = j + 1) begin
                    `RESET_PES(j)
                end

                // Reset internal signals
                r_req <= 1;
                r_transfer_done <= 0;
                r_count <= 0;
            end
            LOAD: begin
                
            end
            DISTRIBUTE: begin
                
            end
            COMPUTE: begin
                
            end
            CLEANUP: begin
                
            end
            UNLOAD: begin
                
            end
         endcase
            
    end

    // Assign gated outputs


endmodule
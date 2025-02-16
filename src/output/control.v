/*
 * Copyright (c) 2024 WAT.ai Chip Team
 * Author: Madhav Malhotra
 * SPDX-License-Identifier: Apache-2.0
 * Implements non-cached controller for PE array
 * Spec: https://docs.google.com/document/d/1bwynsWdD87AS_AJQEDSaEcCtV5cUac0pMMwL_9xpX6k/edit?tab=t.0#heading=h.2psj995hbk8u
 */

`include "parameters.vh"

/* ==============================================
Helper macros to reset memories, GLBs, and PEs 
============================================== */

// Resets weight and input data memories
`define RESET_MEMS(i) \
    r_mem_weight_rw[i] <= 0; \
    r_mem_weight_addr[i] <= 0; \
    r_mem_weight_ready[i] <= 0; \
    r_mem_input_rw[i] <= 0; \
    r_mem_input_addr[i] <= 0; \
    r_mem_input_ready[i] <= 0;

`define STALL_MEMS(i) \ 
    r_mem_weight_rw[i] <= 1'bz; \
    r_mem_weight_addr[i] <= 0; \
    r_mem_weight_ready[i] <= 1; \
    r_mem_input_rw[i] <= 1'bz; \
    r_mem_input_addr[i] <= 0; \
    r_mem_input_ready[i] <= 1;

// Resets global buffers that collect output data
`define GLB_RESET(i) \
    r_glb_rw[i] <= 0; \
    r_glb_addr[i] <= 0; \
    r_glb_ready[i] <= 0;

// Stalls (but does not 0) global buffers
`define GLB_STALL(i) \
    r_glb_rw[i] <= 1'bz; \
    r_glb_addr[i] <= 0; \
    r_glb_ready[i] <= 1;

`define GLB_READ_ADDR(i, addr) \
    r_glb_rw[i] <= 1; \
    r_glb_addr[i] <= addr; \
    r_glb_ready[i] <= 1;

`define GLB_READ_INCR(i) \
    r_glb_rw[i] <= 1; \
    r_glb_ready[i] <= 1; \
    r_glb_addr[i] <= r_glb_addr[i] + 1;

// Sets weight memory to read data into specified address
`define MEM_WEIGHT_READ_ADDR(i, addr) \
    r_mem_weight_rw[i] <= 1; \
    r_mem_weight_ready[i] <= 1; \
    r_mem_weight_addr[i] <= addr;

// Sets weight memory to read data with pre-incremented address
`define MEM_WEIGHT_READ_INCR(i) \
    r_mem_weight_rw[i] <= 1; \
    r_mem_weight_ready[i] <= 1; \
    r_mem_weight_addr[i] <= r_mem_weight_addr[i] + 1;

// Sets weight memory to write data from specified address
`define MEM_WEIGHT_WRITE_ADDR(i, addr) \
    r_mem_weight_rw[i] <= 0; \
    r_mem_weight_ready[i] <= 1; \
    r_mem_weight_addr[i] <= addr;

// Sets weight memory to write data with pre-incremented address
`define MEM_WEIGHT_WRITE_INCR(i) \
    r_mem_weight_rw[i] <= 0; \
    r_mem_weight_ready[i] <= 1; \
    r_mem_weight_addr[i] <= r_mem_weight_addr[i] + 1; 

// Sets input memory to read data into specified address
`define MEM_INPUT_READ_ADDR(i, addr) \
    r_mem_input_rw[i] <= 1; \
    r_mem_input_ready[i] <= 1; \
    r_mem_input_addr[i] <= addr;

// Sets input memory to read data with pre-incremented address
`define MEM_INPUT_READ_INCR(i) \
    r_mem_input_rw[i] <= 1; \
    r_mem_input_ready[i] <= 1; \
    r_mem_input_addr[i] <= r_mem_input_addr[i] + 1;
    
// Sets input memory to write data from specified address
`define MEM_INPUT_WRITE_ADDR(i, addr) \
    r_mem_input_rw[i] <= 0; \
    r_mem_input_ready[i] <= 1; \
    r_mem_input_addr[i] <= addr;

// Sets input memory to write data from pre-incremented address
`define MEM_INPUT_WRITE_INCR(i) \
    r_mem_input_rw[i] <= 0; \
    r_mem_input_ready[i] <= 1; \
    r_mem_input_addr[i] <= r_mem_input_addr[i] + 1; 

// Sets range of PEs to read
`define PE_READ_RANGE(bottom, top) \
    for (i = bottom; i < top; i = i + 1) begin \
        r_pe_ready[i] <= 1; \
        r_pe_rw[i] <= 1; \
        r_pe_stream[i] <= 0; \
    end

// Sets range of PEs to read with streaming
`define PE_READ_STREAM_RANGE(bottom, top) \
    for (i = bottom; i < top; i = i + 1) begin \
        r_pe_ready[i] <= 1; \
        r_pe_rw[i] <= 1; \
        r_pe_stream[i] <= 1; \
    end

// Sets range of PEs to be reset
`define PE_RESET_RANGE(bottom, top) \
    for (j = bottom; j < top; j = j + 1) begin \
        r_pe_ready[j] <= 0; \
        r_pe_rw[j] <= 0; \
        r_pe_stream[j] <= 0; \
    end

// Sets range of PEs to write
`define PE_WRITE_RANGE(bottom, top) \
    for (i = bottom; i < top; i = i + 1) begin \
        r_pe_ready[i] <= 1; \
        r_pe_rw[i] <= 0; \
        r_pe_stream[i] <= 0; \
    end

// Sets range of PEs to write with streaming
`define PE_WRITE_STREAM_RANGE(bottom, top) \
    for (i = bottom; i < top; i = i + 1) begin \
        r_pe_ready[i] <= 1; \
        r_pe_rw[i] <= 0; \
        r_pe_stream[i] <= 1; \
    end

// Sets specific PE to write without streaming
`define PE_WRITE(i) \
    r_pe_ready[i] <= 1; \
    r_pe_rw[i] <= 0; \
    r_pe_stream[i] <= 0;

// Sets specific PE to write with streaming
`define PE_WRITE_STREAM(i) \
    r_pe_ready[i] <= 1; \
    r_pe_rw[i] <= 0; \
    r_pe_stream[i] <= 1;

// Sets specific PE to read
`define PE_READ(i) \
    r_pe_ready[i] <= 1; \
    r_pe_rw[i] <= 1; \
    r_pe_stream[i] <= 0;

// Sets specific PE to read with streaming
`define PE_READ_STREAM(i) \
    r_pe_ready[i] <= 1; \
    r_pe_rw[i] <= 1; \
    r_pe_stream[i] <= 1;

// Sets specific PE to be reset
`define PE_RESET(i) \
    r_pe_ready[i] <= 0; \
    r_pe_rw[i] <= 0; \
    r_pe_stream[i] <= 0;


/* ==============================================
Controller module 
============================================== */

module control #(
    parameter NUM_MEMS = `OUT_CTL_NUM_MEMS,                                     // Number of memories feeding the array       
    parameter NUM_PES = NUM_MEMS * NUM_MEMS,                                    // Number of PEs in the array
    parameter BURST_WIDTH = `OUT_ARB_BURST_WIDTH,                               // Burst signal data width
    parameter MEM_ADDR_WIDTH = $clog2(`OUT_MEM_NUM_ROWS),                       // Address width for memories
    parameter GLB_ADDR_WIDTH = $clog2(`OUT_GLB_NUM_ROWS)                        // Address width for global buffers
) (
    input wire w_clock,                                                         // Clock input
    input wire w_ready,                                                         // Active high ready
    input wire [BURST_WIDTH-1:0] w_burst,                                       // Burst size for data transfer
    input wire w_grant,                                                         // Grant signal from the arbiter
    
    output reg r_req,                                                           // Request signal to the arbiter
    
    output reg [NUM_MEMS-1:0] r_mem_weight_rw,                                  // Weight memory read/write signals
    output reg [MEM_ADDR_WIDTH-1:0] r_mem_weight_addr [NUM_MEMS-1:0],           // Weight memory address signals
    output reg [NUM_MEMS-1:0] r_mem_weight_ready,                               // Weight memory ready signals

    output reg [NUM_MEMS-1:0] r_mem_input_rw,                                   // Input memory read/write signals
    output reg [MEM_ADDR_WIDTH-1:0] r_mem_input_addr [NUM_MEMS-1:0],            // Input memory address signals
    output reg [NUM_MEMS-1:0] r_mem_input_ready,                                // Input memory ready signals

    output reg [NUM_MEMS-1:0] r_glb_rw,                                         // GLB read/write signals
    output reg [GLB_ADDR_WIDTH-1:0] r_glb_addr [NUM_MEMS-1:0],                  // GLB address signals
    output reg [NUM_MEMS-1:0] r_glb_ready,                                      // GLB ready signals

    // These are ordered by PE delay group, though it'll be weird to connect wires properly
    // Specifically, the order from bit 0 to the highest bit is:
    // PE (11), (12, 21), (13, 22, 31), (14, 23, 32, 41), (24, 33, 42), (34, 43), (44)
    // (the parentheses enclose the delay group)
    output reg [NUM_PES-1:0] r_pe_ready,                                        // PE ready signals
    output reg [NUM_PES-1:0] r_pe_rw,                                           // Read data from mem or pass forward
    output reg [NUM_PES-1:0] r_pe_stream                                        // Stream forwarded data or own data
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
    reg [BURST_WIDTH:0] r_burst;            // Intentionally oversized to handle overflow
    integer i, j, k;                        // index variables for mems, GLBs, PEs.

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
                LOAD: if (r_transfer_done) begin
                    r_state <= DISTRIBUTE;
                    r_transfer_done <= 0;
                    r_count <= 0;
                end
                // Finish distributing data to last PE before computing
                DISTRIBUTE: if (r_transfer_done) begin
                    r_state <= COMPUTE;
                    r_transfer_done <= 0;
                    r_count <= 0;
                end
                // Finish computing in earliest PE before cleanup
                COMPUTE: if (r_transfer_done) begin
                    r_state <= CLEANUP;
                    r_transfer_done <= 0;
                    r_count <= 0;
                end
                // Finish cleanup for all PEs before unloading GLBs
                CLEANUP: if (r_transfer_done) begin
                    r_state <= UNLOAD;
                    r_transfer_done <= 0;
                    r_count <= 0;
                end
                // Finish unloading GLBs before resetting 
                // (waiting for grant within state logic)
                UNLOAD: if (r_transfer_done) begin
                    r_state <= RESET;
                    r_transfer_done <= 0;
                    r_count <= 0;
                end
                default: r_state <= RESET;
            endcase
        end
    end

    // Register assignments
    always @(posedge w_clock) begin

         case (r_state)
            RESET: begin
                // Reset all memory and GLB addresses and ready signals
                for (i = 0; i < NUM_MEMS; i = i + 1) begin
                    `RESET_MEMS(i)
                    `GLB_RESET(i)
                end

                // Reset all PEs
                for (j = 0; j < NUM_PES; j = j + 1) begin
                    `PE_RESET(j)
                end

                // Reset internal signals
                r_req <= 1;
                r_transfer_done <= 0;
                r_count <= 0;
                r_burst <= 0;
            end
            LOAD: begin
                r_req <= 1;
                if (r_transfer_done == 0) r_count <= r_count + 1;

                // Reset all GLBs
                for (i = 0; i < NUM_MEMS; i = i + 1) begin
                    `GLB_RESET(i)
                end

                // Reset all PEs
                for (j = 0; j < NUM_PES; j = j + 1) begin
                    `PE_RESET(j)
                end
                
                // Step 1 - get burst length
                if (r_count == 0) begin
                    r_burst <= w_burst;
                    r_transfer_done <= 0;

                    // Memories stay off while determining burst length
                    for (k = 0; k < NUM_MEMS; k = k + 1) begin
                        `RESET_MEMS(k)
                    end
                end 
                // Step 2 - load data into memories
                else begin
                    // +1 offset for burst capture at start
                    if (r_count == r_burst + 1) begin
                        r_transfer_done <= 1;
                        r_burst <= r_burst;
                    end

                    for (k = 0; k < NUM_MEMS; k = k + 1) begin
                        if (r_count == 1) begin
                            `MEM_WEIGHT_READ_ADDR(k, 0)
                            `MEM_INPUT_READ_ADDR(k, 0)
                        end else begin
                            `MEM_WEIGHT_READ_INCR(k)
                            `MEM_INPUT_READ_INCR(k)
                        end
                    end
                end
            end
            DISTRIBUTE: begin
                r_req <= 0;
                if (r_transfer_done == 0) r_count <= r_count + 1;
                r_burst <= r_burst;

                // Reset all GLBs
                for (i = 0; i < NUM_MEMS; i = i + 1) begin
                    `GLB_RESET(i)
                end

                // Get new mem active every cycle until all mems active
                if (r_count < NUM_MEMS) begin
                    // Already active mems increment addresses
                    for (j = 0; j < r_count; j = j + 1) begin
                        `MEM_WEIGHT_WRITE_INCR(j)
                        `MEM_INPUT_WRITE_INCR(j)
                    end
                    // Just became active mem starts address at 0
                    `MEM_WEIGHT_WRITE_ADDR(r_count, 0)
                    `MEM_INPUT_WRITE_ADDR(r_count, 0)
                end 
                
                // Keep memories active until data is distributed
                else begin
                    for (j = 0; j < NUM_MEMS; j = j + 1) begin
                        if (r_mem_weight_addr[j] == r_burst) begin
                            r_mem_weight_ready[j] <= 0;
                            r_mem_input_ready[j] <= 0;
                        end else begin
                            `MEM_WEIGHT_WRITE_INCR(j)
                            `MEM_INPUT_WRITE_INCR(j)
                        end
                    end
                end

                // Warning - hardcoded section
                case (r_count)
                    0: begin 
                        `PE_READ_RANGE(0, 1)
                        `PE_RESET_RANGE(1, 16)
                    end
                    1: begin
                        `PE_READ_RANGE(0, 3)
                        `PE_RESET_RANGE(3, 16)
                    end
                    2: begin
                        `PE_READ_RANGE(0, 6)
                        `PE_RESET_RANGE(6, 16)
                    end
                    3: begin
                        `PE_READ_RANGE(0, 10)
                        `PE_RESET_RANGE(10, 16)
                    end
                    4: begin
                        `PE_READ_RANGE(0, 13)
                        `PE_RESET_RANGE(13, 16)
                    end
                    5: begin
                        `PE_READ_RANGE(0, 15)
                        `PE_RESET_RANGE(15, 16)
                    end
                    6: begin
                        `PE_READ_RANGE(0, 16)
                        r_transfer_done <= 1;
                    end
                    default: begin
                        `PE_RESET_RANGE(0, 16)
                    end
                endcase

            end
            COMPUTE: begin
                if (r_transfer_done == 0) r_count <= r_count + 1;
                r_burst <= r_burst;

                // Reset all GLBs; keep PEs active; keep memories active
                for (i = 0; i < NUM_MEMS; i = i + 1) begin
                    `GLB_RESET(i)
                    `PE_READ_RANGE(0, 16)
                    
                    if (r_mem_weight_addr[i] == r_burst) begin
                        r_mem_weight_ready[i] <= 0;
                        r_mem_input_ready[i] <= 0;
                    end else begin
                        `MEM_WEIGHT_WRITE_INCR(i)
                        `MEM_INPUT_WRITE_INCR(i)
                    end
                end

                // Transition to cleanup after first PE completes
                if (r_mem_weight_addr[0] == r_burst) begin
                    r_transfer_done <= 1;
                end
            end
            CLEANUP: begin
                if (r_transfer_done == 0) r_count <= r_count + 1;
                r_burst <= r_burst;
                r_transfer_done <= 0;

                // Warning - hardcoded section dependent on PE order
                // PE (11), (12, 21), (13, 22, 31), (14, 23, 32, 41), (24, 33, 42), (34, 43), (44)
                //     0     1    2    3   4   5     6   7   8   9     10  11  12    13  14    15
                case (r_count)
                    0: begin
                        `PE_WRITE(0)
                        `PE_READ_STREAM(1)
                        `PE_READ_RANGE(2, 16)

                        `STALL_MEMS(0)
                        for (i = 1; i < NUM_MEMS; i = i + 1) begin
                            `MEM_WEIGHT_READ_INCR(i)
                            `MEM_INPUT_READ_INCR(i)
                        end

                        for (k = 1; k < NUM_MEMS; k = k + 1) begin
                            `GLB_RESET(k)
                        end
                    end
                    1: begin
                        `PE_RESET(0)
                        `PE_WRITE_RANGE(1, 3)
                        `PE_READ_STREAM_RANGE(3, 5)
                        `PE_READ_RANGE(5, 16)
                        
                        for (i = 0; i < 2; i = i + 1) begin
                            `STALL_MEMS(i)
                        end

                        for (j = 2; j < NUM_MEMS; j = j + 1) begin
                            `MEM_WEIGHT_READ_INCR(j)
                            `MEM_INPUT_READ_INCR(j)
                        end

                        for (k = 1; k < NUM_MEMS; k = k + 1) begin
                            `GLB_STALL(k)
                        end
                    end
                    2: begin
                        `PE_RESET(0)
                        `PE_RESET(2)
                        `PE_WRITE_STREAM(1)
                        `PE_WRITE_RANGE(3, 6)
                        `PE_READ_STREAM_RANGE(6, 9)
                        `PE_READ_RANGE(9, 16)

                        for (i = 0; i < 3; i = i + 1) begin
                            `STALL_MEMS(i)
                        end

                        for (j = 3; j < NUM_MEMS; j = j + 1) begin
                            `MEM_WEIGHT_READ_INCR(j)
                            `MEM_INPUT_READ_INCR(j)
                        end

                        for (k = 1; k < NUM_MEMS; k = k + 1) begin
                            `GLB_STALL(k)
                        end
                    end
                    3: begin
                        `PE_RESET(0)
                        `PE_RESET(2)
                        `PE_RESET(5)
                        `PE_WRITE_STREAM(1)
                        `PE_WRITE_STREAM(3)
                        `PE_WRITE_STREAM(4)
                        `PE_WRITE_RANGE(6, 10)
                        `PE_READ_STREAM_RANGE(10, 13)
                        `PE_READ_RANGE(13, 16)

                        for (i = 0; i < NUM_MEMS; i = i + 1) begin
                            `STALL_MEMS(i)
                        end

                        `GLB_READ_ADDR(0, 0)
                        for (k = 1; k < NUM_MEMS; k = k + 1) begin
                            // Switching to stalling now to prevent data from being overwritten
                            `GLB_STALL(k)
                        end
                    end
                    4: begin
                        `PE_RESET(0)
                        `PE_RESET(2)
                        `PE_RESET(5)
                        `PE_RESET(9)
                        `PE_WRITE_STREAM(1)
                        `PE_WRITE_STREAM(3)
                        `PE_WRITE_STREAM(4)
                        `PE_WRITE_STREAM(6)
                        `PE_WRITE_STREAM(7)
                        `PE_WRITE_STREAM(8)
                        `PE_WRITE(10)
                        `PE_WRITE(11)
                        `PE_WRITE(12)
                        `PE_READ_STREAM(13)
                        `PE_READ_STREAM(14)
                        `PE_READ(15)
                        
                        for (i = 0; i < NUM_MEMS; i = i + 1) begin
                            `STALL_MEMS(i)
                        end

                        `GLB_READ_ADDR(0, 1)
                        `GLB_READ_ADDR(1, 0)
                        `GLB_STALL(2)
                        `GLB_STALL(3)
                    end
                    5: begin
                        `PE_RESET(0)
                        `PE_RESET(2)
                        `PE_RESET(5)
                        `PE_RESET(9)
                        `PE_WRITE_STREAM(1)
                        `PE_WRITE_STREAM(3)
                        `PE_WRITE_STREAM(4)
                        `PE_WRITE_STREAM(7)
                        `PE_WRITE_STREAM(8)
                        `PE_WRITE_STREAM(10)
                        `PE_WRITE_STREAM(11)
                        `PE_WRITE_STREAM(12)
                        `PE_WRITE(13)
                        `PE_WRITE(14)
                        `PE_READ_STREAM(6)
                        `PE_READ_STREAM(15)

                        for (i = 0; i < NUM_MEMS; i = i + 1) begin
                            `STALL_MEMS(i)
                        end

                        `GLB_STALL(0)
                        `GLB_READ_ADDR(1, 1)
                        `GLB_READ_ADDR(2, 0)
                        `GLB_STALL(3)
                    end
                    6: begin
                        `PE_RESET(0)
                        `PE_RESET(2)
                        `PE_RESET(5)
                        `PE_RESET(9)
                        `PE_WRITE_STREAM(1)
                        `PE_WRITE_STREAM(4)
                        `PE_WRITE_STREAM(6)
                        `PE_WRITE_STREAM(7)
                        `PE_WRITE_STREAM(8)
                        `PE_WRITE_STREAM(11)
                        `PE_WRITE_STREAM(12)
                        `PE_WRITE_STREAM(13)
                        `PE_WRITE_STREAM(14)
                        `PE_WRITE(15)
                        `PE_READ_STREAM(3)
                        `PE_READ_STREAM(10)

                        for (i = 0; i < NUM_MEMS; i = i + 1) begin
                            `STALL_MEMS(i)
                        end

                        `GLB_READ_ADDR(0, 2)
                        `GLB_STALL(1)
                        `GLB_READ_ADDR(2, 1)
                        `GLB_READ_ADDR(3, 0)
                    end
                    7: begin
                        `PE_RESET(0)
                        `PE_RESET(1)
                        `PE_RESET(2)
                        `PE_RESET(5)
                        `PE_RESET(9)
                        `PE_WRITE_STREAM(3)
                        `PE_WRITE_STREAM(4)
                        `PE_WRITE_STREAM(8)
                        `PE_WRITE_STREAM(10)
                        `PE_WRITE_STREAM(11)
                        `PE_WRITE_STREAM(12)
                        `PE_WRITE_STREAM(14)
                        `PE_WRITE_STREAM(15)
                        `PE_READ_STREAM(6)
                        `PE_READ_STREAM(7)
                        `PE_READ_STREAM(13)

                        for (i = 0; i < NUM_MEMS; i = i + 1) begin
                            `STALL_MEMS(i)
                        end

                        `GLB_STALL(0)
                        `GLB_READ_ADDR(1, 2)
                        `GLB_STALL(2)
                        `GLB_READ_ADDR(3, 1)
                    end
                    8: begin
                        `PE_RESET(0)
                        `PE_RESET(1)
                        `PE_RESET(2)
                        `PE_RESET(3)
                        `PE_RESET(4)
                        `PE_RESET(5)
                        `PE_RESET(9)
                        `PE_WRITE_STREAM(6)
                        `PE_WRITE_STREAM(7)
                        `PE_WRITE_STREAM(8)
                        `PE_WRITE_STREAM(12)
                        `PE_WRITE_STREAM(13)
                        `PE_WRITE_STREAM(14)
                        `PE_READ_STREAM(10)
                        `PE_READ_STREAM(11)
                        `PE_READ_STREAM(15)

                        for (i = 0; i < NUM_MEMS; i = i + 1) begin
                            `STALL_MEMS(i)
                        end

                        `GLB_READ_ADDR(0, 3)
                        `GLB_STALL(1)
                        `GLB_READ_ADDR(2, 2)
                        `GLB_STALL(3)
                    end
                    9: begin
                        for (i = 0; i < 10; i = i + 1) begin
                            `PE_RESET(i)
                        end
                        `PE_WRITE_STREAM(10)
                        `PE_WRITE_STREAM(11)
                        `PE_WRITE_STREAM(12)
                        `PE_WRITE_STREAM(15)
                        `PE_READ_STREAM(13)
                        `PE_READ_STREAM(14)

                        for (j = 0; j < NUM_MEMS; j = j + 1) begin
                            `STALL_MEMS(j)
                        end

                        `GLB_STALL(0)
                        `GLB_READ_ADDR(1, 3)
                        `GLB_STALL(2)
                        `GLB_READ_ADDR(3, 2)
                    end
                    10: begin
                        for (i = 0; i < 13; i = i + 1) begin
                            `PE_RESET(i)
                        end
                        `PE_WRITE_STREAM(13)
                        `PE_WRITE_STREAM(14)
                        `PE_READ_STREAM(15)

                        for (j = 0; j < NUM_MEMS; j = j + 1) begin
                            `STALL_MEMS(j)
                        end

                        `GLB_STALL(0)
                        `GLB_STALL(1)
                        `GLB_READ_ADDR(2, 3)
                        `GLB_STALL(3)
                    end
                    11: begin
                        for (i = 0; i < 15; i = i + 1) begin
                            `PE_RESET(i)
                        end
                        `PE_WRITE_STREAM(15)

                        for (j = 0; j < NUM_MEMS; j = j + 1) begin
                            `STALL_MEMS(j)
                        end

                        `GLB_STALL(0)
                        `GLB_STALL(1)
                        `GLB_STALL(2)
                        `GLB_READ_ADDR(3, 3)

                        r_transfer_done <= 1;
                    end
                    // Should never reach this state
                    default: begin
                        for (i = 0; i < 16; i = i + 1) begin
                            `PE_RESET(i)
                        end

                        for (j = 0; j < NUM_MEMS; j = j + 1) begin
                            `STALL_MEMS(j)
                            `GLB_STALL(j)
                        end
                    end
                endcase  
            end
            UNLOAD: begin
                // Keep waiting till grant received
                r_req <= 1;

                if (w_grant) begin
                    if (r_transfer_done == 0) r_count <= r_count + 1;

                    // Reset all MEMs
                    for (i = 0; i < NUM_MEMS; i = i + 1) begin
                        `STALL_MEMS(i)
                    end

                    // Reset all PEs
                    for (j = 0; j < NUM_PES; j = j + 1) begin
                        `PE_RESET(j)
                    end

                    // Step 1 - get burst length
                    if (r_count == 0) begin
                        r_burst <= w_burst;
                        r_transfer_done <= 0;

                        // GLBs stay off while determining burst length
                        for (k = 0; k < NUM_MEMS; k = k + 1) begin
                            `GLB_STALL(k)
                        end
                    end 
                    // Step 2 - load data into memories
                    else begin
                        if (r_count == r_burst) begin
                            r_transfer_done <= 1;
                            r_burst <= r_burst;
                        end

                        for (k = 0; k < NUM_MEMS; k = k + 1) begin
                            if (r_count == 1) begin
                                `GLB_READ_ADDR(k, 0)
                            end else begin
                                `GLB_READ_INCR(k)
                            end
                        end
                    end
                end
            end
         endcase
    end
endmodule
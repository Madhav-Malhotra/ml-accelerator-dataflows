/*
 * Copyright (c) 2024 WAT.ai Chip Team
 * Author: Zoe Lussier-Gibbons
 * SPDX-License-Identifier: Apache-2.0
 * Implements PE array core
 * Spec: https://docs.google.com/document/d/1bwynsWdD87AS_AJQEDSaEcCtV5cUac0pMMwL_9xpX6k/edit?tab=t.0#heading=h.tlr9wct1v7uh
 */

`include "parameters.vh"

module core #(
    parameter MEM_NUM_ROWS = `OUT_MEM_NUM_ROWS,                         // Num rows per input/weight memory  
    parameter MEM_NUM_BITS = `OUT_MEM_NUM_BITS,                         // Num bits/row for I/W memory
    parameter GLB_NUM_ROWS = `OUT_GLB_NUM_ROWS,                         // Num rows per GLB
    parameter GLB_NUM_BITS = `OUT_GLB_NUM_BITS,                         // Num bits/row for GLB
    parameter PE_WEIGHT_WIDTH = `OUT_PE_WEIGHT_WIDTH,                   // num bits for PE weight
    parameter PE_INPUT_WIDTH = `OUT_PE_INPUT_WIDTH,                     // num bits for PE input
    parameter PE_SCRATCH_WIDTH = `OUT_PE_SCRATCH_WIDTH,                 // num bits for PE scratchpad
    parameter PE_FWD_WIDTH = `OUT_PE_FWD_WIDTH,                         // num bits for PE forward reg
    parameter ARB_NUM_CORES = `OUT_ARB_NUM_CORES,                       // num cores for arbiter to manage
    parameter ARB_ADDR_WIDTH = `OUT_ARB_ADDR_WIDTH,                     // num bits for arbiter address signal
    parameter ARB_FIXED_BURST_WRITE = `OUT_ARB_FIXED_BURST_WRITE,       // fixed burst write length
    parameter ARB_FIXED_BURST_READ = `OUT_ARB_FIXED_BURST_READ,         // fixed burst read length
    parameter ARB_BURST_WIDTH = `OUT_ARB_BURST_WIDTH,                   // num bits for arbiter burst signal
    parameter CTL_BURST_WIDTH = `OUT_ARB_BURST_WIDTH                    // num bits for controller burst signal (same as arbiter)
    parameter CTL_NUM_MEMS = `OUT_CTL_NUM_MEMS,                         // num memories for control unit
    parameter CTL_MAIN_MEM_ADDR_WIDTH = `OUT_CTL_MAIN_MEM_ADDR_WIDTH,   // num bits for main memory address
) (
    input wire w_clock,                                                 // Goes to every submodule
    inout wire [NUM_BUS_WIRES-1:0] w_bus,                               // Connects with mems/GLBs
    output wire w_main_mem_rw,                                          // Arbiter's output to main memory
    output wire [CTL_MAIN_MEM_ADDR_WIDTH-1:0] w_main_mem_addr,          // Arbiter's output to main memory
)

    // Will need a BUNCH of internal wires and genvar loops here

endmodule
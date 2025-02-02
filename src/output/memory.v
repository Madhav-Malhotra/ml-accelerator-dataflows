/*
 * Copyright (c) 2024 WAT.ai Chip Team
 * Author: Zoe Lussier-Gibbons
 * SPDX-License-Identifier: Apache-2.0
 * Implements memory for single PE
 */

`include "parameters.vh"

module memory #(
  parameter OUT_MEM_NUM_ROWS = `OUT_MEM_NUM_ROWS,           // number of rows in memory
  parameter OUT_MEM_ADDR_WIDTH = $clog2(OUT_MEM_NUM_ROWS),  // address for num rows
  parameter OUT_MEM_NUM_BITS = `OUT_MEM_NUM_BITS            // number of bits per row
)(
  input wire w_clock,                                       // clock input
  input wire w_ready,                                       // start reading/writing when active high, when active low reset
  input wire w_rw,                                          // read when active high, write when active low
  input wire [OUT_MEM_ADDR_WIDTH-1:0] w_address,            // Address of the row in Q, 2^6 = 64
  input wire [OUT_MEM_NUM_BITS - 1:0] w_data_in,            // data input
  output wire [OUT_MEM_NUM_BITS - 1:0] w_data_out           // data output
);
  
  reg [OUT_MEM_NUM_BITS - 1:0] r_Q [OUT_MEM_NUM_ROWS-1:0];  // State, array with 64 8-bit numbers
  reg [OUT_MEM_NUM_BITS - 1:0] r_data_out;
  integer i;
  
  always @(posedge w_clock) begin
    if (!w_ready) begin                                     // reset Q when ready = 0
      for (i = 0; i < OUT_MEM_NUM_ROWS; i = i + 1) begin
        r_Q[i] <= {OUT_MEM_NUM_BITS{1'b0}};
      end
      
    end else if (w_ready) begin                             // read or write when ready = 1
      if (w_rw) begin 
        r_Q[w_address] <= w_data_in;                        // read number
      end else if (!w_rw) begin
        r_data_out <= r_Q[w_address];                       // writing number
      end
    end
  end

  // only connect reg to output if ready and write mode
  assign w_data_out = (!w_ready || w_rw || w_rw === 1'bz) ? {OUT_MEM_NUM_BITS{1'bz}} : r_data_out;
endmodule
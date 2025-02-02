/*
 * Copyright (c) 2024 WAT.ai Chip Team
 * Author: Zoe Lussier-Gibbons
 * SPDX-License-Identifier: Apache-2.0
 * Implements a global buffer with add-enable functionality
 * Spec: https://docs.google.com/document/d/1bwynsWdD87AS_AJQEDSaEcCtV5cUac0pMMwL_9xpX6k/edit?tab=t.0#heading=h.qjwttrfzpb37
 */

`include "parameters.vh"

module glb #(
  parameter WGT_GLB_NUM_ROWS = `WGT_GLB_NUM_ROWS,           // number of rows in memory
  parameter WGT_GLB_ADDR_WIDTH = $clog2(WGT_GLB_NUM_ROWS),  // address for num rows
  parameter WGT_GLB_NUM_BITS = `WGT_GLB_NUM_BITS            // number of bits per row
)(
  input wire w_clock,                                       // clock input
  input wire w_ready,                                       // start reading/writing when active high, when active low reset
  input wire w_rw,                                          // read when active high, write when active low
  input wire w_add,                                         // add onto existing data if high, else overwrite 
  input wire [WGT_GLB_ADDR_WIDTH-1:0] w_address,            // address of the row in Q, 2^6 = 64
  input wire [WGT_GLB_NUM_BITS - 1:0] w_data_in,            // data input
  output wire [WGT_GLB_NUM_BITS - 1:0] w_data_out           // data output
);
  
  reg [WGT_GLB_NUM_BITS - 1:0] r_Q [WGT_GLB_NUM_ROWS-1:0];  // State, array with 64 8-bit numbers
  reg [WGT_GLB_NUM_BITS - 1:0] r_data_out;
  integer i;
  
  always @(posedge w_clock) begin
    if (!w_ready) begin                                     // reset Q when ready = 0
      for (i = 0; i < WGT_GLB_NUM_ROWS; i = i + 1) begin
        r_Q[i] <= {WGT_GLB_NUM_BITS{1'b0}};
      end
      
    end else if (w_ready) begin                             // read or write when ready = 1
      if (w_rw) begin
        if (w_add) begin
          r_Q[w_address] <= r_Q[w_address] + w_data_in;     // add onto existing
        end else begin
          r_Q[w_address] <= w_data_in;                      // overwrite existing
        end 
      end else if (!w_rw) begin
        r_data_out <= r_Q[w_address];                       // writing number
      end
    end
  end

  // only connect reg to output if ready and write mode
  assign w_data_out = (!w_ready || w_rw || w_rw === 1'bz) ? {WGT_GLB_NUM_BITS{1'bz}} : r_data_out;
endmodule
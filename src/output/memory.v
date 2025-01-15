/*
 * Copyright (c) 2024 WAT.ai Chip Team
 * Author: Zoe Lussier-Gibbons
 * SPDX-License-Identifier: Apache-2.0
 * Implements memory for single PE
 */
module memory #(
  parameter num_bits = 8 // number of bits 
)(
  input wire w_clk, // clock input
  input wire w_ready, // start reading/writing when active high, when active low reset
  input wire w_rw, // read when active high, write when active low
  input wire [5:0] w_address, // Address of the row in Q, 2^6 = 64
  input wire [num_bits - 1:0] w_data_in, // data input
  output reg [num_bits - 1:0] r_data_out // data output
);
  
  reg [num_bits - 1:0] r_Q [63:0]; // State, array with 64 8-bit numbers
  reg [num_bits - 1:0] r_data_out_reg;
  integer i;
  
  // only connect reg to output if ready and rw
  always @(*) begin
    if (!w_ready || w_rw || w_rw === 1'bz) begin
      r_data_out = {num_bits{1'bz}}; // z when not ready or in read mode
    end else begin
      r_data_out = r_data_out_reg;
    end
  end
  
  always @(posedge w_clk) begin
    if (!w_ready) begin // reset Q when ready = 0
      for (i = 0; i < 64; i = i + 1) begin
        r_Q[i] <= {num_bits{1'b0}};
      end
      
    end else if (w_ready) begin // read or write when ready = 1
      if (w_rw) begin 
        r_Q[w_address] <= w_data_in; // read number
      end else if (!w_rw) begin
        r_data_out_reg <= r_Q[w_address]; // writing number
      end
    end
  end
endmodule
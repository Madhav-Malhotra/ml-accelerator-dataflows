/*
 * Copyright (c) 2024 WAT.ai Chip Team
 * Author: Zoe Lussier-Gibbons
 * SPDX-License-Identifier: Apache-2.0
 * Implements Output Stationary Cache
 */

module cache #(
  parameter wa_bits = 8, // number of bits for weight and activation
  parameter wa_rows = 256, // number of rows for weight and activation 
  parameter p_bits = 16, // number of bits for psums
  parameter p_rows = 32 // number of rows for psums
)(
  input wire w_clk, // clock input
  input wire w_ready, // When active high: load/send data or idle when active low: reset signals
  input wire [2:0] w_state, // controls functionality, 3 bits for 7 states
  input wire [wa_bits - 1 : 0] w_bus_in, // input to bus
  input wire [p_bits - 1 : 0] w_glb_in, // input to GLB
  input wire [7:0] w_w_addr, // address of weight register also used for psum register address, 8 bits for 256 numbers
  input wire [7:0] w_a_addr, // address of activation register, 8 bits for 256 numbers
  output reg [wa_bits - 1 : 0] r_wout, // weight output
  output reg [wa_bits - 1 : 0] r_aout, // activation output
  output reg [p_bits - 1 : 0] r_bus_out // psum output to bus
);
  
  reg [wa_bits - 1 : 0] r_w [wa_rows - 1 : 0]; // weight register
  reg [wa_bits - 1 : 0] r_a [wa_rows - 1 : 0]; // activation register
  reg [p_bits - 1 : 0] r_p [p_rows - 1 : 0]; // psum register
  integer i;
  
  // assign values to registers and to output
  always @ (posedge w_clk) begin
    // if not ready clear all registers
    if (!w_ready) begin
      for (i = 0; i < p_rows; i = i + 1) begin
        r_w[i] <= {wa_bits{1'b0}};
        r_a[i] <= {wa_bits{1'b0}};
        r_p[i] <= {p_bits{1'b0}};
      end 
      for (i = p_rows; i < wa_rows ; i = i + 1) begin
        r_w[i] <= {wa_bits{1'b0}};
        r_a[i] <= {wa_bits{1'b0}};
      end
      r_wout <= {wa_bits{1'bz}};
      r_aout <= {wa_bits{1'bz}};
      r_bus_out <= {p_bits{1'bz}};
    end else begin
    case (w_state)
      3'b000: begin
        r_w[w_w_addr] <= w_bus_in;  // Load weight data
        r_wout <= {wa_bits{1'bz}};
      	r_aout <= {wa_bits{1'bz}};
      	r_bus_out <= {p_bits{1'bz}};
      end 
      3'b001: begin 
        r_a[w_a_addr] <= w_bus_in;  // Load activation data
        r_wout <= {wa_bits{1'bz}};
      	r_aout <= {wa_bits{1'bz}};
      	r_bus_out <= {p_bits{1'bz}};
      end 
      3'b010: begin
        r_wout <= r_w[w_w_addr];    // Send weight data
        r_aout <= {wa_bits{1'bz}};
      	r_bus_out <= {p_bits{1'bz}};
      end
      3'b011: begin 
        r_aout <= r_a[w_a_addr];    // Send activation data
        r_wout <= {wa_bits{1'bz}};
        r_bus_out <= {p_bits{1'bz}};
      end
      3'b100: begin                        // Send both weight & activation
        r_wout <= r_w[w_w_addr];
        r_aout <= r_a[w_a_addr];
        r_bus_out <= {p_bits{1'bz}};
      end
      3'b101: begin
        r_p[w_w_addr] <= w_glb_in;  // Load psum data
        r_wout <= {wa_bits{1'bz}};
      	r_aout <= {wa_bits{1'bz}};
      	r_bus_out <= {p_bits{1'bz}};
      end
      3'b110: begin
        r_bus_out <= r_p[w_w_addr]; // Send psum data
        r_wout <= {wa_bits{1'bz}};
      	r_aout <= {wa_bits{1'bz}};
      end
      3'b111: begin
        r_wout <= {wa_bits{1'bz}};
      	r_aout <= {wa_bits{1'bz}};
      	r_bus_out <= {p_bits{1'bz}};
      end
    endcase
  end 
  end
endmodule 
      
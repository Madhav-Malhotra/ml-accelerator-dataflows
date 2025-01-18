/*
 * Copyright (c) 2024 WAT.ai Chip Team
 * Author: Brian Ibitoye
 * SPDX-License-Identifier: Apache-2.0
 * Implements a Weight-Stationary Processing Element (PE)
 */

module pe #(
    parameter WIDTH = 16                      // Width of input and weight registers
) (
    input wire w_clk,                         // Clock signal
    input wire w_rst_n,                       // Active-low reset
    input wire w_ready,                       // Ready signal to indicate PE is ready to compute
    input wire w_rw,                          // Read/Write signal: 1 for read/compute, 0 for output
    input wire [WIDTH-1:0] w_weight,          // Stationary weight input
    input wire [WIDTH-1:0] w_input,           // Input data
    output wire [2*WIDTH-1:0] w_output        // 32-bit partial sum output
);

  // Internal storage registers
  reg [WIDTH-1:0] r_weight;                   // Register to store the stationary weight
  reg [2*WIDTH-1:0] r_scratch;                // Scratchpad for partial sums

  // Computation logic
  always @(posedge w_clk or negedge w_rst_n) begin
    if (!w_rst_n) begin
      r_weight <= {WIDTH{1'b0}};
      r_scratch <= {2*WIDTH{1'b0}};
    end else if (w_ready) begin
      if (w_rw) begin
        // Compute phase
        if (r_weight != 0 && w_input != 0) begin
          r_scratch <= r_scratch + (r_weight * w_input);
        end
      end
    end
  end

  // Output logic: Assign w_output based on w_ready
  assign w_output = w_ready ? r_scratch : {2*WIDTH{1'bz}};

endmodule

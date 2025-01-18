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
    output reg [2*WIDTH-1:0] w_output         // 32-bit partial sum output
);

  // Internal storage registers
  reg [WIDTH-1:0] r_weight;                   // Register to store the stationary weight
  reg [2*WIDTH-1:0] r_scratch;                // Scratchpad for partial sums
  reg r_phase;                                // Phase tracking: 0 = Load weight, 1 = Compute

  // Computation logic
  always @(posedge w_clk or negedge w_rst_n) begin
    if (!w_rst_n) begin
      r_weight <= {WIDTH{1'b0}};
      r_scratch <= {2*WIDTH{1'b0}};
      r_phase <= 1'b0; // Start in weight load phase
    end else if (w_ready) begin
      if (!w_rw) begin
        // Load weight phase
        r_weight <= w_weight;
        r_phase <= 1'b1; // Switch to compute phase
      end else if (r_phase) begin
        // Compute phase
        if (r_weight != 0 && w_input != 0) begin
          r_scratch <= r_scratch + (r_weight * w_input);
        end
      end
    end
  end

  // Output logic: Update output only when w_rw = 0 (Output Phase)
  always @(posedge w_clk) begin
    if (!w_rw) begin
      w_output <= r_scratch;
    end
  end

endmodule

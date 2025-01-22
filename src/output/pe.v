/*
 * Copyright (c) 2025 WAT.ai Chip Team
 * Author: Huy Trinh
 * SPDX-License-Identifier: Apache-2.0
 * 
 * Implements a two-stage, output-stationary Processing Element (PE) for 
 * AI MAC operations following the “A2” design.
 */
module pe #(
    parameter WEIGHT_WIDTH  = 8,
    parameter INPUT_WIDTH   = 8,
    parameter SCRATCH_WIDTH = 16,
    parameter FWD_WIDTH     = 16
)(
    input  wire                   w_clk,
    input  wire                   w_rst_n,      // active-low reset
    input  wire                   w_ready,      
    input  wire                   w_rw,
    input  wire                   w_stream,
    input  wire [WEIGHT_WIDTH-1:0] w_weight,
    input  wire [INPUT_WIDTH-1:0]  w_input,
    input  wire [FWD_WIDTH-1:0]    w_fwd_in,

    // Internal registers
    output wire [FWD_WIDTH-1:0]    w_out,
    output wire [WEIGHT_WIDTH-1:0] w_wreg_out,
    output wire [INPUT_WIDTH-1:0]  w_ireg_out
);

    reg [SCRATCH_WIDTH-1:0] r_scratch;
    reg [WEIGHT_WIDTH-1:0]  r_wreg;
    reg [INPUT_WIDTH-1:0]   r_ireg;
    reg [FWD_WIDTH-1:0]     r_freg;
    reg [FWD_WIDTH-1:0]     r_out;

    // Gated multiplier
    wire [SCRATCH_WIDTH-1:0] w_product = 
        ((w_weight == 0) || (w_input == 0)) ? 0 : (w_weight * w_input);

    always @(posedge w_clk or negedge w_rst_n) begin
        if (!w_rst_n) begin
            r_scratch <= 0;
            r_wreg    <= 0;
            r_ireg    <= 0;
            r_freg    <= 0;
            r_out     <= 0;
        end else begin
            // Defaults next states equal current state
            reg [SCRATCH_WIDTH-1:0] nxt_scratch = r_scratch;
            reg [WEIGHT_WIDTH-1:0]  nxt_wreg    = r_wreg;
            reg [INPUT_WIDTH-1:0]   nxt_ireg    = r_ireg;
            reg [FWD_WIDTH-1:0]     nxt_freg    = r_freg;
            reg [FWD_WIDTH-1:0]     nxt_out     = {FWD_WIDTH{1'bz}};

            if (!w_ready) begin
                // Load mode (w_ready=0)
                nxt_scratch = 0;
                nxt_wreg    = w_weight;
                nxt_ireg    = w_input;
                nxt_freg    = 0;
                nxt_out     = {FWD_WIDTH{1'bz}};
            end else if (w_ready && !w_rw) begin
                // read/no-MAC
                nxt_wreg    = w_weight;
                nxt_ireg    = w_input;
                nxt_scratch = r_scratch;
                nxt_freg    = r_freg;
                if (!w_stream)
                    // Out signal gets current scratch value
                    nxt_out = r_scratch;
                else
                    // Out signal gets current forward register 
                    nxt_out = r_freg;
            end else if (w_ready && w_rw) begin
                // Performs MAC operations
                nxt_scratch = r_scratch + w_product;
                nxt_wreg    = w_weight;
                nxt_ireg    = w_input;
                if (!w_stream) begin
                    // Output signal is high impedence when w_stream is low
                    nxt_out  = {FWD_WIDTH{1'bz}};
                    nxt_freg = r_freg;
                end else begin
                    // Streaming, outsignal load new freg from w_fwd_in
                    nxt_out  = r_freg;
                    nxt_freg = w_fwd_in;
                end
            end

            // Update internal registers
            r_scratch <= nxt_scratch;
            r_wreg    <= nxt_wreg;
            r_ireg    <= nxt_ireg;
            r_freg    <= nxt_freg;
            r_out     <= nxt_out;
        end
    end

    assign w_out       = r_out;
    assign w_wreg_out  = r_wreg;
    assign w_ireg_out  = r_ireg;

endmodule

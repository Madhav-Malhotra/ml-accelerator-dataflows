/*
 * Copyright (c) 2025 WAT.ai Chip Team
 * Author: Huy Trinh
 * SPDX-License-Identifier: Apache-2.0
 * 
 * Implements a two-stage, output-stationary Processing Element (PE) for 
 * AI MAC operations
 * Spec: https://docs.google.com/document/d/1bwynsWdD87AS_AJQEDSaEcCtV5cUac0pMMwL_9xpX6k/edit?tab=t.0#heading=h.pdc4986g7pr4
 */

`include "parameters.vh"

module pe #(
    parameter OUT_PE_WEIGHT_WIDTH  = `OUT_PE_WEIGHT_WIDTH,
    parameter OUT_PE_INPUT_WIDTH   = `OUT_PE_INPUT_WIDTH,
    parameter OUT_PE_SCRATCH_WIDTH = `OUT_PE_SCRATCH_WIDTH,
    parameter OUT_PE_FWD_WIDTH     = `OUT_PE_FWD_WIDTH
)(
    input  wire                           w_clock,
    input  wire                           w_ready,      
    input  wire                           w_rw,
    input  wire                           w_stream,
    input  wire [OUT_PE_WEIGHT_WIDTH-1:0] w_weight,
    input  wire [OUT_PE_INPUT_WIDTH-1:0]  w_input,
    input  wire [OUT_PE_FWD_WIDTH-1:0]    w_fwd_in,

    output wire [OUT_PE_FWD_WIDTH-1:0]    w_out,
    output wire [OUT_PE_WEIGHT_WIDTH-1:0] w_wgt_out,
    output wire [OUT_PE_INPUT_WIDTH-1:0]  w_inp_out
);

    // Internal signals
    reg [OUT_PE_WEIGHT_WIDTH-1:0]  r_wgt;
    reg [OUT_PE_INPUT_WIDTH-1:0]   r_inp;
    reg [OUT_PE_FWD_WIDTH-1:0]     r_fwd;
    reg [OUT_PE_SCRATCH_WIDTH-1:0] r_scratch;
    reg [OUT_PE_SCRATCH_WIDTH-1:0] r_pipeline;

    always @(posedge w_clock) begin
        r_wgt <= w_weight;
        r_inp <= w_input;
        
        // Normal operations
        if (w_ready) begin
            // Data gated pipeline addition
            if (r_pipeline != {OUT_PE_SCRATCH_WIDTH{1'b0}}) begin
                r_scratch <= r_scratch + r_pipeline;
                r_pipeline <= {OUT_PE_SCRATCH_WIDTH{1'b0}};
            end else begin
                r_scratch <= r_scratch;
                r_pipeline <= r_pipeline;
            end

            // If read, then initiate pipelined multiplication with data gating
            if (w_rw) begin
                if (w_weight != {OUT_PE_WEIGHT_WIDTH{1'b0}} && w_input != {OUT_PE_INPUT_WIDTH{1'b0}}) begin
                    r_pipeline <= w_weight * w_input;
                end 
                // Stream enabled or disabled
                r_fwd <= (w_stream) ? w_fwd_in : r_fwd;
            end 
            
            // If write, keep internal signals unchanged.
            else begin
                r_fwd <= r_fwd;
            end
        
        // Reset state
        end else begin
            r_scratch <= {OUT_PE_SCRATCH_WIDTH{1'b0}};
            r_fwd <= {OUT_PE_FWD_WIDTH{1'b0}};
            r_pipeline <= {OUT_PE_SCRATCH_WIDTH{1'b0}};
        end
    end

    // Combinational assignments
    assign w_wgt_out = r_wgt;
    assign w_inp_out  = r_inp;

    // Z when not ready or read w/o stream. 
    assign w_out = (!w_ready || (w_rw && !w_stream)) ? 
        {OUT_PE_FWD_WIDTH{1'bz}} :
        // If stream, output fwd_in. Else (write w/o stream), output scratchpad.
        (w_stream) ? r_fwd : r_scratch; 
        
endmodule

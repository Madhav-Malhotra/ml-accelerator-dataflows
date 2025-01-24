module a5_controller (
  input logic grant, 
  output logic [3:0][3:0][7:0] pe_out,
  output logic [3:0][7:0] i_out,
  output logic [3:0][7:0] w_out,
  output logic [3:0][7:0] g_out,
  output logic req,
  input logic clk,
  input logic [8:0] n_in
  
);
  // for future improvements, need to store certain below values in regs to save power
  
  `define DEFAULT_VALUE 9'b0zzzzzzzz
  
`define WRITE_PE(value) \
    for (int i = 0; i < 4; i = i + 1) begin : ROW_LOOP \
        for (int j = 0; j < 4; j = j + 1) begin : COL_LOOP \
            pe_out[i][j] = value; \
        end \
    end

`define WRITE_W(value) \
    for (int j = 0; j < 4; j = j + 1) begin : COL_LOOP \
        w_out[j] = value; \
    end

`define WRITE_I(value) \
    for (int j = 0; j < 4; j = j + 1) begin : COL_LOOP \
        i_out[j] = value; \
    end

`define WRITE_G(value) \
    for (int j = 0; j < 4; j = j + 1) begin : COL_LOOP \
        g_out[j] = value; \
    end
  
  `define WRITE_I_W_ROW(l, value) \
  i_out[l] = value; \
  w_out[l] = value; 
  
  `define WRITE_L_DELAY_PE(l, value) \
      for (int i = 0; i < 4; i = i + 1) begin : ROW_LOOP \
        for (int j = 0; j < 4; j = j + 1) begin : COL_LOOP \
          if (i + j == l) begin \
            pe_out[i][j] = value; \
          end\
        end \
    end



  
  logic q[8:0] = 0;
  logic n[9:0] = 0;
  logic q_min_2;
  assign q_min_2 = q-2;
  
  logic q_min_n_min_1;
  assign q_min_n_min_1 = q - n - 1;
  
  always_ff @(posedge clk) begin
    if ((q == 0 || q == 'd137) && grant == 1) begin
      q <= 'b1;
    end else if (q == 'd142 && grant == 0) begin
      q <= 'b0;
    end else begin
      q <= q + 1;
    end
    
    if (q == 1) begin
      n <= n_in;
    end
  end
  
  always_comb begin
    if (q == 0 || q == 1) begin
      `WRITE_PE(`DEFAULT_VALUE)
      `WRITE_W(`DEFAULT_VALUE)
      `WRITE_I(`DEFAULT_VALUE)
      `WRITE_G(`DEFAULT_VALUE)
    end
    
    if (q >= 2 && q <= n + 1) begin
      `WRITE_PE(`DEFAULT_VALUE)
      `WRITE_W({1,1,q_min_2[7:0]})
      `WRITE_I({1,1,q_min_2[7:0]})
      `WRITE_G(`DEFAULT_VALUE)
    end
    
    if (q >= n+2) begin
      `WRITE_L_DELAY_PE(0, {1,1,8'b0})
      `WRITE_L_DELAY_PE(1, `DEFAULT_VALUE)
      `WRITE_L_DELAY_PE(2, `DEFAULT_VALUE)
      `WRITE_L_DELAY_PE(3, `DEFAULT_VALUE)
      `WRITE_L_DELAY_PE(4, `DEFAULT_VALUE)
      `WRITE_L_DELAY_PE(5, `DEFAULT_VALUE)
      `WRITE_L_DELAY_PE(6, `DEFAULT_VALUE)
      `WRITE_G(`DEFAULT_VALUE)
      `WRITE_I_W_ROW(0, {1,0,8'b0})
      `WRITE_I_W_ROW(1, `DEFAULT_VALUE)
      `WRITE_I_W_ROW(2, `DEFAULT_VALUE)
      `WRITE_I_W_ROW(3, `DEFAULT_VALUE)
    end
    
    if (q >= n+3) begin
      `WRITE_L_DELAY_PE(0, {1,1,8'b0})
      `WRITE_L_DELAY_PE(1, {1,1,8'b0})
      `WRITE_L_DELAY_PE(2, `DEFAULT_VALUE)
      `WRITE_L_DELAY_PE(3, `DEFAULT_VALUE)
      `WRITE_L_DELAY_PE(4, `DEFAULT_VALUE)
      `WRITE_L_DELAY_PE(5, `DEFAULT_VALUE)
      `WRITE_L_DELAY_PE(6, `DEFAULT_VALUE)
      `WRITE_G(`DEFAULT_VALUE)
      `WRITE_I_W_ROW(0, {1,0,8'b1})
      `WRITE_I_W_ROW(1, {1,0,8'b0})
      `WRITE_I_W_ROW(2, `DEFAULT_VALUE)
      `WRITE_I_W_ROW(3, `DEFAULT_VALUE)
      
    end
    
    if (q >= n+4) begin
      `WRITE_L_DELAY_PE(0, {1,1,8'b0})
      `WRITE_L_DELAY_PE(1, {1,1,8'b0})
      `WRITE_L_DELAY_PE(2, {1,1,8'b0})
      `WRITE_L_DELAY_PE(3, `DEFAULT_VALUE)
      `WRITE_L_DELAY_PE(4, `DEFAULT_VALUE)
      `WRITE_L_DELAY_PE(5, `DEFAULT_VALUE)
      `WRITE_L_DELAY_PE(6, `DEFAULT_VALUE)
      `WRITE_G(`DEFAULT_VALUE)
      `WRITE_I_W_ROW(0, {1,0,8'd2})
      `WRITE_I_W_ROW(1, {1,0,8'b1})
      `WRITE_I_W_ROW(2, {1,0,8'b0})
      `WRITE_I_W_ROW(`DEFAULT_VALUE)
      
    end
    
    if (q >= n+5) begin
      `WRITE_L_DELAY_PE(0, {1,1,8'b0})
      `WRITE_L_DELAY_PE(1, {1,1,8'b0})
      `WRITE_L_DELAY_PE(2, {1,1,8'b0})
      `WRITE_L_DELAY_PE(3, {1,1,8'b0})
      `WRITE_L_DELAY_PE(4, `DEFAULT_VALUE)
      `WRITE_L_DELAY_PE(5, `DEFAULT_VALUE)
      `WRITE_L_DELAY_PE(6, `DEFAULT_VALUE)
      `WRITE_G(`DEFAULT_VALUE)
      `WRITE_I_W_ROW(0, {1,0,8'd3})
      `WRITE_I_W_ROW(1, {1,0,8'd2})
      `WRITE_I_W_ROW(2, {1,0,8'd1})
      `WRITE_I_W_ROW(3, {1,0,8'b0})
      
    end
    
    if (q >= n+6) begin
      `WRITE_L_DELAY_PE(0, {1,1,8'b0})
      `WRITE_L_DELAY_PE(1, {1,1,8'b0})
      `WRITE_L_DELAY_PE(2, {1,1,8'b0})
      `WRITE_L_DELAY_PE(3, {1,1,8'b0})
      `WRITE_L_DELAY_PE(4, {1,1,8'b0})
      `WRITE_L_DELAY_PE(5, `DEFAULT_VALUE)
      `WRITE_L_DELAY_PE(6, `DEFAULT_VALUE)
      `WRITE_G(`DEFAULT_VALUE)
          `WRITE_I_W_ROW(0, {1,0,8'd4})
          `WRITE_I_W_ROW(1, {1,0,8'd3})
          `WRITE_I_W_ROW(2, {1,0,8'd3})
          `WRITE_I_W_ROW(3, {1,0,8'b1})
      
    end
    
    if (q >= n+7) begin
      `WRITE_L_DELAY_PE(0, {1,1,8'b0})
      `WRITE_L_DELAY_PE(1, {1,1,8'b0})
      `WRITE_L_DELAY_PE(2, {1,1,8'b0})
      `WRITE_L_DELAY_PE(3, {1,1,8'b0})
      `WRITE_L_DELAY_PE(4, {1,1,8'b0})
      `WRITE_L_DELAY_PE(5, {1,1,8'b0})
      `WRITE_L_DELAY_PE(6, `DEFAULT_VALUE)
      `WRITE_G(`DEFAULT_VALUE)
          `WRITE_I_W_ROW(0, {1,0,8'd5})
          `WRITE_I_W_ROW(1, {1,0,8'd4})
          `WRITE_I_W_ROW(2, {1,0,8'd3})
          `WRITE_I_W_ROW(3, {1,0,8'd2})
      
    end
    
    if (q >= n+8) begin
      `WRITE_L_DELAY_PE(0, {1,1,8'b0})
      `WRITE_L_DELAY_PE(1, {1,1,8'b0})
      `WRITE_L_DELAY_PE(2, {1,1,8'b0})
      `WRITE_L_DELAY_PE(3, {1,1,8'b0})
      `WRITE_L_DELAY_PE(4, {1,1,8'b0})
      `WRITE_L_DELAY_PE(5, {1,1,8'b0})
      `WRITE_L_DELAY_PE(6, {1,1,8'b0})
      `WRITE_G(`DEFAULT_VALUE)
          `WRITE_I_W_ROW(0, {1,0,8'd6})
          `WRITE_I_W_ROW(1, {1,0,8'd5})
          `WRITE_I_W_ROW(2, {1,0,8'd4})
          `WRITE_I_W_ROW(3, {1,0,8'd3})
      
    end
    
    if (q >= n+9 && q <= 2 * n) begin
      `WRITE_G(`DEFAULT_VALUE)
      `WRITE_PE({1,1,8'b0})
      `WRITE_I_W_ROW(0, {1,0,q_min_n_min_1[7:0]})
      `WRITE_I_W_ROW(1, {1,0,(q-n-2) & 8'hFF})
      `WRITE_I_W_ROW(2, {1,0,(q-n-3) & 8'hFF})
      `WRITE_I_W_ROW(3, {1,0,(q-n-4) & 8'hFF})
      
    end

    if (q >= 2*n + 8 && q <= 2 * n + 13) begin
      `WRITE_G(`DEFAULT_VALUE)
      `WRITE_PE({1,1,8'b0})
      `WRITE_I_W_ROW(0, {1,0,q_min_n_min_1[7:0]})
      `WRITE_I_W_ROW(1, {1,0,(q-n-2) & 8'hFF})
      `WRITE_I_W_ROW(2, {1,0,(q-n-3) & 8'hFF})
      `WRITE_I_W_ROW(3, {1,0,(q-n-4) & 8'hFF})
      
    end
  
    
			
  end
  
endmodule
  
  

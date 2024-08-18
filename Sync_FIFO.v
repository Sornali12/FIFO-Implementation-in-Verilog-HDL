//---------------------------------------------------Synchronous FIFO Design---------------------------------------------------------------------------------

module Synchronous_FIFO #(parameter DEPTH=16, DATA_WIDTH=8) (
  input clk, rst,
  input w_en, r_en,                        //write enable and read enable
  input [DATA_WIDTH-1:0] w_data,
  output reg [DATA_WIDTH-1:0] r_data,
  output full, empty                       //flags for indicating full and empty conditions
);
  
  parameter PTR_WIDTH = $clog2(DEPTH);
  reg [PTR_WIDTH:0] w_ptr, r_ptr;          //extra bit used in w_ptr and r_ptr to detect full/empty condition
  reg [DATA_WIDTH-1:0] FIFO[0:DEPTH-1];    
  
  //Default values when FIFO is reset
  always@(posedge clk) 
    begin
      if(rst) 
        begin
          w_ptr <= 0; r_ptr <= 0;
          r_data <= 0;
        end
    end
  
  //Write data to FIFO
  always@(posedge clk) 
    begin
      if(w_en & !full & !rst)
        begin
          FIFO[w_ptr[PTR_WIDTH-1:0]] <= w_data;
          w_ptr <= w_ptr + 1;
        end
    end
  
  //Read data from FIFO
  always@(posedge clk) 
    begin
      if(r_en & !empty & !rst) 
        begin
          r_data <= FIFO[r_ptr[PTR_WIDTH-1:0]];
          r_ptr <= r_ptr + 1;
        end
    end
  
  //Full condition: MSB of write and read pointers are different due to wrap around and remainimg bits are same.
  assign full = ({~w_ptr[PTR_WIDTH],w_ptr[PTR_WIDTH-1:0]}==r_ptr);
  
  //Empty condition: All bits of write and read pointers are same.
  assign empty = (w_ptr == r_ptr);
endmodule
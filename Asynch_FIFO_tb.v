//---------------------------------------------Test-Bench for Asynchronous FIFO--------------------------------------------------------------------------------------------------
`timescale 1ns/1ns
`include "Asynch_FIFO.v"

module async_fifo_tb;

  parameter DATA_WIDTH = 8;
  wire [DATA_WIDTH-1:0] data_out;
  wire full;
  wire empty;
  reg [DATA_WIDTH-1:0] data_in;
  reg w_en, w_clk, w_rst;
  reg r_en, r_clk, r_rst;

  Asynchronous_FIFO F11 (.w_clk(w_clk), .w_rst(w_rst), .r_clk(r_clk), .r_rst(r_rst), .w_en(w_en),
   .r_en(r_en), .w_data(data_in), .r_data(data_out), .full(full), .empty(empty));

  always #2 w_clk = ~w_clk;                  //Write clock - 250MHz
  always #8 r_clk = ~r_clk;                  //Read clock - 62.5MHz
  
  initial 
    begin
      w_clk <= 0; w_rst <= 1;
      r_clk <=0; r_rst <=1;
      w_en <= 0; r_en <= 0;
      #20 w_rst <= 0; r_rst <=0; 
      #2 w_en <= 1;
      #10 r_en <= 1;
    end

  
  always @(posedge w_clk)
    begin
      if(full)
        begin 
          $display("FIFO is full!! Cannot write data into FIFO");
        end
      else
        begin
           data_in <= $random;
           $display("Write to FIFO: w_en=%b, r_en=%b, data_in=%h",w_en, r_en,data_in);
        end
    end

  
  always @(posedge r_clk)
    begin
      if(empty)
        begin
          $display("FIFO Empty!! Can not read data_out");
        end
      else
      $display("Read from FIFO: w_en=%b, r_en=%b, data_out=%h",w_en, r_en, data_out);
    end
    
  
  initial 
    begin 
      $dumpfile("fifo.vcd"); 
      $dumpvars(0,async_fifo_tb);
      #200 $finish;
    end
endmodule
//-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
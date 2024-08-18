//---------------------------------------------------TestBench for Synchronous FIFO------------------------------------------------------------------
`timescale 1ns/1ns
`include "Sync_FIFO.v"
module sync_fifo_tb;
  reg clk, rst;
  reg w_en, r_en;
  reg [7:0] data_in;
  wire [7:0] data_out;
  wire full, empty;
  
  Synchronous_FIFO F1(.clk(clk), .rst(rst), .w_en(w_en), .r_en(r_en), .w_data(data_in), .r_data(data_out), .full(full), .empty(empty));
  
  always #2 clk = ~clk;
  initial 
    begin
      clk <= 0; rst <= 1;
      w_en <= 0; r_en <= 0;
      #20 rst <= 0;
      #3 w_en <= 1;
      #30 r_en <= 1;
      #10 w_en <=0;
      #40 w_en <= 1;
    end

  
  always @(posedge clk)
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

  
  always @(posedge clk)
    begin
      #21
      if(empty)
        begin
          $display("FIFO Empty!! Can not read data_out");
        end
      else
        begin
          $display("Read from FIFO: w_en=%b, r_en=%b, data_out=%h",w_en, r_en,data_out);
        end
    end
    
  
  initial 
    begin 
      $dumpfile("fifo.vcd"); 
      $dumpvars(0,sync_fifo_tb);
      #200 $finish;
    end
endmodule
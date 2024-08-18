//---------------------------------------------------------------Asynchronous FIFO Design---------------------------------------------------------------------------------
module Asynchronous_FIFO #(parameter DEPTH=16, DATA_WIDTH=8) (
  input w_clk, r_clk, w_rst, r_rst,               //Write and read clock domains are different in asynchronous FIFO 
  input w_en, r_en,                               //write enable and read enable
  input [DATA_WIDTH-1:0] w_data,                  //data coming from the transmitter that is to be written to the FIFO
  output reg [DATA_WIDTH-1:0] r_data,             //data that is read from the FIFO by the receiver
  output full, empty                              //flags for indicating full and empty conditions
);
  
  parameter PTR_WIDTH = $clog2(DEPTH);            //Address bits: log(base2) of FIFO depth
  wire [PTR_WIDTH:0] w_ptr, r_ptr, gw_ptr, gr_ptr, gr_ptr_s, gw_ptr_s;          //extra bit used in w_ptr and r_ptr to detect full/empty condition
  reg [DATA_WIDTH-1:0] FIFO[0:DEPTH-1];           //16 * 8 FIFO memory declaration

//Write data to FIFO
  always@(posedge w_clk)
    begin
      if(w_en & !full & !w_rst)                   //Write to FIFO can be done only when it is not full and write enable is 1
        begin
          FIFO[w_ptr[PTR_WIDTH-1:0]] <= w_data;
        end
    end
  
//Read data from FIFO
  always@(posedge r_clk) 
    begin
      if(r_en & !empty & !r_rst)                  //Read from FIFO can be done only if FIFO is not empty and read enable is 1 
        begin
          r_data <= FIFO[r_ptr[PTR_WIDTH-1:0]];
        end
      else r_data <= 0;
    end
  
//Synchronizing read pointer to write clock domain using 2-FF synchronizer
  read_ptr_sync s1 (.gr_ptr_s(gr_ptr_s), .gr_ptr(gr_ptr), .w_clk(w_clk), .w_rst(w_rst));
//Write pointer logic block - Evaluating full condition in write clock domain
  write_full w1 (.full(full), .bw_ptr(w_ptr), .gw_ptr(gw_ptr), .gr_ptr_s(gr_ptr_s), .w_en(w_en), .w_clk(w_clk), .w_rst(w_rst));


//Synchronizing write pointer to read clock domain using 2-FF synchronizer
  write_ptr_sync s2 (.gw_ptr_s(gw_ptr_s), .gw_ptr(gw_ptr), .r_clk(r_clk), .r_rst(r_rst));
//Read pointer logic block - Evaluating empty condition in read clock domain
  read_empty r1 (.empty(empty), .br_ptr(r_ptr), .gr_ptr(gr_ptr), .gw_ptr_s(gw_ptr_s), .r_en(r_en), .r_clk(r_clk), .r_rst(r_rst));

endmodule
//------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

//---------------------------------------------------------------------Sub-Modules------------------------------------------------------------------------------------------------------------------

//------------------------------------------------------------Read Pointer Synchronizer Module-----------------------------------------------------------------------------------------------
module read_ptr_sync #(parameter PTR_WIDTH = 4) (
  output reg [PTR_WIDTH:0] gr_ptr_s,               //Output - Synchronized gray read pointer
  input [PTR_WIDTH:0] gr_ptr,                      //Input - Gray read pointer from Read pointer logic block
  input w_clk, w_rst                               //Read pointer is synchronized to the write clock domain
);
  reg [PTR_WIDTH:0] wq1;
  always @(posedge w_clk or posedge w_rst)
    begin
      if (w_rst)
        begin
           gr_ptr_s <= 0;
           wq1 <= 0;
        end
      else 
        begin
           gr_ptr_s <= wq1;                        //2-FF synchronizer logic
           wq1 <= gr_ptr;      
        end
    end
endmodule
//---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

//------------------------------------------------------------Write Pointer Synchronizer Module---------------------------------------------------------------------------------
module write_ptr_sync #(parameter PTR_WIDTH = 4) (
  output reg [PTR_WIDTH:0] gw_ptr_s,               //Output - Synchronized gray write pointer
  input [PTR_WIDTH:0] gw_ptr,                      //Input - Gray write pointer from Write pointer logic block
  input r_clk, r_rst                               //Write pointer is synchronized to the read clock domain
);
  reg [PTR_WIDTH:0] rq1;
  always @(posedge r_clk or posedge r_rst)
    begin
      if (r_rst) 
        begin
           gw_ptr_s <= 0;
           rq1 <= 0;
        end
      else
        begin
            gw_ptr_s <= rq1;                       //2-FF synchronizer logic
            rq1 <= gw_ptr;
        end
    end
endmodule
//---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

//------------------------------------------------------------Read Pointer Logic Block----------------------------------------------------------------------------------------------------
module read_empty #(parameter PTR_WIDTH = 4) (
  output reg empty,                                        
  output reg [PTR_WIDTH:0] br_ptr,                 //Output - Binary read pointer which points to the next location to be read
  output reg [PTR_WIDTH:0] gr_ptr,                 //Output - Gray read pointer that needs to be synchronized to the write domain
  input [PTR_WIDTH :0] gw_ptr_s,                   //Input - Synchronized gray write pointer
  input r_en, r_clk, r_rst
);
  wire [PTR_WIDTH:0] gr_ptr_nxt, br_ptr_nxt;       //To capture the next value of the read pointer

  always @(posedge r_clk or posedge r_rst)
    begin
      if (r_rst) {br_ptr, gr_ptr} <= 10'd0; 
      else {br_ptr, gr_ptr} <= {br_ptr_nxt, gr_ptr_nxt};      //Updating read pointer values
    end

  assign br_ptr_nxt = br_ptr + (r_en & ~empty);               //Incrementing read pointer if read enable is 1 and FIFO not empty
  assign gr_ptr_nxt = (br_ptr_nxt>>1) ^ br_ptr_nxt;           //Converting binary read pointer to gray to compare with input gray write pointer 
                                                              //to evaluate empty condition.

 // FIFO is empty when the next gray read pointer value = synchronized gray write pointer value or on reset
  assign empty_val = (gr_ptr_nxt == gw_ptr_s);
  always @(posedge r_clk or posedge r_rst)
    begin
      if (r_rst) empty <= 1'b1;
      else empty <= empty_val;                                //Updating empty flag
    end
endmodule
//-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

//------------------------------------------------------------Write Pointer Logic Block-----------------------------------------------------------------------------------------------------
module write_full #(parameter PTR_WIDTH = 4) (
  output reg full,
  output reg [PTR_WIDTH:0] bw_ptr,                 //Output - Binary write pointer which points to the location to be written
  output reg [PTR_WIDTH :0] gw_ptr,                //Output - Gray write pointer that needs to be synchronized to the read domain
  input [PTR_WIDTH :0] gr_ptr_s,                   //Input - Synchronized gray read pointer
  input w_en, w_clk, w_rst
);
  wire [PTR_WIDTH:0] gw_ptr_nxt, bw_ptr_nxt;       //To capture the next value of the write pointer
  wire full_val;
 
  always @(posedge w_clk or posedge w_rst)
    begin
      if (w_rst) {bw_ptr, gw_ptr} <= 10'd0;
      else {bw_ptr, gw_ptr} <= {bw_ptr_nxt, gw_ptr_nxt};      //Updating write pointer values
    end
 
  assign bw_ptr_nxt = bw_ptr + (w_en & ~full);                //Incrementing write pointer if write enable is 1 and FIFO not full
  assign gw_ptr_nxt = (bw_ptr_nxt>>1) ^ bw_ptr_nxt;           //Converting binary write pointer to gray to compare with input gray read pointer 
                                                              //to evaluate full condition.
 
 // FIFO will be full when:
 // MSB's and 2nd MSB's of both the gray read and write pointers are different and
 // All other bits of the gray read and write pointers are equal
  assign full_val = (gw_ptr_nxt == {~gr_ptr_s[PTR_WIDTH:PTR_WIDTH-1], gr_ptr_s[PTR_WIDTH-2:0]});
  always @(posedge w_clk or posedge w_rst)
    begin
      if (w_rst) full <= 1'b0;
      else full <= full_val;                                  //Updating empty flag
    end
endmodule
//--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
`timescale 1ns / 1ps

module test_minimal();
   reg clk;
   reg rst_n;
   
   always #5 clk = ~clk;
   
   initial begin
      clk = 0;
      rst_n = 0;
      #100 $finish;
   end
endmodule

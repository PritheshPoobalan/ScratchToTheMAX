`timescale 1ns / 1ps

module test_simple();
   reg clk;
   reg rst_n;
   reg [23:0] addr = 24'h0;
   reg [31:0] wdata = 32'hDEADBEEF;
   wire [31:0] rdata;
   wire mem_valid, mem_ready;

   memory_controller u_mem (
      .clk(clk), .rst_n(rst_n),
      .cpu_addr(addr), .cpu_write_data(wdata),
      .cpu_read_data(rdata), .cpu_mem_valid(mem_valid),
      .cpu_mem_ready(mem_ready),
      .external_addr(),
      .external_data(),
      .external_oe_n(),
      .external_we_n(),
      .external_ce_n()
   );

   always #5 clk = ~clk;

   initial begin
      clk = 0;
      rst_n = 0;
      #20 rst_n = 1;
      mem_valid = 1;
      #20 mem_valid = 0;
      #50 $finish;
   end
endmodule

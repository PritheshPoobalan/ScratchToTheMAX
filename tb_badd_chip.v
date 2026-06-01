`timescale 1ns / 1ps

module tb_badd_chip();
   reg clk;
   reg rst_n;
   wire [21:0] addr;
   wire [31:0] data;
   wire oe_n, we_n, ce_n;
   wire [63:0] pup_challenge;
   wire [63:0] pup_response;
   wire [7:0] leds;
   wire uart_tx;

   // Instantiate top-level badd_chip
   badd_chip u_dut (
      .clk(clk),
      .rst_n(rst_n),
      .addr(addr),
      .data(data),
      .oe_n(oe_n),
      .we_n(we_n),
      .ce_n(ce_n),
      .puf_challenge_out(pup_challenge),
      .puf_response_in(pup_response),
      .leds(leds),
      .uart_tx(uart_tx),
      .uart_rx(1'b1)
   );

   always #5 clk = ~clk;

   initial begin
      clk = 0;
      rst_n = 0;
      #20 rst_n = 1;
      #100 $finish;
   end
endmodule
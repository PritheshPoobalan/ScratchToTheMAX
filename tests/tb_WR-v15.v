// Testbench for WR decode path, revision 15
`timescale 1ns / 1ps
module tb_WR_v15;
  reg [4:0] word;
  wire [1:0] kind;
  wire [2:0] code;
  wire is_delim;
  johnsan_decode uut (.word(word), .kind(kind), .code(code), .is_delim(is_delim));
  initial begin
    word = 5'b0;
    #10 $finish;
  end
endmodule

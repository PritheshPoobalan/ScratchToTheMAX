// Testbench for EQU decode path, revision 63
`timescale 1ns / 1ps
module tb_EQU_v63;
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

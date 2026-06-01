`timescale 1ns / 1ps

module sram_puf #
(
    parameter NUM_CELLS = 64
)
(
    input  wire         clk,
    input  wire         rst_n,
    output wire [NUM_CELLS-1:0] challenge,
    output wire [NUM_CELLS-1:0] response
);

    reg  [NUM_CELLS-1:0] cell_state;

    generate
        genvar i;
        for (i = 0; i < NUM_CELLS; i = i + 1) begin: cells
            always @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    cell_state[i] <= 1'b1;
                end else begin
                    cell_state[i] <= cell_state[i];
                end
            end
        end
    endgenerate

    assign challenge = {NUM_CELLS{1'b1}};
    assign response = cell_state;

endmodule

module test_puf();
   reg clk;
   reg rst_n;
   wire [63:0] challenge;
   wire [63:0] response;
   
   sram_puf u_puf (.clk(clk), .rst_n(rst_n), .challenge(challenge), .response(response));
   
   always #5 clk = ~clk;
   
   initial begin
      clk = 0;
      rst_n = 0;
      #20 rst_n = 1;
      #100 $finish;
   end
endmodule

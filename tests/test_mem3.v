`timescale 1ns / 1ps

module memory_controller (
    input  wire              clk,
    input  wire              rst_n,
    input  wire [23:0]       cpu_addr,
    input  wire [31:0]       cpu_write_data,
    output wire [31:0]       cpu_read_data,
    input  wire              cpu_mem_valid,
    output wire              cpu_mem_ready,
    output wire [23:0]       external_addr,
    output wire [31:0]       external_data,  // changed from inout
    output wire              external_oe_n,
    output wire              external_we_n,
    output wire              external_ce_n
);
    reg  [31:0] mem [0:8191];
    assign cpu_read_data = mem[cpu_addr[18:5]];
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            integer k;
            for (k = 0; k < 8192; k = k + 1) begin
                mem[k] <= 32'h0;
            end
        end else begin
            if (cpu_mem_valid && !cpu_mem_ready) begin
                mem[cpu_addr[18:5]] <= cpu_write_data;
            end
        end
    end
    assign external_addr = cpu_addr;
    assign external_data = cpu_write_data;  // just output
    assign external_oe_n = (~cpu_mem_valid) | 1'b1;
    assign external_we_n = cpu_mem_valid & (~1'b1);
    assign external_ce_n = 1'b0;
    assign cpu_mem_ready = 1'b1;
endmodule

module test_mem();
   reg clk;
   reg rst_n;
   reg [23:0] cpu_addr = 24'h0;
   reg [31:0] cpu_write_data = 32'hDEADBEEF;
   wire [31:0] cpu_read_data;
   wire cpu_mem_valid, cpu_mem_ready;
   wire [23:0] external_addr;
   wire [31:0] external_data;
   wire external_oe_n, external_we_n, external_ce_n;
   
   memory_controller u_mem (
      .clk(clk), .rst_n(rst_n),
      .cpu_addr(cpu_addr), .cpu_write_data(cpu_write_data),
      .cpu_read_data(cpu_read_data), .cpu_mem_valid(cpu_mem_valid),
      .cpu_mem_ready(cpu_mem_ready),
      .external_addr(external_addr), .external_data(external_data),
      .external_oe_n(external_oe_n), .external_we_n(external_we_n),
      .external_ce_n(external_ce_n)
   );
   
   always #5 clk = ~clk;
   
   initial begin
      clk = 0;
      rst_n = 0;
      #20 rst_n = 1;
      cpu_mem_valid = 1;
      #20 cpu_mem_valid = 0;
      #50 $finish;
   end
endmodule

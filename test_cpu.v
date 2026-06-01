`timescale 1ns / 1ps

module badd_cpu #
(
    parameter XLEN = 32
)
(
    input  wire         clk,
    input  wire         rst_n,
    output reg  [XLEN-1:0] addr,
    output reg  [XLEN-1:0] write_data,
    input  wire [XLEN-1:0] read_data,
    input  wire          mem_valid,
    output wire          mem_ready,
    output reg  [3:0]    alu_op,
    output reg           reg_write,
    output reg  [4:0]    write_reg,
    output reg  [XLEN-1:0] write_data_in
);

    reg  [XLEN-1:0] regs [0:31];
    integer i;
    reg  [XLEN-1:0] pc;
    wire [XLEN-1:0] pc_next;
    reg  [XLEN-1:0] instr_mem [0:1023];
    wire [31:0] instr = instr_mem[pc[XLEN-1:2]];
    wire [6:0]  opcode = instr[6:0];
    wire [4:0]  rd     = instr[11:7];
    wire [4:0]  rs1    = instr[19:15];
    wire [4:0]  rs2    = instr[24:20];
    wire [6:0]  func3  = instr[14:12];
    wire [6:0]  func7  = instr[31:25];
    wire [XLEN-1:0] src1 = (rs1 == 5'b0) ? {XLEN{1'b0}} : regs[rs1];
    wire [XLEN-1:0] src2 = (rs2 == 5'b0) ? {XLEN{1'b0}} : regs[rs2];
    reg [XLEN-1:0] alu_result;
    
    always @(*) begin
        case ({func7[5], func3})
            4'b0_000: alu_result = src1 + src2;
            4'b1_000: alu_result = src1 - src2;
            4'b0_111: alu_result = src1 & src2;
            4'b0_110: alu_result = src1 | src2;
            4'b0_100: alu_result = src1 ^ src2;
            4'b0_001: alu_result = src1 << src2[4:0];
            4'b0_101: alu_result = src1 >> src2[4:0];
            4'b0_010: alu_result = (src1 < src2) ? 1 : 0;
            4'b0_011: alu_result = (src1 < src2) ? 1 : 0;
            default:  alu_result = src1 + src2;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 32; i = i + 1) begin
                regs[i] <= {XLEN{1'b0}};
            end
            pc <= 32'h0;
        end else begin
            if (reg_write && (write_reg != 5'b0)) begin
                regs[write_reg] <= write_data_in;
            end
            pc <= pc_next;
        end
    end

    assign pc_next = pc + 4;
    assign mem_ready = 1'b1;
    always @(*) begin
        addr     = pc;
        write_data = alu_result;
        alu_op   = 4'b0000;
        reg_write = 1'b1;
        write_reg = rd;
        write_data_in = alu_result;
    end
endmodule

module test_cpu();
   reg clk;
   reg rst_n;
   wire [31:0] addr, write_data;
   wire [3:0] alu_op;
   wire reg_write;
   wire [4:0] write_reg;
   wire [31:0] write_data_in;
   wire mem_valid, mem_ready;
   reg [31:0] read_data = 32'h0;
   
   badd_cpu u_cpu (
      .clk(clk), .rst_n(rst_n),
      .addr(addr), .write_data(write_data),
      .read_data(read_data), .mem_valid(mem_valid),
      .mem_ready(mem_ready), .alu_op(alu_op),
      .reg_write(reg_write), .write_reg(write_reg),
      .write_data_in(write_data_in)
   );
   
   always #5 clk = ~clk;
   
   initial begin
      clk = 0;
      rst_n = 0;
      #20 rst_n = 1;
      #100 $finish;
   end
endmodule

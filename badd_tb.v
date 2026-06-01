`timescale 1ns / 1ps

// ================================================================
// BADD Chip Testbench — Simple program loader and runner
// Loads a tiny RUN ISA program into memory and lets the CPU execute
// ================================================================
module badd_tb;

    reg         clk;
    reg         rst_n;

    // Memory interface
    wire [21:0]  addr;
    wire [31:0]  data;
    wire         oe_n;
    wire         we_n;
    wire         ce_n;

    // PUF interface
    wire [63:0]  puf_challenge;
    wire [63:0]  puf_response;

    // LEDs and UART
    wire [7:0]   leds;
    wire         uart_tx;
    wire         uart_rx;

    // Instantiate the chip
    badd_chip uut (
        .clk             (clk),
        .rst_n           (rst_n),
        .addr            (addr),
        .data            (data),
        .oe_n            (oe_n),
        .we_n            (we_n),
        .ce_n            (ce_n),
        .puf_challenge_out (puf_challenge),
        .puf_response_in   (puf_response),
        .leds            (leds),
        .uart_tx         (uart_tx),
        .uart_rx         (uart_rx)
    );

    // Simple SRAM model
    reg [31:0] mem [0:1023];

    // Drive the data bus when reading (oe_n low, we_n high = output enabled, not writing)
    assign data = (~oe_n &&  we_n) ? mem[addr] : 32'bz;

    // Write to memory when we_n is low
    always @(posedge clk) begin
        if (~we_n && ~ce_n) begin
            mem[addr] <= data;
        end
    end

    // PUF response: deterministic pattern based on challenge
    assign puf_response = 64'hA5A5_5A5A_A5A5_5A5A;

    // Clock generation: 100 MHz (10 ns period)
    initial clk = 0;
    always #5 clk = ~clk;

    // Test program: simple RUN ISA program
    // addr 0:  ADDI x1, x0, 10      (x1 = 10)
    // addr 1:  ADDI x2, x0, 20      (x2 = 20)
    // addr 2:  ADD  x3, x1, x2      (x3 = 30)
    // addr 3:  ADDI x4, x3, 5       (x4 = 35)
    // addr 4:  JAL  x5, 8           (jump to end)
    // addr 5-7: NOP padding
    // addr 8:  ADDI x6, x0, 99      (x6 = 99, end marker)
    // addr 9:  JAL  x0, 8           (infinite loop at end)
    initial begin
        mem[0]  = 32'h00A0008B; // ADDI x1, x0, 10  (opcode=0010011, rs1=0, func3=000, rd=1, imm=10)
        mem[1]  = 32'h0140010B; // ADDI x2, x0, 20
        mem[2]  = 32'h002081B3; // ADD  x3, x1, x2  (opcode=0110011, func3=000, func7=0000000)
        mem[3]  = 32'h0051808B; // ADDI x4, x3, 5
        mem[4]  = 32'h008000EF; // JAL  x5, 8       (opcode=1101111, rd=5, imm=8)
        mem[5]  = 32'h00000013; // ADDI x0, x0, 0   (NOP)
        mem[6]  = 32'h00000013; // ADDI x0, x0, 0   (NOP)
        mem[7]  = 32'h00000013; // ADDI x0, x0, 0   (NOP)
        mem[8]  = 32'h0630008B; // ADDI x6, x0, 99
        mem[9]  = 32'hFFCFF0EF; // JAL  x0, -4      (loop forever)
        mem[10] = 32'h00000013; // NOP
    end

    // Reset and run
    initial begin
        rst_n = 0;
        #20 rst_n = 1;
        #2000 $finish;
    end

    // Monitor PC and key registers
    always @(posedge clk) begin
        if (rst_n) begin
            $display("t=%0t pc=%h data=%h", $time, addr, data);
        end
    end

endmodule
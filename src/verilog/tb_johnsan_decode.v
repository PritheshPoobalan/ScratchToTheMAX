`timescale 1ns / 1ps
`default_nettype none

// ============================================================================
// tb_johnsan_decode — self-checking testbench for the BADD 5-bit decoder
//
// 1. Sweeps representative words and prints kind/code/is_delim.
// 2. Checks the official direct opcodes, a number, a letter, the prefix,
//    and the extended opcode helper.  Prints PASS/FAIL and a final summary.
// ============================================================================

module tb_johnsan_decode;

    reg  [4:0] word;
    wire [1:0] kind;
    wire [2:0] code;
    wire       is_delim;

    // Extended-decode wrapper
    reg        ext_valid;
    wire [1:0] x_kind;
    wire [2:0] x_code;
    wire       x_delim;
    wire [2:0] ext_op;
    wire       ext_hit;
    wire       is_prefix;

    integer pass_count;
    integer fail_count;
    integer i;

    reg [4:0] sweep_word [0:12];
    reg [8*12-1:0] sweep_name [0:12];

    johnsan_decode dut (
        .word     (word),
        .kind     (kind),
        .code     (code),
        .is_delim (is_delim)
    );

    johnsan_decode_ext xdut (
        .word      (word),
        .ext_valid (ext_valid),
        .kind      (x_kind),
        .code      (x_code),
        .is_delim  (x_delim),
        .ext_op    (ext_op),
        .ext_hit   (ext_hit),
        .is_prefix (is_prefix)
    );

    // ----------------------------------------------------------------
    // Base-word self-check task
    // ----------------------------------------------------------------
    task automatic check_word(
        input [4:0]       w,
        input [1:0]       exp_kind,
        input [2:0]       exp_code,
        input             exp_delim,
        input [8*12-1:0]  name
    );
        begin
            word = w;
            #1;
            if ((kind === exp_kind) && (code === exp_code) &&
                (is_delim === exp_delim)) begin
                $display("PASS  %0s  word=%b  kind=%0d code=%0d delim=%b",
                         name, w, kind, code, is_delim);
                pass_count = pass_count + 1;
            end else begin
                $display("FAIL  %0s  word=%b  got kind=%0d code=%0d delim=%b  expected kind=%0d code=%0d delim=%b",
                         name, w, kind, code, is_delim,
                         exp_kind, exp_code, exp_delim);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // ----------------------------------------------------------------
    // Extended-token self-check task (exercises johnsan_decode_ext)
    // ----------------------------------------------------------------
    task automatic check_ext(
        input [4:0]       w,
        input             valid,
        input [2:0]       exp_ext,
        input             exp_hit,
        input [8*12-1:0]  name
    );
        begin
            word      = w;
            ext_valid = valid;
            #1;
            if ((ext_op === exp_ext) && (ext_hit === exp_hit) &&
                (x_kind === 2'd3)) begin
                $display("PASS  %0s  word=%b  ext_valid=%b  ext_op=%0d hit=%b kind=%0d",
                         name, w, valid, ext_op, ext_hit, x_kind);
                pass_count = pass_count + 1;
            end else begin
                $display("FAIL  %0s  word=%b  ext_valid=%b  got ext_op=%0d hit=%b kind=%0d  expected ext_op=%0d hit=%b kind=3",
                         name, w, valid, ext_op, ext_hit, x_kind, exp_ext, exp_hit);
                fail_count = fail_count + 1;
            end
            ext_valid = 1'b0;
        end
    endtask

    initial begin
        pass_count = 0;
        fail_count = 0;
        ext_valid  = 1'b0;
        word       = 5'd0;

        // Representative sweep ------------------------------------------------
        sweep_word[0]  = 5'b11000; sweep_name[0]  = "STRT";
        sweep_word[1]  = 5'b11001; sweep_name[1]  = "AD";
        sweep_word[2]  = 5'b11010; sweep_name[2]  = "TI";
        sweep_word[3]  = 5'b11011; sweep_name[3]  = "PR";
        sweep_word[4]  = 5'b11100; sweep_name[4]  = "VAR";
        sweep_word[5]  = 5'b11101; sweep_name[5]  = "%";
        sweep_word[6]  = 5'b11110; sweep_name[6]  = "$";
        sweep_word[7]  = 5'b11111; sweep_name[7]  = "|";
        sweep_word[8]  = 5'b10101; sweep_name[8]  = "num 5";
        sweep_word[9]  = 5'b10111; sweep_name[9]  = "num 7";
        sweep_word[10] = 5'b01000; sweep_name[10] = "var a";
        sweep_word[11] = 5'b01111; sweep_name[11] = "var h";
        sweep_word[12] = 5'b00000; sweep_name[12] = "ext prefix";

        $display("=============================================================");
        $display(" BADD 5-bit Johnsan / ThinkerBinary decoder sweep");
        $display(" kind: 0=number 1=letter 2=direct-syntax 3=extended");
        $display("=============================================================");
        $display(" word   name         kind code delim");
        for (i = 0; i < 13; i = i + 1) begin
            word = sweep_word[i];
            #1;
            $display(" %b   %0s   %0d    %0d    %b",
                     sweep_word[i], sweep_name[i], kind, code, is_delim);
        end

        // Base checks ---------------------------------------------------------
        $display("-------------------------------------------------------------");
        $display(" Base-word checks");
        $display("-------------------------------------------------------------");
        check_word(5'b11000, 2'd2, 3'd0, 1'b0, "STRT");
        check_word(5'b11001, 2'd2, 3'd1, 1'b0, "AD");
        check_word(5'b11010, 2'd2, 3'd2, 1'b0, "TI");
        check_word(5'b11011, 2'd2, 3'd3, 1'b0, "PR");
        check_word(5'b11100, 2'd2, 3'd4, 1'b0, "VAR");
        check_word(5'b11101, 2'd2, 3'd5, 1'b0, "%");
        check_word(5'b11110, 2'd2, 3'd6, 1'b0, "$");
        check_word(5'b11111, 2'd2, 3'd7, 1'b1, "|");
        check_word(5'b10101, 2'd0, 3'd5, 1'b0, "num 5");
        check_word(5'b10000, 2'd0, 3'd0, 1'b0, "num 0");
        check_word(5'b01000, 2'd1, 3'd0, 1'b0, "var a");
        check_word(5'b01111, 2'd1, 3'd7, 1'b0, "var h");
        check_word(5'b00000, 2'd3, 3'd0, 1'b0, "ext prefix");

        // Extended-opcode checks ----------------------------------------------
        $display("-------------------------------------------------------------");
        $display(" Extended-opcode checks (prefix 00000 then payload word)");
        $display("-------------------------------------------------------------");
        check_ext(5'b00001, 1'b1, 3'd1, 1'b1, "END");
        check_ext(5'b00010, 1'b1, 3'd2, 1'b1, "MN");
        check_ext(5'b00011, 1'b1, 3'd3, 1'b1, "DV");
        check_ext(5'b00100, 1'b1, 3'd4, 1'b1, "EQU");
        check_ext(5'b00101, 1'b1, 3'd5, 1'b1, "IF");
        check_ext(5'b00110, 1'b1, 3'd6, 1'b1, "THEN");
        check_ext(5'b00111, 1'b1, 3'd7, 1'b1, "GOTO");

        // A bare 00000 is a prefix; the escaped 00000 is not.
        word      = 5'b00000;
        ext_valid = 1'b0;
        #1;
        if (is_prefix === 1'b1) begin
            $display("PASS  bare 00000 flagged as prefix");
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL  bare 00000 not flagged as prefix (is_prefix=%b)", is_prefix);
            fail_count = fail_count + 1;
        end

        word      = 5'b00000;
        ext_valid = 1'b1;
        #1;
        if ((is_prefix === 1'b0) && (ext_op === 3'd0)) begin
            $display("PASS  escaped 00000 resolves to ext_op=0, not a new prefix");
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL  escaped 00000: is_prefix=%b ext_op=%0d", is_prefix, ext_op);
            fail_count = fail_count + 1;
        end
        ext_valid = 1'b0;

        // Summary -------------------------------------------------------------
        $display("=============================================================");
        $display(" RESULT: %0d passed, %0d failed", pass_count, fail_count);
        $display("=============================================================");
        if (fail_count != 0)
            $fatal(1, "johnsan_decode testbench FAILED");
        $finish;
    end

endmodule

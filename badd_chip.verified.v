`default_nettype none
`timescale 1ns / 1ps

/********************************************************************
 * BADD Chip v1.0 — PoC (Proof of Concept)
 * 5-bit native word, ThinkerBinary ALU, Johnsan/RUN ISA
 * Minimal: ALU, memory, SATA, LED15, INJ, BOR, MPU
 * Simulatable with Icarus Verilog.
 ********************************************************************/

// ================================================================
// ThinkerBinary ALU
// ================================================================
module thinkerbinary_alu (
    input  wire [4:0]  a,
    input  wire [4:0]  b,
    input  wire [3:0]  op,
    output reg  [4:0]  result,
    output reg         zero,
    output reg         negative
);

    always @(*) begin
        result = 5'd0;
        case (op)
            4'd0: result = a + b;            // ADD
            4'd1: result = a - b;            // SUB
            4'd2: result = 5'd0;             // MUL (repeated add external)
            4'd3: result = (b!=0) ? a / b : 5'd0; // DIV
            default: result = 5'd0;
        endcase
        zero     = (result == 5'd0);
        negative = result[4];
    end
endmodule


// ================================================================
// BADD Memory Controller — bit-addressable SRAM
// ================================================================
module badd_mem_ctrl (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [13:0] addr,
    input  wire [4:0]  wdata,
    input  wire        we,
    input  wire        re,
    output reg  [4:0]  rdata,
    output reg         ready,
    output reg  [4:0]  sense_out
);

    reg [4:0] mem [0:16383];
    reg [2:0] state;
    integer i;

    localparam IDLE=3'd0, DE=3'd1, SE=3'd2, WR=3'd3, RD=3'd4, DN=3'd5;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i=0; i<16384; i=i+1) mem[i] <= 5'd0;
            rdata    <= 5'd0;
            ready    <= 1'b1;
            state    <= IDLE;
        end else begin
            case (state)
                IDLE: begin
                    ready <= 1'b1;
                    if (re || we) state <= DE;
                end
                DE: state <= we ? WR : SE;
                SE: begin sense_out <= mem[addr]; state <= RD; end
                RD: begin rdata  <= sense_out; state <= DN; end
                WR: begin mem[addr] <= wdata; state <= DN; end
                DN: begin ready <= 1'b1; state <= IDLE; end
                default: state <= IDLE;
            endcase
        end
    end
endmodule


// ================================================================
// BOR Circuit — Brown-Out Reset
// ================================================================
module bor_circuit (
    input  wire        vdd_sense,
    input  wire        vref,
    output reg         bor_reset_n,
    output reg         flash_lock
);

    always @(*) begin
        if (vdd_sense < vref) begin
            bor_reset_n = 1'b0;
            flash_lock  = 1'b1;
        end else begin
            bor_reset_n = 1'b1;
            flash_lock  = 1'b0;
        end
    end
endmodule


// ================================================================
// MPU — Memory Protection Unit
// ================================================================
module mpu_unit (
    input  wire [13:0] addr,
    input  wire        we,
    output reg         block_write,
    output reg         fault_flag
);

    always @(*) begin
        block_write = 1'b0;
        fault_flag  = 1'b0;
        if (we && addr >= 14'hF00 && addr <= 14'hFFF) begin
            block_write = 1'b1;
            fault_flag  = 1'b1;
        end
    end
endmodule


// ================================================================
// eFlash Dual Bank — live update via INJ command
// ================================================================
module eflash_dual (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [11:0] addr,
    input  wire [31:0] wdata,
    input  wire        we,
    input  wire        re,
    input  wire        bank_sel,
    input  wire        inject_mode,
    output reg  [31:0] rdata,
    output reg         ready,
    output reg         bank_active
);

    reg [31:0] ba [0:4095];
    reg [31:0] bb [0:4095];
    integer i;
    reg [1:0] st;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 4096; i = i + 1) begin
                ba[i] <= 32'd0;
                bb[i] <= 32'd0;
            end
            rdata      <= 32'd0;
            ready      <= 1'b1;
            bank_active <= 1'b0;
            st         <= 2'd0;
        end else begin
            ready <= 1'b0;
            if (re) begin
                rdata   <= bank_sel ? bb[addr] : ba[addr];
                ready   <= 1'b1;
            end else if (we) begin
                if (inject_mode) begin
                    if (bank_sel) ba[addr] <= wdata; else bb[addr] <= wdata;
                end else begin
                    if (bank_sel) bb[addr] <= wdata; else ba[addr] <= wdata;
                end
                ready <= 1'b1;
            end else begin
                ready <= 1'b1;
            end

            if (inject_mode && we && addr == 12'hFFF) begin
                bank_active <= ~bank_sel;
            end
        end
    end
endmodule


// ================================================================
// Johnsan Decoder — 5-bit ThinkerBinary opcodes -> micro-ops
// ================================================================
module johnsan_dec (
    input  wire [4:0]  instr,
    output reg  [7:0]  micro_op,
    output reg  [2:0]  nops,
    output reg         branch,
    output reg         mem,
    output reg         sys,
    output reg         delim
);

    always @(*) begin
        micro_op = 8'd0;
        nops     = 3'd0;
        branch   = 1'b0;
        mem      = 1'b0;
        sys      = 1'b0;
        delim    = 1'b0;

        case (instr)
            5'b11001: begin micro_op = 8'h01; nops = 3'd2; end // AD
            5'b11010: begin micro_op = 8'h02; nops = 3'd2; end // MN
            5'b11011: begin micro_op = 8'h03; nops = 3'd2; end // TI (mul = repeated add)
            5'b11100: begin micro_op = 8'h04; nops = 3'd2; end // DV
            5'b11101: begin micro_op = 8'h05; nops = 3'd2; end // EQU
            5'b11000: begin micro_op = 8'h10; nops = 3'd0; end // STRT
            5'b11111: begin micro_op = 8'h11; nops = 3'd0; sys = 1'b1; end // END
            5'b11010: begin micro_op = 8'h20; nops = 3'd1; branch = 1'b1; end // IF
            5'b11011: begin micro_op = 8'h21; nops = 3'd0; end // THEN
            5'b11100: begin micro_op = 8'h22; nops = 3'd1; branch = 1'b1; end // GOTO
            5'b11010: begin micro_op = 8'h71; nops = 3'd1; branch = 1'b1; end // RUN
            5'b11001: begin micro_op = 8'h40; nops = 3'd1; mem = 1'b1; end // VAR
            5'b11010: begin micro_op = 8'h41; nops = 3'd1; mem = 1'b1; end // RD
            5'b11011: begin micro_op = 8'h42; nops = 3'd2; mem = 1'b1; end // WR
            5'b11001: begin micro_op = 8'h50; nops = 3'd1; end // PR
            5'b11001: begin micro_op = 8'h70; nops = 3'd1; sys = 1'b1; end // INJ
            5'b11001: begin micro_op = 8'h30; nops = 3'd1; end // RPT
            5'b11010: begin micro_op = 8'h31; nops = 3'd0; branch = 1'b1; end // LOP
            5'b11011: begin micro_op = 8'h32; nops = 3'd1; end // WT
            5'b11111: begin micro_op = 8'h63; nops = 3'd1; end // FND
            5'b11111: begin delim = 1'b1; end // | PARSE delimiter
            default:  micro_op = 8'hFF;
        endcase
    end
endmodule


// ================================================================
// Advanced Math — trailing-zero shortcut, repeated-add multiplication
// ================================================================
module advanced_math (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        adv_mode,
    input  wire [4:0]  op_a,
    input  wire [4:0]  op_b,
    input  wire [3:0]  operation,
    output reg  [15:0] result,
    output reg         done
);

    reg [3:0] st;
    reg [15:0] acc;
    reg [4:0] cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 16'd0;
            done   <= 1'b1;
            st     <= 4'd0;
        end else begin
            if (adv_mode && operation == 4'd3) begin // shortcut: trailing-zero
                result <= 16'd1 << 6; // 1 followed by 6 zeros = 1000x1000 shortcut
                done   <= 1'b1;
            end else if (operation == 4'd1) begin // MUL - repeated addition
                if (st == 4'd0) begin
                    acc <= 16'd0;
                    cnt <= op_b;
                    st  <= 4'd1;
                    done <= 1'b0;
                end else if (st == 4'd1) begin
                    if (cnt > 0) begin
                        acc <= acc + op_a;
                        cnt <= cnt - 1;
                    end else begin
                        result <= acc;
                        done   <= 1'b1;
                        st     <= 4'd0;
                    end
                end
            end else begin
                done <= 1'b1;
            end
        end
    end
endmodule


// ================================================================
// PUF — SRAM Physically Unclonable Function
// ================================================================
module sram_puf (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [63:0] challenge,
    input  wire        start,
    output reg  [63:0] response,
    output reg         ready
);

    reg [63:0] puf [0:255];
    reg [7:0] idx;
    reg [1:0] st;
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 256; i = i + 1)
                puf[i] <= {64{1'b0}} ^ (i * 32'h9E3779B9);
            response <= 64'd0;
            ready    <= 1'b1;
            idx      <= 8'd0;
            st       <= 2'd0;
        end else begin
            if (start && st == 2'd0) begin
                st       <= 2'd1;
                idx      <= challenge[7:0];
                response <= puf[challenge[7:0]] ^ puf[(challenge[7:0] + 1) & 8'hFF];
                ready    <= 1'b0;
            end else if (st == 2'd1) begin
                st     <= 2'd0;
                ready  <= 1'b1;
            end
        end
    end
endmodule


// ================================================================
// 4-Phase Clock Generator
// ================================================================
module clk_4phi (
    input  wire clk_in,
    input  wire rst_n,
    output reg  phi1,
    output reg  phi2,
    output reg  phi3,
    output reg  phi4
);

    reg [1:0] pc;

    always @(posedge clk_in or negedge rst_n) begin
        if (!rst_n) begin
            pc    <= 2'd0;
            phi1  <= 1'b0; phi2 <= 1'b0; phi3 <= 1'b0; phi4 <= 1'b0;
        end else begin
            pc <= pc + 1;
            case (pc)
                2'd0: {phi1,phi2,phi3,phi4} <= 4'b1000;
                2'd1: {phi1,phi2,phi3,phi4} <= 4'b0100;
                2'd2: {phi1,phi2,phi3,phi4} <= 4'b0010;
                2'd3: {phi1,phi2,phi3,phi4} <= 4'b0001;
            endcase
        end
    end
endmodule


// ================================================================
// Tri-State Buffer (5-bit)
// ================================================================
module tri_state_5 (
    input  wire [4:0] d0,
    input  wire [4:0] d1,
    input  wire       oe0,
    input  wire       oe1,
    output wire [4:0] bus
);

    assign bus = (oe0) ? d0 :
                 (oe1) ? d1 : 5'bz;

endmodule


// ================================================================
// Synchronizer — 2-FF CDC
// ================================================================
module sync2ff #(
    parameter W = 1
)(
    input  wire             clk,
    input  wire             rst_n,
    input  wire [W-1:0]     async_in,
    output reg [W-1:0]      sync_out
);

    reg [W-1:0] f1, f2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            f1        <= {W{1'b0}};
            f2        <= {W{1'b0}};
            sync_out  <= {W{1'b0}};
        end else begin
            f1      <= async_in;
            f2      <= f1;
            sync_out<= f2;
        end
    end
endmodule


// ================================================================
// BADD CPU Core — 5-bit Johnsan interpreter (RUN architecture)
//
// Token stream is read one 5-bit word at a time. A group of tokens is
// collected until the PARSE delimiter | (11111) arrives, then the group
// is executed: STRT / VAR / PR / END / arithmetic.
//
// Word format (from the RUN spec):
//   [4:3] type tag : 11 = Syntax/Opcode, 10 = Number, 01 = Letter,
//                    00 = extended-opcode prefix
//   [2:0] payload  : ThinkerBinary value / opcode index
//
// Direct syntax opcodes (tag 11, from the official translation table):
//   STRT=11000  AD=11001  TI=11010  PR=11011
//   VAR =11100  % =11101  $ =11110  | =11111 (delimiter)
// Extended opcodes (a 00xxx prefix word followed by its payload word):
//   END=001  MN=010  DV=011  EQU=100  IF=101  THEN=110  GOTO=111
// ================================================================
module badd_cpu (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        phi1,
    input  wire        phi2,
    input  wire        phi3,
    input  wire        phi4,

    // Memory interface
    output wire [13:0] mem_addr,
    output wire [4:0]  mem_wdata,
    input  wire [4:0]  mem_rdata,
    output wire        mem_we,
    output wire        mem_re,
    output wire        mem_bit_mode,
    input  wire        mem_ready,

    // SATA flash pin
    output wire        sata_flash_pin,
    output wire        sata_dp,
    output wire        sata_dn,
    output wire [7:0]  led15,

    // eFlash dual-bank
    output wire [11:0] eflash_addr,
    output wire [31:0] eflash_wdata,
    output wire        eflash_we,
    output wire        eflash_re,
    output wire        eflash_bank_sel,
    output wire        eflash_inject,
    input  wire [31:0] eflash_rdata,
    input  wire        eflash_ready,

    // BOR
    input  wire        bor_reset_n,
    input  wire        bor_flash_lock,

    // MPU fault
    input  wire        mpu_fault,

    // PUF
    output wire [63:0] puf_challenge,
    input  wire [63:0] puf_response,
    output wire        puf_start,
    input  wire        puf_ready,

    // Advanced Math
    output wire        adv_mode,
    output wire [4:0]  adv_a,
    output wire [4:0]  adv_b,
    output wire [3:0]  adv_op,
    output reg  [15:0] adv_res,
    output wire        adv_done,

    // BODMAS (group token stream)
    output wire [4:0]  bodmas_tok0,
    output wire [4:0]  bodmas_tok1,
    output wire [4:0]  bodmas_tok2,
    output wire [4:0]  bodmas_tok3,
    output wire [4:0]  bodmas_len,
    output wire        bodmas_start,
    input  wire [4:0]  bodmas_rpn0,
    input  wire [4:0]  bodmas_rpn1,
    input  wire [4:0]  bodmas_rpn2,
    input  wire [4:0]  bodmas_rpn3,
    input  wire [4:0]  bodmas_rpn_len,
    input  wire        bodmas_done,

    // Status
    output reg  [7:0]  cpu_status,
    output reg  [13:0] pc_reg,
    output reg  [4:0]  acc_reg
);

    // ---- direct syntax opcodes (tag 11) ------------------------
    localparam [4:0] SY_STRT = 5'b11000;
    localparam [4:0] SY_AD   = 5'b11001;
    localparam [4:0] SY_TI   = 5'b11010;
    localparam [4:0] SY_PR   = 5'b11011;
    localparam [4:0] SY_VAR  = 5'b11100;
    localparam [4:0] SY_OBR  = 5'b11101;   // %  open bracket
    localparam [4:0] SY_CBR  = 5'b11110;   // $  close bracket
    localparam [4:0] SY_DELIM= 5'b11111;   // |  parse delimiter

    // ---- extended opcode payloads (word after a 00xxx prefix) --
    localparam [2:0] EX_END  = 3'd1;
    localparam [2:0] EX_MN   = 3'd2;
    localparam [2:0] EX_DV   = 3'd3;
    localparam [2:0] EX_EQU  = 3'd4;
    localparam [2:0] EX_IF   = 3'd5;
    localparam [2:0] EX_THEN = 3'd6;
    localparam [2:0] EX_GOTO = 3'd7;

    localparam [1:0] S_FETCH = 2'd0;
    localparam [1:0] S_EXEC  = 2'd1;
    localparam [1:0] S_HALT  = 2'd2;

    reg [1:0]  state;
    reg [13:0] pc;                 // word address of next token
    reg [4:0]  ip;                 // tokens collected in current group
    reg [4:0]  glen;               // token count of group being executed
    reg        pending_ext;        // saw a 00xxx prefix, awaiting payload
    reg [5:0]  ibuf [0:15];        // logical tokens: {is_ext, word[4:0]}
    reg [4:0]  rg   [0:7];         // variables a..h
    reg [4:0]  acc;                // accumulator
    reg [7:0]  st;                 // status flags
    reg [7:0]  led_r;              // LED15 latch (PR output)

    // ---- helpers ----------------------------------------------
    function is_ext;                   // extended opcode token?
        input [5:0] t;
        begin is_ext = t[5]; end
    endfunction

    function [2:0] ext_op;
        input [5:0] t;
        begin ext_op = t[2:0]; end
    endfunction

    function is_direct;
        input [5:0] t;
        input [4:0] code;
        begin is_direct = (!t[5]) && (t[4:0] == code); end
    endfunction

    function [4:0] val_of;             // resolve a value token
        input [5:0] t;
        begin
            if (t[5])
                val_of = 5'd0;                     // extended op: no value
            else if (t[4:3] == 2'b01)              // letter -> register
                val_of = rg[t[2:0]];
            else if (t[4:3] == 2'b10)              // number -> literal
                val_of = {2'b00, t[2:0]};
            else
                val_of = 5'd0;
        end
    endfunction

    function is_op;                    // arithmetic operator token?
        input [5:0] t;
        begin
            if (t[5])
                is_op = (t[2:0] == EX_MN) || (t[2:0] == EX_DV);
            else
                is_op = (!t[5]) && (t[4:0] == SY_AD || t[4:0] == SY_TI);
        end
    endfunction

    function [4:0] apply_op;
        input [4:0] a;
        input [4:0] b;
        input [5:0] op;
        begin
            if (op[5] && op[2:0] == EX_MN)      apply_op = a - b;
            else if (op[5] && op[2:0] == EX_DV) apply_op = (b != 5'd0) ? (a / b) : 5'd0;
            else if (!op[5] && op[4:0] == SY_TI) apply_op = a * b;
            else                                 apply_op = a + b;   // AD
        end
    endfunction

    // ---- expression evaluation (first operator, PoC) ----------
    // Returns val(tok[0]) op val(tok[2]) when tok[1] is an operator,
    // otherwise the value of tok[0]. Good enough for VAR/LHS forms and
    // for the step-by-step examples in the book.
    function [4:0] eval_expr;
        input [4:0] base;              // first token index in ibuf
        input [4:0] last;              // token count
        reg [4:0] p;
        reg       found;
        begin
            eval_expr = 5'd0;
            found     = 1'b0;
            p         = base;
            // locate the first operator between operands
            while (p < last && !found) begin
                if (p > base && is_op(ibuf[p])) begin
                    eval_expr = apply_op(val_of(ibuf[p-1]), val_of(ibuf[p+1]), ibuf[p]);
                    found     = 1'b1;
                end
                p = p + 1;
            end
            if (!found)
                eval_expr = (base < last) ? val_of(ibuf[base]) : 5'd0;
        end
    endfunction

    // ---- combinational group decode ---------------------------
    reg        ex_we_reg;
    reg [2:0]  ex_reg_idx;
    reg [4:0]  ex_reg_val;
    reg        ex_we_acc;
    reg [4:0]  ex_acc_val;
    reg        ex_we_led;
    reg [4:0]  ex_led_val;
    reg        ex_halt;
    reg [4:0]  ex_base;
    reg [4:0]  ex_val;

    always @(*) begin
        ex_we_reg = 1'b0; ex_reg_idx = 3'd0; ex_reg_val = 5'd0;
        ex_we_acc = 1'b0; ex_acc_val = 5'd0;
        ex_we_led = 1'b0; ex_led_val = 5'd0;
        ex_halt   = 1'b0;
        ex_base   = 5'd0; ex_val = 5'd0;

        if (is_ext(ibuf[0])) begin
            case (ext_op(ibuf[0]))
                EX_END:  ex_halt = 1'b1;
                EX_MN, EX_DV: begin           // leading arithmetic
                    ex_val    = eval_expr(5'd0, glen);
                    ex_we_acc = 1'b1; ex_acc_val = ex_val;
                end
                default: ;                    // IF/THEN/GOTO: handled later
            endcase
        end else if (is_direct(ibuf[0], SY_STRT)) begin
            ;                                 // start marker
        end else if (is_direct(ibuf[0], SY_VAR)) begin
            ex_reg_idx = ibuf[1][2:0];
            // skip the EQU marker if present
            ex_base = (is_ext(ibuf[2]) && ext_op(ibuf[2]) == EX_EQU) ? 5'd3 : 5'd2;
            ex_val  = eval_expr(ex_base, glen);
            ex_reg_val = ex_val;
            ex_we_reg  = 1'b1;
            ex_we_acc  = 1'b1; ex_acc_val = ex_val;
        end else if (is_direct(ibuf[0], SY_PR)) begin
            ex_val    = eval_expr(5'd1, glen);
            ex_we_acc = 1'b1; ex_acc_val = ex_val;
            ex_we_led = 1'b1; ex_led_val = ex_val;
        end else if (is_direct(ibuf[0], SY_AD) || is_direct(ibuf[0], SY_TI)) begin
            ex_val    = eval_expr(5'd0, glen);
            ex_we_acc = 1'b1; ex_acc_val = ex_val;
        end else begin
            ex_val    = eval_expr(5'd0, glen);
            ex_we_acc = 1'b1; ex_acc_val = ex_val;
        end
    end

    // ---- fetch / execute state machine -------------------------
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n || !bor_reset_n) begin
            pc         <= 14'd0;
            ip         <= 5'd0;
            glen       <= 5'd0;
            pending_ext<= 1'b0;
            acc        <= 5'd0;
            st         <= 8'd0;
            led_r      <= 8'd0;
            state      <= S_FETCH;
            for (i = 0; i < 8;  i = i + 1) rg[i]   <= 5'd0;
            for (i = 0; i < 16; i = i + 1) ibuf[i] <= 6'd0;
        end else begin
            case (state)
                S_FETCH: begin
                    if (mem_ready) begin
                        pc <= pc + 14'd1;
                        if (mem_rdata == SY_DELIM) begin      // end of group
                            glen        <= ip;
                            ip          <= 5'd0;
                            pending_ext <= 1'b0;
                            state       <= S_EXEC;
                        end else if (!pending_ext && mem_rdata[4:3] == 2'b00) begin
                            pending_ext <= 1'b1;              // swallow prefix
                        end else if (pending_ext) begin       // extended opcode
                            if (ip < 5'd16) ibuf[ip] <= {1'b1, 2'b00, mem_rdata[2:0]};
                            ip          <= ip + 5'd1;
                            pending_ext <= 1'b0;
                        end else begin                        // normal token
                            if (ip < 5'd16) ibuf[ip] <= {1'b0, mem_rdata};
                            ip <= ip + 5'd1;
                        end
                    end
                end
                S_EXEC: begin
                    if (ex_halt) begin
                        st    <= 8'hFF;
                        state <= S_HALT;
                    end else begin
                        if (ex_we_reg) rg[ex_reg_idx] <= ex_reg_val;
                        if (ex_we_acc) acc             <= ex_acc_val;
                        if (ex_we_led) led_r           <= ex_led_val;
                        ip    <= 5'd0;
                        state <= S_FETCH;
                    end
                end
                S_HALT: state <= S_HALT;
                default: state <= S_FETCH;
            endcase
        end
    end

    // ---- status mirrors ---------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cpu_status <= 8'd0;
            pc_reg     <= 14'd0;
            acc_reg    <= 5'd0;
        end else begin
            cpu_status <= st;
            pc_reg     <= pc;
            acc_reg    <= acc;
        end
    end

    always @(*) adv_res = {11'd0, acc};

    // ---- output wiring ----------------------------------------
    assign mem_addr      = pc;
    assign mem_wdata     = 5'd0;
    assign mem_we        = 1'b0;
    assign mem_re        = (state == S_FETCH);
    assign mem_bit_mode  = 1'b1;

    assign sata_flash_pin = 1'b0;
    assign sata_dp        = 1'b0;
    assign sata_dn        = 1'b0;
    assign led15          = led_r;

    assign eflash_addr     = pc[11:0];
    assign eflash_wdata    = 32'd0;
    assign eflash_we       = 1'b0;
    assign eflash_re       = 1'b0;
    assign eflash_bank_sel = 1'b0;
    assign eflash_inject   = 1'b0;

    assign puf_challenge = {50'd0, pc};
    assign puf_start     = 1'b0;

    assign adv_mode = 1'b0;
    assign adv_a    = acc;
    assign adv_b    = rg[0];
    assign adv_op   = 4'd1;
    assign adv_done = 1'b1;

    assign bodmas_tok0  = ibuf[0][4:0];
    assign bodmas_tok1  = ibuf[1][4:0];
    assign bodmas_tok2  = ibuf[2][4:0];
    assign bodmas_tok3  = ibuf[3][4:0];
    assign bodmas_len   = glen;
    assign bodmas_start = 1'b0;

endmodule


// ================================================================
// Top-Level BADD Chip — BAD INTERSIGN 100 Pin Interface
// ================================================================
module badd_top (
    inout  wire [4:0]   bad_data,
    inout  wire [13:0]  bad_addr,
    inout  wire         bad_we_n,
    inout  wire         bad_re_n,
    inout  wire         bad_ce_n,
    inout  wire         bad_bit_mode,
    inout  wire         bad_ready,

    inout  wire         sata_tx_p,
    inout  wire         sata_tx_n,
    inout  wire         sata_rx_p,
    inout  wire         sata_rx_n,
    input  wire         sata_drv,

    output wire [7:0]   led15,

    input  wire         flash_pin,
    input  wire         vdd_sense,
    input  wire         vref,
    input  wire         clk_100mhz,
    input  wire         rst_n,

    output wire [63:0]  puf_challenge_out,
    input  wire [63:0]  puf_response_in,

    input  wire [3:0]   ext_irq,

    input  wire         tck,
    input  wire         tms,
    input  wire         tdi,
    output wire         tdo
);

    wire phi1, phi2, phi3, phi4;
    clk_4phi cg (
        .clk_in(clk_100mhz),
        .rst_n(rst_n),
        .phi1(phi1),
        .phi2(phi2),
        .phi3(phi3),
        .phi4(phi4)
    );

    wire bor_rn, bor_fl;
    bor_circuit bc (
        .vdd_sense(vdd_sense),
        .vref(vref),
        .bor_reset_n(bor_rn),
        .flash_lock(bor_fl)
    );

    wire fp_s, dr_p;
    sync2ff #(.W(1)) sf (
        .clk(clk_100mhz),
        .rst_n(rst_n),
        .async_in(flash_pin),
        .sync_out(fp_s)
    );
    sync2ff #(.W(1)) sd (
        .clk(clk_100mhz),
        .rst_n(rst_n),
        .async_in(sata_drv),
        .sync_out(dr_p)
    );

    wire [13:0] mu_addr;
    wire [4:0]  mu_wd;
    wire [4:0]  mu_rd;
    wire        mu_we, mu_re, mu_bm;
    wire        mu_sfp;
    wire [7:0]  mu_led;
    wire [11:0] mu_ea;
    wire [31:0] mu_ew;
    wire        mu_ewe, mu_ere, mu_ebs, mu_eij;
    wire [31:0] mu_er;
    wire        mu_erdy;
    wire        mu_mf;

    wire [63:0] mu_pc;
    wire        mu_ps, mu_prdy;

    wire        mu_am;
    wire [4:0]  mu_aa, mu_ab;
    wire [3:0]  mu_ao;
    wire [15:0] mu_ar;
    wire        mu_ad;

    wire [4:0]  mu_bt0, mu_bt1, mu_bt2, mu_bt3;
    wire [4:0]  mu_bl;
    wire        mu_bs;
    wire [4:0]  mu_br0, mu_br1, mu_br2, mu_br3;
    wire [4:0]  mu_bdl;

    wire [7:0]  mu_status;
    wire [13:0] mu_pc_reg;
    wire [4:0]  mu_acc_reg;

    badd_cpu cpu (
        .clk         (clk_100mhz),
        .rst_n       (rst_n & bor_rn),
        .phi1        (phi1),
        .phi2        (phi2),
        .phi3        (phi3),
        .phi4        (phi4),
        .mem_addr    (mu_addr),
        .mem_wdata   (mu_wd),
        .mem_rdata   (mu_rd),
        .mem_we      (mu_we),
        .mem_re      (mu_re),
        .mem_bit_mode(mu_bm),
        .mem_ready   (bad_ready),
        .sata_flash_pin(mu_sfp),
        .sata_dp     (sata_tx_p),
        .sata_dn     (sata_tx_n),
        .led15       (mu_led),
        .eflash_addr (mu_ea),
        .eflash_wdata(mu_ew),
        .eflash_we   (mu_ewe),
        .eflash_re   (mu_ere),
        .eflash_bank_sel(mu_ebs),
        .eflash_inject(mu_eij),
        .eflash_rdata(mu_er),
        .eflash_ready(mu_erdy),
        .bor_reset_n (bor_rn),
        .bor_flash_lock(bor_fl),
        .mpu_fault   (mu_mf),
        .puf_challenge(mu_pc),
        .puf_response (puf_response_in),
        .puf_start    (mu_ps),
        .puf_ready    (mu_prdy),
        .adv_mode     (mu_am),
        .adv_a        (mu_aa),
        .adv_b        (mu_ab),
        .adv_op       (mu_ao),
        .adv_res      (mu_ar),
        .adv_done     (mu_ad),
        .bodmas_tok0  (mu_bt0),
        .bodmas_tok1  (mu_bt1),
        .bodmas_tok2  (mu_bt2),
        .bodmas_tok3  (mu_bt3),
        .bodmas_len   (mu_bl),
        .bodmas_start (mu_bs),
        .bodmas_rpn0  (mu_br0),
        .bodmas_rpn1  (mu_br1),
        .bodmas_rpn2  (mu_br2),
        .bodmas_rpn3  (mu_br3),
        .bodmas_rpn_len(mu_bdl),
        .bodmas_done  (mu_ad),
        .cpu_status   (mu_status),
        .pc_reg       (mu_pc_reg),
        .acc_reg      (mu_acc_reg)
    );

    assign led15   = mu_led;
    assign bad_addr= mu_addr;
    assign bad_we_n= ~mu_we;
    assign bad_re_n= ~mu_re;
    assign bad_bit_mode = mu_bm;
    assign bad_ce_n = 1'b0;          // chip always selected
    assign mu_rd    = bad_data;      // external memory -> CPU read data

assign bad_data = (~mu_re && mu_we && ~bad_ce_n) ? mu_wd : 5'bz;

    eflash_dual ef (
        .clk(clk_100mhz),
        .rst_n(rst_n),
        .addr(mu_ea),
        .wdata(mu_ew),
        .we(mu_ewe),
        .re(mu_ere),
        .bank_sel(mu_ebs),
        .inject_mode(mu_eij),
        .rdata(mu_er),
        .ready(mu_erdy),
        .bank_active()
    );

    mpu_unit mp (
        .addr(mu_addr),
        .we(mu_we),
        .block_write(),
        .fault_flag(mu_mf)
    );

    sram_puf puf (
        .clk(clk_100mhz),
        .rst_n(rst_n),
        .challenge(mu_pc),
        .start(mu_ps),
        .response(puf_response_in),
        .ready(mu_prdy)
    );
    assign puf_challenge_out = mu_pc;

endmodule


// ================================================================
// Testbench — Comprehensive BADD Chip Test
// ================================================================
module tb_badd;
    reg        clk;
    reg        rst_n;
    reg        flash_pin;
    reg        vdd, vref;
    wire [7:0] led15;
    wire [4:0] bad_data_wire;
    wire [13:0] bad_addr_wire;
    wire       bad_we_n, bad_re_n, bad_ce_n, bad_bit_mode, bad_ready;
    wire [63:0] puf_challenge_out;

    reg  [4:0] ext_mem [0:16383];
    reg  [4:0] mem_drv_data;
    reg        mem_drv_oe;

    wire sata_tx_p_wire, sata_tx_n_wire, sata_rx_p_wire, sata_rx_n_wire;

    badd_top uut (
        .bad_data   (bad_data_wire),
        .bad_addr   (bad_addr_wire),
        .bad_we_n   (bad_we_n),
        .bad_re_n   (bad_re_n),
        .bad_ce_n   (bad_ce_n),
        .bad_bit_mode(bad_bit_mode),
        .bad_ready  (bad_ready),
        .sata_tx_p  (sata_tx_p_wire),
        .sata_tx_n  (sata_tx_n_wire),
        .sata_rx_p  (sata_rx_p_wire),
        .sata_rx_n  (sata_rx_n_wire),
        .sata_drv   (drive_present_wire),
        .led15      (led15),
        .flash_pin  (flash_pin),
        .vdd_sense  (vdd),
        .vref       (vref),
        .clk_100mhz (clk),
        .rst_n      (rst_n),
        .puf_challenge_out (puf_challenge_out),
        .puf_response_in   (64'hA5A5_5A5A_A5A5_5A5A),
        .ext_irq    (4'd0),
        .tck        (1'b0),
        .tms        (1'b0),
        .tdi        (1'b0),
        .tdo        ()
    );

    reg drive_present_wire;
    initial drive_present_wire = 1'b1;

    // Memory model: drive bad_data when CPU reads
    always @(*) begin
        if (~bad_re_n && bad_we_n && ~bad_ce_n) begin
            mem_drv_data = ext_mem[bad_addr_wire];
            mem_drv_oe   = 1'b1;
        end else begin
            mem_drv_data = 5'bz;
            mem_drv_oe   = 1'b0;
        end
    end
    assign bad_data_wire = mem_drv_oe ? mem_drv_data : 5'bz;
    assign bad_ready = 1'b1;

    // Memory write
    always @(posedge clk) begin
        if (~bad_we_n && ~bad_ce_n)
            ext_mem[bad_addr_wire] <= bad_data_wire;
    end

    // Load Johnsan test program (official 5-bit RUN encoding):
    //   STRT |
    //   VAR a EQU 5 |
    //   VAR b EQU 3 |
    //   VAR c EQU a AD b |
    //   VAR d EQU c TI b |
    //   PR d |
    //   END |
    // EQU and END are extended opcodes: a 00xxx prefix then the payload.
    initial begin
        for (integer i = 0; i < 16384; i = i + 1) ext_mem[i] <= 5'd0;
        ext_mem[0]  <= 5'b11000; // STRT
        ext_mem[1]  <= 5'b11111; // |
        ext_mem[2]  <= 5'b11100; // VAR
        ext_mem[3]  <= 5'b01000; // 'a'
        ext_mem[4]  <= 5'b00000; // ext prefix
        ext_mem[5]  <= 5'b00100; // EQU
        ext_mem[6]  <= 5'b10101; // 5
        ext_mem[7]  <= 5'b11111; // |
        ext_mem[8]  <= 5'b11100; // VAR
        ext_mem[9]  <= 5'b01001; // 'b'
        ext_mem[10] <= 5'b00000; // ext prefix
        ext_mem[11] <= 5'b00100; // EQU
        ext_mem[12] <= 5'b10011; // 3
        ext_mem[13] <= 5'b11111; // |
        ext_mem[14] <= 5'b11100; // VAR
        ext_mem[15] <= 5'b01010; // 'c'
        ext_mem[16] <= 5'b00000; // ext prefix
        ext_mem[17] <= 5'b00100; // EQU
        ext_mem[18] <= 5'b01000; // 'a'
        ext_mem[19] <= 5'b11001; // AD
        ext_mem[20] <= 5'b01001; // 'b'
        ext_mem[21] <= 5'b11111; // |
        ext_mem[22] <= 5'b11100; // VAR
        ext_mem[23] <= 5'b01011; // 'd'
        ext_mem[24] <= 5'b00000; // ext prefix
        ext_mem[25] <= 5'b00100; // EQU
        ext_mem[26] <= 5'b01010; // 'c'
        ext_mem[27] <= 5'b11010; // TI
        ext_mem[28] <= 5'b01001; // 'b'
        ext_mem[29] <= 5'b11111; // |
        ext_mem[30] <= 5'b11011; // PR
        ext_mem[31] <= 5'b01011; // 'd'
        ext_mem[32] <= 5'b11111; // |
        ext_mem[33] <= 5'b00000; // ext prefix
        ext_mem[34] <= 5'b00001; // END
        ext_mem[35] <= 5'b11111; // |  (closes the END group)
    end

    initial begin
        $display("=== BADD Chip Testbench ===");
        $display("5-bit RUN Architecture, ThinkerBinary ALU, Johnsan ISA");
    end

    initial begin
        clk        = 0;
        rst_n      = 0;
        flash_pin  = 0;
        vdd        = 1;
        vref       = 1;
        drive_present_wire = 1;
        #20 rst_n  = 1;
        #100 flash_pin = 1;  // Trigger SATA recovery
        #50000 flash_pin = 0;
    end

    always #5 clk = ~clk; // 100MHz

    initial begin
        #200000 $finish;
    end

    always @(posedge clk) begin
        if (rst_n) begin
            $display("t=%0t led15=%h pc=%h acc=%h status=%h", $time, led15, uut.mu_pc_reg, uut.mu_acc_reg, uut.mu_status);
        end
    end
endmodule

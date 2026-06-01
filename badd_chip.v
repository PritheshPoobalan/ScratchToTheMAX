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
    output wire [15:0] adv_res,       // low 16 bits of advanced_mode result
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
    localparam [1:0] S_EVAL  = 2'd3;   // waiting on bodmas_eval

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

    // NOTE (audit fix): the old single-operator eval_expr/apply_op helpers
    // (5-bit datapath, unchecked ibuf[p+1] indexing) have been removed.
    // Expression evaluation now goes through bodmas_eval, which uses an
    // 8-bit intermediate datapath (so 7 TI 7 = 49 is not prematurely
    // truncated) and only reads operands inside its bounds-checked token
    // array.  Its 8-bit result is truncated to the 5-bit CPU word on
    // commit (see S_EVAL).
    //
    // Expressions must be operand-first (e.g. "a AD b"); a leading
    // operator is not accepted (M8: documented PoC limitation).  A
    // trailing/dangling operator is reported by bodmas_eval as error=1
    // with result=0 rather than reading past the group.

    // ---- combinational group decode ---------------------------
    // Destination decode; applied in S_EVAL after bodmas_eval finishes.
    reg        ex_we_reg;
    reg [2:0]  ex_reg_idx;
    reg        ex_we_acc;
    reg        ex_we_led;
    reg        ex_halt;
    reg        ex_eval;            // group must run through bodmas_eval
    reg        ex_has_ti;          // group carries a TI (multiply)
    reg        ex_bad_op;          // H6: unknown extended opcode (payload 000)

    // Expression view for bodmas_eval: up to 8 logical tokens starting at
    // ev_base inside ibuf.  Slots past ev_ntok are zero-filled.
    reg [4:0]  ev_base;
    reg [4:0]  ev_ntok;
    reg [5:0]  ev_tok0, ev_tok1, ev_tok2, ev_tok3;
    reg [5:0]  ev_tok4, ev_tok5, ev_tok6, ev_tok7;

    integer j;

    always @(*) begin
        ex_we_reg = 1'b0; ex_reg_idx = 3'd0;
        ex_we_acc = 1'b0;
        ex_we_led = 1'b0;
        ex_halt   = 1'b0;
        ex_eval   = 1'b1;
        ex_has_ti = 1'b0;
        ex_bad_op = 1'b0;
        ev_base   = 5'd0;
        ev_ntok   = 5'd0;
        ev_tok0 = 6'd0; ev_tok1 = 6'd0; ev_tok2 = 6'd0; ev_tok3 = 6'd0;
        ev_tok4 = 6'd0; ev_tok5 = 6'd0; ev_tok6 = 6'd0; ev_tok7 = 6'd0;

        // --- group classification / destination --------------------
        if (glen == 5'd0) begin
            // M7: an empty group (e.g. two consecutive '|') is a no-op.
            // Do not execute stale ibuf contents or touch acc/rg.
            ex_eval = 1'b0;
        end else if (is_ext(ibuf[0])) begin
            case (ext_op(ibuf[0]))
                EX_END: begin
                    ex_halt = 1'b1;
                    ex_eval = 1'b0;
                end
                3'd0: begin
                    // H6: extended payload 000 is not a valid operation.
                    ex_bad_op = 1'b1;
                    ex_eval   = 1'b0;
                end
                default: ex_we_acc = 1'b1;  // leading arithmetic (MN/DV/..)
            endcase
        end else if (is_direct(ibuf[0], SY_STRT)) begin
            ex_eval = 1'b0;                 // start marker: nothing to run
        end else if (is_direct(ibuf[0], SY_VAR)) begin
            ex_reg_idx = ibuf[1][2:0];
            ex_we_reg  = 1'b1;
            ex_we_acc  = 1'b1;
        end else if (is_direct(ibuf[0], SY_PR)) begin
            ex_we_acc = 1'b1;
            ex_we_led = 1'b1;
        end else begin
            ex_we_acc = 1'b1;
        end

        // --- expression token window ------------------------------
        // VAR: skip the extended EQU marker when one is present.
        // PR : skip the PR opcode itself.
        if (glen != 5'd0) begin
            if (is_direct(ibuf[0], SY_VAR)) begin
                ev_base = (glen > 5'd2 && is_ext(ibuf[2]) &&
                           ext_op(ibuf[2]) == EX_EQU) ? 5'd3 : 5'd2;
            end else if (is_direct(ibuf[0], SY_PR)) begin
                ev_base = 5'd1;
            end
            if (glen > ev_base) ev_ntok = glen - ev_base;
        end
        if (ev_ntok > 5'd8) ev_ntok = 5'd8;  // evaluator has 8 token ports

        if (ev_ntok > 5'd0) ev_tok0 = ibuf[ev_base];
        if (ev_ntok > 5'd1) ev_tok1 = ibuf[ev_base + 5'd1];
        if (ev_ntok > 5'd2) ev_tok2 = ibuf[ev_base + 5'd2];
        if (ev_ntok > 5'd3) ev_tok3 = ibuf[ev_base + 5'd3];
        if (ev_ntok > 5'd4) ev_tok4 = ibuf[ev_base + 5'd4];
        if (ev_ntok > 5'd5) ev_tok5 = ibuf[ev_base + 5'd5];
        if (ev_ntok > 5'd6) ev_tok6 = ibuf[ev_base + 5'd6];
        if (ev_ntok > 5'd7) ev_tok7 = ibuf[ev_base + 5'd7];

        // --- scan the group: TI presence / unknown opcodes --------
        for (j = 0; j < 16; j = j + 1) begin
            if (j < glen) begin
                if (is_direct(ibuf[j], SY_TI)) ex_has_ti = 1'b1;
                // H6: any extended token with payload 000 is invalid.
                if (is_ext(ibuf[j]) && ext_op(ibuf[j]) == 3'd0)
                    ex_bad_op = 1'b1;
            end
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
                    // M9: MPU fault takes priority — protected memory access
                    // attempted.  Halt immediately with status 8'hFD.
                    if (mpu_fault) begin
                        st    <= 8'hFD;
                        state <= S_HALT;
                    end else if (mem_ready) begin
                        if (pc == 14'd16383) begin
                            // H6: the next increment would wrap the 14-bit
                            // program counter.  Trap instead of spinning.
                            st    <= 8'hFE;
                            state <= S_HALT;
                        end else begin
                            pc <= pc + 14'd1;
                            if (mem_rdata == SY_DELIM) begin  // end of group
                                glen        <= ip;
                                ip          <= 5'd0;
                                pending_ext <= 1'b0;
                                state       <= S_EXEC;
                            end else if (!pending_ext && mem_rdata[4:3] == 2'b00) begin
                                pending_ext <= 1'b1;      // swallow prefix
                            end else if (pending_ext) begin // extended opcode
                                ibuf[ip]    <= {1'b1, 2'b00, mem_rdata[2:0]};
                                pending_ext <= 1'b0;
                                if (mem_rdata[2:0] == EX_END) begin
                                    // M11: END closes the group immediately,
                                    // even without a trailing '|'.
                                    glen  <= ip + 5'd1;
                                    ip    <= 5'd0;
                                    state <= S_EXEC;
                                end else if (ip == 5'd15) begin
                                    // ibuf is full: force end of group at 16.
                                    glen  <= 5'd16;
                                    ip    <= 5'd0;
                                    state <= S_EXEC;
                                end else begin
                                    ip <= ip + 5'd1;
                                end
                            end else begin                    // normal token
                                ibuf[ip] <= {1'b0, mem_rdata};
                                if (ip == 5'd15) begin
                                    // ibuf is full: force end of group at 16.
                                    glen  <= 5'd16;
                                    ip    <= 5'd0;
                                    state <= S_EXEC;
                                end else begin
                                    ip <= ip + 5'd1;
                                end
                            end
                        end
                    end
                end
                S_EXEC: begin
                    // M9: MPU fault may be signaled during execution (e.g. by
                    // a memory-mapped register write).  Treat as immediate halt.
                    if (mpu_fault) begin
                        st    <= 8'hFD;
                        state <= S_HALT;
                    end else begin
                        // be_start is asserted combinationally during this
                        // cycle, so bodmas_eval latches the group on this edge.
                        if (ex_halt) begin
                        // Reflect any advanced-math error in status[7].
                        // (Halt already drives every status bit high.)
                        st    <= 8'hFF | {adv_error, 7'd0};
                        state <= S_HALT;
                    end else if (ex_bad_op) begin
                        // H6: unknown opcode -> error status, stop.
                        st    <= 8'hFE;
                        state <= S_HALT;
                    end else if (ex_eval) begin
                        ip    <= 5'd0;
                        state <= S_EVAL;
                    end else begin
                        // STRT or empty group: nothing to commit.
                        ip    <= 5'd0;
                        state <= S_FETCH;
                    end
                end
            end
                S_EVAL: begin
                    // ---- wait for full BODMAS evaluation -----------------
                    if (be_done) begin
                        // bodmas_eval computes in an 8-bit datapath, so a
                        // product such as 7 TI 7 = 49 is formed exactly;
                        // the 5-bit CPU word then wraps (49 % 32 = 17).
                        // advanced_mode exposes the full-width result.
                        if (ex_we_reg) rg[ex_reg_idx] <= be_result[4:0];
                        if (ex_we_acc) acc             <= be_result[4:0];
                        if (ex_we_led) led_r           <= {3'b000, be_result[4:0]};
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

    // ---- advanced_mode instance (compute only, no write-back) ---
    // The engine's result is exposed on adv_res/adv_done.  It never feeds
    // back into acc/rg, so existing numeric results are unchanged.
    wire [31:0] adv_result32;
    wire        adv_error;
    wire        adv_start = (state == S_EXEC) && ex_has_ti && !ex_halt;

    advanced_mode u_advanced_mode (
        .clk    (clk),
        .rst_n  (rst_n),
        .start  (adv_start),
        .adv    (adv_mode),              // st[2] BIOS advanced-mode flag
        .op     (ex_has_ti ? 2'd1 : 2'd0),
        .a      ({11'd0, acc}),
        .b      ({11'd0, rg[0]}),
        .result (adv_result32),
        .done   (adv_done),
        .error  (adv_error)
    );

    assign adv_res = adv_result32[15:0];   // low 16 bits of the result
    assign adv_mode = st[2];
    assign adv_a    = acc;
    assign adv_b    = rg[0];
    assign adv_op   = {2'b00, (ex_has_ti ? 2'd1 : 2'd0)};

    // ---- bodmas_eval instance (multi-cycle expression core) -----
    wire [7:0]  be_result;
    wire        be_done;
    wire        be_error;
    wire [39:0] be_regs = {rg[7], rg[6], rg[5], rg[4],
                           rg[3], rg[2], rg[1], rg[0]};
    wire        be_start = (state == S_EXEC) && ex_eval;

    bodmas_eval u_bodmas_eval (
        .clk     (clk),
        .rst_n   (rst_n),
        .start   (be_start),
        .tok0    (ev_tok0),
        .tok1    (ev_tok1),
        .tok2    (ev_tok2),
        .tok3    (ev_tok3),
        .tok4    (ev_tok4),
        .tok5    (ev_tok5),
        .tok6    (ev_tok6),
        .tok7    (ev_tok7),
        .ntokens (ev_ntok),
        .regs    (be_regs),
        .result  (be_result),
        .done    (be_done),
        .error   (be_error)
    );

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

    // Legacy BODMAS port mirrors, kept for badd_top compatibility.
    assign bodmas_tok0  = ev_tok0[4:0];
    assign bodmas_tok1  = ev_tok1[4:0];
    assign bodmas_tok2  = ev_tok2[4:0];
    assign bodmas_tok3  = ev_tok3[4:0];
    assign bodmas_len   = glen;
    assign bodmas_start = be_start;

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
    // Audit fix: the PoC has no external memory controller handshake, so
    // ready is driven here.  Testbenches must NOT drive bad_ready (that
    // would be a multi-driver); they just observe it.
    assign bad_ready = 1'b1;
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

    wire mu_mpu_block_write;

    mpu_unit mp (
        .addr(mu_addr),
        .we(mu_we),
        .block_write(mu_mpu_block_write),
        .fault_flag(mu_mf)
    );

    // Audit fix: sram_puf is an internal model; its response must NOT be
    // connected to the external input port puf_response_in (that created a
    // multi-driver / X on the port).  Keep it on a local wire.
    wire [63:0] puf_int_resp;

    sram_puf puf (
        .clk(clk_100mhz),
        .rst_n(rst_n),
        .challenge(mu_pc),
        .start(mu_ps),
        .response(puf_int_resp),
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
    // bad_ready is driven by badd_top itself (audit fix); do not drive it here.

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

// ================================================================
// Appended verified modules (parts/)
// Wrapped in `default_nettype wire because some parts were written
// without the strict-nettype directive; restored to none below.
// ================================================================
`default_nettype wire

// ---- parts/advanced_mode.v -------------------------------------
`default_nettype none
`timescale 1ns / 1ps

/********************************************************************
 * advanced_mode.v — BADD CPU "Advanced Math Mode" arithmetic unit
 *
 * Two ways to multiply (op = TI):
 *
 *   STANDARD MODE (adv = 0)
 *     Multiplication is repeated addition, exactly as the BADD book
 *     describes: 3 TI 3  =>  3 + 3 + 3.  The accumulator starts at 0
 *     and 'a' is added once per clock until 'b' additions have been
 *     performed.  Small operands are slow on purpose (this is the
 *     educational "why is 1000 TI 1000 painful?" demo).
 *
 *     For simulation safety a bounded fallback is provided: if b is
 *     larger than REPEAT_ADD_LIMIT, the finite product is computed
 *     directly in one cycle instead of spinning the FSM for tens of
 *     thousands of clocks.  Values at or below the limit always use
 *     the genuine repeated-add loop.
 *
 *   ADVANCED MODE (adv = 1)
 *     The flagship decimal trailing-zero shortcut:
 *
 *         1000 TI 1000
 *           strip three zeros from each operand  ->  1 TI 1
 *           multiply the cores                    ->  1
 *           append (3 + 3) = 6 zeros              ->  1,000,000
 *
 *     The FSM removes decimal trailing zeros one division by ten per
 *     clock, multiplies the reduced cores with a shift-and-add loop,
 *     then rescales by 10^(za+zb).  Decimal place-value logic, not
 *     brute-force addition.  A zero operand short-circuits to zero.
 *
 * Opcodes (2-bit):
 *     0 = AD  (a + b)
 *     1 = TI  (a * b, repeated add or trailing-zero shortcut)
 *     2 = DV  (a / b, divide-by-zero sets error)
 *     3 = MN  (a - b, "minus", 32-bit wrap)
 *
 * Multi-cycle handshake:
 *     pulse start for one clock while the operands are valid;
 *     done is low while busy and goes high when result is valid;
 *     done stays high until the next start pulse.
 ********************************************************************/

module advanced_mode (
    input  wire        clk,
    input  wire        rst_n,     // active-low asynchronous reset
    input  wire        start,     // one-clock start pulse
    input  wire        adv,       // 1 = advanced (trailing-zero) mode
    input  wire [1:0]  op,        // 0=AD, 1=TI, 2=DV, 3=MN
    input  wire [15:0] a,         // left operand
    input  wire [15:0] b,         // right operand
    output reg  [31:0] result,    // 32-bit result
    output reg         done,      // result valid when high
    output reg         error      // set for divide-by-zero / bad op
);

    // ---------------- opcode encoding ----------------
    localparam [1:0] OP_AD = 2'd0,
                     OP_TI = 2'd1,
                     OP_DV = 2'd2,
                     OP_MN = 2'd3;

    // Standard-mode repeated-add is bounded for simulation sanity.
    // Above this many additions, use the direct product instead.
    localparam integer REPEAT_ADD_LIMIT = 4096;

    // ---------------- FSM states ----------------
    localparam [3:0] S_IDLE       = 4'd0,  // waiting for start
                     S_MUL_REP    = 4'd1,  // standard TI: repeated addition
                     S_TI_ZERO_A  = 4'd2,  // advanced TI: strip zeros from a
                     S_TI_ZERO_B  = 4'd3,  // advanced TI: strip zeros from b
                     S_TI_CORE_MUL= 4'd4,  // advanced TI: shift-and-add cores
                     S_TI_SCALE   = 4'd5,  // advanced TI: multiply by 10^(za+zb)
                     S_FINISH     = 4'd6;  // raise done for one clock

    reg [3:0] state;

    // Latched operands and mode (inputs may change after start).
    reg [15:0] a_lat, b_lat;
    reg [1:0]  op_lat;
    reg        adv_lat;

    // ---- standard repeated-addition working registers ----
    reg [31:0] acc;        // running sum
    reg [15:0] rep_count;  // additions still to perform

    // ---- advanced trailing-zero working registers ----
    reg [15:0] core_a;     // a with decimal trailing zeros removed
    reg [15:0] core_b;     // b with decimal trailing zeros removed
    reg [4:0]  za;         // number of zeros stripped from a
    reg [4:0]  zb;         // number of zeros stripped from b
    reg [31:0] prod;       // core_a * core_b
    reg [31:0] mcand;      // shift-and-add multiplicand
    reg [15:0] mplier;     // shift-and-add multiplier
    reg [4:0]  scale_count;// remaining factors of ten to apply
    reg [31:0] scaled;     // product while being rescaled

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // All registers to a known state; done idles high.
            state       <= S_IDLE;
            result      <= 32'd0;
            done        <= 1'b1;
            error       <= 1'b0;
            a_lat       <= 16'd0;
            b_lat       <= 16'd0;
            op_lat      <= OP_AD;
            adv_lat     <= 1'b0;
            acc         <= 32'd0;
            rep_count   <= 16'd0;
            core_a      <= 16'd0;
            core_b      <= 16'd0;
            za          <= 5'd0;
            zb          <= 5'd0;
            prod        <= 32'd0;
            mcand       <= 32'd0;
            mplier      <= 16'd0;
            scale_count <= 5'd0;
            scaled      <= 32'd0;
        end else begin
            case (state)
                // ====================================================
                // S_IDLE — latch operands and dispatch on opcode
                // ====================================================
                S_IDLE: begin
                    if (start) begin
                        a_lat   <= a;
                        b_lat   <= b;
                        op_lat  <= op;
                        adv_lat <= adv;
                        error   <= 1'b0;   // clear stale error
                        done    <= 1'b0;   // busy

                        case (op)
                            // ---- AD: 32-bit sum --------------------
                            OP_AD: begin
                                result <= {16'd0, a} + {16'd0, b};
                                state  <= S_FINISH;
                            end

                            // ---- MN: 32-bit difference -------------
                            // "MN" is minus in the Johnsan/RUN ISA.
                            OP_MN: begin
                                result <= {16'd0, a} - {16'd0, b};
                                state  <= S_FINISH;
                            end

                            // ---- DV: integer divide ----------------
                            OP_DV: begin
                                if (b == 16'd0) begin
                                    result <= 32'd0;
                                    error  <= 1'b1;   // divide by zero
                                end else begin
                                    result <= {16'd0, a} / {16'd0, b};
                                end
                                state <= S_FINISH;
                            end

                            // ---- TI: multiply ----------------------
                            OP_TI: begin
                                if (adv) begin
                                    // ADVANCED: decimal trailing-zero
                                    // shortcut.  Zero short-circuits
                                    // (we must never divide 0 by 10 in
                                    // a loop looking for zeros).
                                    if (a == 16'd0 || b == 16'd0) begin
                                        result <= 32'd0;
                                        state  <= S_FINISH;
                                    end else begin
                                        core_a <= a;
                                        core_b <= b;
                                        za     <= 5'd0;
                                        zb     <= 5'd0;
                                        state  <= S_TI_ZERO_A;
                                    end
                                end else begin
                                    // STANDARD: repeated addition.
                                    if (b == 16'd0) begin
                                        // zero additions => zero
                                        result <= 32'd0;
                                        state  <= S_FINISH;
                                    end else if (b > REPEAT_ADD_LIMIT) begin
                                        // Bounded simulation fallback:
                                        // still correct, just not slow.
                                        result <= {16'd0, a} * {16'd0, b};
                                        state  <= S_FINISH;
                                    end else begin
                                        acc       <= 32'd0;
                                        rep_count <= b;
                                        state     <= S_MUL_REP;
                                    end
                                end
                            end

                            // ---- unused opcode ---------------------
                            default: begin
                                result <= 32'd0;
                                error  <= 1'b1;
                                state  <= S_FINISH;
                            end
                        endcase
                    end
                end

                // ====================================================
                // S_MUL_REP — standard multiply by repeated addition
                //   result = a + a + ... (b times)
                // One addition per clock, deliberately simple/slow.
                // ====================================================
                S_MUL_REP: begin
                    if (rep_count == 16'd0) begin
                        result <= acc;        // all additions done
                        state  <= S_FINISH;
                    end else begin
                        acc       <= acc + {16'd0, a_lat};
                        rep_count <= rep_count - 16'd1;
                    end
                end

                // ====================================================
                // S_TI_ZERO_A — strip decimal trailing zeros from a
                //   1000 -> 100 -> 10 -> 1, za counts 3
                // One divide-by-ten per clock.  A value with no
                // trailing zero (or an odd last digit) stops the loop.
                // ====================================================
                S_TI_ZERO_A: begin
                    if (core_a != 16'd0 && (core_a % 16'd10) == 16'd0) begin
                        core_a <= core_a / 16'd10;
                        za     <= za + 5'd1;
                    end else begin
                        state <= S_TI_ZERO_B;   // core_a is now reduced
                    end
                end

                // ====================================================
                // S_TI_ZERO_B — same reduction for b
                // ====================================================
                S_TI_ZERO_B: begin
                    if (core_b != 16'd0 && (core_b % 16'd10) == 16'd0) begin
                        core_b <= core_b / 16'd10;
                        zb     <= zb + 5'd1;
                    end else begin
                        // Both cores ready: seed shift-and-add.
                        mcand  <= {16'd0, core_a};
                        mplier <= core_b;
                        prod   <= 32'd0;
                        state  <= S_TI_CORE_MUL;
                    end
                end

                // ====================================================
                // S_TI_CORE_MUL — shift-and-add product of the cores
                //   (advanced-mode secondary trick; <=16 iterations)
                // ====================================================
                S_TI_CORE_MUL: begin
                    if (mplier == 16'd0) begin
                        // Multiplication complete; prepare scaling.
                        scaled      <= prod;
                        scale_count <= za + zb;
                        state       <= S_TI_SCALE;
                    end else begin
                        if (mplier[0])
                            prod <= prod + mcand;
                        mcand  <= mcand  << 1;
                        mplier <= mplier >> 1;
                    end
                end

                // ====================================================
                // S_TI_SCALE — append the zeros: multiply by 10 (za+zb)
                // times.  This is the "put the zeros back" step:
                // 1000*1000 -> 1 * 10^6 = 1,000,000.
                // ====================================================
                S_TI_SCALE: begin
                    if (scale_count == 5'd0) begin
                        result <= scaled;
                        state  <= S_FINISH;
                    end else begin
                        scaled      <= scaled * 32'd10;
                        scale_count <= scale_count - 5'd1;
                    end
                end

                // ====================================================
                // S_FINISH — result is valid; raise done for one clock.
                // done then stays high in S_IDLE until the next start.
                // ====================================================
                S_FINISH: begin
                    done  <= 1'b1;
                    state <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule

`default_nettype wire

// ---- parts/badd_sram.v -----------------------------------------
// ============================================================================
// badd_sram.v -- BADD "Bit-Addressable Design" static RAM subsystem
// ----------------------------------------------------------------------------
// Book constraints implemented here:
//   1. Storage uses 6-transistor STATIC RAM cells (cell6t), never 1T1C DRAM.
//      A 6T cell is 4 transistors in a cross-coupled latch + 2 access
//      transistors.  It holds a bit indefinitely while powered (no refresh).
//   2. Address decoding is HIERARCHICAL (hier_decoder): the 14-bit address is
//      split into Bank -> Block -> Word so no single decoder has to explode
//      from 14 inputs into 16384 row lines in one flat level.
//   3. Every stored bit passes through a per-bit precision SENSE AMPLIFIER
//      (sense_amp) on the read path.  Five of them serve the 5-bit CPU word.
//   4. Read/write are MULTI-CYCLE: decode -> sense/charge -> latch.
//   5. The CPU word is 5 bits, so a word is 5 individual bit cells.
//
// For simulation the array is a behavioral reg [4:0] mem [0:16383]; the five
// bits of the selected word are still routed through five real sense_amp
// instances so the read path matches the book's architecture.
// ============================================================================
`timescale 1ns / 1ps

// ----------------------------------------------------------------------------
// cell6t -- one 6-transistor static SRAM bit
// ----------------------------------------------------------------------------
// Transistor inventory (exactly 6):
//
//   Transistors M1..M4 : the cross-coupled latch (the actual storage)
//       M1 (PMOS) + M2 (NMOS) form inverter A:  internal node Q  -> QB
//       M3 (PMOS) + M4 (NMOS) form inverter B:  internal node QB -> Q
//     Each inverter output drives the other's input, so the two inverters
//     reinforce each other and the pair is bistable.  That is why SRAM holds
//     its data forever (while powered) and DRAM does not.
//
//   Transistors M5..M6 : the two access transistors (NMOS), gated by the
//     wordline (the row-select produced by the decoder)
//       M5 connects internal node Q  to the true  bitline
//       M6 connects internal node QB to the complement bitline_bar
//
// Write: wordline is high, the write driver forces bitline/bitline_bar to the
//        new complementary pair, and the (relatively strong) bitline pair
//        overpowers the small latch, flipping Q/QB.
// Read : wordline is high but the bitline pair is precharged/floating; the
//        latch drives the tiny differential onto bitline/bitline_bar and a
//        sense amplifier downstream resolves it to a clean 1 or 0.
// ----------------------------------------------------------------------------
module cell6t (
    input  wire wordline,    // row select (turns on access transistors M5/M6)
    inout  wire bitline,     // true bitline        (drain of M5)
    inout  wire bitline_bar, // complement bitline  (drain of M6)
    input  wire we,          // 1 = write through the access transistors
    input  wire data_in,     // value to store when we=1
    output wire data_out     // value currently held by the cell
);

    // Internal storage nodes: the outputs of the two cross-coupled inverters.
    reg q;   // node Q  (true)
    reg qb;  // node QB (complement)

    // Power-up state.  A real SRAM cell settles to a random state due to
    // device mismatch (this is the basis of the SRAM PUF).  The model starts
    // deterministically at 0 for reproducible simulation.
    initial begin
        q  = 1'b0;
        qb = 1'b1;
    end

    // M1..M4 hold the value.  When wordline && we, M5/M6 are on and the
    // bitline pair writes through them, overpowering the latch.  Otherwise
    // the latch simply holds (inferred storage / latch behavior).
    always @(*) begin
        if (wordline && we) begin
            q  =  data_in;   // bitline     -> node Q
            qb = ~data_in;   // bitline_bar -> node QB
        end
    end

    // Read path: access transistors are on and we=0, so the latch drives the
    // bitline pair.  When the row is not selected the cell releases both
    // bitlines (high-Z) so other cells sharing the column may drive them.
    assign bitline     = (wordline && !we) ? q  : 1'bz;
    assign bitline_bar = (wordline && !we) ? qb : 1'bz;

    // Direct observation of the stored bit.
    assign data_out = q;

endmodule


// ----------------------------------------------------------------------------
// sense_amp -- one precision sense amplifier for one bitline pair
// ----------------------------------------------------------------------------
// The selected 6T cell only develops a tiny differential voltage on
// bitline/bitline_bar.  The sense amplifier is enabled after that differential
// has had time to build, then regenerates it to a full-swing logic level.
// One instance per bit => five instances for a 5-bit BADD word.
// ----------------------------------------------------------------------------
module sense_amp (
    input  wire bl,          // bitline from the selected cell
    input  wire bl_bar,      // complementary bitline
    input  wire sense_en,    // enable from the memory FSM (SENSE phase)
    output reg  data_out     // regenerated full-swing bit
);

    always @(*) begin
        if (!sense_en) begin
            // Amplifier disabled: bitlines are still precharged/equal.
            data_out = 1'b0;
        end else if (bl !== bl_bar) begin
            // The pair has split: amplify the true bitline to a clean level.
            data_out = (bl === 1'b1);
        end else begin
            // No differential (both high or both low): nothing to sense.
            data_out = 1'b0;
        end
    end

endmodule


// ----------------------------------------------------------------------------
// hier_decoder -- hierarchical bank / block / word row decoder
// ----------------------------------------------------------------------------
// A flat 14-to-16384 decoder is huge.  Instead the 14-bit address is split:
//
//   addr[13:10] -> bank  index :  4 bits -> 16 one-hot bank selects
//   addr[ 9: 5] -> block index :  5 bits -> 32 one-hot block selects / bank
//   addr[ 4: 0] -> word  index :  5 bits -> 32 one-hot word  selects / block
//
//   16 banks * 32 blocks * 32 words = 16384 rows total.
//
// The decoder is purely combinational: at every level exactly one line is
// asserted (one-hot), and the concatenation picks exactly ONE row of the
// 16384-row array (row_sel is also one-hot).
// ----------------------------------------------------------------------------
module hier_decoder (
    input  wire [13:0]    addr,
    output wire [15:0]    bank_sel,   // one-hot: which of 16 banks
    output wire [31:0]    block_sel,  // one-hot: which of 32 blocks in bank
    output wire [31:0]    word_sel,   // one-hot: which of 32 words in block
    output wire           sel_valid,  // address is in range (always 1: 14 bits)
    output wire [16383:0] row_sel     // one-hot: the single selected row
);

    // Stage 1: Bank Selector (top 4 address bits).
    wire [3:0] bank_idx  = addr[13:10];
    // Stage 2: Block Selector inside the selected bank (next 5 bits).
    wire [4:0] block_idx = addr[9:5];
    // Stage 3: Word Selector inside the selected block (low 5 bits).
    wire [4:0] word_idx  = addr[4:0];

    assign bank_sel  = 16'd1 << bank_idx;
    assign block_sel = 32'd1 << block_idx;
    assign word_sel  = 32'd1 << word_idx;

    // A 14-bit address always names exactly one of the 16384 rows.
    assign sel_valid = 1'b1;

    // Final hierarchical row select: {bank, block, word} == addr, so exactly
    // one of the 16384 row lines is high.  This is the wordline that the
    // selected 6T cells see.
    assign row_sel   = 16384'd1 << addr;

endmodule


// ----------------------------------------------------------------------------
// badd_sram -- bit-addressable 16384 x 5 SRAM controller
// ----------------------------------------------------------------------------
// Interface matches the CPU memory port (same shape as badd_mem_ctrl).
// Multi-cycle FSM:
//
//   IDLE -> DECODE -> SENSE (read)  -> LATCH -> DONE -> IDLE
//                  -> WRITE (write) -> LATCH -> DONE -> IDLE
//
//   IDLE   : ready=1, wait for re or we; latch address/data and op type.
//   DECODE : hier_decoder resolves bank/block/word; row line is asserted.
//   SENSE  : five sense amplifiers resolve the five stored bits.
//   WRITE  : the five bits are written into the selected row.
//   LATCH  : capture sensed data into the CPU-facing rdata register.
//   DONE   : assert ready to report completion.
// ----------------------------------------------------------------------------
module badd_sram (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [13:0] addr,
    input  wire [4:0]  wdata,
    input  wire        we,
    input  wire        re,
    output reg  [4:0]  rdata,
    output reg         ready,
    output reg  [2:0]  state_dbg
);

    // FSM state encoding (fits in state_dbg[2:0]).
    localparam [2:0] IDLE   = 3'd0,
                     DECODE = 3'd1,
                     SENSE  = 3'd2,
                     WRITE  = 3'd3,
                     LATCH  = 3'd4,
                     DONE   = 3'd5;

    // Behavioral backing store: 16384 rows of 5 individual SRAM bits.
    reg [4:0] mem [0:16383];
    integer   i;

    // Latched request (the external address/data are only sampled once).
    reg [13:0] addr_q;
    reg [4:0]  wdata_q;
    reg        we_q;        // 1 = this operation is a write, 0 = read
    reg [4:0]  sense_lat;   // registered outputs of the five sense amps

    // ------------------------------------------------------------------
    // Hierarchical address decode (combinational).
    // ------------------------------------------------------------------
    wire [15:0]    bank_sel;
    wire [31:0]    block_sel;
    wire [31:0]    word_sel;
    wire           sel_valid;
    wire [16383:0] row_sel;

    hier_decoder u_decoder (
        .addr      (addr_q),
        .bank_sel  (bank_sel),
        .block_sel (block_sel),
        .word_sel  (word_sel),
        .sel_valid (sel_valid),
        .row_sel   (row_sel)
    );

    // One bank AND one block AND one word AND one final row must all be
    // selected.  row_sel[addr_q] is the single wordline for this access.
    wire row_active = sel_valid & (|bank_sel) & (|block_sel) & (|word_sel) &
                      row_sel[addr_q];

    // ------------------------------------------------------------------
    // Read path: five per-bit sense amplifiers, one per BADD bit.
    // Each amplifier sees a true/complement bitline pair taken from the
    // selected word, exactly as if five 6T cells were driving them.
    // ------------------------------------------------------------------
    wire [4:0] sense_bits;
    wire       sense_en = (state_dbg == SENSE) & row_active;

    genvar gi;
    generate
        for (gi = 0; gi < 5; gi = gi + 1) begin : g_sense_amp
            sense_amp u_sense_amp (
                .bl       (mem[addr_q][gi]),
                .bl_bar   (~mem[addr_q][gi]),
                .sense_en (sense_en),
                .data_out (sense_bits[gi])
            );
        end
    endgenerate

    // ------------------------------------------------------------------
    // Multi-cycle control FSM.
    // ------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialize every bit of the array to 0.
            for (i = 0; i < 16384; i = i + 1)
                mem[i] <= 5'd0;

            rdata     <= 5'd0;
            ready     <= 1'b1;
            state_dbg <= IDLE;
            addr_q    <= 14'd0;
            wdata_q   <= 5'd0;
            we_q      <= 1'b0;
            sense_lat <= 5'd0;
        end else begin
            case (state_dbg)

                IDLE: begin
                    ready <= 1'b1;
                    if (we || re) begin
                        // Latch the request.  A simultaneous we+re is a write
                        // (write has priority, matching the CPU memory port).
                        addr_q    <= addr;
                        wdata_q   <= wdata;
                        we_q      <= we;
                        ready     <= 1'b0;
                        state_dbg <= DECODE;
                    end
                end

                DECODE: begin
                    // hier_decoder has now resolved the bank/block/word row.
                    state_dbg <= we_q ? WRITE : SENSE;
                end

                SENSE: begin
                    // Five sense amps regenerate the selected word's five bits.
                    sense_lat <= sense_bits;
                    state_dbg <= LATCH;
                end

                WRITE: begin
                    // Charge the selected row's five bit cells with wdata.
                    mem[addr_q] <= wdata_q;
                    state_dbg   <= LATCH;
                end

                LATCH: begin
                    // A read presents the sensed word to the CPU; a write leaves
                    // rdata untouched.
                    if (!we_q)
                        rdata <= sense_lat;
                    state_dbg <= DONE;
                end

                DONE: begin
                    // Operation complete: handshake ready back to the CPU.
                    ready     <= 1'b1;
                    state_dbg <= IDLE;
                end

                default: state_dbg <= IDLE;
            endcase
        end
    end

endmodule

// ---- parts/bodmas_eval.v ---------------------------------------
`default_nettype none
`timescale 1ns / 1ps

/********************************************************************
 * bodmas_eval.v — BODMAS / PEMDAS evaluator for the BADD RUN CPU
 *
 * Accepts one buffered token group (up to 8 logical tokens, each a
 * 6-bit {is_ext, word[4:0]} value) and produces an arithmetic result.
 *
 * SHARED WORD ENCODING (see badd_chip.v)
 *   5-bit word [4:3] tag:
 *     2'b11 -> syntax/opcode.  We care about:
 *                AD=11001 (+), TI=11010 (*),
 *                % =11101 (open bracket), $ =11110 (close bracket)
 *              (STRT/PR/VAR/delimiter are ignored inside an expression)
 *     2'b10 -> number, payload [2:0] is one DECIMAL DIGIT (0..7)
 *     2'b01 -> letter, payload [2:0] is register index a..h
 *     2'b00 -> extended-op prefix; the CPU has already folded the
 *              prefix+payload into a single logical token:
 *                END=001, MN=010 (-), DV=011 (/), EQU=100
 *   Logical tokens are 6-bit: {1'b1, 2'b00, ext_op} for extended ops
 *   (bit 5 set) and {1'b0, word} for ordinary words (bit 5 clear).
 *
 * GRAMMAR / SEMANTICS
 *   - Numbers: a single number token is one decimal digit.  Because the
 *     payload is only 3 bits, a multi-digit literal is written as
 *     CONSECUTIVE number tokens: 2,0 -> 20.  (This is how the 20 MN 5 DV 3
 *     check below is encoded.  A single token can never represent 20.)
 *   - Letters: a..h read regs[5*idx +: 5].
 *   - Operators: TI (*) has precedence 2; AD (+), MN (-), DV (/) have
 *     precedence 1 and associate left-to-right.
 *   - Brackets: % opens, $ closes.  Innermost brackets are reduced first,
 *     then TI, then AD/MN/DV left-to-right.  Arbitrary nesting depth is
 *     supported (up to the token-group size).
 *   - Adjacency is multiplication: 2 %3+4$ means 2*(3+4); a(3+4) means
 *     a*(3+4); (3+4)5 means (3+4)*5.  The one exception is digit-digit
 *     adjacency, which forms a multi-digit decimal literal as above.
 *   - Extended EQU tokens are skipped.  Stray STRT/END tokens are ignored.
 *   - Division by zero, unmatched brackets, empty brackets, or a malformed
 *     operator/operand sequence raise error=1 with result=0.
 *
 * WIDTH NOTE
 *   The RUN word is 5 bits, but the required BODMAS test
 *   "2 % 3 AD 4 $ TI 5" must produce 70, which does not fit in 5 bits
 *   (70 mod 32 = 6).  To make the arithmetic checkable this module uses an
 *   8-bit datapath and an 8-bit result.  The 5-bit CPU word view is simply
 *   result[4:0] (for the example above that is 6).  Operands larger than
 *   31 (e.g. the literal 20) also require this width.
 *
 * IMPLEMENTATION
 *   A small multi-cycle FSM works on a compact internal token array:
 *     1. PREP   (combinational): decode the input group, skip EQU, resolve
 *        letters to register values, form multi-digit literals, and insert
 *        an implicit TI token wherever two factors are adjacent.
 *     2. FIND   : locate the first close bracket and its matching open
 *        bracket (the nearest open to its left = the innermost pair).
 *     3. TI     : reduce the leftmost TI inside the selected range.
 *     4. AS     : reduce the leftmost AD/MN/DV inside the range.
 *     5. FOLD   : replace the bracket pair with its value and continue.
 *   With no brackets left, the whole expression is the selected range and
 *   the AS state finishes the calculation.
 *
 * One reduction happens per clock, which keeps the logic easy to follow.
 ********************************************************************/

module bodmas_eval (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,

    // Logical token group: tok0 is the first token of the group.
    input  wire [5:0]  tok0, tok1, tok2, tok3,
                       tok4, tok5, tok6, tok7,
    input  wire [4:0]  ntokens,       // number of valid token slots (0..8)

    // Variable file: regs[5*i +: 5] is register i (a=0 .. h=7).
    input  wire [39:0] regs,

    output reg  [7:0]  result,        // 8-bit result; result[4:0] = CPU word
    output reg         done,          // high when result/error is valid
    output reg         error          // division by zero / malformed input
);

    // -----------------------------------------------------------------
    // 5-bit word constants (tag included, as they appear in the memo)
    // -----------------------------------------------------------------
    localparam [4:0] SY_STRT = 5'b11000;
    localparam [4:0] SY_AD   = 5'b11001;  // +
    localparam [4:0] SY_TI   = 5'b11010;  // *
    localparam [4:0] SY_PR   = 5'b11011;
    localparam [4:0] SY_VAR  = 5'b11100;
    localparam [4:0] SY_OBR  = 5'b11101;  // % open bracket
    localparam [4:0] SY_CBR  = 5'b11110;  // $ close bracket
    localparam [4:0] SY_DELIM= 5'b11111;  // | (never inside a group)

    // Extended-op payloads carried in logical-token bits [2:0].
    localparam [2:0] EX_END  = 3'd1;
    localparam [2:0] EX_MN   = 3'd2;      // -
    localparam [2:0] EX_DV   = 3'd3;      // /
    localparam [2:0] EX_EQU  = 3'd4;

    // -----------------------------------------------------------------
    // Compact internal token kinds.  Values live in a parallel array.
    // -----------------------------------------------------------------
    localparam [2:0] K_NUM   = 3'd0;
    localparam [2:0] K_ADD   = 3'd1;
    localparam [2:0] K_SUB   = 3'd2;
    localparam [2:0] K_MUL   = 3'd3;
    localparam [2:0] K_DIV   = 3'd4;
    localparam [2:0] K_OPEN  = 3'd5;
    localparam [2:0] K_CLOSE = 3'd6;

    // -----------------------------------------------------------------
    // FSM states
    // -----------------------------------------------------------------
    localparam [2:0] ST_IDLE = 3'd0;
    localparam [2:0] ST_FIND = 3'd1;   // find innermost bracket pair
    localparam [2:0] ST_TI   = 3'd2;   // reduce '*' in the active range
    localparam [2:0] ST_AS   = 3'd3;   // reduce +,-,/ in the active range
    localparam [2:0] ST_FOLD = 3'd4;   // collapse a bracket pair to a value

    // -----------------------------------------------------------------
    // Input token array (internal unpacked array; ports stay scalar)
    // -----------------------------------------------------------------
    wire [5:0] tin [0:7];
    assign tin[0] = tok0;
    assign tin[1] = tok1;
    assign tin[2] = tok2;
    assign tin[3] = tok3;
    assign tin[4] = tok4;
    assign tin[5] = tok5;
    assign tin[6] = tok6;
    assign tin[7] = tok7;

    // =================================================================
    // PREP — combinational decode of the input group
    // =================================================================
    // pk[]  : kind of each compact token
    // pv[]  : 8-bit value of each compact token (numbers only)
    // pn    : compact token count
    reg [2:0] pk [0:31];
    reg [7:0] pv [0:31];
    reg [5:0] pn;

    integer pi;          // prep loop index
    integer p_eff;       // clamped number of input tokens to scan
    reg [5:0] pt;        // current input token
    reg [7:0] pacc;      // multi-digit decimal accumulator
    reg       pprev_digit; // previous token was a number digit
    reg       pprev_end;   // previous token can end a factor

    always @(*) begin
        // Defaults (also make all 32 slots well-defined for simulation).
        pn          = 6'd0;
        pacc        = 8'd0;
        pprev_digit = 1'b0;
        pprev_end   = 1'b0;
        for (pi = 0; pi < 32; pi = pi + 1) begin
            pk[pi] = K_NUM;
            pv[pi] = 8'd0;
        end

        // Never read past the eight physical token ports.
        p_eff = (ntokens > 5'd8) ? 8 : ntokens;

        for (pi = 0; pi < p_eff; pi = pi + 1) begin
            pt = tin[pi];

            if (pt[5]) begin
                // ---------------- extended opcode token ----------------
                case (pt[2:0])
                    EX_MN: begin
                        pk[pn] = K_SUB; pv[pn] = 8'd0; pn = pn + 1;
                        pprev_end = 1'b0; pprev_digit = 1'b0;
                    end
                    EX_DV: begin
                        pk[pn] = K_DIV; pv[pn] = 8'd0; pn = pn + 1;
                        pprev_end = 1'b0; pprev_digit = 1'b0;
                    end
                    EX_EQU: begin
                        // Assignment marker: ignore it inside an expression.
                    end
                    default: begin
                        // END / IF / THEN / GOTO: not arithmetic; ignore.
                    end
                endcase
            end else begin
                case (pt[4:3])
                    // ---------------- syntax / opcode word ------------
                    2'b11: begin
                        case (pt[4:0])
                            SY_AD: begin
                                pk[pn] = K_ADD; pv[pn] = 8'd0; pn = pn + 1;
                                pprev_end = 1'b0; pprev_digit = 1'b0;
                            end
                            SY_TI: begin
                                pk[pn] = K_MUL; pv[pn] = 8'd0; pn = pn + 1;
                                pprev_end = 1'b0; pprev_digit = 1'b0;
                            end
                            SY_OBR: begin
                                // Number/letter/bracket immediately before
                                // an open bracket means implicit multiply.
                                if (pprev_end) begin
                                    pk[pn] = K_MUL; pv[pn] = 8'd0; pn = pn + 1;
                                end
                                pk[pn] = K_OPEN; pv[pn] = 8'd0; pn = pn + 1;
                                pprev_end = 1'b0; pprev_digit = 1'b0;
                            end
                            SY_CBR: begin
                                pk[pn] = K_CLOSE; pv[pn] = 8'd0; pn = pn + 1;
                                pprev_end = 1'b1; pprev_digit = 1'b0;
                            end
                            default: begin
                                // STRT / PR / VAR / delimiter: no operand.
                            end
                        endcase
                    end

                    // ---------------- decimal digit --------------------
                    2'b10: begin
                        if (pprev_digit) begin
                            // Consecutive digits form one decimal literal.
                            pacc = pacc * 8'd10 + {5'd0, pt[2:0]};
                            pv[pn - 1] = pacc;
                            pprev_end = 1'b1;
                        end else begin
                            if (pprev_end) begin
                                pk[pn] = K_MUL; pv[pn] = 8'd0; pn = pn + 1;
                            end
                            pacc = {5'd0, pt[2:0]};
                            pk[pn] = K_NUM; pv[pn] = pacc; pn = pn + 1;
                            pprev_digit = 1'b1;
                            pprev_end   = 1'b1;
                        end
                    end

                    // ---------------- letter / variable -----------------
                    2'b01: begin
                        if (pprev_end) begin
                            pk[pn] = K_MUL; pv[pn] = 8'd0; pn = pn + 1;
                        end
                        pk[pn] = K_NUM;
                        pv[pn] = {3'd0, regs[5*pt[2:0] +: 5]};
                        pn = pn + 1;
                        pprev_digit = 1'b0;
                        pprev_end   = 1'b1;
                    end

                    default: begin
                        // tag 00 should not survive CPU token buffering.
                    end
                endcase
            end
        end
    end

    // =================================================================
    // Working storage for the FSM
    // =================================================================
    reg [2:0] wk [0:31];   // compact kinds
    reg [7:0] wv [0:31];   // values
    reg [5:0] wn;          // number of compact tokens

    reg [5:0] lo, hi;      // active reduction range (inclusive)
    reg [5:0] bri, brj;    // bracket open/close indices
    reg       in_bracket;  // 1 = reducing bracket contents

    reg [2:0] state;

    integer si;            // sequential loop index
    integer qi;            // shift loop index
    integer slo, shi, swn; // signed integer copies of range/count
    integer sp;            // scan hit (-1 = none)
    integer sj;            // close-bracket scan hit
    reg     sf;            // scan-found flag

    // =================================================================
    // Main FSM
    // =================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= ST_IDLE;
            done       <= 1'b0;
            error      <= 1'b0;
            result     <= 8'd0;
            wn         <= 6'd0;
            lo         <= 6'd0;
            hi         <= 6'd0;
            bri        <= 6'd0;
            brj        <= 6'd0;
            in_bracket <= 1'b0;
            for (si = 0; si < 32; si = si + 1) begin
                wk[si] <= K_NUM;
                wv[si] <= 8'd0;
            end
        end else begin
            case (state)

                // ------------------------------------------------
                // Wait for a group, then copy the prepared tokens.
                // ------------------------------------------------
                ST_IDLE: begin
                    if (start) begin
                        for (si = 0; si < 32; si = si + 1) begin
                            wk[si] <= pk[si];
                            wv[si] <= pv[si];
                        end
                        wn         <= pn;
                        done       <= 1'b0;
                        error      <= 1'b0;
                        result     <= 8'd0;
                        in_bracket <= 1'b0;
                        state      <= ST_FIND;
                    end
                end

                // ------------------------------------------------
                // Locate the innermost bracket pair, or select the
                // whole expression if no brackets remain.
                // ------------------------------------------------
                ST_FIND: begin
                    swn = wn;
                    if (swn == 0) begin
                        // Empty group: define the result as zero.
                        result <= 8'd0;
                        error  <= 1'b0;
                        done   <= 1'b1;
                        state  <= ST_IDLE;
                    end else begin
                        // First close bracket = innermost close.
                        sf = 1'b0; sj = -1;
                        for (si = 0; si < swn; si = si + 1) begin
                            if (!sf && wk[si] == K_CLOSE) begin
                                sj = si;
                                sf = 1'b1;
                            end
                        end

                        if (!sf) begin
                            // No brackets: evaluate the full token array.
                            lo         <= 6'd0;
                            hi         <= wn - 6'd1;
                            in_bracket <= 1'b0;
                            state      <= ST_TI;
                        end else begin
                            // Nearest open bracket to the left.
                            sf = 1'b0; sp = -1;
                            for (si = sj - 1; si >= 0; si = si - 1) begin
                                if (!sf && wk[si] == K_OPEN) begin
                                    sp = si;
                                    sf = 1'b1;
                                end
                            end

                            if (!sf) begin
                                // Close without an open: malformed.
                                result <= 8'd0;
                                error  <= 1'b1;
                                done   <= 1'b1;
                                state  <= ST_IDLE;
                            end else if (sj <= sp + 1) begin
                                // "% $" with nothing between: malformed.
                                result <= 8'd0;
                                error  <= 1'b1;
                                done   <= 1'b1;
                                state  <= ST_IDLE;
                            end else begin
                                bri        <= sp;
                                brj        <= sj;
                                lo         <= sp + 1;
                                hi         <= sj - 1;
                                in_bracket <= 1'b1;
                                state      <= ST_TI;
                            end
                        end
                    end
                end

                // ------------------------------------------------
                // Precedence 2: reduce the leftmost '*' in range.
                // ------------------------------------------------
                ST_TI: begin
                    slo = lo; shi = hi;
                    sf = 1'b0; sp = -1;
                    for (si = slo + 1; si <= shi - 1; si = si + 1) begin
                        if (!sf && wk[si] == K_MUL) begin
                            sp = si;
                            sf = 1'b1;
                        end
                    end

                    if (!sf) begin
                        state <= ST_AS;         // no more multiplies here
                    end else if (wk[sp-1] != K_NUM || wk[sp+1] != K_NUM) begin
                        // Operator without value operands.
                        result <= 8'd0;
                        error  <= 1'b1;
                        done   <= 1'b1;
                        state  <= ST_IDLE;
                    end else begin
                        // Replace [a op b] with the product.
                        wk[sp-1] <= K_NUM;
                        wv[sp-1] <= wv[sp-1] * wv[sp+1];

                        // Remove the operator and right operand.
                        swn = wn;
                        for (qi = sp; qi < swn - 2; qi = qi + 1) begin
                            wk[qi] <= wk[qi+2];
                            wv[qi] <= wv[qi+2];
                        end
                        wn   <= wn - 6'd2;
                        hi   <= hi - 6'd2;
                        // The close bracket is to the right of the removed
                        // tokens, so it slides left as well.
                        if (in_bracket) brj <= brj - 6'd2;
                        state <= ST_TI;
                    end
                end

                // ------------------------------------------------
                // Precedence 1: reduce the leftmost +, -, or / in
                // range.  Leftmost-first gives left associativity.
                // ------------------------------------------------
                ST_AS: begin
                    slo = lo; shi = hi;
                    sf = 1'b0; sp = -1;
                    for (si = slo + 1; si <= shi - 1; si = si + 1) begin
                        if (!sf && (wk[si] == K_ADD ||
                                    wk[si] == K_SUB ||
                                    wk[si] == K_DIV)) begin
                            sp = si;
                            sf = 1'b1;
                        end
                    end

                    if (!sf) begin
                        if (in_bracket) begin
                            state <= ST_FOLD;   // bracket contents done
                        end else if (wn == 6'd1 && wk[0] == K_NUM) begin
                            result <= wv[0];
                            error  <= 1'b0;
                            done   <= 1'b1;
                            state  <= ST_IDLE;
                        end else begin
                            // Trailing values, unmatched '(' etc.
                            result <= 8'd0;
                            error  <= 1'b1;
                            done   <= 1'b1;
                            state  <= ST_IDLE;
                        end
                    end else if (wk[sp-1] != K_NUM || wk[sp+1] != K_NUM) begin
                        result <= 8'd0;
                        error  <= 1'b1;
                        done   <= 1'b1;
                        state  <= ST_IDLE;
                    end else if (wk[sp] == K_DIV && wv[sp+1] == 8'd0) begin
                        // Division by zero is the one defined arithmetic error.
                        result <= 8'd0;
                        error  <= 1'b1;
                        done   <= 1'b1;
                        state  <= ST_IDLE;
                    end else begin
                        wk[sp-1] <= K_NUM;
                        case (wk[sp])
                            K_ADD: wv[sp-1] <= wv[sp-1] + wv[sp+1];
                            K_SUB: wv[sp-1] <= wv[sp-1] - wv[sp+1];
                            K_DIV: wv[sp-1] <= wv[sp-1] / wv[sp+1];
                            default: wv[sp-1] <= 8'd0;
                        endcase

                        swn = wn;
                        for (qi = sp; qi < swn - 2; qi = qi + 1) begin
                            wk[qi] <= wk[qi+2];
                            wv[qi] <= wv[qi+2];
                        end
                        wn   <= wn - 6'd2;
                        hi   <= hi - 6'd2;
                        // Track the matching close bracket while the
                        // contents shrink.
                        if (in_bracket) brj <= brj - 6'd2;
                        state <= ST_AS;
                    end
                end

                // ------------------------------------------------
                // Bracket contents are a single value: replace
                // "% value $" with "value" and shift the tail down.
                // ------------------------------------------------
                ST_FOLD: begin
                    if (!(hi == lo && wk[lo] == K_NUM)) begin
                        result <= 8'd0;
                        error  <= 1'b1;
                        done   <= 1'b1;
                        state  <= ST_IDLE;
                    end else begin
                        sp = brj - bri;          // number of slots removed

                        wk[bri] <= K_NUM;
                        wv[bri] <= wv[lo];       // lo == bri + 1

                        // Move everything after the close bracket down.
                        swn = wn;
                        for (qi = bri + 1; qi <= swn - 1 - sp; qi = qi + 1) begin
                            wk[qi] <= wk[qi+sp];
                            wv[qi] <= wv[qi+sp];
                        end
                        wn         <= wn - sp;
                        in_bracket <= 1'b0;
                        state      <= ST_FIND;
                    end
                end

                default: state <= ST_IDLE;
            endcase
        end
    end

endmodule

`default_nettype wire

// ---- parts/johnsan_decode.v ------------------------------------
`timescale 1ns / 1ps
`default_nettype none

// ============================================================================
// johnsan_decode — BADD 5-bit ThinkerBinary word decoder
//
// Official word format (RUN architecture):
//
//   word[4:3]  type tag      word[2:0] payload
//   ---------  ------------- ------------------------------------------------
//   2'b11      Syntax/Opcode direct opcode 000..111 (111 = PARSE delimiter)
//   2'b10      Number        literal 0..7
//   2'b01      Letter        variable index 0..7 -> a..h
//   2'b00      Extended      extended-opcode prefix (00000) or payload
//
// Direct syntax opcodes (tag 11):
//   11000 STRT   11001 AD    11010 TI    11011 PR
//   11100 VAR    11101 %     11110 $     11111 |   (is_delim)
//
// Extended opcodes are two words: prefix 00000 followed by a word whose
// payload [2:0] selects the operation (001..111), 000 being the planned
// escape/page mechanism:
//   001 END   010 MN   011 DV   100 EQU   101 IF   110 THEN   111 GOTO
//
// This module decodes a single 5-bit word.  It is intentionally stateless:
// the caller is responsible for remembering that a 00000 prefix was seen
// and for presenting the following word with ext_valid asserted to
// johnsan_decode_ext, which resolves ext_op.
// ============================================================================

module johnsan_decode (
    input  wire [4:0] word,        // raw 5-bit ThinkerBinary word
    output reg  [1:0] kind,        // 0=number 1=letter 2=direct-syntax 3=ext
    output reg  [2:0] code,        // opcode index or payload value
    output reg        is_delim     // asserted only for 11111
);

    localparam [1:0] K_NUMBER = 2'd0;
    localparam [1:0] K_LETTER = 2'd1;
    localparam [1:0] K_DIRECT = 2'd2;
    localparam [1:0] K_EXT    = 2'd3;

    always @(*) begin
        kind     = K_NUMBER;
        code     = 3'd0;
        is_delim = 1'b0;

        case (word[4:3])
            2'b10: begin                       // Number: literal 0..7
                kind = K_NUMBER;
                code = word[2:0];
            end
            2'b01: begin                       // Letter: variable a..h
                kind = K_LETTER;
                code = word[2:0];
            end
            2'b11: begin                       // Direct syntax / opcode
                kind = K_DIRECT;
                code = word[2:0];
                if (word == 5'b11111)
                    is_delim = 1'b1;           // PARSE delimiter
            end
            2'b00: begin                       // Extended prefix / payload
                kind = K_EXT;
                code = word[2:0];
            end
            default: begin                     // unreachable for 5-bit input
                kind = K_NUMBER;
                code = 3'd0;
            end
        endcase
    end

endmodule


// ============================================================================
// johnsan_decode_ext — extended-token helper
//
// The CPU swallows a 00000 prefix word, then records the following word as an
// extended token.  This wrapper exposes that resolved operation:
//
//   is_prefix : word is a 00000 prefix (tag 00, payload 000) and no ext_valid
//   ext_hit   : caller says this word is the payload of a pending prefix
//   ext_op    : resolved 3-bit extended opcode (001..111), 000 when unused
//
// It instantiates the base decoder, so both views always agree.
// ============================================================================

module johnsan_decode_ext (
    input  wire [4:0] word,
    input  wire       ext_valid,   // 1 = this word follows a 00000 prefix
    output wire [1:0] kind,
    output wire [2:0] code,
    output wire       is_delim,
    output wire [2:0] ext_op,
    output wire       ext_hit,
    output wire       is_prefix
);

    johnsan_decode u_decode (
        .word     (word),
        .kind     (kind),
        .code     (code),
        .is_delim (is_delim)
    );

    assign ext_hit   = ext_valid;
    assign ext_op    = ext_valid ? code : 3'd0;
    assign is_prefix = (!ext_valid) && (kind == 2'd3) && (code == 3'd0);

endmodule

`default_nettype none

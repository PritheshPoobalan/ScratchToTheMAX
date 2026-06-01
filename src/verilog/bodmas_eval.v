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

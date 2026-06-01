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

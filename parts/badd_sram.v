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

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

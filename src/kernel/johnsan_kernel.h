#ifndef JOHNSAN_KERNEL_H
#define JOHNSAN_KERNEL_H

/* Johnsan kernel - translates Johnsan source text into 5-bit ThinkerBinary
 * token words. This is the system microcode layer: Johnsan mnemonics map to
 * fixed 5-bit encodings owned by this translation table.
 */

#include <stddef.h>

/* One translated token plus its 5-bit word. */
typedef struct {
    const char *mnemonic; /* Johnsan source text, NULL for literals/letters */
    uint8_t word;         /* 5-bit ThinkerBinary encoding */
    bool is_ext;          /* true when this token is an extended payload word */
} johnsan_token_t;

/* Translate a single Johnsan statement line (without the trailing |) into
 * tokens. Returns the number of tokens written, or -1 on error. The caller
 * must append the PARSE delimiter word 0b11111 itself. */
int johnsan_translate_line(const char *line, johnsan_token_t *out,
                           size_t out_cap);

/* Translate a full Johnsan program (multiple lines) into a flat word stream.
 * Returns the number of 5-bit words written, or -1 on error. */
int johnsan_translate_program(const char *source, uint8_t *words_out,
                              size_t words_cap);

/* Look up the 5-bit encoding of a Johnsan mnemonic. Returns -1 if unknown. */
int johnsan_opcode_of(const char *mnemonic);

#endif /* JOHNSAN_KERNEL_H */

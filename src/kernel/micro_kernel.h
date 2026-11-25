#ifndef MICRO_KERNEL_H
#define MICRO_KERNEL_H

/* BADD micro-kernel - fetch/decode/execute loop for the 5-bit RUN CPU.
 *
 * This is the C reference model of the system micro-kernel. It fetches 5-bit
 * ThinkerBinary words from memory, groups them until the PARSE delimiter,
 * decodes them with the Johnsan decoder, and executes the group against the
 * architectural state (registers a-h, ACC, LED15).
 */

#include <stdint.h>
#include <stdbool.h>

/* A 5-bit ThinkerBinary word. */
typedef uint8_t badd_word_t;

/* Decoder output kind. */
#define BADD_KIND_NUMBER  0
#define BADD_KIND_LETTER  1
#define BADD_KIND_DIRECT  2
#define BADD_KIND_EXT     3

/* Direct opcodes (tag 11). */
#define BADD_OP_STRT  0b000
#define BADD_OP_AD    0b001
#define BADD_OP_TI    0b010
#define BADD_OP_PR    0b011
#define BADD_OP_VAR   0b100
#define BADD_OP_OPEN  0b101   /* % */
#define BADD_OP_CLOSE 0b110   /* $ */
#define BADD_OP_DELIM 0b111   /* | */

/* Extended opcodes (prefix 00000 + payload). */
#define BADD_EXT_END  0b001
#define BADD_EXT_MN   0b010
#define BADD_EXT_DV   0b011
#define BADD_EXT_EQU  0b100
#define BADD_EXT_IF   0b101
#define BADD_EXT_THEN 0b110
#define BADD_EXT_GOTO 0b111

/* Architectural state: 5-bit registers a-h plus ACC. */
typedef struct {
    uint8_t reg[8];
    uint8_t acc;
    uint8_t led15;
    uint16_t pc;
    bool halted;
    uint8_t status;
} badd_state_t;

/* Memory interface used by the micro-kernel. */
typedef struct {
    uint8_t (*read5)(uint16_t addr);
    void (*write5)(uint16_t addr, uint8_t value);
    bool ready;
} badd_mem_t;

/* Decode one 5-bit word into kind/code/is_delim. */
void badd_decode(badd_word_t word, uint8_t *kind, uint8_t *code, bool *is_delim);

/* Resolve an extended token after a pending 00000 prefix. */
bool badd_ext_resolve(badd_word_t word, bool ext_valid, uint8_t *ext_op);

/* Run the fetch/decode/execute loop until halt or fault. */
void badd_run(badd_state_t *state, const badd_mem_t *mem);

/* Reset architectural state to power-on defaults. */
void badd_reset(badd_state_t *state);

#endif /* MICRO_KERNEL_H */

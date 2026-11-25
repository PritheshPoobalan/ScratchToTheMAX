#include "micro_kernel.h"
#include "johnsan_kernel.h"

#include <stdio.h>

/* Decode one 5-bit word: tag in [4:3], payload in [2:0]. */
void badd_decode(badd_word_t word, uint8_t *kind, uint8_t *code, bool *is_delim)
{
    uint8_t tag = (word >> 3) & 0x03;
    uint8_t payload = word & 0x07;

    *kind = BADD_KIND_NUMBER;
    *code = payload;
    *is_delim = false;

    switch (tag) {
    case 0b10: /* number literal 0-7 */
        *kind = BADD_KIND_NUMBER;
        *code = payload;
        break;
    case 0b01: /* letter variable a-h */
        *kind = BADD_KIND_LETTER;
        *code = payload;
        break;
    case 0b11: /* direct syntax opcode */
        *kind = BADD_KIND_DIRECT;
        *code = payload;
        *is_delim = (word == 0b11111);
        break;
    case 0b00: /* extended prefix or payload */
        *kind = BADD_KIND_EXT;
        *code = payload;
        break;
    }
}

/* Resolve extended token: caller asserts ext_valid when this word follows a
 * pending 00000 prefix word. Returns true when a complete extended opcode
 * has been resolved. */
bool badd_ext_resolve(badd_word_t word, bool ext_valid, uint8_t *ext_op)
{
    if (!ext_valid) {
        *ext_op = 0;
        return false;
    }
    *ext_op = word & 0x07;
    return *ext_op != 0;
}

static void write_acc(badd_state_t *s, uint8_t value)
{
    s->acc = value & 0x1f;
    s->led15 = s->acc;
}

static void exec_var(badd_state_t *s, const uint8_t *group, size_t n)
{
    /* VAR <letter> [EQU] <value> */
    if (n < 2) return;
    uint8_t letter = group[0] & 0x07;
    size_t i = 1;
    if (i < n && group[i] == BADD_EXT_EQU) i++;
    if (i < n) {
        uint8_t value = (group[i] & 0x07);
        s->reg[letter] = value & 0x1f;
        write_acc(s, s->reg[letter]);
    }
}

static uint8_t eval_expr(badd_state_t *s, const uint8_t *group, size_t n)
{
    /* GEN1 evaluates the first operand-operator-operand triple. */
    if (n < 3) return s->acc;
    uint8_t a = (group[0] & 0x07);
    uint8_t op = group[1];
    uint8_t b = (group[2] & 0x07);
    uint8_t result = s->acc;
    switch (op) {
    case BADD_OP_AD:  result = (a + b) & 0x1f; break;
    case BADD_OP_TI:  result = ((uint8_t)((a * b) & 0x1f)); break;
    case BADD_EXT_MN: result = (a - b) & 0x1f; break;
    case BADD_EXT_DV: result = (b != 0) ? (a / b) & 0x1f : 0; break;
    default:          result = s->acc; break;
    }
    return result;
}

void badd_run(badd_state_t *state, const badd_mem_t *mem)
{
    uint8_t group[16];
    size_t gn = 0;
    bool pending_ext = false;

    while (!state->halted) {
        if (!mem->ready) continue;
        badd_word_t w = mem->read5(state->pc);
        state->pc++;

        uint8_t kind, code;
        bool is_delim;
        badd_decode(w, &kind, &code, &is_delim);

        if (kind == BADD_KIND_EXT && code == 0 && !pending_ext && !is_delim) {
            pending_ext = true;
            continue;
        }

        if (pending_ext) {
            uint8_t ext_op;
            if (badd_ext_resolve(w, true, &ext_op)) {
                if (gn < 16) group[gn++] = (ext_op << 3) | 0b100; /* ext marker */
            }
            pending_ext = false;
            continue;
        }

        if (is_delim) {
            /* Execute the collected group. */
            if (gn > 0) {
                uint8_t first = group[0] & 0x07;
                if (first == BADD_OP_VAR) {
                    exec_var(state, group + 1, gn - 1);
                } else if (first == BADD_OP_AD || first == BADD_OP_TI ||
                           first == BADD_EXT_MN || first == BADD_EXT_DV) {
                    write_acc(state, eval_expr(state, group, gn));
                } else if (first == BADD_OP_PR && gn > 1) {
                    uint8_t v = (group[1] & 0x07);
                    write_acc(state, state->reg[v]);
                }
            }
            gn = 0;
            continue;
        }

        if (gn < 16) {
            group[gn++] = w;
        }
    }
}

void badd_reset(badd_state_t *s)
{
    for (int i = 0; i < 8; i++) s->reg[i] = 0;
    s->acc = 0;
    s->led15 = 0;
    s->pc = 0;
    s->halted = false;
    s->status = 0;
}

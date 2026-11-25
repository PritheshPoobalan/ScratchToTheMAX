#include "johnsan_kernel.h"

#include <ctype.h>
#include <string.h>
#include <stdio.h>

/* Direct opcodes (tag 11). */
#define W_STRT 0b11000
#define W_AD   0b11001
#define W_TI   0b11010
#define W_PR   0b11011
#define W_VAR  0b11100
#define W_OPEN 0b11101
#define W_CLOSE 0b11110
#define W_DELIM 0b11111

/* Extended words: prefix 0b00000 then payload. */
#define PREFIX 0b00000
#define W_END  0b00001
#define W_MN   0b00010
#define W_DV   0b00011
#define W_EQU  0b00100
#define W_IF   0b00101
#define W_THEN 0b00110
#define W_GOTO 0b00111

static int emit(johnsan_token_t *out, size_t *n, size_t cap, const char *m,
                uint8_t word, bool is_ext)
{
    if (*n >= cap) return -1;
    out[*n].mnemonic = m;
    out[*n].word = word;
    out[*n].is_ext = is_ext;
    (*n)++;
    return 0;
}

static int is_letter_word(const char *tok)
{
    return strlen(tok) == 1 && tok[0] >= 'a' && tok[0] <= 'h';
}

static int is_number_word(const char *tok)
{
    if (strlen(tok) != 1) return 0;
    return tok[0] >= '0' && tok[0] <= '7';
}

int johnsan_opcode_of(const char *mnemonic)
{
    if (strcmp(mnemonic, "STRT") == 0) return W_STRT;
    if (strcmp(mnemonic, "AD") == 0) return W_AD;
    if (strcmp(mnemonic, "TI") == 0) return W_TI;
    if (strcmp(mnemonic, "PR") == 0) return W_PR;
    if (strcmp(mnemonic, "VAR") == 0) return W_VAR;
    if (strcmp(mnemonic, "%") == 0) return W_OPEN;
    if (strcmp(mnemonic, "$") == 0) return W_CLOSE;
    if (strcmp(mnemonic, "|") == 0) return W_DELIM;
    if (strcmp(mnemonic, "END") == 0) return W_END;
    if (strcmp(mnemonic, "MN") == 0) return W_MN;
    if (strcmp(mnemonic, "DV") == 0) return W_DV;
    if (strcmp(mnemonic, "EQU") == 0) return W_EQU;
    if (strcmp(mnemonic, "IF") == 0) return W_IF;
    if (strcmp(mnemonic, "THEN") == 0) return W_THEN;
    if (strcmp(mnemonic, "GOTO") == 0) return W_GOTO;
    return -1;
}

static int skip_spaces(const char **p)
{
    while (**p == ' ' || **p == '\t') (*p)++;
    return 0;
}

static int next_tok(const char **p, char *tok, size_t cap)
{
    skip_spaces(p);
    size_t i = 0;
    while (**p && **p != ' ' && **p != '\t' && **p != '|') {
        if (i + 1 >= cap) return -1;
        tok[i++] = *(*p)++;
    }
    tok[i] = '\0';
    skip_spaces(p);
    return (int)i;
}

int johnsan_translate_line(const char *line, johnsan_token_t *out,
                           size_t out_cap)
{
    size_t n = 0;
    const char *p = line;
    char tok[16];

    while (*p) {
        int len = next_tok(&p, tok, sizeof(tok));
        if (len <= 0) break;

        if (strcmp(tok, "|") == 0) break; /* statement terminator handled outside */

        int opcode = johnsan_opcode_of(tok);
        if (opcode >= 0) {
            if (opcode == W_END || opcode == W_MN || opcode == W_DV ||
                opcode == W_EQU || opcode == W_IF || opcode == W_THEN ||
                opcode == W_GOTO) {
                /* Extended opcode: emit prefix then payload word. */
                if (emit(out, &n, out_cap, tok, PREFIX, false) != 0) return -1;
                if (emit(out, &n, out_cap, tok, (uint8_t)opcode, true) != 0) return -1;
            } else {
                if (emit(out, &n, out_cap, tok, (uint8_t)opcode, false) != 0) return -1;
            }
        } else if (is_letter_word(tok)) {
            uint8_t word = 0b01000 | (uint8_t)(tok[0] - 'a');
            if (emit(out, &n, out_cap, tok, word, false) != 0) return -1;
        } else if (is_number_word(tok)) {
            uint8_t word = 0b10000 | (uint8_t)(tok[0] - '0');
            if (emit(out, &n, out_cap, tok, word, false) != 0) return -1;
        } else {
            fprintf(stderr, "johnsan_kernel: unknown token '%s'\n", tok);
            return -1;
        }
    }
    return (int)n;
}

int johnsan_translate_program(const char *source, uint8_t *words_out,
                              size_t words_cap)
{
    size_t wc = 0;
    const char *p = source;

    while (*p) {
        /* Extract one line up to the delimiter '|' or newline. */
        char line[256];
        size_t i = 0;
        while (*p && *p != '|' && *p != '\n') {
            if (i + 1 >= sizeof(line)) return -1;
            line[i++] = *p++;
        }
        line[i] = '\0';
        if (*p == '|') p++; /* consume delimiter */
        if (*p == '\n') p++; /* consume newline */

        johnsan_token_t toks[64];
        size_t tcap = sizeof(toks) / sizeof(toks[0]);
        int nt = johnsan_translate_line(line, toks, tcap);
        if (nt < 0) return -1;

        for (int k = 0; k < nt; k++) {
            if (wc >= words_cap) return -1;
            words_out[wc++] = toks[k].word;
        }
        if (wc >= words_cap) return -1;
        words_out[wc++] = W_DELIM;
    }
    return (int)wc;
}

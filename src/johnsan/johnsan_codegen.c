/* johnsan_codegen.c - Johnsan code generator */
#include <stdio.h>

/* Emit ThinkerBinary words for a parsed Johnsan program. */
void johnsan_codegen_emit(FILE *out, unsigned word) {
    fprintf(out, "%05u\n", word & 0x1F);
}

/* Words are written as five-bit zero-padded binary strings. */

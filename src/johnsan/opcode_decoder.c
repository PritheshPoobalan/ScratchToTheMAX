/* opcode_decoder.c - decode a 5-bit ThinkerBinary word */
#include <stdio.h>

/* Mirrors parts/johnsan_decode.v in software. */
const char *johnsan_decode_kind(unsigned word) {
    switch (word >> 3) {
    case 2: return "number";
    case 1: return "letter";
    case 3: return "opcode";
    default: return "extended";
    }
}

/* Unknown words default to extended kind for forward compatibility. */

/* encoder.c - Johnsan ThinkerBinary encoder */
#include <stdio.h>

/* Encode a Johnsan opcode into a 5-bit word. */
unsigned johnsan_encode_opcode(unsigned opcode) {
    return (3 << 3) | (opcode & 0x7);
}

/* Only opcodes 0-7 fit in the 3-bit payload. */

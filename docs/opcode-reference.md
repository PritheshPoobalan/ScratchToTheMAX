# BADD Opcode Reference

Complete encoding table for the 5-bit ThinkerBinary / RUN ISA.

## Direct syntax opcodes (tag 11)

| Mnemonic | Word | Hex | Meaning |
|----------|------|-----|---------|
| STRT | 11000 | 0x18 | Start marker |
| AD | 11001 | 0x19 | Add |
| TI | 11010 | 0x1A | Multiply (repeated addition) |
| PR | 11011 | 0x1B | Print to ACC and LED15 |
| VAR | 11100 | 0x1C | Declare / assign variable |
| % | 11101 | 0x1D | Open bracket |
| $ | 11110 | 0x1E | Close bracket |
| \| | 11111 | 0x1F | PARSE delimiter |

## Extended opcodes (prefix 00000 + payload word)

| Mnemonic | Prefix | Payload | Full encoding | Meaning |
|----------|--------|---------|---------------|---------|
| END | 00000 | 00001 | 00000 00001 | End program / halt |
| MN | 00000 | 00010 | 00000 00010 | Minus / subtract |
| DV | 00000 | 00011 | 00000 00011 | Divide |
| EQU | 00000 | 00100 | 00000 00100 | Equals / assignment |
| IF | 00000 | 00101 | 00000 00101 | Conditional test |
| THEN | 00000 | 00110 | 00000 00110 | Conditional branch target |
| GOTO | 00000 | 00111 | 00000 00111 | Unconditional jump |

## Token types

| Tag [4:3] | Type | Payload [2:0] | Word range |
|-----------|------|---------------|------------|
| 11 | Direct syntax | opcode index 000-111 | 11000-11111 |
| 10 | Number literal | value 0-7 | 10000-10111 |
| 01 | Letter variable | index 0-7 => a-h | 01000-01111 |
| 00 | Extended | prefix 00000 or payload 001-111 | 00000-00111 |

## Planned escape pages (documentation-only in GEN1)

Page 0: IM, EX, RD, WR, FC, WT, DEF, TO.
Page 1: LIB, CONT, FND, INJ, RUN, RPT, LOP, RET.

Encoding: 00000 00000 00ppp 00sss (four words per operation).

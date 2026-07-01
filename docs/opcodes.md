# Johnsan Opcode Reference

## Direct syntax opcodes (tag 11)

| binary | mnemonic | meaning |
|--------|----------|---------|
| 11000  | STRT     | start program |
| 11001  | AD       | add |
| 11010  | TI       | store/input |
| 11011  | PR       | print |
| 11100  | VAR      | declare variable |
| 11101  | %        | modulo |
| 11110  | $        | indirection |
| 11111  | \|       | PARSE delimiter |

## Extended opcodes (prefix 00000 + payload)

| payload | mnemonic | meaning |
|---------|----------|---------|
| 001     | END      | end program |
| 010     | MN       | move |
| 011     | DV       | divide |
| 100     | EQU      | equal |
| 101     | IF       | conditional |
| 110     | THEN     | branch target |
| 111     | GOTO     | unconditional jump |

Payload 000 is the reserved prefix/page escape.

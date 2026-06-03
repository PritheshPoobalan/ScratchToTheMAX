# Johnsan Language Specification

Johnsan is the human-readable source language for the BADD 5-bit RUN CPU.
Every Johnsan statement ends with the PARSE delimiter `|`. The system
microcode layer translates Johnsan source into a stream of 5-bit ThinkerBinary
words before the CPU ever sees it.

## Vocabulary

| Johnsan | Meaning | Encoding |
|---------|---------|----------|
| STRT | Start marker | direct `11000` |
| AD | Add | direct `11001` |
| TI | Times (multiply by repeated addition) | direct `11010` |
| PR | Print to ACC and LED15 | direct `11011` |
| VAR | Declare / assign variable | direct `11100` |
| % | Open bracket | direct `11101` |
| $ | Close bracket | direct `11110` |
| \| | PARSE delimiter | direct `11111` |
| END | End program / halt | ext `00000 00001` |
| MN | Minus / subtract | ext `00000 00010` |
| DV | Divide | ext `00000 00011` |
| EQU | Equals / assignment operator | ext `00000 00100` |
| IF | Conditional test | ext `00000 00101` |
| THEN | Conditional branch target | ext `00000 00110` |
| GOTO | Unconditional jump | ext `00000 00111` |

The remaining sixteen vocabulary entries (IM, EX, RD, WR, FC, WT, DEF, TO,
LIB, CONT, FND, INJ, RUN, RPT, LOP, RET) are reserved on the two planned
escape pages and are documentation-only in GEN1.

## Statement forms

```
STRT |
VAR a EQU 5 |
VAR b 3 |
VAR c EQU a AD b |
PR c |
END |
```

- `VAR` requires the next token to be a letter (`a`–`h`). `EQU` is optional.
- `PR` evaluates the tokens after `PR` and writes the result to ACC and LED15.
- A group whose first token is an arithmetic operator is a leading expression
  and writes ACC.
- `END` halts the core with status `0xFF`.

## Values and ranges

Variables `a`–`h` and ACC are 5 bits (0–31). Arithmetic wraps modulo 32.
BODMAS order applies: brackets first, then TI/MN/DV left to right, then AD left
to right. The GEN1 interpreter evaluates only the first operand-operator-operand
triple in a group; fully nested BODMAS is a microcode revision.

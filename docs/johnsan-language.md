# Johnsan Language Specification

Johnsan is the source language for the BADD CPU. It compiles to 5-bit
ThinkerBinary words of the RUN architecture.

## Word encoding

Each ThinkerBinary word is 5 bits:

| tag [4:3] | kind     | payload [2:0]         |
|-----------|----------|-----------------------|
| 11        | opcode   | direct opcode 000-111 |
| 10        | number   | literal 0-7           |
| 01        | letter   | variable a-h          |
| 00        | extended | prefix or opcode      |

## Direct syntax opcodes

- STRT (11000) - start program
- AD   (11001) - add
- TI   (11010) - store/input
- PR   (11011) - print
- VAR  (11100) - declare variable
- %    (11101) - modulo
- $    (11110) - indirection
- \|   (11111) - PARSE delimiter

## Extended opcodes

Extended opcodes are two words: prefix `00000` followed by a payload word:

- END  (001) - end program
- MN   (010) - move
- DV   (011) - divide
- EQU  (100) - equal
- IF   (101) - conditional
- THEN (110) - branch target
- GOTO (111) - unconditional jump

## Variables and literals

Variables `a`-`h` map to letter indices 0-7. Number literals 0-7 map directly.
Johnsan expressions are balanced before code generation: every operator has
matching operands and delimiters.

## Balancing rules

A Johnsan program is balanced when every opening delimiter has a matching
closing delimiter and every operator has the operands it requires. The compiler
rejects unbalanced programs before code generation.

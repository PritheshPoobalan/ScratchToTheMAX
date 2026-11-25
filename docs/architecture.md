# BADD Architecture

## Overview

BADD (Binary Arithmetic Dual-Domain) is a proof-of-concept 5-bit CPU built
around the ThinkerBinary encoding. The native word is exactly five bits:

- `word[4:3]` — type tag (`11` direct syntax, `10` number, `01` letter,
  `00` extended)
- `word[2:0]` — payload (opcode index, literal 0–7, variable index a–h,
  or extended payload)

## Blocks

- **Top level** — `badd_chip.v`: ALU, memory controller, SATA, LED15, INJ,
  BOR, MPU.
- **Johnsan decoder** — `src/verilog/johnsan_decode.v`: stateless decode of
  one 5-bit word into `kind`, `code`, `is_delim`; `johnsan_decode_ext`
  resolves extended opcodes with the pending-prefix rule.
- **Memory** — bit-addressable 6T SRAM, hierarchical decoder, sense amps,
  14-bit address space (16K words of 5-bit data).
- **eFlash** — dual bank (A/B), 4K words each, INJ live update, commit at
  `0x0FFF`.
- **BOR** — brown-out reset asserts reset and `flash_lock` while supply sags.
- **MPU** — protects window `0x0F00`–`0x0FFF` from writes.
- **PUF** — SRAM power-up state fingerprint, 256-entry x 64-bit table model.

## Known PoC limitations

SATA, IRQ, JTAG, stores (WR/RD), branch execution (IF/THEN/GOTO), MPU
fault observation, and eFlash bank switching are not wired in GEN1. These are
implementation gaps, not encoding gaps.

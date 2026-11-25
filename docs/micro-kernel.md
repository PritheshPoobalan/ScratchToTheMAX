# System Micro-Kernel Design

The BADD micro-kernel sits between the Johnsan source language and the 5-bit
hardware token stream. It is stored in eFlash and is updatable live through the
INJ dual-bank mechanism.

## Pipeline

```
Johnsan source
      |
      v
Translator / system microcode  (eFlash, updatable)
      |
      v
5-bit ThinkerBinary token stream
      |
      v
johnsan_decode  ->  kind / code / is_delim / ext_op
      |
      v
CPU group interpreter  ->  ALU / registers / LED15
      |
      v
BADD silicon: SRAM, eFlash, SATA, PUF, MPU
```

## Responsibilities

1. **Keyword mapping** — owns the Johnsan-to-ThinkerBinary table. A revision can
   change a mnemonic or add an escape-page operation without a new chip mask.
2. **Live update** — can rewrite a program image in eFlash while the active bank
   keeps executing; a commit write to `0x0FFF` toggles the active bank.
3. **Translation contract** — direct opcode values are fixed because they are
   wired into the decoder and CPU comparison logic.

## Micro-kernel source

The C reference implementation of the micro-kernel fetch/decode/execute loop
lives in `src/kernel/`. The Johnsan kernel (translator) lives next to it.

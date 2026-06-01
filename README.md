# ScratchToTheMAX

BADD CPU — a 5-bit ThinkerBinary / RUN architecture proof of concept, with the
Johnsan source language, the Johnsan kernel, and a system micro-kernel layer.

## What this is

ScratchToTheMAX is the open-source home of the BADD MicroBeep R-A PoC (GEN1),
a minimal 5-bit native-word CPU written for learners, FPGA implementers, and
system-microcode authors. The design is intentionally tiny so that a single
person can read the whole thing:

- **5-bit ThinkerBinary words** — type tag in bits [4:3], payload in [2:0].
- **Johnsan language** — STRT, VAR, AD, TI, PR, END, and friends, encoded to
  ThinkerBinary words by the system microcode layer.
- **johnsan_decode** — stateless 5-bit word decoder in Verilog.
- **Micro-kernel** — fetch/decode/execute loop written in C, plus the Johnsan
  kernel that translates Johnsan source into token streams.
- **BADD chip RTL** — ALU, bit-addressable SRAM controller, BOR, MPU, PUF, and
  eFlash dual-bank live update via INJ.

## Repository layout

```
docs/          ISA reference, Johnsan language spec, micro-kernel design
examples/      Johnsan example programs (.johnsan)
src/kernel/    Micro-kernel and Johnsan kernel sources (C)
src/verilog/   Johnsan decoder and BADD Verilog modules
tests/         Verilog testbenches and C test harnesses
badd_chip.v    Top-level BADD chip Verilog
badd_tb.v      Chip testbench
badd_sim       Built simulation binary
badd_tb        Built testbench binary
```

## Build and run

Verilog testbenches build with Icarus Verilog:

```bash
iverilog -g2012 -o tb_johnsan_decode.vvp \
    src/verilog/tb_johnsan_decode.v src/verilog/johnsan_decode.v
vvp tb_johnsan_decode.vvp
```

The C micro-kernel builds with any C99 compiler:

```bash
cc -Wall -Wextra -o micro_kernel src/kernel/micro_kernel.c src/kernel/johnsan_kernel.c
```

## License

MIT. See LICENSE.

## Public open-source rule

No emojis in commit messages. This repository is public; every commit adds
documentation, code, tests, or examples.

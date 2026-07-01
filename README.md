# ScratchToTheMAX

ScratchToTheMAX - 64-bit OS with BADD CPU, Johnsan language, Johnsan kernel,
micro-kernel architecture.

This repository is a public open-source exploration of a small clean-sheet
computing stack. It brings together a 5-bit ThinkerBinary CPU core (BADD), the
Johnsan source language that targets it, a Johnsan kernel written in C, and a
micro-kernel architecture that runs drivers and services as user-space servers.

## Contents

- `badd_chip.v`          - BADD CPU RTL: ThinkerBinary ALU, memory controller,
                           BOR/MPU/PUF security blocks, INJ live-update path.
- `parts/johnsan_decode.v` - Johnsan 5-bit word opcode decoder.
- `parts/badd_sram.v`    - bit-addressable SRAM controller.
- `parts/advanced_mode.v` - advanced execution mode unit.
- `parts/bodmas_eval.v`  - BODMAS expression evaluator.
- `tests/`               - software tests and simulation harnesses.
- `src/kernel/`          - Johnsan kernel (scheduler, memory, IPC).
- `src/johnsan/`         - Johnsan compiler frontend and code generator.
- `docs/`                - architecture and language documentation.
- `examples/`            - example Johnsan programs.

## Architecture

ScratchToTheMAX follows a micro-kernel design. The Johnsan kernel is kept
minimal: scheduling, address spaces, inter-process communication, and
interrupt handling. Device drivers, filesystems, and the shell run as
user-space servers that talk to the kernel through message passing. The whole
stack targets the BADD CPU, whose 5-bit ThinkerBinary words are produced by the
Johnsan compiler.

## BADD CPU

The BADD CPU is a 5-bit native-word core using the ThinkerBinary encoding and
the RUN architecture. Each instruction word is exactly 5 bits: a 2-bit type tag
and a 3-bit payload. Tags select between number literals, letter variables,
direct syntax opcodes, and extended opcodes. The core includes an ALU, a
bit-addressable SRAM controller, BOR/MPU/PUF security blocks, and an INJ
eFlash live-update path.

## Johnsan language

Johnsan is the source language for BADD. It compiles to ThinkerBinary words and
supports variables (a-h), number literals (0-7), direct syntax opcodes
(STRT, AD, TI, PR, VAR), and extended opcodes (END, MN, DV, EQU, IF, THEN,
GOTO). Programs are balanced expressions executed by the RUN machine.

## Getting started

The BADD chip is simulatable with Icarus Verilog:

    iverilog -o badd_tb badd_chip.v badd_tb.v
    vvp badd_tb

The Johnsan kernel builds with a standard C compiler:

    cc -c src/kernel/kern_main.c -o build/kern_main.o

See `docs/build-run.md` for detailed build and run instructions.

## Roadmap

- BADD CPU PoC simulation (complete)
- Johnsan language specification and encoder
- Johnsan kernel: scheduler, memory, IPC
- Micro-kernel server model
- Self-hosting Johnsan compiler

## Contributing

See `CONTRIBUTING.md` for how to report bugs, submit patches, and propose
architecture changes. All contributions are welcome.

## Project structure

- `docs/`           - architecture, language, ISA, security, build guides.
- `src/kernel/`     - Johnsan kernel implementation in C.
- `src/johnsan/`    - Johnsan compiler frontend and code generator.
- `parts/`          - Verilog parts: decoder, SRAM, advanced mode, BODMAS.
- `tests/`          - software unit tests and runner.
- `examples/`       - example Johnsan programs.

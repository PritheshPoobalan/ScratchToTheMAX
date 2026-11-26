# ScratchToTheMAX

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![CI](https://github.com/PritheshPoobalan/ScratchToTheMAX/actions/workflows/ci.yml/badge.svg)](https://github.com/PritheshPoobalan/ScratchToTheMAX/actions/workflows/ci.yml)
[![GitHub stars](https://img.shields.io/github/stars/PritheshPoobalan/ScratchToTheMAX?style=flat)](https://github.com/PritheshPoobalan/ScratchToTheMAX/stargazers)
[![GitHub forks](https://img.shields.io/github/forks/PritheshPoobalan/ScratchToTheMAX?style=flat)](https://github.com/PritheshPoobalan/ScratchToTheMAX/network)

**BADD CPU Architecture** — A 5-bit ThinkerBinary RISC-V compatible CPU with the Johnsan programming language, compiler, and micro-kernel operating system. An educational and research project featuring complete RTL (Verilog), ISA specification, kernel implementation, examples, and tests.

## Overview

ScratchToTheMAX is a clean-sheet computing stack built from the ground up:

| Component | Description |
|-----------|-------------|
| **BADD CPU** | 5-bit native-word core using ThinkerBinary encoding and RUN architecture |
| **Johnsan Language** | Source language compiling to ThinkerBinary words with variables, literals, and opcodes |
| **Johnsan Compiler** | Frontend and code generator targeting BADD CPU |
| **Micro-kernel OS** | Minimal kernel with scheduling, memory management, IPC, and user-space servers |
| **Verilog RTL** | Complete hardware implementation including ALU, SRAM, security blocks (BOR/MPU/PUF) |

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    User Space Servers                       │
│  (Drivers, Filesystems, Shell, Applications)                │
├─────────────────────────────────────────────────────────────┤
│                    Johnsan Micro-kernel                      │
│         (Scheduler, Memory, IPC, Interrupts)                │
├─────────────────────────────────────────────────────────────┤
│                    Johnsan Compiler                          │
│           (Frontend → Code Generator → ThinkerBinary)       │
├─────────────────────────────────────────────────────────────┤
│                    BADD CPU (Verilog RTL)                    │
│    (ALU, Bit-addressable SRAM, BOR/MPU/PUF, INJ eFlash)    │
└─────────────────────────────────────────────────────────────┘
```

### BADD CPU

- **Word size**: 5 bits (ThinkerBinary encoding)
- **Architecture**: RUN (Reduced Universal Notation)
- **Instruction format**: 2-bit type tag + 3-bit payload
- **Tags**: Number literals, letter variables, direct syntax opcodes, extended opcodes
- **Features**: ALU, bit-addressable SRAM controller, BOR/MPU/PUF security blocks, INJ live-update path

### Johnsan Language

- **Variables**: Single-letter (a-h)
- **Literals**: 0-7 (3-bit)
- **Direct opcodes**: `STRT`, `AD`, `TI`, `PR`, `VAR`
- **Extended opcodes**: `END`, `MN`, `DV`, `EQU`, `IF`, `THEN`, `GOTO`
- **Execution**: Balanced expressions on RUN machine

## Quick Start

### Prerequisites

- **Icarus Verilog** (for CPU simulation): `sudo apt-get install iverilog`
- **C Compiler** (for kernel): `gcc` or `clang`
- **Make**: `sudo apt-get install make`

### Simulate BADD CPU

```bash
# Clone the repository
git clone https://github.com/PritheshPoobalan/ScratchToTheMAX.git
cd ScratchToTheMAX

# Run CPU simulation
make sim
# Or manually:
iverilog -o badd_tb badd_chip.v badd_tb.v
vvp badd_tb
```

### Build Johnsan Kernel

```bash
# Build kernel objects
make kernel
# Or manually:
mkdir -p build
cc -c src/kernel/kern_main.c -o build/kern_main.o
cc -c src/kernel/kern_sched.c -o build/kern_sched.o
cc -c src/kernel/kern_ipc.c -o build/kern_ipc.o
cc -c src/kernel/kern_mem.c -o build/kern_mem.o
```

### Run Tests

```bash
# Run all tests
make test

# Run specific test
./tests/run_tests.sh
```

### Compile Johnsan Programs

```bash
# Compile a Johnsan program
./src/johnsan/johnsan_compiler examples/adder.johnsan

# Run example
cd examples
./run_example.sh adder.johnsan
```

## Project Structure

```
ScratchToTheMAX/
├── .github/
│   └── workflows/           # GitHub Actions CI/CD
├── docs/                    # Architecture and language documentation
│   ├── architecture.md
│   ├── build-run.md
│   ├── BADD_ISA.md
│   ├── security-model.md
│   └── ...
├── examples/                # Example Johnsan programs
│   ├── adder.johnsan
│   ├── arithmetic.johnsan
│   └── ex001-005.johnsan
├── parts/                   # Verilog modules
│   ├── johnsan_decode.v     # Opcode decoder
│   ├── badd_sram.v          # Bit-addressable SRAM
│   ├── advanced_mode.v      # Advanced execution mode
│   └── bodmas_eval.v        # BODMAS expression evaluator
├── src/
│   ├── kernel/              # Johnsan kernel (C)
│   │   ├── kern_main.c
│   │   ├── kern_sched.c
│   │   ├── kern_ipc.c
│   │   └── kern_mem.c
│   ├── johnsan/             # Johnsan compiler
│   │   └── johnsan_compiler.c
│   └── verilog/             # Additional Verilog sources
├── tests/                   # Test suites
│   ├── kernel_test.c
│   ├── run_tests.sh
│   └── *.v (Verilog testbenches)
├── badd_chip.v              # Main BADD CPU RTL
├── badd_chip.verified.v     # Verified version
├── badd_tb.v                # Testbench
├── Makefile                 # Build automation
├── CONTRIBUTING.md
├── SECURITY.md
├── CODEOWNERS
├── LICENSE
└── CHANGELOG.md
```

## Documentation

- [Architecture Overview](docs/architecture.md)
- [BADD ISA Specification](docs/BADD_ISA.md)
- [Build and Run Guide](docs/build-run.md)
- [Security Model](docs/security-model.md)
- [Research Findings](docs/BADD_RESEARCH_FINDINGS.md)

## Roadmap

- [x] BADD CPU PoC simulation (complete)
- [x] Johnsan language specification and encoder
- [x] Johnsan kernel: scheduler, memory, IPC
- [x] Micro-kernel server model
- [ ] Self-hosting Johnsan compiler
- [ ] FPGA synthesis target
- [ ] Formal verification of security blocks

## Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on:

- Reporting bugs
- Submitting patches
- Proposing architecture changes
- Code style and commit conventions

## Security

See [SECURITY.md](SECURITY.md) for our security policy and how to report vulnerabilities. The BADD CPU includes hardware security features (BOR, MPU, PUF) documented in [docs/security-model.md](docs/security-model.md).

## License

MIT License — see [LICENSE](LICENSE) for details.

## Acknowledgments

Thanks to all contributors improving the BADD CPU, Johnsan language, and micro-kernel architecture. This project is built for education and research in computer architecture.

---

**Keywords**: `cpu` `verilog` `rtl` `risc-v` `computer-architecture` `operating-system` `kernel` `compiler` `johnsan` `badd` `microkernel` `educational` `research` `hardware` `isa` `cpu-design`
# BADD MicroBeep R-A PoC Gen 1 — Target Specification

## Chip Identity
- **Name:** MicroBeep R-A PoC (MicroBeep Research Architecture — Proof of Concept)
- **Generation:** GEN1 (first-generation BADD chip)
- **Division:** BADD Division under PX Tech Solutions Sole Proprietor
- **Target Audience:** Young learners / educational use
- **Philosophy:** Zero-burn philosophy, all IP flows through PX Tech Solutions Sole Proprietor

## Core Architecture

### RUN ISA (Reduced Instruction Set Computer ISA)
- **Word size:** 32-bit (XLEN=32)
- **Register file:** 32 general-purpose registers (x1-x31, x0 hardwired to zero)
- **Instruction format:** 32-bit RISC-like encoding
  - Opcode: bits 6:0 (7 bits)
  - rd (destination): bits 11:7 (5 bits)
  - rs1 (source 1): bits 19:15 (5 bits)
  - rs2 (source 2): bits 24:20 (5 bits)
  - func3: bits 14:12 (3 bits)
  - func7: bits 31:25 (7 bits)
- **Key operations:** ADD, SUB, AND, OR, XOR, SLL (shift left), SRL (shift right), SLT (set less than), SLTU (set less than unsigned), LW (load word), SW (store word)
- **Purpose:** Minimal RISC-like core for educational FPGA implementation

### ADDISA (ADD ISA)
- **Purpose:** CUDA/Vulkan/OpenGL translation layer for BADD CPU iGPU
- **Function:** Intercepts CUDA API calls and translates to native BADD silicon instructions
- **Enables:** AI model processing, hardware synthesis, local LLM inference on BADD iGPU

### SRAM PUF (Static RAM Physical Unclonable Function)
- **Purpose:** Hardware security primitive — device fingerprint from SRAM power-up state
- **Cells:** 64 SRAM cells (configurable)
- **Output:** Challenge-response pairs
- **Property:** Unique to each silicon chip due to manufacturing variations
- **No additional hardware needed:** Uses existing SRAM cells

## Design Goals (Educational / FPGA)

### Target Implementation
- **Synthesizable Verilog** for FPGA development
- **Simulable with Icarus Verilog** (iverilog) or Verilator
- **Educational transparency:** Every module documented with comments
- **Modular sub-designs:**
  1. **SRAM PUF module** — 64-cell challenge/response
  2. **BADD CPU core** — minimal RISC implementation
  3. **Memory controller** — SRAM/Flash interface
  4. **Top-level chip** — combines all sub-modules

### Hardware Development Rig
- **Host:** PX-HOME1-SERVER1 (Lenovo ThinkCentre + RTX 2080 + 48GB RAM + 6TB NAS)
- **Simulation tools:** Verilator, Icarus Verilog (iverilog), GTKWave
- **AI tooling:** Local AI tooling generates Verilog/System Johnsan logic
- **Logic simulation:** Verifies MicroBeep R-A timing & gate execution
- **Offline AI development:** RTX 2080 runs synthesis models without cloud API fees

### Milestones
1. ✅ Verilog code created (badd_chip.v) — 336 lines, 3 sub-modules
2. ✅ Logic simulator verification (Verilator/iverilog)
3. ⏳ Cradle CIP Spark grant application package (design specs ready)
4. ⏷ Physical silicon realization (post-funding / PX International SDN Bhd incorporation)

## Verification & Simulation Setup

### Icarus Verilog Testbench
The `badd_chip.v` includes testable modules that can be simulated with iverilog:

```bash
iverilog -o badd_chip_sim badd_chip.v
vvp badd_chip_sim
```

### Key Simulable Features
- SRAM PUF power-up state initialization and challenge-response
- BADD CPU register file read/write behavior
- Instruction memory fetch/decode/execute cycle
- Memory controller read/write to external SRAM
- LED indicator assignments (PUF response parity + PC bits)
- UART transmit (idle high)

### Gaps from Target Specification
| Requirement | Current Status | Notes |
|---|---|---|
| 32-bit RUN ISA | ✅ Implemented | `badd_cpu` module with XLEN=32 |
| 64-cell SRAM PUF | ✅ Implemented | `sram_puf` module with NUM_CELLS=64 |
| Memory controller | ✅ Implemented | `memory_controller` module |
| FPGA-synthesizable | ✅ Mostly | Iverilog simulation ready |
| Verilator-compatible | ⚠ Partial | Some `real` time constructs; convert to `time` for full compatibility |
| Young learner friendly | ✅ Comments included | All modules have explanatory comments |
| Cradle CIP Spark ready | ✅ Design specs documented | BADD_RESEARCH_FINDINGS.md created |

## Context Alignment
- **PX Tech Solutions Sole Proprietor** — Current legal entity (SSM: 202603038511)
- **BADD Division** — Microchip + ISA + SiliconDev + SiliconCreate
- **RUN ISA** — Source code on 6TB NAS, implemented in Verilog
- **SRAM PUF** — Hardware security for edge nodes, complements VELOX 10x Cascade Encryption
- **MicroBeep R-A PoC** — RTL/Verilog/microcode, logic simulator verification
- **ADDISA ISA** — CUDA-to-iGPU translation, runs on BADD CPU iGPU
- **Cradle CIP Spark** — Grant pathway for MicroBeep R-A PoC commercialization
- **Zero-burn philosophy** — RM 21/month net burn, ~10-month runway on RM 162 buffer
- **PX-HOME1-SERVER1** — Development rig: RTX 2080 + 48GB RAM + Verilator for simulation
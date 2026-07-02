# Build and Run Instructions

## Simulating the BADD CPU

The Verilog RTL simulates with Icarus Verilog.

    iverilog -o badd_tb badd_chip.v badd_tb.v
    vvp badd_tb

To run the chip-level testbench:

    iverilog -o tb_badd_chip tb_badd_chip.v badd_chip.v
    vvp tb_badd_chip

## Building the Johnsan kernel

    cc -I src/kernel -c src/kernel/kern_main.c -o build/kern_main.o
    cc -I src/kernel -c src/kernel/kern_sched.c -o build/kern_sched.o
    cc -I src/kernel -c src/kernel/kern_mem.c -o build/kern_mem.o
    cc -I src/kernel -c src/kernel/kern_ipc.c -o build/kern_ipc.o

## Running tests

    python3 tests/test_alu.py
    python3 tests/test_decode.py

## Verification

Run the full test suite:

    ./tests/run_tests.sh

Simulate all Verilog testbenches and inspect the waveform output.

## Requirements

- Icarus Verilog (iverilog) for RTL simulation.
- A C compiler (cc/gcc/clang) for the kernel.
- Python 3 for software tests.

## Continuous verification

Run tests and simulation on every change before opening a pull request.

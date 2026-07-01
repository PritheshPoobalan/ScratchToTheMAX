# Porting Guide

## Porting to new hardware

The Johnsan kernel assumes a BADD-compatible CPU with a 5-bit ThinkerBinary
word, an MPU, and a timer interrupt. To port to a new target:

1. Implement the BADD CPU or a cycle-accurate model.
2. Provide `kern_trap` and timer interrupt wiring.
3. Implement the frame allocator for the target memory map.
4. Bring up the serial server as the first user-space server.

## Toolchain

A hosted C compiler and Icarus Verilog are sufficient to develop and test the
kernel and compiler on a development machine.

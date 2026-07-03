# Memory Map

## Physical memory

The BADD memory controller is bit-addressable with 16384 locations of 5 bits
each (ThinkerBinary words). Addresses are 14 bits.

## Kernel layout

- 0x0000 - 0x03FF: kernel code and static data
- 0x0400 - 0x07FF: kernel stack
- 0x0800 - 0x0BFF: scheduler structures
- 0x0C00 - 0x0FFF: IPC message buffers
- 0x1000 - 0x3FFF: user servers and applications
- 0x4000 - 0x7FFF: device registers (MMIO)

## Protection

The MPU restricts user-mode access to kernel ranges. Attempts to execute or
write kernel memory from user mode trap to the kernel.

## Device registers

MMIO registers live above 0x4000 and are accessed through load/store
instructions that the MPU guards for user-mode code.

# BOR, MPU, and PUF

## BOR — brown-out reset

The BOR compares vdd_sense against vref:

| Condition | bor_reset_n | flash_lock |
|-----------|-------------|------------|
| vdd_sense < vref | 0 (reset) | 1 (writes blocked) |
| vdd_sense >= vref | 1 (running) | 0 (writable) |

bor_reset_n gates the CPU reset; flash_lock gates eFlash programming. A supply
sag during an eFlash update prevents a partially programmed bank from being
committed.

## MPU — memory protection unit

Watches the 14-bit address bus and write strobe. Writes inside 0x0F00–0x0FFF
are blocked and raise mpu_fault. Advisory only in the PoC.

## PUF — physically unclonable function

At power-up each 6T SRAM cell settles to 0 or 1 from manufacturing mismatch,
giving a stable per-die fingerprint. The PoC model provides:

- 8-bit challenge selecting a table entry
- 256-entry x 64-bit response table
- response = table[idx] XOR table[idx+1]
- start / ready handshake

In silicon the 64 response bits come directly from 64 SRAM cells at power-up.
The PUF can gate eFlash unlock, seed key derivation, or attest device identity.

# BADD ISA Summary

## ThinkerBinary word

- Native word: 5 bits.
- Type tag: bits [4:3].
- Payload: bits [2:0].

## Addressing

Variables a-h (8 registers). Number literals 0-7. Extended opcodes use a prefix
word plus a payload word, allowing a small encoding space to express a useful
instruction set.

## Security blocks

- BOR: brown-out reset.
- MPU: memory protection unit.
- PUF: physically unclonable function for device identity.

## Live update

The INJ path supports eFlash dual-bank live updates so the running system can
be patched without a cold reboot.

## Reference

See `BADD_ISA.md` for the full instruction-set reference.

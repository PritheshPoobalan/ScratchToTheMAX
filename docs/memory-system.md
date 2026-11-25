# BADD Memory System

## 6T SRAM bitcells

Each memory cell uses four transistors in two cross-coupled inverters forming
the storage loop, plus two access transistors connecting the cell to a bitline
pair during read or write.

## Bit-addressable array

The GEN1 PoC models 16,384 word lines of 5-bit data, addressed by a 14-bit
address bus (0x0000–0x3FFF), with mem_bit_mode asserted for bit-granular
access.

## Hierarchical decoder

1. Predecode the address into row-group and column fields.
2. Global row decoder selects a row block.
3. Local row decoders select one word line.
4. Column multiplexer selects the bitline group.

## Memory controller states

| State | Action |
|-------|--------|
| IDLE | ready=1; wait for re or we |
| DE | Decode address |
| SE | Sense selected location |
| RD | Latch read data |
| WR | Write data |
| DN | Assert ready, return to IDLE |

## Protected window

The MPU blocks writes to 0x0F00–0x0FFF (system microcode, translation table,
recovery vectors). Writes in this window raise mpu_fault. Reads are not
blocked in the PoC.

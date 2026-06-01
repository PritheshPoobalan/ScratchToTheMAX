# BADD CPU — RUN Architecture ISA Reference

**Device:** BADD MicroBeep R-A PoC (GEN1)
**Native word:** 5 bits (ThinkerBinary)
**Architecture:** RUN (Reduced Unified Notation), Johnsan source language
**Audience:** young learners, FPGA implementers, and system-microcode authors

This document is the instruction-set reference for the 5-bit BADD core. It covers
the word format, the complete Johnsan-to-ThinkerBinary translation, the execution
model, the balancing rules for expressions, the memory subsystem, the system
Johnsan microcode layer, the eFlash live-update path, the security blocks, the
BAD INTERSIGN 100 package interface, and a fully encoded worked example.

Two conventions are used throughout:

- **Implemented** means the encoding is exercised by the RTL and the reference
  decoder in `parts/johnsan_decode.v`.
- **Planned / reserved** means the code point is assigned by this document but
  is not yet implemented in the PoC decoder or silicon.

---

## Contents

1. [The 5-bit word](#1-the-5-bit-word)
2. [Johnsan to ThinkerBinary translation](#2-johnsan-to-thinkerbinary-translation)
3. [Planned extended codes](#3-planned-extended-codes)
4. [Execution model](#4-execution-model)
5. [Memory system](#5-memory-system)
6. [System Johnsan microcode layer](#6-system-johnsan-microcode-layer)
7. [eFlash dual-bank live update via INJ](#7-eflash-dual-bank-live-update-via-inj)
8. [BOR, MPU, and PUF](#8-bor-mpu-and-puf)
9. [BAD INTERSIGN 100 pin interface](#9-bad-intersign-100-pin-interface)
10. [Worked example program](#10-worked-example-program)
11. [Reference implementation](#11-reference-implementation)
12. [Known PoC limitations](#12-known-poc-limitations)

---

## 1. The 5-bit word

Every token in the instruction stream is exactly one 5-bit word. The two high
bits are the **type tag**; the three low bits are the **payload**.

| Bits `[4:3]` | Type tag | Payload `[2:0]` meaning | Word range |
|---|---|---|---|
| `11` | Syntax / direct opcode | direct opcode index `000`–`111` | `11000`–`11111` |
| `10` | Number literal | unsigned value `0`–`7` | `10000`–`10111` |
| `01` | Letter / variable | variable index `0`–`7` → `a`–`h` | `01000`–`01111` |
| `00` | Extended opcode | prefix `00000`, or payload `001`–`111` | `00000`–`00111` |

### 1.1 Type tags

| Tag | Name | Interpretation |
|---|---|---|
| `11` | Syntax / Opcode | Direct Johnsan command. The payload is the opcode number. |
| `10` | Number | The payload is the literal value, 0 through 7. |
| `01` | Letter | The payload is a register index: `000`=a, `001`=b, … `111`=h. |
| `00` | Extended | A prefix word (`00000`) or the payload word of an extended opcode. |

### 1.2 The parse delimiter

`11111` is the **PARSE delimiter**, written `|` in Johnsan. It is a direct
syntax word (tag `11`, payload `111`) and it sets the decoder's `is_delim`
output. It is never stored in a group buffer: it terminates the current group
and triggers execution. The same byte value is what the CPU compares against
while fetching.

### 1.3 Extended words and the pending-prefix rule

An extended opcode is two consecutive words:

```
00000          prefix (tag 00, payload 000)
00kkk          payload word; kkk = 001..111 selects the operation
```

The second word also has tag `00`, because every payload value from 1 to 7
fits in three bits. It is **not** a second prefix: the parser remembers that a
prefix is pending and consumes exactly one following word as the payload,
regardless of that word's tag bits. The payload word's `[4:3]` bits are
therefore semantically ignored while a prefix is pending.

The reference decoder models this with two modules:

- `johnsan_decode` — stateless decode of one word into `kind`, `code`, `is_delim`.
- `johnsan_decode_ext` — same view plus `ext_valid`, `ext_op`, `ext_hit`, `is_prefix`.

`kind[1:0]` is `0`=number, `1`=letter, `2`=direct syntax, `3`=extended
(prefix or resolved payload).

---

## 2. Johnsan to ThinkerBinary translation

### 2.1 Direct syntax opcodes (tag `11`)

| Johnsan | Meaning | 5-bit word | Hex | Payload |
|---|---|---|---|---|
| `STRT` | Start program / start marker | `11000` | `0x18` | `000` |
| `AD` | Add | `11001` | `0x19` | `001` |
| `TI` | Times / multiply (repeated addition) | `11010` | `0x1A` | `010` |
| `PR` | Print (to accumulator and LED15) | `11011` | `0x1B` | `011` |
| `VAR` | Declare / assign variable | `11100` | `0x1C` | `100` |
| `%` | Open bracket | `11101` | `0x1D` | `101` |
| `$` | Close bracket | `11110` | `0x1E` | `110` |
| `\|` | PARSE delimiter | `11111` | `0x1F` | `111` |

### 2.2 Extended opcodes (tag `00` prefix + payload)

| Johnsan | Meaning | Prefix | Payload word | Full 10-bit encoding |
|---|---|---|---|---|
| `END` | End program / halt | `00000` | `00001` | `00000 00001` |
| `MN` | Minus / subtract | `00000` | `00010` | `00000 00010` |
| `DV` | Divide | `00000` | `00011` | `00000 00011` |
| `EQU` | Equals / assignment operator | `00000` | `00100` | `00000 00100` |
| `IF` | Conditional test | `00000` | `00101` | `00000 00101` |
| `THEN` | Conditional branch target | `00000` | `00110` | `00000 00110` |
| `GOTO` | Unconditional jump | `00000` | `00111` | `00000 00111` |

### 2.3 Complete vocabulary coverage

The book's full Johnsan vocabulary has 29 entries. Six are direct syntax, seven
fit the primary extended field, and the remaining 16 are assigned to the
planned escape pages in Section 3.

| # | Johnsan | Meaning | Current encoding | Status |
|---|---|---|---|---|
| 1 | `AD` | Add | direct `11001` | Implemented |
| 2 | `MN` | Subtract | ext `010` | Implemented |
| 3 | `DV` | Divide | ext `011` | Implemented |
| 4 | `TI` | Multiply | direct `11010` | Implemented |
| 5 | `IM` | Import | page 0, sub 0 | Planned |
| 6 | `EX` | Export | page 0, sub 1 | Planned |
| 7 | `PR` | Print | direct `11011` | Implemented |
| 8 | `RD` | Read | page 0, sub 2 | Planned |
| 9 | `WR` | Write | page 0, sub 3 | Planned |
| 10 | `FC` | Function | page 0, sub 4 | Planned |
| 11 | `VAR` | Variable | direct `11100` | Implemented |
| 12 | `END` | End / halt | ext `001` | Implemented |
| 13 | `STRT` | Start | direct `11000` | Implemented |
| 14 | `WT` | Wait | page 0, sub 5 | Planned |
| 15 | `IF` | If | ext `101` | Implemented |
| 16 | `THEN` | Then | ext `110` | Implemented |
| 17 | `DEF` | Define | page 0, sub 6 | Planned |
| 18 | `GOTO` | Jump | ext `111` | Implemented |
| 19 | `EQU` | Equals | ext `100` | Implemented |
| 20 | `TO` | Transfer / assign-to | page 0, sub 7 | Planned |
| 21 | `LIB` | Library | page 1, sub 0 | Planned |
| 22 | `CONT` | Continue | page 1, sub 1 | Planned |
| 23 | `FND` | Find | page 1, sub 2 | Planned |
| 24 | `INJ` | Inject | page 1, sub 3 | Planned |
| 25 | `RUN` | Run | page 1, sub 4 | Planned |
| 26 | `RPT` | Repeat | page 1, sub 5 | Planned |
| 27 | `LOP` | Loop | page 1, sub 6 | Planned |
| 28 | `RET` | Return | page 1, sub 7 | Planned |
| 29 | `\|=PARSE` | Parse delimiter | direct `11111` | Implemented |

Planned counts: 6 direct implemented + 7 extended implemented + 16 planned = 29.

---

## 3. Planned extended codes

The primary extended field is only three bits wide, so only seven operations
fit beside the installed seven (`END`, `MN`, `DV`, `EQU`, `IF`, `THEN`,
`GOTO`). The remaining 16 vocabulary entries need a second level.

### 3.1 Escape-page encoding (planned)

A two-page escape is reserved as follows. It costs four words per operation and
is **not** implemented in the PoC decoder.

```
00000          extended prefix
00000          escape (payload 000; the primary field's unused code point)
00ppp          page selector: 000 = page 0, 001 = page 1, 010..111 reserved
00sss          sub-opcode 000..111 within the page
```

### 3.2 Page 0 — data and structure

| Sub-op | Johnsan | Meaning |
|---|---|---|
| `000` | `IM` | Import |
| `001` | `EX` | Export |
| `010` | `RD` | Read |
| `011` | `WR` | Write |
| `100` | `FC` | Function |
| `101` | `WT` | Wait |
| `110` | `DEF` | Define |
| `111` | `TO` | Transfer / assign-to |

### 3.3 Page 1 — control and system

| Sub-op | Johnsan | Meaning |
|---|---|---|
| `000` | `LIB` | Library |
| `001` | `CONT` | Continue |
| `010` | `FND` | Find |
| `011` | `INJ` | Inject (eFlash live update) |
| `100` | `RUN` | Run |
| `101` | `RPT` | Repeat |
| `110` | `LOP` | Loop |
| `111` | `RET` | Return |

Pages `010`–`111` are reserved for future instruction-set growth, giving 48
additional code points without changing the 5-bit word width or the tag scheme.

> **Design note.** The escape word `00000` is unambiguous because a payload
> word is only interpreted as an escape when a prefix is already pending. A
> bare `00000` outside a pending prefix is always a prefix.

---

## 4. Execution model

### 4.1 Fetch, group, execute

The core is a token-stream interpreter, not a fixed-width instruction machine.

1. **Fetch.** While `mem_ready` is asserted, read one 5-bit word at `PC` and
   increment `PC`.
2. **Prefix handling.** If a `00` word arrives and no prefix is pending, set
   `pending_ext` and store nothing. The next word is captured as an extended
   token `{is_ext=1, word[2:0]}` and clears `pending_ext`.
3. **Group collection.** Ordinary tokens are appended to a 16-entry group
   buffer as `{is_ext=0, word[4:0]}`.
4. **Delimiter.** On `11111` (`|`), stop collecting. The group length becomes
   the execution length and the state machine enters execute. The delimiter is
   not part of the group.
5. **Execute.** Decode the first token of the group, evaluate the group, write
   registers/accumulator/LEDs, then return to fetch at the next word.

The PoC group buffer holds up to 16 logical tokens. A group longer than that
silently drops further tokens; programs should keep groups short.

### 4.2 Direct statement forms

| Form | Semantics |
|---|---|
| `STRT \|` | Start marker. No architectural effect; documents program entry. |
| `VAR a EQU 5 \|` | Declare/assign: write 5 to variable `a` and to `ACC`. |
| `VAR a 5 \|` | Same as above; `EQU` is optional and skipped if present. |
| `PR c \|` | Evaluate `c`, write the result to `ACC` and to `LED15`. |
| `c AD b \|` | Leading expression: result goes to `ACC`. |
| `END \|` | Halt. Status becomes `0xFF`; the core stays halted until reset. |

`VAR` requires the next token to be a letter token. The expression begins after
the letter and after an optional `EQU` word. `PR` evaluates the tokens after
the `PR` word. A group whose first token is `AD` or `TI`, or whose first token
is an extended `MN` or `DV`, is treated as a leading arithmetic expression and
writes `ACC`.

### 4.3 Values and ranges

- Every variable (`a`–`h`) and the accumulator (`ACC`) is **5 bits**, value
  0–31.
- Number literals can only encode 0–7 directly.
- Arithmetic wraps modulo 32. A result of 33 becomes 1; a subtraction below
  zero wraps to the high end.
- `LED15` latches the last `PR` value in its low 8 bits; the PoC drives eight
  LED pins.

### 4.4 Expressions and BODMAS

Operands are number tokens (literal) or letter tokens (register value).
Operators are `AD`, `TI`, `MN`, and `DV`. Brackets are `%` (open) and `$`
(close).

The intended evaluation order is BODMAS:

1. Bracketed sub-expressions, innermost first.
2. `TI`, `MN`, and `DV`, left to right.
3. `AD`, left to right.

Example:

```
% 2 AD 3 $ TI 4        evaluates as (2 + 3) * 4 = 20
2 AD 3 TI 4            evaluates as 2 + (3 * 4) = 14
```

> **PoC limitation.** The GEN1 interpreter evaluates only the first
> `operand operator operand` triple in a group. The BODMAS unit receives up to
> four tokens (`%`, operand, operator, `$`) and returns a four-slot RPN stream,
> but the CPU's `eval_expr` stops at the first operator. Fully nested BODMAS is
> a microcode/next-revision feature. The bracket tokens and their encoding are
> final; only the depth of evaluation is limited.

### 4.5 TI — repeated-addition multiply

`TI` is the Johnsan multiply. In the baseline core it is implemented as
repeated addition:

```
a TI b  ==  a + a + ... + a     (b copies of a)
```

Examples:

```
3 TI 2   -> 3 + 3           = 6
2 TI 4   -> 2 + 2 + 2 + 2   = 8
5 TI 0   -> 0
```

The ThinkerBinary ALU's multiply opcode returns zero by design; the
repeated-add sequencer drives the 5-bit adder. Results wrap modulo 32 in the
baseline core.

### 4.6 Advanced mode — trailing-zero shortcut

Advanced mode accelerates multiplication when an operand has trailing binary
zeros. A factor of `2^n` is a left shift, so repeated addition collapses to one
shift:

```
8 TI 8  =  2^3 * 2^3  =  2^6  =  64  =  1 << 6
```

Instead of adding 8 eight times, the advanced-math unit returns
`16'd1 << 6 = 16'd64`. The advanced result is 16 bits wide, so values above the
5-bit baseline range are representable in the advanced path. If either operand
is not a power of two, or the shortcut does not apply, the unit falls back to
repeated addition.

---

## 5. Memory system

### 5.1 Bit-addressable 6T SRAM

BADD memory is built from **6T SRAM bitcells**. Each cell uses four transistors
in two cross-coupled inverters (the storage loop) plus two access transistors
that connect the cell to a bitline pair during a read or write.

The array is **bit-addressable**: an address selects an individual bit rather
than forcing byte-granular access. The GEN1 PoC models 16,384 word lines of
5-bit data (14-bit address, `0x0000`–`0x3FFF`) with `mem_bit_mode` asserted by
the CPU. A full production array organizes the same storage as bitcells behind
a column multiplexer.

### 5.2 Hierarchical decoder

A flat decoder for a large array would have enormous fanout and delay. BADD
uses a hierarchical decoder:

1. **Predecode** the address into row-group and column fields.
2. A **global row decoder** selects a row block.
3. **Local row decoders** inside the block select one word line.
4. A **column multiplexer** selects the bitline group for the requested bit or
   word.

This keeps each decoder stage small, reduces switched capacitance, and lets the
array grow without a linear delay penalty.

### 5.3 Sense amplifiers

A 6T cell only nudges its bitline pair by a small differential voltage. Sense
amplifiers at the bottom of each bitline column detect that difference and
drive it to a full logic level. The read path is:

```
precharge/equalize -> word line asserted -> cell develops bitline delta
-> sense amp resolves -> output latch -> precharge again
```

Write drivers overpower the cross-coupled inverters through the access
transistors to flip the cell. `mem_bit_mode` tells the controller whether the
access is a single bit or a wider word.

### 5.4 PoC memory controller

The reference controller is a small handshake state machine:

| State | Action |
|---|---|
| `IDLE` | `ready=1`; wait for `re` or `we` |
| `DE` | Decode address |
| `SE` | Sense the selected location |
| `RD` | Latch read data |
| `WR` | Write data |
| `DN` | Assert `ready`, return to `IDLE` |

`mem_re` is asserted by the CPU while fetching; `mem_ready` closes the
handshake. The CPU presents `PC` on `mem_addr` and consumes `mem_rdata`.

---

## 6. System Johnsan microcode layer

The 5-bit ISA is deliberately tiny, so BADD separates the **human language**
from the **hardware token stream** with a system microcode layer:

```
Johnsan source
      |
      v
Translator / system microcode   (stored in eFlash, updatable)
      |
      v
5-bit ThinkerBinary token stream
      |
      v
johnsan_decode  ->  kind / code / is_delim / ext_op
      |
      v
CPU group interpreter  ->  ThinkerBinary ALU / registers / LED15
      |
      v
BADD silicon: SRAM, eFlash, SATA, PUF, MPU
```

Why the extra layer matters:

- Johnsan keywords map to the fixed table in Section 2. The microcode owns that
  mapping, so a revision can change a mnemonic or add a page-escape operation
  without a new chip mask.
- The microcode can rewrite a program image in eFlash while the active bank
  continues to execute (Section 7).
- Learners see words such as `VAR`, `AD`, `TI`, and `PR`; the hardware only
  sees five-bit tags and payloads.

The translation contract is the table in this document. Any microcode update
must preserve the direct opcode values, because those are wired into the
decoder and the CPU's comparison logic.

---

## 7. eFlash dual-bank live update via INJ

The eFlash block contains **two independent banks**, each 4,096 words of
32 bits (16 KiB per bank):

- **Bank A** and **Bank B**.
- One bank is active (serving fetches); the other is the update target.
- `bank_sel` selects which bank is addressed.
- `inject_mode` is driven by the `INJ` command.

### 7.1 Update sequence

1. The CPU executes from the active bank.
2. `INJ` asserts `inject_mode`. Writes in inject mode go to the **opposite**
   bank from `bank_sel`, leaving the running image untouched.
3. The new image is written word by word.
4. A commit write to address `0x0FFF` toggles `bank_active`, atomically
   switching the fetch source to the newly written bank.
5. `inject_mode` is released. The old bank becomes the next update target.

This is a classic A/B live-update scheme: a failed or interrupted update leaves
the active bank intact, and reprogramming is repeatable.

### 7.2 Brown-out interaction

If the supply sags during an update, the BOR circuit asserts `flash_lock`.
Flash writes are blocked while the lock is active, preventing a partially
programmed bank from being committed. The CPU is held in reset until the supply
recovers.

---

## 8. BOR, MPU, and PUF

### 8.1 BOR — brown-out reset

The BOR block compares `vdd_sense` against `vref`:

| Condition | `bor_reset_n` | `flash_lock` |
|---|---|---|
| `vdd_sense < vref` | `0` (reset asserted) | `1` (flash writes blocked) |
| `vdd_sense >= vref` | `1` (running) | `0` (flash writable) |

`bor_reset_n` gates the CPU reset; `flash_lock` gates eFlash programming. This
keeps both the core and the non-volatile image safe during power transients.

### 8.2 MPU — memory protection unit

The MPU watches the 14-bit address bus and the write strobe. Writes inside the
protected window `0x0F00`–`0x0FFF` are blocked and raise `fault_flag`, which is
routed to the CPU as `mpu_fault`. The protected window is intended for system
microcode, the translation table, and recovery vectors. Reads are not blocked
by the PoC MPU.

### 8.3 PUF — SRAM physically unclonable function

At power-up, every 6T SRAM cell settles to 0 or 1 determined by microscopic
manufacturing mismatch. The pattern is stable for a given die but unpredictable
across dice, which makes it a natural device fingerprint.

The PoC model provides:

- A challenge input (`challenge[7:0]` selects an entry).
- A 256-entry × 64-bit response table.
- `response = table[idx] XOR table[idx+1]`, producing a 64-bit response. The
  XOR of two adjacent table entries is a simulation model; in silicon the 64
  response bits come directly from 64 SRAM cells.
- `start` / `ready` handshake.

In silicon the response comes directly from the power-up state of the SRAM
cells. The PUF can gate eFlash unlock, seed key derivation, or attest device
identity. The 64-bit challenge/response buses visible in the simulation
top-level are **not** bonded out on the 100-pin package; the PUF stays on-die
and only its start/ready handshake is exposed.

---

## 9. BAD INTERSIGN 100 pin interface

The BAD INTERSIGN 100 package exposes exactly 100 pins in four functional
groups.

| Group | Pins | Contents |
|---|---|---|
| Data / address / strobes | 40 | data, address, write/read/chip-select, bit-mode |
| SATA | 16 | four differential TX/RX lane pairs |
| Power / ground / clock | 20 | core and IO rails, grounds, clocks, references |
| Control / status / recovery | 24 | reset, flash, LEDs, interrupts, JTAG, PUF, recovery |

### 9.1 Data / address — 40 pins

| Signal | Pins | Notes |
|---|---|---|
| `BAD_DATA[15:0]` | 16 | PoC RTL bonds `BAD_DATA[4:0]` (5-bit native word) |
| `BAD_ADDR[19:0]` | 20 | PoC RTL bonds `BAD_ADDR[13:0]` (16K words) |
| `BAD_WE_N` | 1 | Active-low write strobe |
| `BAD_RE_N` | 1 | Active-low read strobe |
| `BAD_CE_N` | 1 | Active-low chip select |
| `BAD_BIT_MODE` | 1 | Selects bit-granular access |
| **Total** | **40** | |

The wider package field is reserved so a future die can bond a 16-bit data path
and a 1 MiB address space without changing the package.

### 9.2 SATA — 16 pins

| Lane | Signals | Pins |
|---|---|---|
| SATA0 | `TX_P`, `TX_N`, `RX_P`, `RX_N` | 4 |
| SATA1 | `TX_P`, `TX_N`, `RX_P`, `RX_N` | 4 |
| SATA2 | `TX_P`, `TX_N`, `RX_P`, `RX_N` | 4 |
| SATA3 | `TX_P`, `TX_N`, `RX_P`, `RX_N` | 4 |
| **Total** | | **16** |

The PoC RTL bonds one lane (`sata_tx_p/n`, `sata_rx_p/n`) plus the
`SATA_DRV` drive-present input, which is counted in the control group.

### 9.3 Power / ground / clock — 20 pins

| Signal | Pins |
|---|---|
| `VDD_CORE` | 2 |
| `VDD_IO` | 2 |
| `VSS` | 8 |
| `CLK_100MHZ` | 1 |
| `CLK_AUX` | 1 |
| `PLL_REF_P`, `PLL_REF_N` | 2 |
| `VREF` | 1 |
| `VDD_SENSE` | 1 |
| Spare / no-connect | 2 |
| **Total** | **20** |

`VDD_SENSE` and `VREF` feed the brown-out comparator. `CLK_100MHZ` drives the
four-phase clock generator (`phi1`–`phi4`); `CLK_AUX` is reserved for a
low-power or debug clock.

### 9.4 Control / status / recovery — 24 pins

| Signal | Pins | Purpose |
|---|---|---|
| `RST_N` | 1 | Asynchronous active-low reset |
| `FLASH_PIN` | 1 | Flash / recovery strap, synchronized on chip |
| `LED15[7:0]` | 8 | Learner-visible output latch (`PR` result) |
| `EXT_IRQ[3:0]` | 4 | External interrupt inputs |
| `BAD_READY` | 1 | Memory handshake ready |
| `TCK` | 1 | JTAG clock |
| `TMS` | 1 | JTAG mode select |
| `TDI` | 1 | JTAG data in |
| `TDO` | 1 | JTAG data out |
| `MPU_FAULT` | 1 | Memory-protection violation |
| `PUF_START` | 1 | Begin PUF challenge |
| `PUF_READY` | 1 | PUF response valid |
| `SATA_DRV` | 1 | SATA drive-present detect |
| `RECOVERY` | 1 | Force recovery / bootloader entry |
| **Total** | **24** | |

### 9.5 Pin-budget check

```
40 data/address + 16 SATA + 20 power/ground/clock + 24 control/status = 100
```

The on-chip four-phase generator, BOR, MPU, eFlash, PUF array, and BODMAS unit
do not consume package pins. Their only external connections are the supplies,
references, JTAG, and the status pins above.

---

## 10. Worked example program

### 10.1 Johnsan source

```
STRT |
VAR a EQU 5 |
VAR b EQU 3 |
VAR c EQU a AD b |
PR c |
END |
```

The program declares `a = 5` and `b = 3`, computes `c = a + b`, prints `c`, and
halts. The expected result is `c = 8`, `ACC = 8`, `LED15 = 0x08`.

### 10.2 Group-by-group execution

| Group | Tokens | Effect |
|---|---|---|
| 1 | `STRT` | Start marker; no architectural change |
| 2 | `VAR a EQU 5` | `a = 5`; `ACC = 5` |
| 3 | `VAR b EQU 3` | `b = 3`; `ACC = 3` |
| 4 | `VAR c EQU a AD b` | `c = 5 + 3 = 8`; `ACC = 8` |
| 5 | `PR c` | `LED15 = 0x08`; `ACC = 8` |
| 6 | `END` | Halt; status `0xFF` |

### 10.3 5-bit encoding

`EQU` is a two-word extended opcode: prefix `00000` followed by payload
`00100`. The payload word also begins with `00`, but it is consumed as a
payload because the prefix is pending.

| PC | Token | 5-bit word | Hex | Note |
|---:|---|---|---|---|
| 0 | `STRT` | `11000` | `0x18` | direct |
| 1 | `\|` | `11111` | `0x1F` | delimiter |
| 2 | `VAR` | `11100` | `0x1C` | direct |
| 3 | `a` | `01000` | `0x08` | letter index 0 |
| 4 | `EQU` | `00000` | `0x00` | prefix |
| 5 | `EQU` | `00100` | `0x04` | extended payload 100 |
| 6 | `5` | `10101` | `0x15` | number 5 |
| 7 | `\|` | `11111` | `0x1F` | delimiter |
| 8 | `VAR` | `11100` | `0x1C` | direct |
| 9 | `b` | `01001` | `0x09` | letter index 1 |
| 10 | `EQU` | `00000` | `0x00` | prefix |
| 11 | `EQU` | `00100` | `0x04` | extended payload 100 |
| 12 | `3` | `10011` | `0x13` | number 3 |
| 13 | `\|` | `11111` | `0x1F` | delimiter |
| 14 | `VAR` | `11100` | `0x1C` | direct |
| 15 | `c` | `01010` | `0x0A` | letter index 2 |
| 16 | `EQU` | `00000` | `0x00` | prefix |
| 17 | `EQU` | `00100` | `0x04` | extended payload 100 |
| 18 | `a` | `01000` | `0x08` | letter index 0 |
| 19 | `AD` | `11001` | `0x19` | direct |
| 20 | `b` | `01001` | `0x09` | letter index 1 |
| 21 | `\|` | `11111` | `0x1F` | delimiter |
| 22 | `PR` | `11011` | `0x1B` | direct |
| 23 | `c` | `01010` | `0x0A` | letter index 2 |
| 24 | `\|` | `11111` | `0x1F` | delimiter |
| 25 | `END` | `00000` | `0x00` | prefix |
| 26 | `END` | `00001` | `0x01` | extended payload 001 |
| 27 | `\|` | `11111` | `0x1F` | delimiter |

Total: 28 words = 140 bits.

### 10.4 Continuous bitstream

```
11000 11111 11100 01000 00000 00100 10101 11111
11100 01001 00000 00100 10011 11111
11100 01010 00000 00100 01000 11001 01001 11111
11011 01010 11111 00000 00001 11111
```

### 10.5 Final machine state

| Item | Value |
|---|---|
| `a` | 5 |
| `b` | 3 |
| `c` | 8 |
| `ACC` | 8 |
| `LED15` | `0x08` |
| Status | `0xFF` (halted) |

---

## 11. Reference implementation

| File | Contents |
|---|---|
| `parts/johnsan_decode.v` | `johnsan_decode` (stateless 5-bit decode) and `johnsan_decode_ext` (extended-op helper) |
| `parts/tb_johnsan_decode.v` | Self-checking testbench: sweep, direct checks, extended checks, PASS/FAIL summary |

Build and run:

```bash
iverilog -g2012 -o tb_johnsan_decode.vvp \
    parts/tb_johnsan_decode.v parts/johnsan_decode.v
vvp tb_johnsan_decode.vvp
```

The testbench checks all eight direct opcodes, number and letter tokens, the
extended prefix, all seven installed extended opcodes, and the escape-word
disambiguation. It prints a final `RESULT: <n> passed, <m> failed` line and
calls `$fatal` if any check fails.

### Revision notes

- The 5-bit tag scheme, direct opcode values, and the seven primary extended
  opcodes are fixed by the book and by the GEN1 decoder.
- Bracket tokens `%` and `$` are encoded and reserved; full nested BODMAS
  evaluation is a microcode/next-revision feature.
- The 16 remaining vocabulary entries are reserved on the two escape pages in
  Section 3. They are documentation-only until the microcode and decoder are
  extended.

---

## 12. Known PoC limitations

The ISA and architecture above describe the intended design. GEN1 is a proof of
concept; the following gaps are known and intentional at this stage.

| # | Area | Current PoC behavior |
|---:|---|---|
| 1 | SATA / TAP / IRQ | SATA TX pins are tied low and RX pins are unconnected; TCK/TMS/TDI are unused, TDO is undriven, and `ext_irq` is ignored. |
| 2 | Stores | `mem_we` and `mem_wdata` are tied to zero; `WR` and `RD` are not wired, so programs cannot write external memory. |
| 3 | MPU | Advisory only: `block_write` is left open and `mpu_fault` is not observed by the CPU. |
| 4 | eFlash live update | `eflash_bank_sel` and `eflash_inject` are tied low. The `eflash_dual` module supports INJ, but the CPU does not drive it, so no bank switch occurs. |
| 5 | Control flow | `IF`, `THEN`, and `GOTO` are parsed and encoded but not executed: there is no branch unit, and `PC` only increments. |
| 6 | Error handling | An extended opcode with payload `000` (invalid) or a PC wrap at `0x3FFF` traps to `status = 0xFE` and halts. |
| 7 | Memory | Memory is external; the CPU stalls until `mem_ready` is high. `badd_top` currently ties `bad_ready` high, but an integrator wiring `badd_cpu` directly must drive `mem_ready`. |
| 8 | Numeric width | Registers, `ACC`, and the committed result are 5-bit and wrap modulo 32 (for example, `7 TI 7` = 49 commits as 17). The full-width product is exposed only by the `advanced_mode` unit on `adv_res`/`adv_done`, which does not write back. |
| 9 | Legacy modules | `thinkerbinary_alu`, `badd_mem_ctrl`, `advanced_math`, and `tri_state_5` remain in `badd_chip.v` for reference but are not instantiated by the PoC. |

These are implementation gaps, not encoding gaps: the 5-bit word format, direct
opcodes, and installed extended opcodes in Sections 1–3 are stable.

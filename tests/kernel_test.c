tests/kernel_test.c - C harness for the Johnsan kernel and micro-kernel

Build:
  cc -Wall -Wextra -o kernel_test tests/kernel_test.c src/kernel/johnsan_kernel.c src/kernel/micro_kernel.c

Run:
  ./kernel_test
*/

#include "johnsan_kernel.h"
#include "micro_kernel.h"

#include <stdio.h>
#include <string.h>

static int tests_run = 0;
static int tests_fail = 0;

static void check(int cond, const char *what)
{
    tests_run++;
    if (!cond) {
        printf("FAIL: %s\n", what);
        tests_fail++;
    } else {
        printf("pass: %s\n", what);
    }
}

/* Simple in-memory model: 16 words, preloaded. */
static uint8_t mem_image[16];
static bool mem_ready = true;

static uint8_t mem_read5(uint16_t addr)
{
    return mem_image[addr & 0x0f];
}

static void mem_write5(uint16_t addr, uint8_t value)
{
    mem_image[addr & 0x0f] = value;
}

int main(void)
{
    /* 1. Direct opcode table */
    check(johnsan_opcode_of("STRT") == 0b11000, "STRT encodes to 11000");
    check(johnsan_opcode_of("AD") == 0b11001, "AD encodes to 11001");
    check(johnsan_opcode_of("TI") == 0b11010, "TI encodes to 11010");
    check(johnsan_opcode_of("PR") == 0b11011, "PR encodes to 11011");
    check(johnsan_opcode_of("VAR") == 0b11100, "VAR encodes to 11100");
    check(johnsan_opcode_of("END") == 0b00001, "END extended payload 001");
    check(johnsan_opcode_of("MN") == 0b00010, "MN extended payload 010");
    check(johnsan_opcode_of("DV") == 0b00011, "DV extended payload 011");
    check(johnsan_opcode_of("EQU") == 0b00100, "EQU extended payload 100");
    check(johnsan_opcode_of("IF") == 0b00101, "IF extended payload 101");
    check(johnsan_opcode_of("THEN") == 0b00110, "THEN extended payload 110");
    check(johnsan_opcode_of("GOTO") == 0b00111, "GOTO extended payload 111");
    check(johnsan_opcode_of("NOPE") == -1, "unknown mnemonic rejects");

    /* 2. Translate the worked example from BADD_ISA.md */
    const char *src =
        "STRT |\n"
        "VAR a EQU 5 |\n"
        "VAR b EQU 3 |\n"
        "VAR c EQU a AD b |\n"
        "PR c |\n"
        "END |\n";
    uint8_t words[128];
    int nw = johnsan_translate_program(src, words, sizeof(words));
    check(nw == 28, "worked example translates to 28 words");

    /* Spot-check encodings against BADD_ISA.md section 10.3. */
    check(words[0] == 0b11000, "PC0 STRT 11000");
    check(words[1] == 0b11111, "PC1 delim 11111");
    check(words[2] == 0b11100, "PC2 VAR 11100");
    check(words[3] == 0b01000, "PC3 letter a 01000");
    check(words[4] == 0b00000, "PC4 EQU prefix 00000");
    check(words[5] == 0b00100, "PC5 EQU payload 00100");
    check(words[6] == 0b10101, "PC6 number 5 10101");
    check(words[25] == 0b00000, "PC25 END prefix 00000");
    check(words[26] == 0b00001, "PC26 END payload 00001");
    check(words[27] == 0b11111, "PC27 delim 11111");

    /* 3. Micro-kernel: VAR a EQU 5 then PR a */
    badd_state_t st;
    badd_mem_t m;
    memset(mem_image, 0, sizeof(mem_image));
    mem_image[0] = 0b11100; /* VAR */
    mem_image[1] = 0b01000; /* a */
    mem_image[2] = 0b00000; /* prefix */
    mem_image[3] = 0b00100; /* EQU payload */
    mem_image[4] = 0b10101; /* 5 */
    mem_image[5] = 0b11111; /* delim */
    mem_image[6] = 0b11011; /* PR */
    mem_image[7] = 0b01000; /* a */
    mem_image[8] = 0b11111; /* delim */
    mem_image[9] = 0b00000; /* END prefix */
    mem_image[10] = 0b00001; /* END payload */
    mem_image[11] = 0b11111; /* delim */
    m.read5 = mem_read5;
    m.write5 = mem_write5;
    m.ready = true;
    badd_reset(&st);
    st.pc = 0;
    badd_run(&st, &m);
    check(st.acc == 5, "micro-kernel sets acc to 5");
    check(st.reg[0] == 5, "micro-kernel sets reg a to 5");
    check(st.halted, "micro-kernel halts on END");

    printf("\nRESULT: %d passed, %d failed\n", tests_run - tests_fail, tests_fail);
    return tests_fail == 0 ? 0 : 1;
}

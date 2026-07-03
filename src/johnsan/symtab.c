/* symtab.c - symbol table for Johnsan variables a-h */
#include <string.h>

#define VARS 8

static char names[VARS];
static int count = 0;

int johnsan_sym_lookup(char name) {
    for (int i = 0; i < count; i++) {
        if (names[i] == name) return i;
    }
    return -1;
}

int johnsan_sym_add(char name) {
    if (count < VARS && johnsan_sym_lookup(name) < 0) {
        names[count++] = name;
        return count - 1;
    }
    return -1;
}

/* Variable names are limited to a-h (8 entries). */

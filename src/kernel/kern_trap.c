/* kern_trap.c - trap and interrupt handler */
#include "kern.h"

void kern_trap(int num) {
    /* save context, dispatch to trap handler, restore context */
    (void)num;
}

/* Trap numbers are defined by the BADD CPU exception map. */

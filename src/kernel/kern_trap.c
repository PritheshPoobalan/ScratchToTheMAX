/* kern_trap.c - trap and interrupt handler */
#include "kern.h"

void kern_trap(int num) {
    /* save context, dispatch to trap handler, restore context */
    (void)num;
}

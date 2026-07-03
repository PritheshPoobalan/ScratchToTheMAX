/* kern_time.c - time and tick management */
#include "kern.h"

static unsigned long ticks = 0;

long kern_time_ticks(void) {
    return ticks;
}

void kern_time_tick(void) {
    ticks++;
}

/* Tick frequency is one tick per timer interrupt. */

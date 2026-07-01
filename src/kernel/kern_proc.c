/* kern_proc.c - process management */
#include "kern.h"

int kern_proc_create(void (*entry)(void)) {
    /* allocate a thread and enqueue it on the scheduler */
    (void)entry;
    return -1;
}

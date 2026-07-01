/* kern_sched.c - round-robin scheduler */
#include "kern.h"

#define MAX_THREADS 8

static int current = 0;
static int run_queue[MAX_THREADS];
static int queue_len = 0;

void kern_sched_start(void) {
    current = 0;
    queue_len = 0;
}

void kern_sched_add(int tid) {
    if (queue_len < MAX_THREADS) {
        run_queue[queue_len++] = tid;
    }
}

void kern_sched_run_once(void) {
    if (queue_len == 0) return;
    current = (current + 1) % queue_len;
    /* dispatch run_queue[current] in real implementation */
}

/* Preemption tick: called by the timer interrupt. */
void kern_sched_tick(void) {
    kern_sched_run_once();
}

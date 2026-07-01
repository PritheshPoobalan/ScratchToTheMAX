/* kern_mem.c - kernel memory manager */
#include "kern.h"

#define FRAME_COUNT 256

static int free_frames[FRAME_COUNT];
static int free_count = 0;

void kern_mem_init(void) {
    for (int i = 0; i < FRAME_COUNT; i++) {
        free_frames[i] = i;
    }
    free_count = FRAME_COUNT;
}

int kern_alloc_frame(void) {
    if (free_count == 0) return -1;
    return free_frames[--free_count];
}

void kern_free_frame(int frame) {
    if (free_count < FRAME_COUNT) {
        free_frames[free_count++] = frame;
    }
}

/* Kernel invariant: free_count never exceeds FRAME_COUNT. */

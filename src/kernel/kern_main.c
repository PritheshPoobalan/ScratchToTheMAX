/* kern_main.c - Johnsan kernel entry point */
#include "kern.h"

void kern_main(void) {
    kern_init();
    kern_sched_start();
    /* scheduler loop never returns */
    while (1) {
        kern_sched_run_once();
    }
}

int main(void) {
    kern_main();
    return 0;
}

/* Version string for the kernel build. */
const char *kern_version = "0.1.0-dev";

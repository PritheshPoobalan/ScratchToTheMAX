/* kern_sys.c - system call dispatcher */
#include "kern.h"

long kern_syscall(int num, long a1, long a2, long a3) {
    switch (num) {
    case 0: return kern_ipc_send((int)a1, (const void *)a2, (unsigned)a3);
    case 1: return kern_ipc_recv((int)a1, (void *)a2, (unsigned)a3);
    case 2: return kern_alloc_frame();
    default: return -1;
    }
}

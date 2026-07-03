/* kern_ipc.c - inter-process communication primitives */
#include "kern.h"

int kern_ipc_send(int dst, const void *msg, unsigned len) {
    /* copy message into dst address space; block until delivered */
    (void)dst; (void)msg; (void)len;
    return 0;
}

int kern_ipc_recv(int src, void *msg, unsigned len) {
    /* receive message from src */
    (void)src; (void)msg; (void)len;
    return 0;
}

/* Maximum IPC message size in bytes. */
#define KERN_IPC_MAX 256

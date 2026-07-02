# Johnsan Kernel Overview

The Johnsan kernel is the supervisor-mode component of ScratchToTheMAX. It is
written in C under `src/kernel/` and targets the BADD CPU.

## Responsibilities

- Boot and system initialization.
- Round-robin thread scheduling with preemption.
- Physical frame and virtual page memory management.
- Inter-process communication: send, receive, reply.
- System call dispatch from user mode.
- Interrupt and exception handling.

## Source layout

- `src/kernel/kern_main.c` - entry point and initialization.
- `src/kernel/kern_sched.c` - scheduler implementation.
- `src/kernel/kern_mem.c` - memory manager.
- `src/kernel/kern_ipc.c` - IPC primitives.
- `src/kernel/kern_sys.c` - system call dispatcher.
- `src/kernel/kern_trap.c` - trap and interrupt handler.
- `src/kernel/kern_proc.c` - process management.
- `src/kernel/kern_vfs.c` - virtual filesystem placeholder.
- `src/kernel/kern_time.c` - time and tick management.

## Build all kernel objects

    for c in src/kernel/*.c; do cc -I src/kernel -c "$c"; done

## Kernel design goals

Small, predictable, auditable. The kernel avoids dynamic memory allocation in
the hot path and keeps scheduler decisions deterministic.

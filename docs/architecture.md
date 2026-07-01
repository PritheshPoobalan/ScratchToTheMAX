# Micro-kernel Architecture

## Overview

ScratchToTheMAX is built around a micro-kernel. The kernel is deliberately
small and implements only what cannot be done in user space:

- thread scheduling
- address-space management
- inter-process communication (IPC)
- interrupt and exception dispatch

Everything else - device drivers, filesystems, network stacks, the shell - runs
as a user-space server. Servers talk to the kernel and to each other through
message passing, so a crash in one server does not bring down the whole system.

## Layers

1. Hardware: BADD CPU (5-bit ThinkerBinary, RUN ISA).
2. Johnsan kernel: micro-kernel running in supervisor mode.
3. Servers: user-space drivers and services.
4. Applications: Johnsan programs compiled to ThinkerBinary.

## Isolation

Each server and application runs in its own address space. The kernel enforces
isolation through the BADD MPU and memory-management primitives. IPC messages
are copied between address spaces so servers cannot observe each other's memory
directly.

## Boot sequence

1. BADD CPU comes out of reset and enters supervisor mode.
2. The Johnsan kernel initializes the scheduler, memory manager, and IPC.
3. The kernel starts the root server (init).
4. init starts the remaining servers and the first application.

## Why micro-kernel

A small kernel is easier to verify, audit, and trust. It also makes the system
extensible: new servers can be added without touching the kernel.

# Micro-kernel Design

## Minimal kernel principle

A micro-kernel keeps the trusted computing base small. In ScratchToTheMAX the
kernel does not implement device drivers or filesystems. Those live in user
space as servers. If a disk driver panics, only the disk server restarts; the
kernel and other servers keep running.

## Inter-process communication

IPC is the primary interaction mechanism. A thread sends a message to a server
and blocks until the server replies. The kernel copies the message between
address spaces and schedules the receiver. This synchronous model makes server
interfaces easy to reason about and test.

## Memory management

The kernel manages physical frames and maps pages into thread address spaces.
User servers request memory through syscalls; the kernel tracks ownership and
reclaims frames when a server exits.

## Drivers as servers

Each device (serial, disk, network) has a user-space server that owns the
device registers and answers client requests. The kernel only delivers
interrupts to the owning server.

## Failure isolation

Because drivers run in user space, a driver fault is contained. The kernel
restarts the faulty server without affecting other servers or applications.

## Inter-server communication

Servers expose well-known message ports. A client addresses a server by port
number and waits for a reply, keeping the interaction model uniform.

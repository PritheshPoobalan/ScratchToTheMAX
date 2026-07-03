# System Call Reference

## Syscalls

| number | name        | description           |
|--------|-------------|-----------------------|
| 0      | ipc_send    | send a message        |
| 1      | ipc_recv    | receive a message     |
| 2      | alloc_frame | allocate a memory frame |

## Convention

Syscall number goes in a dedicated register; arguments follow. The kernel
dispatches through `kern_syscall` and returns the result or a negative error
code.

## Error handling

Negative return values indicate errors; zero or positive values indicate
success or return the requested result.

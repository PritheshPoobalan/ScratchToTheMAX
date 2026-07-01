# Interrupt and Exception Handling

## Interrupt delivery

The BADD CPU delivers interrupts to the kernel, which identifies the source and
forwards it to the owning server. The kernel saves the interrupted context and
restores it after the handler runs.

## Exceptions

Exceptions such as illegal instructions, memory protection violations, and
divide-by-zero are delivered as traps to `kern_trap`.

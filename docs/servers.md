# User-Space Server Model

## Server responsibilities

Each server owns a device or service and exposes a message-based interface:

- serial server: console input/output
- disk server: block device access
- net server: packet send/receive
- fs server: filesystem operations

## Communication

Clients send requests to a server and block on a reply. The kernel copies the
message and wakes the server. Servers never share memory directly.

# Security Model

## Hardware roots of trust

The BADD CPU provides three hardware security blocks:

- BOR (brown-out reset): holds the CPU in reset below a safe voltage.
- MPU (memory protection unit): enforces kernel/user address-space isolation.
- PUF (physically unclonable function): derives a per-device identity for
  attestation and key derivation.

## Isolation

User servers and applications run in separate address spaces. The kernel
mediates all cross-server communication through copied IPC messages. A
compromised server cannot read or write another server's memory.

## Live update

The INJ eFlash live-update path is gated behind the PUF identity check so only
authenticated updates can be flashed.

## PUF attestation flow

1. Verifier sends a challenge to the device.
2. Device PUF computes a response from the challenge.
3. Verifier checks the response against the enrolled identity.

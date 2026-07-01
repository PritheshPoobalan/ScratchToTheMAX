# BOR, MPU, and PUF

## BOR - brown-out reset

Holds the CPU in reset below a safe voltage so execution never proceeds on an
unstable supply.

## MPU - memory protection unit

Restricts user-mode access to kernel and other-server address ranges.

## PUF - physically unclonable function

Derives a per-device identity used for attestation, key derivation, and
authenticated eFlash updates.

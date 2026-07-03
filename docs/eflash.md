# eFlash Live Update (INJ)

## Dual-bank update

The BADD CPU provides an INJ (injection) path for eFlash dual-bank live
updates. A new image is written to the inactive bank while the active bank
keeps running. On the next reset, the CPU swaps to the updated bank.

## Authentication

Each update image is signed and verified against the device PUF identity before
being committed. Unauthenticated images are rejected.

## Rollback

If the new bank fails to boot, the CPU falls back to the previous bank,
making updates safe by default.

## Update safety

Dual-bank updates with rollback ensure a bad image cannot brick the device.

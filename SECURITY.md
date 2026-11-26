# Security Policy

## Supported Versions

Only the latest `main` branch receives security updates. This is a research/educational project — we do not maintain long-term support branches.

| Version | Supported |
|---------|-----------|
| `main` (latest) | ✅ Yes |
| Older commits | ❌ No |

## Reporting a Vulnerability

**Please do not publish exploits publicly.**

Report security issues by:

1. **Opening a private GitHub Security Advisory** (preferred):
   - Go to the [Security tab](https://github.com/PritheshPoobalan/ScratchToTheMAX/security)
   - Click "Report a vulnerability"
   - Fill in the details

2. **Email**: If you cannot use GitHub Security Advisories, contact the maintainer directly.

We aim to acknowledge reports within 7 days and provide a fix timeline within 30 days for validated issues.

## Hardware Security Features

The BADD CPU includes dedicated hardware security blocks documented in [`docs/security-model.md`](docs/security-model.md):

| Block | Purpose |
|-------|---------|
| **BOR** (Brown-Out Reset) | Detects voltage drops, triggers secure reset |
| **MPU** (Memory Protection Unit) | Enforces memory access permissions per process |
| **PUF** (Physically Unclonable Function) | Hardware root of trust for key generation |
| **INJ** (eFlash Live Update) | Secure firmware update with authentication |

These features are part of the RTL implementation in `badd_chip.v` and `parts/`.

## Scope

This security policy covers:

- ✅ BADD CPU RTL (Verilog) — `badd_chip.v`, `parts/`
- ✅ Johnsan kernel — `src/kernel/`
- ✅ Johnsan compiler — `src/johnsan/`
- ✅ Build system and tooling — `Makefile`, scripts
- ❌ Third-party dependencies (Icarus Verilog, GCC, etc.)
- ❌ Simulation artifacts and generated files

## Disclosure Timeline

1. **Day 0**: Vulnerability reported
2. **Day 1-7**: Acknowledgment and initial assessment
3. **Day 7-30**: Root cause analysis and fix development
4. **Day 30+**: Fix merged to `main`, advisory published

For critical hardware-level issues (e.g., MPU bypass), we may coordinate with hardware security researchers before public disclosure.

## Security Best Practices for Contributors

- Never commit secrets, keys, or credentials
- Use `make clean` before sharing builds
- Verify simulation outputs match expected behavior
- Report unexpected hardware behavior (may indicate security issues)

## Contact

- **Maintainer**: [@PritheshPoobalan](https://github.com/PritheshPoobalan)
- **Security Advisories**: [GitHub Security Tab](https://github.com/PritheshPoobalan/ScratchToTheMAX/security)

---

*This policy is adapted for an educational/research hardware project. For production systems, consult industry standards (NIST, ISO 27001, etc.).*
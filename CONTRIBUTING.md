# Contributing to ScratchToTheMAX

Thank you for your interest in contributing to ScratchToTheMAX! This project is an educational and research exploration of a complete computing stack — from CPU architecture to programming language to operating system.

## How to Contribute

### 1. Fork and Branch

1. Fork the repository on GitHub
2. Create a feature branch from `main`:
   ```bash
   git checkout -b feature/your-feature-name
   ```

### 2. Make Your Changes

Areas where contributions are especially welcome:

- **BADD CPU RTL** — Verification, optimization, new instructions, FPGA targets
- **Johnsan Compiler** — Backend improvements, optimization passes, self-hosting
- **Kernel** — Scheduler enhancements, memory management, IPC, driver framework
- **Documentation** — Architecture guides, tutorials, API documentation
- **Tests** — Unit tests, integration tests, simulation testbenches
- **Examples** — New Johnsan programs demonstrating language features

### 3. Code Style

- **Verilog**: Follow existing indentation (2 spaces), naming conventions (`snake_case` for signals, `CamelCase` for modules)
- **C (Kernel)**: Use 4-space indentation, K&R brace style, `snake_case` for functions/variables
- **Johnsan**: Follow examples in `examples/` directory
- **Documentation**: Markdown with clear headings, code blocks with language tags
- **Commits**: Clear, imperative messages (e.g., "Add BODMAS evaluator module", "Fix SRAM timing issue")

### 4. Testing

Before submitting, ensure:

```bash
# Run CPU simulation tests
make sim

# Run kernel tests
make test

# Run all tests
make test-all
```

All tests must pass. Add new tests for any new functionality.

### 5. Commit Guidelines

- One logical change per commit
- Message format:
  ```
  <component>: <short description>

  <longer explanation if needed>

  Fixes #<issue-number>
  ```
- No emojis in commit messages
- Reference issues/PRs where applicable

### 6. Pull Request Process

1. Push your branch to your fork
2. Open a PR against `main` branch
3. Fill out the PR template (if available)
4. Ensure CI passes
5. Address review comments
6. Maintainers will merge after approval

## Development Setup

### Prerequisites

- **Icarus Verilog** 11.0+ (`sudo apt-get install iverilog`)
- **GCC/Clang** 10+ (`sudo apt-get install build-essential`)
- **Make** (`sudo apt-get install make`)
- **GTKWave** (optional, for waveform viewing): `sudo apt-get install gtkwave`

### Building

```bash
# Full build
make all

# Individual targets
make sim        # CPU simulation
make kernel     # Kernel objects
make compiler   # Johnsan compiler
make test       # Run tests
```

## Architecture Decisions

Major architectural changes should be discussed in an issue first. We follow these principles:

1. **Simplicity** — Prefer clean, understandable designs over clever optimizations
2. **Education** — Code should be readable and instructive
3. **Modularity** — Clear separation between CPU, compiler, kernel
4. **Verifiability** — Design for testability and formal verification

## Code Review Checklist

Reviewers will check:

- [ ] Build succeeds (`make all`)
- [ ] Tests pass (`make test`)
- [ ] Code follows project style
- [ ] Commit messages are clear
- [ ] Documentation updated if needed
- [ ] No emojis in commits or code comments
- [ ] Changes are focused and minimal

## Community

- **Issues**: Bug reports, feature requests, architecture discussions
- **Discussions**: General questions, design ideas, educational use
- **Pull Requests**: Code contributions

## License

By contributing, you agree that your contributions will be licensed under the MIT License (see [LICENSE](LICENSE)).

---

**Questions?** Open an issue or start a discussion. We're happy to help!
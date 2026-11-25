# Contributing to ScratchToTheMAX

ScratchToTheMAX is public open source. Contributions are welcome.

## How to contribute

1. Fork the repository and create a feature branch from `main`.
2. Add documentation, code, tests, or examples. Every commit must add
   something substantive; no empty commits.
3. Write commit messages without emojis (public repo rule). Keep messages
   varied and descriptive of the change.
4. Push to your fork and open a pull request against `main`.
5. Keep pull requests small and focused. Include test coverage for new
   Verilog or C code when applicable.

## Code style

- Verilog: `default_nettype none`, `timescale 1ns / 1ps`, 4-space indent.
- C: C99, `-Wall -Wextra` clean, 4-space indent, braces on the same line.
- Docs: Markdown, headers describe purpose, tables for encodings.

## Testing

Run Verilog testbenches with Icarus Verilog and check the final
`RESULT: <n> passed, <m> failed` line. Run the C micro-kernel harness and
verify exit status 0.

## License

By contributing, you agree your contributions are licensed under the MIT
License.

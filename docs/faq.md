# Frequently Asked Questions

## What is BADD?

BADD is a 5-bit ThinkerBinary CPU core using the RUN architecture. It is the
hardware substrate for ScratchToTheMAX.

## What is Johnsan?

Johnsan is the source language that compiles to ThinkerBinary words for the
BADD CPU.

## Why a micro-kernel?

A micro-kernel keeps the trusted computing base small and isolates drivers and
services in user space.

## Can I simulate the BADD CPU?

Yes. The Verilog RTL runs under Icarus Verilog. See `docs/build-run.md`.

## How do I contribute?

Open an issue, then submit a pull request with your change on a feature branch.

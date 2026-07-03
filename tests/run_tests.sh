#!/bin/sh
set -e
python3 tests/test_alu.py
python3 tests/test_decode.py
python3 tests/test_badd_sim.py
python3 tests/test_sched.py
python3 tests/test_mem.py
python3 tests/test_ipc.py
python3 tests/test_parser.py
python3 tests/test_typecheck.py
echo "All tests passed."

# Add new test files here as they are created.

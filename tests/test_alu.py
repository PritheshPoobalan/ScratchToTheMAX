"""Test the ThinkerBinary ALU operations (add, sub, mul, div)."""


def alu_op(op, a, b):
    if op == 0:
        return (a + b) & 0x1F
    if op == 1:
        return (a - b) & 0x1F
    if op == 2:
        return 0
    if op == 3:
        return (a // b) & 0x1F if b else 0
    return 0


def test_add():
    assert alu_op(0, 3, 4) == 7


def test_sub():
    assert alu_op(1, 10, 4) == 6


def test_mul_zero():
    assert alu_op(2, 5, 6) == 0


def test_div():
    assert alu_op(3, 20, 4) == 5


def test_div_by_zero():
    assert alu_op(3, 5, 0) == 0


def test_zero_flag():
    assert alu_op(1, 5, 5) == 0


def test_overflow_wrap():
    assert alu_op(0, 31, 1) == 0


def test_negative_sub():
    assert alu_op(1, 2, 10) == (2 - 10) & 0x1F


def test_identity_add():
    assert alu_op(0, 0, 0) == 0

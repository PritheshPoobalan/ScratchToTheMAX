"""Test the Johnsan 5-bit word decoder."""


def decode(word):
    tag = word >> 3
    code = word & 0x7
    if tag == 2:
        return "number", code, False
    if tag == 1:
        return "letter", code, False
    if tag == 3:
        return "opcode", code, word == 0b11111
    return "extended", code, False


def test_number_kind():
    kind, code, delim = decode(0b10011)
    assert kind == "number"
    assert code == 3


def test_letter_kind():
    kind, code, delim = decode(0b01010)
    assert kind == "letter"
    assert code == 2


def test_opcode_kind():
    kind, code, delim = decode(0b11000)
    assert kind == "opcode"
    assert code == 0


def test_delimiter():
    kind, code, delim = decode(0b11111)
    assert delim is True


def test_extended_prefix():
    kind, code, delim = decode(0b00000)
    assert kind == "extended"
    assert code == 0


def test_number_payload_seven():
    kind, code, delim = decode(0b10111)
    assert kind == "number"
    assert code == 7

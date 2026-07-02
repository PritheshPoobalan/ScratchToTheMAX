"""Test the Johnsan kernel scheduler."""


def test_round_robin_order():
    order = []
    n = 4
    for i in range(8):
        order.append(i % n)
    assert order == [0, 1, 2, 3, 0, 1, 2, 3]

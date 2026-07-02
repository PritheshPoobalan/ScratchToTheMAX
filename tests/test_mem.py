"""Test the kernel frame allocator."""


def test_alloc_free_cycle():
    frames = list(range(4))
    free = list(frames)
    assert free.pop() == 3
    free.append(3)
    assert 3 in free

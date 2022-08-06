__author__ = 'Davide Canton'

from cyBitSet import PyBitSet
import itertools as it


def test_basic():
    length = 32
    init_val = {1, 4, 6, 8, 10}
    bitset = PyBitSet(length, init_val)
    assert len(init_val) == bitset.nnz
    bin_str = bitset.to_bin_str()
    assert bin_str == "010010101010000000000000000000000"

    new_val = {1, 2, 3, 6, 8}
    bitset.update(new_val)
    new_val |= init_val
    assert len(new_val) == bitset.nnz

    assert set(it.compress(range(length), bitset)) == set(bitset.elems())
__author__ = 'Davide Canton'

from cyBitSet import PyBitSet
import itertools as it
import random

if __name__ == "__main__":
    length = 32
    init_val = {random.randint(0, 16 - 1) for _ in range(5)}
    bitset = PyBitSet(length, init_val)
    assert len(init_val) == bitset.nnz
    print(init_val)
    bin_str = bitset.to_bin_str()
    print(bin_str)
    print(bitset)
    print(set(bitset.elems()))
    print("-" * 10)

    new_val = {random.randint(0, 16 - 1) for _ in range(5)}
    print(new_val)
    bitset.update(new_val)
    new_val |= init_val
    print(new_val)
    assert len(new_val) == bitset.nnz
    print(bitset)
    print(bitset.to_bin_str())
    print(bitset.elems())

    assert set(it.compress(range(length), bitset)) == set(bitset.elems())
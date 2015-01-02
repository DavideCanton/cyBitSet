from libc.stdlib cimport calloc, free
from cpython cimport array
from cython cimport boundscheck
from array import array

cdef extern from "Python.h":
    object PyByteArray_FromStringAndSize(char *string, int length)

ctypedef unsigned char uint8
ctypedef char int8

cdef inline long bit_set_size(long n):
    return (n + 7) >> 3

cdef inline int get_nnz(uint8 n):
    cdef int s = 0
    while n:
        s += 1
        n &= n - 1
    return s

cpdef inline int check_indices(int bit, int size) except 0:
    if bit < 0 or bit >= size:
        raise IndexError("Invalid index")
    return 1

cdef class PyBitSet:
    cdef public int size
    cdef public bytearray buf
    cdef public int nnz
    
    @boundscheck(False)
    def __cinit__(self, long size, object init_val=None):
        cdef int bsize
        cdef long elem
        cdef int8* buf

        self.size = size
        self.nnz = 0
        bsize = bit_set_size(size)
        buf = <int8*> calloc(bsize, sizeof(int8))

        try:
            if init_val is not None:
                if isinstance(init_val, long):
                    self.fill_buf_from_int(buf, bsize, init_val)
                else:
                    self.fill_buf_from_iterable(buf, size, bsize, init_val)

            self.buf = PyByteArray_FromStringAndSize(buf, bsize)
        finally:
            free(buf)

    @boundscheck(False)
    cdef void fill_buf_from_int(self, int8* buf, int bsize, unsigned long val):
        cdef int i
        self.nnz = 0
        for i in range(bsize):                        
            buf[i] |= <uint8>(val & 0xFF)
            self.nnz += get_nnz(buf[i] & 0xFF)
            val >>= 8

    @boundscheck(False)
    cdef void fill_buf_from_iterable(self, int8* buf, int size,
                                     int bsize, object init_val):
        cdef int el
        cdef int elem
        
        self.nnz = 0
        for el in init_val:
            elem = <long> el
            if elem >= size or elem < 0:
                raise ValueError("values must be between zero (inclusive) and "
                                 "size (exclusive)")
            buf[elem >> 3] |= 1 << (elem & 7)
        for i in range(bsize):
            self.nnz += get_nnz(<uint8>buf[i])
        

    @boundscheck(False)
    cdef int change_one(self, int bit, int isset) except 0:
        cdef uint8 val
        cdef uint8[:] buf = self.buf

        check_indices(bit, self.size)        
        cdef uint8 mask = <uint8>(1 << (bit & 7))
        val = <uint8> buf[bit >> 3]

        if isset:
            if not (val & mask):
                self.nnz += 1
            val |= mask
            buf[bit >> 3] = val
        else:
            if val & mask:
                self.nnz -= 1
            val &= ~mask
            buf[bit >> 3] = val
        return 1

    def __setitem__(self, int bit, object value):
        if bit < 0:
            bit += self.size
        self.change_one(bit, <bint> value)

    @boundscheck(False)
    cdef int get_item(self, int bit) except -1:
        if bit < 0:
            bit += self.size

        check_indices(bit, self.size)
        cdef uint8 val = <uint8> self.buf[bit >> 3]
        val >>= bit & 7
        return <bint>(val & 1)

    def __getitem__(self, int bit):
        return self.get_item(bit)

    def __len__(self):
        return self.nnz

    def __contains__(self, int bit):
        return self.get_item(bit)

    @boundscheck(False)
    def elems(self):
        cdef int i = 0
        cdef int j = 0
        cdef int index
        cdef int val
        cdef int size = bit_set_size(self.size)
        cdef uint8[:] buf = self.buf
        els = set()

        for i in range(size):
            val = buf[i]
            j = 0
            while val:
                if val & 1:
                    index = (i << 3) + j
                    if index < self.size:
                        els.add(index)
                val >>= 1
                j += 1
        return els

    @boundscheck(False)
    def to_bin_str(self):
        cdef int i
        cdef int bsize = bit_set_size(self.size)
        cdef int index
        cdef int val
        cdef uint8[:] buf = self.buf
        cdef char* cstr = <char*> calloc(self.size + 1, sizeof(char))
        cdef int size = self.size
        cdef int end = 0

        for i in range(bsize):
            val = buf[i]
            index = i << 3
            for _ in range(8):                
                if i == bsize - 1 and index >= size:
                    end = 1
                    break
                cstr[size - index - 1] = <char>'0' + (val & 1)
                index += 1
                val >>= 1
            if end:
                break

        return cstr.decode("utf-8")

    @boundscheck(False)
    cpdef object flip_one(self, int bit):
        cdef int isset
        cdef uint8[:] buf = self.buf

        if bit < 0:
            bit += self.size

        check_indices(bit, self.size)

        isset = (buf[bit >> 3] >> (bit & 7)) & 1
        self.change_one(bit, not isset)

    @boundscheck(False)
    cpdef object flip_all(self):
        cdef int bsize = bit_set_size(self.size) 
        cdef uint8 acc
        cdef uint8[:] buf = self.buf
        
        self.nnz = 0
        for i in range(bsize):
            buf[i] = ~buf[i]
            if i == bsize - 1:            
                acc = 8 - (bsize * 8 - self.size)
                buf[bsize - 1] &= (1 << acc) - 1
            acc = buf[i] & 0xFF
            self.nnz += get_nnz(acc)
    
    @boundscheck(False)    
    def __int__(self):
        cdef unsigned long val = 0
        cdef int i
        cdef uint8[:] buf = self.buf
        cdef int bsize = bit_set_size(self.size)
        
        for i in range(bsize):
            val += (<unsigned long> buf[i]) << (8 * i)
        
        return val
        
    def __index__(self):
        return int(self)
        
    def __str__(self):
        return "Bitset: size={}, buf={}, non-zero={}".format(self.size,
                                                             self.buf, self.nnz)
        
    cpdef object update(self, object val):
        cdef int bsize = bit_set_size(self.size)
        cdef int8* buf = self.buf
                
        if isinstance(val, long):
            self.fill_buf_from_int(buf, bsize, val)
        else:
            self.fill_buf_from_iterable(buf, self.size, bsize, val)
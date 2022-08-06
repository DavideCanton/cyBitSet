__author__ = 'davide'

import sys
from setuptools import Extension, setup

exts = [
    Extension(
        "cyBitSet.cyBitSet", ["cyBitSet/cyBitSet.pyx"]
    )
]
for e in exts:
    e.cython_directives = {'language_level': '3'}

setup(
    name='cyBitSet',
    ext_modules=exts,
    packages=['cyBitSet'],
    data_files=[(
        'lib/python{}.{}/site-packages/cyBitSet'.format(*sys.version_info[:2]),
        ["cyBitSet/cyBitSet.pyi"]
    )],
)
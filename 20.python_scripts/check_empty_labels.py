#!/usr/bin/env python3

import sys
import os

import numpy as np

infile = {}

infile['labels'] = sys.argv[1]
infile['timeseries'] = sys.argv[2]

data = {}
for k in infile.keys():
    data[k] = np.genfromtxt(infile[k])

# Compare labels and timeseries  #!# Coming soon?

for k in infile.keys():
    filename, file_extension = os.path.splitext(infile[k])
    np.savetxt(os.path.join(f'{filename}_check', file_extension), data[k],
               fmt="%0.6f")

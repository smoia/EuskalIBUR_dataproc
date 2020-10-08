#!/usr/bin/env python3

import sys
import os

import numpy as np

infile = sys.argv[1]
outfile = sys.argv[2]

data = np.genfromtxt(infile)

if data.size < 20:
    data = np.append(data, [range(data.size + 1, 21)])


np.savetxt(outfile, data, fmt="%0.6f")

#!/usr/bin/env python3

import sys
import os

import numpy as np

infile = sys.argv[1]
outfile = sys.argv[2]

data = np.genfromtxt(infile)

data = (data - data.mean(axis=0)) / data.mean(axis=0)

data = np.nan_to_num(data)

np.savetxt(outfile, data, fmt="%0.6f")

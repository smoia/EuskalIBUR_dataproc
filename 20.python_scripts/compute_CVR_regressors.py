#!/usr/bin/env python3

import sys
import os
import biopac_preproc as bio
import numpy as np

sub = sys.argv[1]
ses = sys.argv[2]
ftype = sys.argv[3]

wdir = '/data'
SET_DPI = 100

cwd = os.getcwd()

os.chdir(wdir)

filename = f'sub-{sub}/ses-{ses}/func_phys/sub-{sub}_ses-{ses}_task-breathhold_physio'
npidx = np.genfromtxt(f'{filename}_manualpeaks.1D').astype('int')
co = np.genfromtxt(f'{filename}_co_orig.1D')

GM_name = f'CVR/sub-{sub}_ses-{ses}_GM_{ftype}_avg'
bio.parttwo(co, npidx, filename, GM_name)

os.chdir(cwd)

#!/usr/bin/env python3

import os
import biopac_preproc as bio
import numpy as np

wdir = '/data'
SET_DPI = 100

cwd = os.getcwd()

os.chdir(wdir)
for sub in ['007', '003', '002']:
    if sub == '002':
        lastses = 10
    else:
        lastses = 9

    for ses in range(1, 11):
        filename = f'sub-{sub}/ses-{ses:02g}/func_phys/sub-{sub}_ses-{ses:02g}_task-breathhold_physio'
        npidx = np.genfromtxt(f'{filename}_manualpeaks.1D').astype('int')
        co = np.genfromtxt(f'{filename}_co_orig.1D')

        ftype_list = ['optcom', 'echo-2', 'meica', 'vessels', 'networks']
        for ftype in ftype_list:
            GM_name = f'CVR/sub-{sub}_ses-{ses:02g}_GM_{ftype}_avg'
            bio.parttwo(co, npidx, filename, GM_name)

os.chdir(cwd)

#!/usr/bin/env python3

import os
import biopac_preproc as bio
import matplotlib.pyplot as plt


wdir = '/data'
SET_DPI = 100

for sub in ['002', '003', '007']:
    for ses in range(1, 11):
        if ses >= 7:
            ch = 5
        else:
            ch = 4

        os.chdir(wdir)
        path = f'sub-{sub}/ses-{ses:02g}/func_phys'
        filename = f'sub-{sub}_ses-{ses:02g}_task-breathhold_physio'
        os.chdir(path)
        co, pidx = bio.partone(filename, ch)

        plt.figure(figsize=(18, 10), dpi=SET_DPI)
        plt.plot(co)
        plt.title(f'sub {sub} ses {ses:02g}')
        plt.savefig(f'{filename}.png', dpi=SET_DPI)
        plt.close()

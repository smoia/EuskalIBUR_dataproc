#!/usr/bin/env python3

import os
import biopac_preproc as bio
import matplotlib.pyplot as plt

from shutil import copyfile

wdir = '/bcbl/home/public/PJMASK_2/PHYSIO/BIDS_BH'
SET_DPI = 100

for sub in ['002', '003', '007']:
    for ses in range(1, 11):  # range(1, 11):
        if ses >= 7:
            ch = 5
        else:
            ch = 4

        os.chdir(wdir)
        path = f'sub-{sub}/ses-{ses:02g}/func'
        filename = f'sub-{sub}_ses-{ses:02g}_task-breathhold_physio'
        os.chdir(path)
        if not os.path.exists('../func_phys'):
            os.mkdir('../func_phys')

        os.chdir('../func_phys')
        print(f'Copying file {filename}')
        copyfile(f'../func/{filename}.tsv.gz', f'./{filename}.tsv.gz')
        print(f'Decimating {filename}')
        co, pidx = bio.partone(filename, ch)

        # plt.figure(figsize=(18, 10), dpi=SET_DPI)
        # plt.plot(co)
        # plt.title(f'sub {sub} ses {ses:02g}')
        # plt.savefig(f'{filename}.png', dpi=SET_DPI)
        plt.close('all')

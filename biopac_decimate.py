#!/usr/bin/env python3

import os
import biopac_preproc as bio
import matplotlib.pyplot as plt


wdir = '/data/PHYSIO/BIDS'
filename = ''  # filename
ch = 4  # or 5


for sub in ['002', '003', '007']:
    for ses in range(1,11):
        if ses >= 7:
            ch = 5
        else:
            ch = 4

        os.chdir(wdir)
        path = 'sub-' + str(sub).zfill(3) + '/ses-' + str(ses).zfill(2) + '/func'
        filename = 'sub-' + str(sub).zfill(3) + '_ses-' + str(ses).zfill(2) + '_task-breathhold_physio'
        os.chdir(path)
        co, pidx = bio.partone(filename,ch)

        set_dpi = 100
        plt.figure(figsize=(18,10), dpi=set_dpi)
        plt.plot(co)
        plt.title('sub ' + str(sub).zfill(3) + ' ses ' + str(ses).zfill(2))
        plt.savefig(filename + '.png', dpi=set_dpi)
        plt.close()

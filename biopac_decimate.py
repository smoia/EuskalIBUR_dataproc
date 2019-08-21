import os
import biopac_preproc as bio
import matplotlib.pyplot as plt
import numpy as np

wdir = '/media/PHYSIO/BIDS'
filename = '' # filename
ch = 5 # or 5


for sub in range(9,11):
    for ses in range(7,11):
        if ses >= 7:
            ch = 6
        else:
            ch = 5

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

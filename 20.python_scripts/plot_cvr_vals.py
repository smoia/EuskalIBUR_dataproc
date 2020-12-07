#!/usr/bin/env python3

import os
import sys

import matplotlib.pyplot as plt
import nibabel as nib
import pandas as pd
import seaborn as sns


SUB_LIST = ['001', '002', '003', '004', '007', '008', '009']
LAST_SES = 10  # 10

SET_DPI = 200
FIGSIZE = (9, 2.5)

FTYPE_LIST = ['echo-2', 'optcom', 'meica-aggr', 'meica-orth',
              'meica-cons']
COLOURS = ['#d62728ff', '#2ca02cff', '#ff7f0eff', '#1f77b4ff',
           '#ff33ccff']
FTYPE_DICT = {'echo-2': 'SE-MPR', 'optcom': 'OC-MPR',
              'meica-aggr': 'ME-AGG', 'meica-orth': 'ME-MOD',
              'meica-cons': 'ME-CON'}
# Segmentation codes  # GM = 2, WM = 3
SEG_CODE = {'GM': 2,
            'WM': 3}
SEG_DICT = {'GM': 'Grey Matter',
            'WM': 'White Matter'}

LAST_SES += 1

wdr = sys.argv[1]

os.chdir(wdr)
os.makedirs('plots', exist_ok=True)


# Create data dictionaries
# Dataframe dictionary
df_columns = ['val', 'tissue', 'ftype', 'ses', 'sub']
data_avg = {'CVR [%BOLD/mmHg]': pd.DataFrame(columns=df_columns),
            'Lag [s]': pd.DataFrame(columns=df_columns),
            'Percentage of significant voxels': pd.DataFrame(columns=df_columns)}
# Subjects segmentations
seg_data = dict.fromkeys(SUB_LIST)

# Read segmentation of all subjects
for sub in SUB_LIST:
    # Load segmentation
    seg_img = nib.load(f'sub-{sub}/ses-01/anat_preproc/'
                       f'sub-{sub}_ses-01_acq-uni_T1w_seg2mref.nii.gz')
    seg_data[sub] = seg_img.get_data()
    # GM = 2, WM = 3

# Prepare plot
fig, ax = plt.subplots(nrows=1, ncols=3, figsize=FIGSIZE, dpi=SET_DPI)
ax = ax.flatten()
plt.suptitle('Average values of all subjects, all sessions, across strategies')

for n, k in enumerate(data_avg.keys()):
    # Create the dataframe
    for sub in SUB_LIST:
        for ses in range(1, LAST_SES):
            for ftype in FTYPE_LIST:
                # Load maps
                f_prefix = f'sub-{sub}_ses-{ses:02d}_{ftype}'
                if k == 'Lag [s]':
                    img = nib.load(f'CVR/{f_prefix}_map_cvr/'
                                   f'{f_prefix}_cvr_lag_masked.nii.gz')

                else:
                    img = nib.load(f'CVR/{f_prefix}_map_cvr/'
                                   f'{f_prefix}_cvr_masked.nii.gz')

                img_data = img.get_data()

                # Get GM and WM, remove 0, average, append to dataframe
                d = {'GM': img_data[seg_data[sub] == SEG_CODE['GM']],
                     'WM': img_data[seg_data[sub] == SEG_CODE['WM']]}

                for dk in d.keys():
                    # if k == 'CVR':
                    #     d[dk] = np.abs(d[dk])

                    # remove zeroes
                    d[dk] = d[dk][d[dk] != 0]

                    if k == 'Percentage of significant voxels':
                        val = (d[dk].size * 100 /
                               (seg_data[sub] == SEG_CODE[dk]).size)
                    else:
                        val = d[dk].mean()

                    df = pd.DataFrame.from_dict({'val': [val],
                                                 'tissue': [SEG_DICT[dk]],
                                                 'ftype': [FTYPE_DICT[ftype]],
                                                 'ses': [f'{ses:02d}'],
                                                 'sub': [sub]})

                    data_avg[k] = data_avg[k].append(df, ignore_index=True)

    # Plot!
    sns.boxplot(data=data_avg[k], x='tissue', y='val',
                hue='ftype', orient='v',
                palette=sns.color_palette(COLOURS), ax=ax[n])

    # Some little tweaks for prettier plots
    if n != 0:
        ax[n].legend().remove()

    ax[n].set_title(k)
    ax[n].yaxis.set_label_text(k)
    ax[n].xaxis.set_label_text('')

    # Export dataframe to play with it
    data_avg[k].to_csv(f'plots/Dataframe_{k.split()[0]}.csv')

# Final tweaks and exports
plt.tight_layout()
plt.savefig('plots/CVR_values.png', dpi=SET_DPI)
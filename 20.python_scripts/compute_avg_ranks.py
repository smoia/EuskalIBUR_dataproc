#!/usr/bin/env python3

import argparse
import os
import sys

import nibabel as nib
import numpy as np

SUB_LIST = ['001', '002', '003', '004', '007', '008', '009']
LAST_SES = 10  # 10

LAST_SES += 1

SET_DPI = 100
FIGSIZE = (18, 10)

COLOURS = ['#1f77b4ff', '#2ca02cff', '#d62728ff', '#ff7f0eff', '#ff33ccff']

ATLAS_DICT = {'Mutsaerts2015': 'Mutsaerts (vascular)',
              'Mutsaerts2015-hem': 'Mutsaerts (vascular)',
              'Mutsaerts2015-sub': 'Mutsaerts (vascular + subcortical)',
              'Subcortical': 'Subcortical + cerebellum',
              'Yeo2011-7': 'Yeo (functional)',
              'Schaefer2018-100': 'Schaefer (functional)'}

#########
# Utils #
#########
def _get_parser():
    parser = argparse.ArgumentParser()

    parser.add_argument('-wdr', '--workdir',
                        dest='wdr',
                        type=str,
                        help='Workdir.',
                        default='/data')
    parser.add_argument('-af', '--atlasfile',
                        dest='atlas_files',
                        nargs='*',
                        help='Use this atlas - fullpath and extension. Multiple allowed.',
                        default='')
    parser.add_argument('-an', '--atlasname',
                        dest='atlas_names',
                        nargs='*',
                        help='Use this name for atlas. Has to be same number as specified with -af.',
                        default='')
    parser.add_argument('-ftype', '--ftype',
                        dest='ftype',
                        type=str,
                        help='The type of map you want to average',
                        required=True)
    return parser


def load_nifti_get_mask(fname, dim=4):
    if fname.endswith('.nii.gz'):
        fname = fname[:-7]
    img = nib.load(f'{fname}.nii.gz')
    data = img.get_fdata()
    if len(data.shape) > dim:
        for ax in range(dim, len(data.shape)):
            data = np.delete(data, np.s_[1:], axis=ax)
    data = np.squeeze(data)
    if len(data.shape) >= 4:
        mask = np.squeeze(np.any(data, axis=3))
    else:
        mask = (data < 0) + (data > 0)
    return data, mask, img


def compute_rank(data):
    reord = np.argsort(data, axis=-1)
    rank = reord.argmax(axis=-1)
    return rank/(data.shape[-1]-1)*100


def export_nifti(data, img, fname):
    out_img = nib.Nifti1Image(data, img.affine, img.header)
    if fname.endswith('.nii.gz'):
        fname = fname[:-7]
    out_img.to_filename(f'{fname}.nii.gz')


#############
# Workflows #
#############


def compute_metric(data, atlases, mask, metric='avg'):
    # metric can be avg or iqr
    # Compute averages and store them in pandas dataframes
    # Then compute rank and store them in other pd.DataFrame

    print(f'Compute metrics: {metric}')
    comp = dict.fromkeys(atlases.keys())
    for atlas in atlases.keys():
        print(f'Working on {atlas}')
        unique = np.unique(atlases[atlas])
        unique = unique[unique > 0]
        print(f'Labels: {unique}, len: {len(unique)}, surr: {data.shape[-1]}')
        # Initialise dataframe and dictionary for series
        parcels = np.empty([len(unique), data.shape[-1]])

        # Compute averages
        for m, label in enumerate(unique):
            print(f'Metric: {metric}, Label: {label} ({m})')
            if metric == 'avg':
                parcels[m, :] = data[atlases[atlas] == label].mean(axis=0)
            elif metric == 'iqr':
                dist = data[atlases[atlas] == label]
                parcels[m, :] = (np.percentile(dist, 75, axis=0) -
                                 np.percentile(dist, 25, axis=0))

        rank = compute_rank(parcels)
        if metric == 'iqr':
            print('Invert iqr rank')
            rank = 100 - rank

        comp[atlas] = atlases[atlas].copy()

        print(f'Recompose atlas {atlas}')
        for m, label in enumerate(unique):
            comp[atlas][atlases[atlas] == label] = rank[m]

    return comp


########
# MAIN #
########
if __name__ == '__main__':
    args = _get_parser().parse_args(sys.argv[1:])
    os.chdir(args.wdr)

    # Prepare dictionaries
    mask = dict.fromkeys(SUB_LIST)
    data = dict.fromkeys(SUB_LIST)
    data['avg'] = dict.fromkeys(SUB_LIST)
    data['var'] = dict.fromkeys(SUB_LIST)

    # Read segmentation of all subjects
    for sub in SUB_LIST:
        data[sub] = {}
        mask[sub] = {}
        for ses in range(1, LAST_SES):
            # Load data
            data[sub][ses], mask[sub][ses], img = load_nifti_get_mask(args.fname, dim=3)

        # Stack in 4d (axis 3) and mask data (invert nimg mask for masked array)
        mask[sub]['stack'] = np.stack(mask[sub].values(), axis=3)
        data[sub]['stack'] = np.ma.array(np.stack(data[sub].values(), axis=3),
                                         mask=abs(mask[sub]['stack']-1))

        # Compute average & variance of masked voxels across d4
        data['avg'][sub] = data[sub]['stack'].mean(axis=3)
        data['var'][sub] = ((data[sub]['stack'] -
                             data['avg'][sub][:, :, :, np.newaxis])**2).mean(axis=3)

    # Stack subjects in 4d
    for val in ['avg', 'var']:
        data[val]['all'] = np.stack(data[val].values(), axis=3)

    # Invert variance & set infinites to zero (if any)
    invvar = 1 / data['var']['all']
    invvar[np.isinf(invvar)] = 0

    # Mask group average using invvar
    data['avg']['all'] = np.ma.array(data['avg']['all'], mask=[invvar == 0])

    # Finally, compute variance weighted average & fill masked entries with 0
    wavg = np.ma.average(data['avg']['all'], weights=invvar, axis=3).filled(0)

    # Export
    export_nifti(wavg.astype(float), img, f'../wavg_{args.ftype}_masked_optcom.nii.gz')

#!/usr/bin/env python3

import argparse
import os
import sys

import nibabel as nib
import numpy as np

SUB_LIST = ['001', '002', '003', '004', '007', '008', '009']
LAST_SES = 10  # 10

LAST_SES += 1


def _get_parser():
    parser = argparse.ArgumentParser()
    parser.add_argument('-ftype', '--ftype',
                        dest='ftype',
                        type=str,
                        help='The type of map you want to average',
                        required=True)
    parser.add_argument('-wdr', '--workdir',
                        dest='wdr',
                        type=str,
                        help='Workdir.',
                        default='/data')
    return parser


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
            img_data = nib.load(f'std_optcom_{args.ftype}_masked_{sub}_{ses:02g}.nii.gz')
            img_mask = nib.load(f'masks/std_optcom_mask_{sub}_{ses:02g}.nii.gz')
            data[sub][ses] = img_data.get_fdata()
            mask[sub][ses] = img_mask.get_fdata()

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
    out_img = nib.Nifti1Image(wavg.astype(float), img_data.affine, img_data.header)
    out_img.to_filename(f'../wavg_{args.ftype}_masked_optcom.nii.gz')

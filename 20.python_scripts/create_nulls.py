#!/usr/bin/env python3

import argparse
import os
import sys

import matplotlib.patches as mpatches
import matplotlib.pyplot as plt
import nibabel as nib
import numpy as np
from brainsmash.workbench.geo import volume
from brainsmash.mapgen.eval import sampled_fit
from brainsmash.mapgen.sampled import Sampled


LAST_SES = 10  # 10
ATLAS_LIST = ['Mutsaerts2015', 'Schaefer2018-100']

SET_DPI = 100
FIGSIZE = (18, 10)

COLOURS = ['#2ca02cff', '#d62728ff']  # , '#1f77b4ff']
# COLOURS = ['#d62728ff', '#2ca02cff', '#ff7f0eff', '#1f77b4ff',
#            '#ff33ccff']
ATLAS_FILE = {'Mutsaerts2015': 'ATTbasedFlowTerritories_resamp_2.5mm',
              'Schaefer2018-100': 'Schaefer2018_100Parcels_7Networks_order_FSLMNI152_2.5mm'}
ATLAS_DICT = {'Mutsaerts2015': 'Mutsaerts (vascular)',
              'Schaefer2018-100': 'Schaefer (functional)'}

ATLAS_FOLDER = os.path.join('CVR_reliability', 'Atlas_comparison')
LAST_SES += 1

DISTMAP = '/home/nemo/Scrivania/Test_workbench/CVR_reliability/Atlas_comparison/mmdist/distmat.npy'
INDEX = '/home/nemo/Scrivania/Test_workbench/CVR_reliability/Atlas_comparison/mmdist/index.npy'


#########
# Utils #
#########
def _get_parser():
    parser = argparse.ArgumentParser()
    parser.add_argument('-in', '--input-file',
                        dest='data_fname',
                        type=str,
                        help='The map you want to scramble',
                        required=True)
    parser.add_argument('-type', '--input-type',
                        dest='data_content',
                        type=str,
                        help='The type of data represented in the map you want '
                             'to scramble',
                        default='')
    parser.add_argument('-wdr', '--workdir',
                        dest='wdr',
                        type=str,
                        help='Workdir.',
                        default='/data')
    parser.add_argument('-sdr', '--scriptdir',
                        dest='scriptdir',
                        type=str,
                        help='Script directory.',
                        default='/scripts')
    parser.add_argument('-overwrite', '--overwrite',
                        dest='overwrite',
                        action='store_true',
                        help='Overwrite previously computed distances.',
                        default=False)
    parser.add_argument('-nm', '--num-null-maps',
                        dest='null_maps',
                        type=int,
                        help='Number of surrogate maps to generate. '
                             'Default is 1000.',
                        default=1000)
    parser.add_argument('-pn', '--plotname',
                        dest='plot_name',
                        type=str,
                        help='Plot name. Default: plots/plot.',
                        default='plots/plot')
    # Workflows
    parser.add_argument('-ga', '--genatlas',
                        dest='genatlas',
                        action='store_true',
                        help='Generate atlas dictionary.',
                        default=False)
    parser.add_argument('-cd', '--compdist',
                        dest='compdist',
                        action='store_true',
                        help='Compute distance and create memory-mapped file.',
                        default=False)
    parser.add_argument('-ev', '--evalvars',
                        dest='evalvars',
                        action='store_true',
                        help='Evaluate variograms.',
                        default=False)
    parser.add_argument('-gs', '--gensurr',
                        dest='gensurr',
                        action='store_true',
                        help='Generate surrogates and plots.',
                        default=False)
    parser.add_argument('-pp', '--plotparc',
                        dest='plotparc',
                        action='store_true',
                        help='Generate plots.',
                        default=False)
    return parser


def export_file(wdr, fname, ex_object):
    ex_file = os.path.join(wdr, ATLAS_FOLDER, fname)
    os.makedirs(os.path.join(wdr, ATLAS_FOLDER), exist_ok=True)
    np.savez_compressed(ex_file, ex_object)


def check_file(wdr, fname):
    in_file = os.path.join(wdr, ATLAS_FOLDER, fname)
    return os.path.isfile(in_file)


def load_file(wdr, fname):
    in_file = os.path.join(wdr, ATLAS_FOLDER, fname)
    read_in = np.load(in_file, allow_pickle=True)['arr_0']
    return read_in[..., np.newaxis][0]


def load_and_mask_nifti(data_fname, atlases):
    data_img = nib.load(f'{data_fname}.nii.gz')
    data = data_img.get_fdata()
    if len(data.shape) == 5:
        data = data[:, :, :, 0, 0]
    elif len(data.shape) == 4:
        data = data[:, :, :, 0]
    elif len(data.shape) > 5:
        raise Exception('Something is wrong with the nifti dimensions')
    return data[atlases['intersect'] > 0]


#############
# Workflows #
#############
def generate_atlas_dictionary(wdr, scriptdir, overwrite=False):
    # Check that you really need to do this
    if overwrite is True or check_file(wdr, 'atlases.npz') is False:
        # Create data dictionary
        atlases = dict.fromkeys(ATLAS_LIST)

        print('Read and intersect atlases')
        # Read atlases
        for atlas in ATLAS_LIST:
            atlas_img = nib.load(os.path.join(scriptdir, '90.template',
                                              f'{ATLAS_FILE[atlas]}.nii.gz'))
            atlases[atlas] = atlas_img.get_fdata()

        # Create intersection of atlases
        atlases['intersect'] = atlases[ATLAS_LIST[0]].copy()

        for atlas in ATLAS_LIST[1:]:
            atlases['intersect'] = atlases['intersect'] + atlases[atlas]

        # Export atlases
        export_file(wdr, 'atlases', atlases)
    else:
        print(f'Found existing atlases dictionary in {wdr}, '
              'loading instead of generating.')
        atlases = load_file(args.wdr, 'atlases.npz')

    return atlases


def compute_distances(wdr, atlases, overwrite=False):
    # Check that you really need to do this
    # distmap = os.path.join('mmdist', 'distmap.npy')
    distmap = DISTMAP
    # if overwrite is True or check_file(wdr, distmap) is False:
    if overwrite is True or os.path.isfile(distmap) is False:
        coord_dir = os.path.join(wdr, ATLAS_FOLDER, 'mmdist')
        # Create folders
        os.makedirs(coord_dir, exist_ok=True)
        print('Computing volume distance')
        # Get position of the voxels in the atlas intersection
        coordinates = np.asarray(np.where(atlases['intersect'] > 0)).transpose()
        dist_fname = volume(coordinates, coord_dir)
    else:
        # distmap = os.path.join(wdr, ATLAS_FOLDER, distmap)
        # index = os.path.join(wdr, ATLAS_FOLDER, 'mmdist', 'index.npy')
        index = INDEX
        print('Distance memory mapped file already exists. Skip computation!')
        dist_fname = {'D': distmap, 'index': index}

    return dist_fname


def evaluate_variograms(data_fname, atlases, dist_fname, wdr, **kwargs):
    # Read data and feed surrogate maps
    data_masked = load_and_mask_nifti(data_fname, atlases)
    print(f'Evaluating variogram for {data_fname}')
    sampled_fit(x=data_masked, D=dist_fname['D'], index=dist_fname['index'],
                nsurr=50, **kwargs)

    ex_file = os.path.join(wdr, ATLAS_FOLDER, f'{data_fname}_variogram.png')
    plt.savefig(ex_file)
    plt.close('all')


def generate_surrogates(data_fname, atlases, dist_fname, null_maps, wdr):
    # Read data and feed surrogate maps
    data_masked = load_and_mask_nifti(data_fname, atlases)
    print(f'Start surrogates for {data_fname}')

    gen = Sampled(x=data_masked, D=dist_fname['D'], index=dist_fname['index'])
    surrogate_maps = gen(n=null_maps)

    # Export atlases
    export_file(wdr, f'surrogates_{data_fname}', surrogate_maps)

    return surrogate_maps, data_masked


def plot_parcels(null_maps, data_content, atlases, surrogate_maps, data_masked, plot_name=''):
    # Plot parcel value against voxel size
    # Setup plot
    plt.figure(figsize=FIGSIZE, dpi=SET_DPI)
    plt.xlabel('Number of voxels in MNI')

    # #!# ylabel has to reflect data
    plt.ylabel(data_content)
    # plt.ylim(0, 1)
    patch = []

    for atlas in ATLAS_LIST:
        # Mask atlas to match data_masked
        atlas_masked = atlases[atlas][atlases['intersect'] > 0]
        # Find unique values (labels) and occurrencies (label size)
        unique, occurrencies = np.unique(atlas_masked, return_counts=True)

        # Populate the plot
        for i, label in enumerate(unique[unique > 0]):
            # Start with all surrogates
            for n in range(null_maps):
                # compute pacel average
                label_avg = surrogate_maps[n][atlas_masked == label].mean()
                plt.plot(occurrencies[i], label_avg, '.', color='#bbbbbbff')

    # New loop to be sure that real data appear on top of surrogates
    for j, atlas in ATLAS_LIST:
        # Mask atlas to match data_masked
        atlas_masked = atlases[atlas][atlases['intersect'] > 0]
        # Find unique values (labels) and occurrencies (label size)
        unique, occurrencies = np.unique(atlas_masked, return_counts=True)

        # Populate the plot
        for i, label in unique[unique > 0]:
            # Continue with real maps
            label_avg = data_masked[atlas_masked == label].mean()
            plt.plot(occurrencies[i], label_avg, '.', color=COLOURS[j])

        # Add a patch for the current atlas
        patch = patch + [mpatches.Patch(color=COLOURS[j], label=ATLAS_DICT[atlas])]

    # Adjust legend and layout
    patch = patch + [mpatches.Patch(color='#bbbbbbff', label='Surrogates')]
    plt.legend(handles=patch)
    plt.tight_layout()

    # Save plot
    plt.savefig(f'{plot_name}_by_voxel.png', dpi=SET_DPI)
    plt.close('all')


########
# MAIN #
########
if __name__ == '__main__':
    args = _get_parser().parse_args(sys.argv[1:])

    # Check that data_fname doesn't end for nii.gz
    data_fname = args.data_fname

    if data_fname.endswith('.nii.gz'):
        data_fname = data_fname[:-7]
    elif data_fname.endswith('.nii'):
        data_fname = data_fname[:-4]

    if args.genatlas is True:
        # Check if atlases was already computed
        if args.overwrite is True or check_file(args.wdr, 'atlases.npz') is False:
            atlases = generate_atlas_dictionary(args.wdr, args.scriptdir)
        else:
            print('Atlas already exists')

    elif args.compdist is True:

        atlases = generate_atlas_dictionary(args.wdr, args.scriptdir)
        dist_fname = compute_distances(args.wdr, atlases, args.overwrite)

    elif args.evalvars is True:
        atlases = generate_atlas_dictionary(args.wdr, args.scriptdir)
        dist_fname = compute_distances(args.wdr, atlases, args.overwrite)
        # kwargs = {'ns': 500,
        #   'knn': 1500,
        #   'pv': 70
        #   }
        evaluate_variograms(data_fname,
                            atlases,
                            dist_fname,
                            args.wdr)

    elif args.gensurr is True:
        atlases = generate_atlas_dictionary(args.wdr, args.scriptdir)
        dist_fname = compute_distances(args.wdr, atlases, args.overwrite)
        surrogate_maps, data_masked = generate_surrogates(data_fname,
                                                          atlases,
                                                          dist_fname,
                                                          args.null_maps,
                                                          args.wdr)
        plot_parcels(args.null_maps,
                     args.data_content,
                     atlases,
                     surrogate_maps,
                     data_masked,
                     args.plot_name)

    elif args.plotparc is True:
        # Check if surrogates exists, otherwise stop
        surrogate_fname = f'surrogates_{data_fname}'
        if check_file(args.wdr, surrogate_fname) is False:
            raise Exception('Cannot find surrogate maps: '
                            f'{surrogate_fname} in '
                            f'{os.path.join(args.wdr, ATLAS_FOLDER)}')
        else:
            atlases = generate_atlas_dictionary(args.wdr, args.scriptdir)
            surrogate_maps = load_file(args.wdr, surrogate_fname)
            # Read and extract data
            data_masked = load_and_mask_nifti(data_fname, atlases)

            plot_parcels(args.null_maps,
                         args.data_content,
                         atlases,
                         surrogate_maps,
                         data_masked,
                         args.plot_name)

    else:
        raise Exception('No workflow flag specified!')

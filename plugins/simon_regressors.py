#!/usr/bin/env python3

import io
import os
import pandas as pd
from os.path import join as opj
import numpy as np


def read_1d(fname):
    """[summary]

    Parameters
    ----------
    fname : [type]
        [description]

    Returns
    -------
    [type]
        [description]
    """
    try:
        content = pd.read_csv(fname, delim_whitespace=True, header=None)
    except:
        content = pd.DataFrame({'A': []})

    return content


def write_1d(fname, output):
    """[summary]

    Parameters
    ----------
    fname : [type]
        [description]
    output : [type]
        [description]
    """
    df = pd.read_csv(io.StringIO('\n'.join(output)),
                     delim_whitespace=True, names=['col'])
    pd.DataFrame(df.values.reshape(1, len(df.values))).to_csv(fname, index=False, header=False, sep=' ')


def read_onsets(onset_path, sbj, ses):
    """[summary]

    Parameters
    ----------
    onset_path : [type]
        [description]
    sbj : [type]
        [description]
    ses : [type]
        [description]

    Returns
    -------
    [type]
        [description]
    """
    # Get 1D files with onsets
    correct = opj(onset_path, f'{sbj}_{ses}_task-simon_correct_onset.1D')
    incorrect = opj(onset_path, f'{sbj}_{ses}_task-simon_incorrect_onset.1D')
    red_left = opj(onset_path, f'{sbj}_{ses}_task-simon_redleft_onset.1D')
    green_left = opj(onset_path, f'{sbj}_{ses}_task-simon_greenleft_onset.1D')
    red_right = opj(onset_path, f'{sbj}_{ses}_task-simon_redright_onset.1D')
    green_right = opj(onset_path, f'{sbj}_{ses}_task-simon_greenright_onset.1D')

    onsets = {'correct': correct, 'incorrect': incorrect, 'red_left': red_left,
              'green_left': green_left, 'red_right': red_right, 'green_right': green_right}

    return onsets


def extract_onsets(task, performance):
    """[summary]

    Parameters
    ----------
    task : [type]
        [description]
    performance : [type]
        [description]

    Returns
    -------
    [type]
        [description]
    """
    onsets = []
    task_squeezed = np.squeeze(task.values)
    for i in range(len(task_squeezed)):
        # Only save if onset is in correct list
        if float(task_squeezed[i].split(':')[0]) in performance.values:
            onsets.append(task_squeezed[i])

    return onsets


def check_save_regressors(onset_path, task_fname, correct_fname,
                          incorrect_fname, out_fname, sbj, ses):
    """[summary]

    Parameters
    ----------
    onset_path : [type]
        [description]
    task_fname : [type]
        [description]
    correct_fname : [type]
        [description]
    incorrect_fname : [type]
        [description]
    out_fname : [type]
        [description]
    sbj : [type]
        [description]
    ses : [type]
        [description]
    """
    # Read 1D files with onsets
    task = read_1d(task_fname)
    correct = read_1d(correct_fname)
    incorrect = read_1d(incorrect_fname)

    # Output filenames
    correct_out_fname = opj(onset_path,
                            f'{sbj}_{ses}_task-simon_{out_fname}_correct_onset.1D')
    incorrect_out_fname = opj(onset_path,
                              f'{sbj}_{ses}_task-simon_{out_fname}_incorrect_onset.1D')

    if correct.empty:
        # Correct onsets file is empty
        correct_onsets = ['-1:0.0']
    else:
        correct_onsets = extract_onsets(task, correct)
        # If correct does not belong to task
        if not correct_onsets:
            correct_onsets = ['-1:0.0']

    if incorrect.empty:
        # Incorrect onsets file is empty
        incorrect_onsets = ['-1:0.0']
    else:
        incorrect_onsets = extract_onsets(task, incorrect)
        # If incorrect does not belong to task
        if not incorrect_onsets:
            incorrect_onsets = ['-1:0.0']

    # Save correct onsets
    write_1d(correct_out_fname, output=correct_onsets)

    # Save incorrect onsets
    write_1d(incorrect_out_fname, output=incorrect_onsets)


def generate_regressors(onset_path, onsets, sbj, ses):
    """[summary]

    Parameters
    ----------
    onset_path : [type]
        [description]
    onsets : [type]
        [description]
    sbj : [type]
        [description]
    ses : [type]
        [description]
    """
    correct = onsets['correct']
    incorrect = onsets['incorrect']

    # Left congruent
    lc_out = 'left_congruent'
    check_save_regressors(onset_path, onsets['green_left'], correct, incorrect, lc_out, sbj, ses)

    # Right congruent
    rc_out = 'right_congruent'
    check_save_regressors(onset_path, onsets['red_right'], correct, incorrect, rc_out, sbj, ses)

    # Left incongruent
    li_out = 'left_incongruent'
    check_save_regressors(onset_path, onsets['red_left'], correct, incorrect, li_out, sbj, ses)

    # Right incongruent
    ri_out = 'right_incongruent'
    check_save_regressors(onset_path, onsets['green_right'], correct, incorrect, ri_out, sbj, ses)


def main():
    """[summary]
    """
    prj_dir = '/bcbl/home/public/PJMASK_2/preproc'

    # Get subject directories
    sbj_dirs = [dirname for dirname in os.listdir(prj_dir) if 'sub' in dirname]

    # Loop through all subject directories
    for sbj_dir in sbj_dirs:

        sbj_path = opj(prj_dir, sbj_dir)

        if os.path.isdir(sbj_path):

            # Get session directories
            ses_dirs = os.listdir(sbj_path)

            # Loop through all session directories
            for ses_dir in ses_dirs:

                try:
                    print(f'Creating regressors for {sbj_dir} and {ses_dir}...')

                    ses_path = opj(sbj_path, ses_dir)
                    onset_path = opj(ses_path, 'func_preproc/onsets')

                    onsets = read_onsets(onset_path, sbj_dir, ses_dir)

                    generate_regressors(onset_path, onsets, sbj_dir, ses_dir)

                except:
                    print(f'Could not create regressors for {sbj_dir} and {ses_dir}')


if __name__ == '__main__':
    main()

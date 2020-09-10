# -*- coding: utf-8 -*-
"""
plot_brains v0.1 creates orthogonal views of the Glasser atlas on normalized T1 images to check the normalization and overlap with ROIs. Though intended for T1s, any imaging file should work.
1) For plot_prob_atlas to work, the Glasser nii needed to be split into a 4d format. However, this function takes forever to draw really nice figures. Went with plot_roi instead.
2) The labels for the atlas are supplied in the txt file that corresponds with the nii.

Created on Wed Sep  2 15:38:22 2020
@author: Annie Sutton, PhD
"""


import os, sys
import pandas as pd
import numpy as np
from glob import glob

import matplotlib.pyplot as plt

import nibabel as nib
from nilearn import plotting

print(f"Python {sys.version_info[0]} + '.' + {sys.version_info[1]} + '.' + {sys.version_info[2]}")

home_dir = '/data/images/eses'
atlas_dir = '/data/analysis/masks'
mask_img = os.path.join(atlas_dir,'MMP_in_MNI_corr.nii')
#mask_img = os.path.join(atlas_dir,'MMP_merged.nii')
mask_labels = os.path.join(atlas_dir, 'MMP_in_MNI_corr.txt')

def find_files(folder, filename):
    """Helper function to get the individuals' imaging files that will be plotted."""
    return sorted(glob(os.path.join(folder,'**', filename + '*.nii'),recursive=True))

def map_Glasser_on_norm(nii):
    """Plot the Glasser parcellations on the normalized brains of preprocessed individuals"""
    img = nib.load(nii)
    subj_name = os.path.basename(nii).split('.')[0]
    fname=os.path.join(home_dir,subj_name+'_MMP.jpg')
    #plotting.plot_prob_atlas(mask_img, img)
    plotting.plot_roi(mask_img,img)
    print(f'Saving {fname}')
    plt.savefig(fname,transparent = True, dpi=300)
    plt.show()


if __name__ == '__main__':
    files = find_files(home_dir, 'wc0e')
    for f in files:
        map_Glasser_on_norm(f)

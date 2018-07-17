# Specifically modified for the Mac Server.

import os
import numpy as np
import pandas as pd
import glob
import filter_study as fs

# import qgrid  #For future, interactive filters that can be built out for non-coders?

# import qgrid  #For future, interactive filters that can be built out for non-coders?
full_desc = 'no'  # Toggle to "debug" new study entries
home = '/Volumes/Data_2/Brianne'
intervening_dir = 'tregellas'
#tool_dir = '/home/brianne/tools/fmri_processing_utilities'
tool_dir = os.path.join(home, 'tools/fmri_processing_utilities')
project = 'wlm'

# study_filters = ('tx','gender','normal_responder','obese') #priming study
study_filters = ('tx', 'gender', 'hunger_level', 'scan_point')  # wlm study

img_dir = glob.glob(os.path.join(home, intervening_dir, (project + '*')))
print(os.path.join(home, intervening_dir, (project + '*')))
analysis_dir = glob.glob(os.path.join(
    home, intervening_dir, (project + '*')))[0]

# Load the dataframe from which we can filter
demo_file = glob.glob(os.path.join(analysis_dir, '*demo*xlsx'))
########################################################################
###  Should not require changes to the hard coding from here         ###
########################################################################
if len(demo_file) > 1:
    print('Detected multiple versions of the study demographics.\nAssuming the first is the correct sheet: {}'.format(
        demo_file[0]))
df = pd.DataFrame(pd.read_excel(demo_file[0])).astype(
    str).sort_values(by=['subject_id'])
# to attempt to normalize names for ensuing functions
df.columns = [x.lower() for x in df.columns]
if 'y' in full_desc:
    print(df.columns.tolist())
    print(df.shape)
    print(fs.define_filter_list())


# this will enable multiple filters to be setup with full brain power and traceable record
setup_file = glob.glob(os.path.join(analysis_dir, '*setup*xlsx'))
if len(setup_file) > 1:
    print('Detected multiple versions of the study demographics.\nAssuming the first is the correct sheet: {}'.format(
        setup_file[0]))
setup_df = pd.DataFrame(pd.read_excel(setup_file[0])).dropna(how='all')
# to attempt to normalize names for ensuing functions
setup_df.columns = [x.lower() for x in setup_df.columns]


if 'y' in full_desc:
    print(setup_df.head(5))


for r in range(setup_df.shape[0] - 5, setup_df.shape[0]):
    err = 'False'  # flag for incomplete variable loading
    # Find the conditions that must be satisfied to be part of the analysis
    # since each analysis might have different columns that are empty, do the col drop here.
    analysis_dict = setup_df.iloc[r].dropna().to_dict()
    task = analysis_dict['task'].strip()
    results_dir = glob.glob(os.path.join(
        home, intervening_dir, (project + '*'), 'results', task))[0]
    #results_dir = 'dummy_file'
    groups = [x.strip() for x in analysis_dict['groups'].split(',')]
    print(len(groups))
    conditions = list(
        [k for k, v in analysis_dict.items() if k in study_filters])
    # apply the filters to pare down the groups and corresponding df's

    for p in range(len(groups)):
        print('Row {}: Group {} of {} is up'.format(r, p + 1, len(groups)))
        input_dict = {}
        for cond in conditions:
            input_dict[cond] = analysis_dict[cond].strip().split(',')[p]
        [filter_dict, filters, result_suffix] = fs.define_filter_list(
            **input_dict)  # normal_responder = responder[k])
        if len(set(analysis_dict['tx'].split(','))) == 1:
            result_suffix = (result_suffix + 'ExpCondOnly')
            print('New suffix = {}'.format(result_suffix))
        try:
            if len(set(analysis_dict['gender'].split(','))) == 1:
                result_suffix = (result_suffix + '_FemOnly')
                print('New suffix = {}'.format(result_suffix))
        except KeyError:
            pass

        if 'y' in analysis_dict['timept_comparison'].strip():
            result_suffix = (result_suffix + '_timeptComp')
            print('New suffix = {}'.format(result_suffix))

        # By setting this new variable before defining the object, we can sneakily avoid truly dynamic variable naming and duplicating an object.
        name = analysis_dict['groups'].split(',')[p].strip()
        print('Loading {} for {}'.format(filter_dict, name))
        groups[p] = fs.GroupDef(filter_dict, filters, df)
        groups[p].filter_subjs()
        groups[p].get_members()
        while len(groups[p].members) < 1:
            print('Sampling size problem with {}'.format(groups[p].filter))
            err = 'True'
            break
        if len(groups[p].members) > 1:
            groups[p].name = name
            with open(os.path.join(analysis_dir, groups[p].txt_file), 'w+') as fp:
                fp.write('{}'.format('\n'.join(groups[p].members)))

    if err == 'False':
            # Set up for the matlab command
        group_names = [groups[x].name for x in range(len(groups))]
        grp_list_suffixes = [groups[x].filter for x in range(
            len(groups))]  # to compbine with "group" in filename
        # print(list_suffixes)
        grp_list_suffixes = (
            '\'' + '\', \''.join(map(str, grp_list_suffixes)) + '\'')
        # print(list_suffixes)
        cons_incl = [x.strip()
                     for x in analysis_dict['cons_incl'].split(',')]
        analysis_type = [x.strip()
                         for x in analysis_dict['analysis_type'].split(',')]
        res_basename = [x.strip()
                        for x in analysis_dict['result_basename'].split(',')]
        if 'suffix' in analysis_dict:
            result_suffix = (result_suffix + analysis_dict['suffix'])
        timept_comparison = [x.strip()
                             for x in analysis_dict['timept_comparison'].split(',')]
        # Make the options for MATLAB function = second_level_spm12(contrasts, Groups, list_suffixes, comp_type, results_dir, result_suffixes)
        opts = ("{\'" + '\', \''.join(cons_incl) + "\'}, {\'" + '\', \''.join(group_names) + "\'}, {" +
                str(grp_list_suffixes) + "}, {" + str(analysis_type) + "}, \'" + results_dir + "\', {\'" +
                result_suffix + "\'}," + str(res_basename) + "," + str(timept_comparison))

        cmd = ('matlab -nosplash -nodesktop -r "addpath(\'' +
               tool_dir + '\'); second_level_spm12(' + opts + '); quit()"')
        print(cmd)
        os.system(cmd)

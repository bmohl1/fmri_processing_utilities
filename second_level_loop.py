#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Fri Aug  9 10:45:13 2019
@author: brianne

"""

import sys, subprocess

# If the version of MATLAB that installed matlab.engine was < 2019, then the version of python had to be lower.
#if not 3 == sys.version_info[0]:
#        raise Exception("Must be using Python 3.5")
#elif not 5 == sys.version_info[1]:
#        raise Exception("Must be using Python 3.5")
  
debug = 'no'
study_name = 'priming'
design_name = 'priming_highCalpalooza' # may be different than the study_name, if the json file is more specific.
mounting_prefix = '/data/images'

import os, shutil, sys, select, time
import glob
import matlab.engine
import collections
import pandas as pd  # There is a LibGL error when running directly on the terminal. The symlink is incorrect, but hasn't been fixed yet.
from pathlib import Path

# Homegrown packages
user = os.path.expanduser('~')
if 'home' in Path(user).parts:
    scripting_tools_dir = os.path.join(user, os.path.relpath('tools'))
else:  
    scripting_tools_dir = '/Volumes/bk/brianne/tools'

sys.path
sys.path.append(os.path.join(scripting_tools_dir,'genius'))
import create_study_info_json

# Get the interactive MATLAB session
# Start the engine from inside MATLAB's command window >> matlab.engine.shareEngine
#tmp=matlab.engine.find_matlab()
try:
    print('Checking for MATLAB session')
    eng=matlab.engine.connect_matlab()
    
except Exception as e:
   
    if 'EngineError' in type(e).__name__:
        eng.quit()
        "Exiting previous matlab session" 
        time.sleep(5)
    else:
        print(e)
        
    eng=matlab.engine.connect_matlab()    

class model_info:
    def __init__(self):
        self.comparison_type = None
        self.timept_comparison = 'no'
        self.factor_dependencies = 0 # Default is independent for a one-sample test
        self.group_names = []
        self.comparison_name = comparison_name
        self.spm_factors_list= ['Experimental manipulation','Group']
        
    def update_study_variables(self, study):
        self.__dict__.update(study.__dict__)
        
    def collect_files(self, group, group_suffix, comparison_name, first_level_con):           
        if not hasattr(self, 'file_lists'):
            self.file_lists = []
        if not hasattr(self, 'subjects'):
            self.subjects = []
            
        try:
            # For pre-subtracted contrasts
            # May be redundant now (01/2020)
            tmp=glob.glob(os.path.join(self.first_level_data_dir, '**', '*' + group_suffix + '*' + first_level_con + '.nii'),recursive=True)
        except Exception as e:  
                tmp = []
                print(e)
                
#        if not tmp:
#            try:
#                tmp=glob.glob(os.path.join(self.first_level_data_dir, '**', '*' + group_suffix + '_' + '*' + first_level_con),recursive=True) # Should work for ICA analyses, where the volume number is specified.
#            except Exception as e:  
#                tmp = []
#                print(e)
                
        if not tmp:
            print('Did not find: {}\n'.format(os.path.join(self.first_level_data_dir, '*' + group_suffix + '_' + '*' + first_level_con + '.nii')))
            # For "normal", copied contrasts
            tmp=sorted(glob.glob(os.path.join(self.first_level_data_dir,'**', '*' + group_suffix + '_' + first_level_con + '*_?.nii'),recursive=True))
            
        if tmp: # Create a split-able column that can provide the id's of the scans that are included.
            if not self.subjects:       
                # For the first loop through, let the user know what files are being hunted
                print('\n', self.comparison_name, comparison_name)
            print('Building file lists: {}'.format(group))  
            ids = [x.split('/')[-1].split('_')[0] for x in tmp]
            self.subjects.extend(ids) # Don't mess with the order again, as it is preserved in SPM
                
            self.file_lists.append(tmp)
            self.file_lists=list(filter(None,self.file_lists))
                
        if debug == 'yes':
            print('Finding {} for {} comparison_name in folder: {}'.format(group, comparison_name, first_level_con))
            print('File lists include {} scan list(s)'.format(len(self.file_lists)))

            
    def update_output_dir(self, output_dir):
        self.output_dir = output_dir
    
    def add_group_name(self, group, result_suffix):
        self.group_names.append(group + '_' + result_suffix)
        
    def check_factor_dependencies(self):
        # If encountering error here, check that "dependencies" are spelled correctly in the json file.
        if len(self.spm_factors_list) != len(self.factor_dependencies):
            self.factor_dependencies = self.factor_dependencies * len(self.spm_factors_list)
            
    def add_regressors(self, comparison_name, regressor_input_file, regressors_of_interest):
        if not regressor_input_file:
            self.regressor_input_file = os.path.normpath(input('What is the full path to the regressor or demographics file?\n'))
            
        regressor_dir = os.path.dirname(self.regressor_input_file)
            
        if os.path.isfile(self.regressor_input_file):
            # Import the raw demographics-style file
            try:
                df = pd.DataFrame(pd.read_csv(self.regressor_input_file))
            except Exception as e:
                    print(e)                   
                    df = pd.DataFrame(pd.read_excel(self.regressor_input_file))
            # Clean up empty spaces
            df = df.dropna(how='all')
            df = df.dropna(how='all', axis=1)            

            ## IF you want to limit on a particular feature... add here.                    
            df = df.loc[df['bmi_bodpod'] >= 25,:]
            subj_col = [col for col in df.columns if 'subj' in col.lower()]        
            import functools
            num_of_files = functools.reduce(lambda total,l: total + len(l),self.file_lists, 0)
            if df.shape[0] < num_of_files:
                for ix in range(len(self.file_lists)):
                    # Provide the ordering for the covariates by mirroring the subject list
                    orig = len(self.file_lists[ix])
                    tmp = []
                    for jx in range(len(self.file_lists[ix])):
                        subj = os.path.basename(self.file_lists[ix][jx]).split('_')[0]
                        if subj in df[subj_col].values:
                            tmp.append(self.file_lists[ix][jx])
                    self.file_lists[ix] = tmp
                    print('Reduced files from {} to {}'.format(orig, len(self.file_lists[ix])))
            else:
                print('Total number of files, {}, matched expected value'.format(num_of_files))
                    
            if self.regressors_of_interest == 'empty':
                print(df.columns)
                self.regressors_of_interest = input('What regressor is being added? ("empty" for no regressor)')
            
            # Input may not adhere to list conventions, so the following checks the type of input and makes it conform.
            if not isinstance(self.regressors_of_interest, list):
                import re
                self.regressors_of_interest = re.sub("[^a-zA-Z0-9,_]","", self.regressors_of_interest).split(',')
                
            # Pass the class's list to a list for the scope of the list comprehension
            tmp_roi_list = self.regressors_of_interest
        
            # Parse to include only the participants with images being used
            regressor_cols = [col for col in df.columns if col in tmp_roi_list]
            if len(regressor_cols) < 1:
                print('The regressor file {} did not have the covariates {} I was looking for.'.format(self.regressor_input_file,tmp_roi_list))
            tmp = pd.DataFrame(columns=regressor_cols)

            for subj in self.subjects:
                # Since the order of a list is persistent, the regressor file can be built in the exact same order as the files are loaded. This is not necessarily alpha-numeric, as SPM accepts the file list as it is given.
                if df.loc[df[subj_col[0]] == subj,regressor_cols].empty:
                    # Add a placeholder, if the covariate is missing.
                    placeholder=[9999] * len(regressor_cols)
                    try:
                        tmp = tmp.append({regressor_cols:[placeholder]})
                    except Exception as e:
                        print('Subroutine add_regressors\n', e)  
                elif df.loc[df[subj_col[0]] == subj,regressor_cols].shape[0] > 1:
                    clean_df = df.loc[df[subj_col[0]] == subj,regressor_cols].dropna(how='all') # Get rid of any rows that are missing all the information
                    tmp = pd.concat([tmp,clean_df.head(1)]) # Append just the first row                    
                else:
                    tmp = pd.concat([tmp,df.loc[df[subj_col[0]] == subj,regressor_cols]])

            
            # Write the txt file, so that MATLAB can read it in.
            self.regressor_output_file = os.path.join(regressor_dir,comparison_name + '_regressors.txt')
            for reg in regressor_cols:
                if any(tmp[reg].isnull()) or (9999 in tmp[reg]):
                    tmp[reg].fillna(tmp[reg].median(),inplace=True) # In the rare instance that there is a missing score, create a median score to keep the imaging files and covariates equal.
            # TODO Decide whether this inclusion is appropriate later.
                    tmp[reg].replace(9999,tmp[reg].median(),inplace=True)
                    problem_covariates =  os.path.join(regressor_dir,comparison_name + '_regressorISSUES.txt')
                    with open(problem_covariates,'w+') as f:
                        f.write(reg)
            
            tmp.to_csv(self.regressor_output_file, header=None, index=None, sep=' ')
        
        else:
            print('Please check file path ({}) and try again.'.format(self.regressor_input_file))




############## Main method ################## 
            
# Set up the directories with the first-level contrasts to hold one contrast per folder.
# The "comparison_first_level_con_dict" in the json will match up the folder and the con number, so it is easiest just to have one contrast type in each folder.
            
if __name__ == "__main__":
    study = create_study_info_json.general_study_info()
    study.auto_update_study_info(os.path.join(mounting_prefix, study_name, 'study_info_' + design_name + '.json'))
    print('Do you want to change any parameters?')
    chg, w,x = select.select([sys.stdin],[],[],5)
    if len(dir(chg)) > 45:
        study.manual_update_study_info()
    else:
        print('Study design parameters can be amended by calling manual_update_study_info or editing the json.')
    
    model_spec = {}
#    if not hasattr(study, 'first_level_contrast_list'):
#        import datetime
#        study.first_level_contrast_list = [datetime.datetime.now().strftime(('%Y%m%d'))]
        
    #for c,contrast in enumerate(study.first_level_contrast_list):
    for c, [comparison_name, first_level_cons] in enumerate(study.comparison_dict.items()):        
        model_spec[c] = model_info()
        model_spec[c].update_study_variables(study)

        output_dir = os.path.join(study.task_output_dir, study.results_output_prefix + comparison_name)
        model_spec[c].update_output_dir(output_dir)
        # Reset parts of the model_spec
        model_spec[c].file_lists = []
        model_spec[c].subjects = []
        model_spec[c].group_names = []
        
        if len(study.groups.keys())*len(first_level_cons) > 2:
            model_spec[c].comparison_type = "full_factorial"
        elif len(study.groups.keys())==1 and len(study.groups.keys())*len(first_level_cons) == 2:
            model_spec[c].comparison_type = "dependent_two_sample"    
        elif len(study.groups.keys())*len(first_level_cons) == 2:
            model_spec[c].comparison_type = "two_sample"
        else:
            model_spec[c].comparison_type = "one_sample"
            
        if study.spm_factors_list:
            model_spec[c].spm_factors_list = study.spm_factors_list
            model_spec[c].check_factor_dependencies()
                 
        for group, group_suffix in study.groups.items():
            for first_level_con in first_level_cons:
                model_spec[c].add_group_name(group, '_'.join([first_level_con.split('_')[-1]]))
                #group_spec[group].files[first_level_con] = group_spec[group].collect_files()
                model_spec[c].collect_files(group, group_suffix, comparison_name, first_level_con)
            
        arg_dict = [('comparison_type', model_spec[c].comparison_type), 
                    ('factor_dependencies', model_spec[c].factor_dependencies), 
                    ('output_dir', model_spec[c].output_dir), 
                    ('group_names', model_spec[c].group_names), 
                    ('file_lists', model_spec[c].file_lists), 
                    ('factors', model_spec[c].spm_factors_list)]
        arg_dict = collections.OrderedDict(arg_dict)
        
        if len(model_spec[c].file_lists) > 0 & hasattr(study,'regressor_input_file'):
            try:
                if not os.path.isfile(study.regressor_input_file):
                    loc = os.path.join(study.first_level_data_dir, study.task_output_dir, study.regressor_input_file)
                    study.regressor_input_file = glob.glob(loc)[0]
                if model_spec[c].file_lists:
                    if len(study.regressors_of_interest) > 2: # 2 is the length of empty brackets
                        model_spec[c].add_regressors(comparison_name, study.regressor_input_file, study.regressors_of_interest)
                        arg_dict['regressor_file'] = model_spec[c].regressor_output_file
            except (NameError, TypeError):
                pass # Expected to be empty sometimes
            except IndexError:
                print('Did not find regressors at {}\n'.format(os.path.join(study.first_level_data_dir, study.task_output_dir, study.regressor_input_file)))
                break # Since the regressor file will be missing for all comparisons, save time and break the loop
            except Exception as e:
                print(e)
                break
    
        
        eng.clear # Make sure the old variables are flushed.
        eng.addpath(study.scripting_tools_dir);
        for k,v in arg_dict.items():
            # Convert to cell arrays via the MATLAB engine API
            eng.workspace[k]=v
        inputs=[ x for x in arg_dict.keys()]
        
        if all([v for k,v in arg_dict.items()]):   
            # The config is good to go and the directories should be made...
            if not os.path.isdir(model_spec[c].output_dir):
                os.makedirs(model_spec[c].output_dir)  
            print('Sending model specs to MATLAB')
            eng.cd(study.first_level_data_dir)
            with open(os.path.join(model_spec[c].output_dir,'files_used.txt'),'w') as listfile:
                for x in model_spec[c].file_lists:
                    listfile.write("{}\n".format(x))

            try:
                if arg_dict['regressor_file']:
                    msg = eng.eval('second_level_py2spm12(comparison_type, factor_dependencies, output_dir, group_names,file_lists,factors,regressor_file)')
            except KeyError:
                msg = eng.eval('second_level_py2spm12(comparison_type, factor_dependencies, output_dir, group_names,file_lists,factors)')
            print(msg)
        else:
            for k,v in arg_dict.items():
                if not v:
                    print('Missing {} for {}'.format(k, comparison_name))
            
    eng.quit()
    study.save_study_info()

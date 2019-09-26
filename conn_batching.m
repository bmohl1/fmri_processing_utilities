addpath('/home/brianne/tools/general_utilities')
[data_dir, pth_subjdirs, subjList] = file_selector();
[pth_taskdirs, task_array] = file_selector_task(pth_subjdirs,{'restrun1'})

home_dir = '/data/analysis/brianne/eats';
save_file = fullfile(home_dir,'batch_var.mat')
clear BATCH
BATCH.filename=fullfile(home_dir,'conn_project1.mat');

BATCH.Setup.RT=2;
BATCH.Setup.isnew=1;  % not re-processing
BATCH.Setup.nsubjects=size(pth_subjdirs,2);
BATCH.Setup.analyses=[1,2];  %1 for ROI-to-ROI analyses, 2 for seed-to-voxel analyses


%% BATCH.Setup.conditions
BATCH.Setup.conditions.names={"rest"};


%% Fill in the per subject fields
for f = 1:size(subjList,2)
  BATCH.Setup.functionals{f}{1} = glob(char(fullfile(pth_taskdirs.fileDirs{f},strcat(subjList(f),'*.nii')))); % Second index is for number of runs
  [subj_dir, subj_file, file_ext] = locate_scan_file('t1',subjList{f});
  BATCH.Setup.structurals{f} = char(fullfile(subj_dir, subj_file));
  BATCH.Setup.masks.Grey.files{f} = char(fullfile(subj_dir, strcat('c1' , subj_file)));
  BATCH.Setup.masks.Grey.dimensions=16; %16 is default for WM and CSF
  BATCH.Setup.masks.White.files{f} = char(fullfile(subj_dir, strcat('c2', subj_file)));
  BATCH.Setup.masks.CSF.files{f} = char(fullfile(subj_dir, strcat('c3' , subj_file)));

  %% Batch conditions
  BATCH.Setup.conditions.onsets{1}{f}{1}=[0]; % Condition 1, Subject f, Session 1
  BATCH.Setup.conditions.durations{1}{f}{1}=[inf];  

  %% Batch covariates
  BATCH.Setup.covariates.names={"motion"};
  BATCH.Setup.covariates.files{1}{f}{1} = glob(char(fullfile(pth_taskdirs.fileDirs{f},'rp*txt')));
  %BATCH.Setup.covariates.onsets{1}{f}{1} = glob(char(fullfile(pth_taskdirs.fileDirs{f},'rp*txt')));
end


%% BATCH.Setup.rois


BATCH.Setup.done=1;
BATCH.Setup.overwrite="No";
%BATCH.Analysis.sources={"MPFC’,’PCC’};
BATCH.Analysis.measure=2;
BATCH.Analysis.analysis_number=1; %Index uniquely identifying a set of connectivity analyses
BATCH.Analysis.type=3; %1 for ROI-to-ROI analyse, 2 for seed-to-voxel analyses, or 3 for both ROI-to-ROI and seed-to-voxel analyses
BATCH.Analysis.done=1;

save('BATCH','save_file');
conn_batch(BATCH);
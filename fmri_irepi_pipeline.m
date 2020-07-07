function [subj] = fmri_realign2smooth (all_proc_files,subj,settings)
% fmri_realign2smooth (all_proc_files,subj,settings)
% Purpose: subroutine of preproc_fmri that pushes files ahead from ACPC alignment to files that can be entered into a first-level analysis
% Author: Brianne Sutton, PhD
% Throughout 2017

display('> Subroutine: Running fmri_irepi_pipeline');
[spm_home, template_home] = update_script_paths;

raw_dir  = pwd; %the functions calling this one should have cd'd into raw_dir
parts    = textscan(raw_dir,'%s','Delimiter','/');
subjIx   = strfind(parts{:},subj);
ix       = find(~cellfun(@isempty,subjIx)); %locates the first match for the subj name
subj_dir = fullfile(parts{1,1}{1:ix});
subj_dir = [filesep, subj_dir];
%define the length of the experiment (should come up with the
%same number either way)
trs = length(all_proc_files); %If no STC, this will have 4 extra volumes
selected_proc_files = {};
[taskDir, fileName, ext] = fileparts(char(all_proc_files{1,1}));
task = textscan(taskDir,'%s', 'Delimiter','/');
task = task{1,1}{end};

if trs == 0
    disp('Hmmm... not finding the necessary files. Check search criteria in preproc_fmri')
elseif trs < 2; %need to split out nii file with ",number_of_volume"
    trs = length(spm_vol(all_proc_files{1,1})); % accommodates the conventional naming, even though the first four volumes are empty
    all_proc_files = char(all_proc_files{1,1});
    if eq(settings.dummies,1)
        for x = 5:(trs);
            selected_proc_files{x} = [strcat(all_proc_files,',',int2str(x))]; %must be square brackets, so there are no quotes in the cell
        end
        selected_proc_files = selected_proc_files(5:end); %discards the first four scans
    else
        for x = 1:(trs);
            selected_proc_files{x} = [strcat(all_proc_files,',',int2str(x))]; %must be square brackets, so there are no quotes in the cell
            normed_proc_files{x} = [strcat(taskDir, filesep, 'v', fileName, '.nii,', int2str(x))]; 
        end
    end
    mean_img = strcat('mean',fileName,',5'); %so the image isn't empty

else %individual files for the volumes exist and need to be loaded sequentially
    selected_proc_files = all_proc_files{:};
    for x = 1:trs
        normed_proc_files{x} = [strcat(taskDir, filesep, 'v', fileName, '.nii,', int2str(x))];
    end
    mean_img = strcat('mean',fileName); %so the image isn't empty
end

if isempty(selected_proc_files)
    fprintf('Not locating files for %s\nfmri_realign2smooth (line 48):\n ',all_proc_files);
    return
end

scan_set = {selected_proc_files'}; % the column cellstr is necessary for SPM12 (SPM12b uses the non-transposed, row cellstr version)
normed_set{1,1} = normed_proc_files';
normed_file = strcat(taskDir, filesep, 'v', fileName, '.nii');

cd(subj_dir);

clear matlabbatch
spm_jobman('initcfg');
save_folder = [];
save_folder{1,1} = [subj_dir];

%% Batch setup variables
y_img = dir(strcat(settings.subj_t1_dir,filesep,'y_*',settings.subj_t1_file));
brain_img = rdir([settings.subj_t1_dir,filesep,subj(1:3),'*brain.nii']);

if eq(settings.special_templates,1)
    global template_file;
    tpm = char(template_file); %expecting a 4D file
    spline = 4;
    %templateSize = 'subj';
    templateSize = 'mni';
else
    tpm = fullfile(template_home,'TPM.nii');
    spline = 2;
    templateSize = 'mni';
end

[subj_irepi_dir, subj_irepi_file, ~] = locate_scan_file ('irepi', subj);
segment_check = rdir(strcat(subj_irepi_dir,filesep, 'mwc*',subj_irepi_file));
y_file = strcat(subj_irepi_dir,filesep, 'y_r',subj_irepi_file); % Will be created, but doesn't exist yet
i=1;

if exist('segment_check', 'var') && isempty(segment_check) || eq(settings.ignore_preproc,1)
    nii_reslice2mm(strcat(settings.subj_t1_dir,filesep,settings.subj_t1_file));
    t1 = strcat(settings.subj_t1_dir,filesep, 'twomm_', settings.subj_t1_file);
    i=3;

    matlabbatch{1}.spm.spatial.coreg.estwrite.ref = {t1};
    matlabbatch{1}.spm.spatial.coreg.estwrite.source = {strcat(subj_irepi_dir,filesep, subj_irepi_file)};
    matlabbatch{1}.spm.spatial.coreg.estwrite.other = {''};
    matlabbatch{1}.spm.spatial.coreg.estwrite.eoptions.cost_fun = 'nmi';
    matlabbatch{1}.spm.spatial.coreg.estwrite.eoptions.sep = [4 2];
    matlabbatch{1}.spm.spatial.coreg.estwrite.eoptions.tol = [0.02 0.02 0.02 0.001 0.001 0.001 0.01 0.01 0.01 0.001 0.001 0.001];
    matlabbatch{1}.spm.spatial.coreg.estwrite.eoptions.fwhm = [7 7];
    matlabbatch{1}.spm.spatial.coreg.estwrite.roptions.interp = 4;
    matlabbatch{1}.spm.spatial.coreg.estwrite.roptions.wrap = [0 0 0];
    matlabbatch{1}.spm.spatial.coreg.estwrite.roptions.mask = 0;
    matlabbatch{1}.spm.spatial.coreg.estwrite.roptions.prefix = 'r';
    matlabbatch{2}.spm.spatial.preproc.channel(1).vols(1) = cfg_dep('Coregister: Estimate & Reslice: Resliced Images', substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','rfiles'));
    matlabbatch{2}.spm.spatial.preproc.channel(1).biasreg = 1e-05;
    matlabbatch{2}.spm.spatial.preproc.channel(1).biasfwhm = 60;
    matlabbatch{2}.spm.spatial.preproc.channel(1).write = [1 1];
    matlabbatch{2}.spm.spatial.preproc.channel(2).vols = {t1};
    matlabbatch{2}.spm.spatial.preproc.channel(2).biasreg = 0.1;
    matlabbatch{2}.spm.spatial.preproc.channel(2).biasfwhm = 60;
    matlabbatch{2}.spm.spatial.preproc.channel(2).write = [0 0];
    matlabbatch{2}.spm.spatial.preproc.tissue(1).tpm = {'/usr/local/MATLAB/tools/spm12/tpm/twomm_TPM.nii,1'};
    matlabbatch{2}.spm.spatial.preproc.tissue(1).ngaus = 1;
    matlabbatch{2}.spm.spatial.preproc.tissue(1).native = [1 0];
    matlabbatch{2}.spm.spatial.preproc.tissue(1).warped = [0 1];
    matlabbatch{2}.spm.spatial.preproc.tissue(2).tpm = {'/usr/local/MATLAB/tools/spm12/tpm/twomm_TPM.nii,2'};
    matlabbatch{2}.spm.spatial.preproc.tissue(2).ngaus = 1;
    matlabbatch{2}.spm.spatial.preproc.tissue(2).native = [1 0];
    matlabbatch{2}.spm.spatial.preproc.tissue(2).warped = [0 0];
    matlabbatch{2}.spm.spatial.preproc.tissue(3).tpm = {'/usr/local/MATLAB/tools/spm12/tpm/twomm_TPM.nii,3'};
    matlabbatch{2}.spm.spatial.preproc.tissue(3).ngaus = 2;
    matlabbatch{2}.spm.spatial.preproc.tissue(3).native = [1 0];
    matlabbatch{2}.spm.spatial.preproc.tissue(3).warped = [0 0];
    matlabbatch{2}.spm.spatial.preproc.tissue(4).tpm = {'/usr/local/MATLAB/tools/spm12/tpm/twomm_TPM.nii,4'};
    matlabbatch{2}.spm.spatial.preproc.tissue(4).ngaus = 3;
    matlabbatch{2}.spm.spatial.preproc.tissue(4).native = [1 0];
    matlabbatch{2}.spm.spatial.preproc.tissue(4).warped = [0 0];
    matlabbatch{2}.spm.spatial.preproc.tissue(5).tpm = {'/usr/local/MATLAB/tools/spm12/tpm/twomm_TPM.nii,5'};
    matlabbatch{2}.spm.spatial.preproc.tissue(5).ngaus = 4;
    matlabbatch{2}.spm.spatial.preproc.tissue(5).native = [1 0];
    matlabbatch{2}.spm.spatial.preproc.tissue(5).warped = [0 0];
    matlabbatch{2}.spm.spatial.preproc.tissue(6).tpm = {'/usr/local/MATLAB/tools/spm12/tpm/twomm_TPM.nii,6'};
    matlabbatch{2}.spm.spatial.preproc.tissue(6).ngaus = 2;
    matlabbatch{2}.spm.spatial.preproc.tissue(6).native = [0 0];
    matlabbatch{2}.spm.spatial.preproc.tissue(6).warped = [0 0];
    matlabbatch{2}.spm.spatial.preproc.warp.mrf = 1;
    matlabbatch{2}.spm.spatial.preproc.warp.cleanup = 2; % Thorough
    matlabbatch{2}.spm.spatial.preproc.warp.reg = [0 0.001 0.5 0.05 0.2];
    matlabbatch{2}.spm.spatial.preproc.warp.affreg = templateSize;
    matlabbatch{2}.spm.spatial.preproc.warp.fwhm = 0;
    matlabbatch{2}.spm.spatial.preproc.warp.samp = 3;
    matlabbatch{2}.spm.spatial.preproc.warp.write = [0 1];
end

matlabbatch{i}.spm.spatial.realign.estwrite.data = scan_set;
matlabbatch{i}.spm.spatial.realign.estwrite.eoptions.quality = 0.9;
matlabbatch{i}.spm.spatial.realign.estwrite.eoptions.sep = 4;
matlabbatch{i}.spm.spatial.realign.estwrite.eoptions.fwhm = 5;
matlabbatch{i}.spm.spatial.realign.estwrite.eoptions.rtm = 0;
matlabbatch{i}.spm.spatial.realign.estwrite.eoptions.interp = 2;
matlabbatch{i}.spm.spatial.realign.estwrite.eoptions.wrap = [0 0 0];
matlabbatch{i}.spm.spatial.realign.estwrite.eoptions.weight = '';
matlabbatch{i}.spm.spatial.realign.estwrite.roptions.which = [0 1];
matlabbatch{i}.spm.spatial.realign.estwrite.roptions.interp = 4;
matlabbatch{i}.spm.spatial.realign.estwrite.roptions.wrap = [0 0 0];
matlabbatch{i}.spm.spatial.realign.estwrite.roptions.mask = 0; % Don't mask
matlabbatch{i}.spm.spatial.realign.estwrite.roptions.prefix = 'r';

matlabbatch{i+1}.spm.spatial.coreg.estimate.ref = {strcat(subj_irepi_dir,filesep,'r', subj_irepi_file)};
matlabbatch{i+1}.spm.spatial.coreg.estimate.source(1) = cfg_dep('Realign: Estimate & Reslice: Mean Image', substruct('.','val', '{}',{i}, '.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','rmean'));
matlabbatch{i+1}.spm.spatial.coreg.estimate.other(1) = cfg_dep('Realign: Estimate & Reslice: Realigned Images (Sess 1)', substruct('.','val', '{}',{i}, '.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','sess', '()',{1}, '.','cfiles'));
matlabbatch{i+1}.spm.spatial.coreg.estimate.eoptions.cost_fun = 'nmi';
matlabbatch{i+1}.spm.spatial.coreg.estimate.eoptions.sep = [4 2];
matlabbatch{i+1}.spm.spatial.coreg.estimate.eoptions.tol = [0.02 0.02 0.02 0.001 0.001 0.001 0.01 0.01 0.01 0.001 0.001 0.001];
matlabbatch{i+1}.spm.spatial.coreg.estimate.eoptions.fwhm = [7 7];

%% Appply deformations
% The Normalize method also for voxel size and bounding box definitions, so
% go with that method over the Apply Deformations method.
% matlabbatch{i+2}.spm.util.defs.comp{1}.def = {y_file};
% matlabbatch{i+2}.spm.util.defs.out{1}.pull.fnames = {all_proc_files}; % The coregistration process updates the headers to include the relative position, so there is no need to have a saved, resliced intermediate file as input.
% matlabbatch{i+2}.spm.util.defs.out{1}.pull.savedir.saveusr = {taskDir};
% matlabbatch{i+2}.spm.util.defs.out{1}.pull.interp = 4;
% matlabbatch{i+2}.spm.util.defs.out{1}.pull.mask = 0;
% matlabbatch{i+2}.spm.util.defs.out{1}.pull.fwhm = [0 0 0];
% matlabbatch{i+2}.spm.util.defs.out{1}.pull.prefix = 'v';

%% Normalise
matlabbatch{i+2}.spm.spatial.normalise.write.subj.def = {y_file};
matlabbatch{i+2}.spm.spatial.normalise.write.subj.resample = {all_proc_files};
% Allow the bounding box to be determined by SPM. Likely will correspond
% with the following values.
%matlabbatch{i+2}.spm.spatial.normalise.write.woptions.bb = [-78 -112 -70
%                                                          78 76 85];
matlabbatch{i+2}.spm.spatial.normalise.write.woptions.vox = [3 3 3];
matlabbatch{i+2}.spm.spatial.normalise.write.woptions.interp = 4;
matlabbatch{i+2}.spm.spatial.normalise.write.woptions.prefix = 'v';

%matlabbatch{i+3}.spm.spatial.smooth.data(1) = cfg_dep('Deformations: Warped Images', substruct('.','val', '{}',{i+2}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','warped'));
matlabbatch{i+3}.spm.spatial.smooth.data = {normed_file};
matlabbatch{i+3}.spm.spatial.smooth.fwhm = [8 8 8];
matlabbatch{i+3}.spm.spatial.smooth.dtype = 0;
matlabbatch{i+3}.spm.spatial.smooth.im = 0;
matlabbatch{i+3}.spm.spatial.smooth.prefix = 's';
savefile = [subj_dir,filesep,'irepi_pipeline_' int2str(i) subj '_' task '.mat'];
save(savefile, 'matlabbatch');
%% Run the batch
spm_jobman('run',matlabbatch)

function [subj] = fmri_realign2smooth (all_proc_files,subj,settings)
% fmri_realign2smooth (all_proc_files,subj,settings)
% Purpose: subroutine of preproc_fmri that pushes files ahead from ACPC alignment to files that can be entered into a first-level analysis
% Author: Brianne Sutton, PhD
% Throughout 2017

display('> Subroutine: Running fmri_realign2smooth');
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
[taskDir, fileName, ~] = fileparts(char(all_proc_files{1,1}));
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
        end
    end
    mean_img = strcat('mean',fileName,',5'); %so the image isn't empty

else %individual files for the volumes exist and need to be loaded sequentially
    selected_proc_files = {all_proc_files{:}};
    mean_img = strcat('mean',fileName); %so the image isn't empty
end

if isempty(selected_proc_files)
    fprintf('Not locating files for %s\nfmri_realign2smooth (line 48):\n ',all_proc_files);
    return
end

scan_set = [];
scan_set{1,1} = selected_proc_files'; % the column cellstr is necessary for SPM12 (SPM12b uses the non-transposed, row cellstr version)
cd(subj_dir);

clear matlabbatch
spm_jobman('initcfg');
save_folder = [];
save_folder{1,1} = [subj_dir];
coreg_check = rdir(strcat(raw_dir,filesep,'r',fileName,'.nii')); %added second r just for Alex's study

%Double check that the correct number of files are actively being considered (catch for settings.dummies)
if eq(settings.dummies,1)
  if ~eq(length(selected_proc_files),length(coreg_check))
    coreg_check = ''; %empty the check, because the scans need to be reprocessed from square one to match for ART, rp_files, etc.
  end
end

%% Batch setup variables
y_img = dir(strcat(settings.subj_t1_dir,filesep,'y_*',settings.subj_t1_file));
brain_img = rdir([settings.subj_t1_dir,filesep,subj(1:3),'*brain.nii']);

if eq(settings.special_templates,1)
    global template_file;
    tpm = char(template_file); %expecting a 4D file
    spline = 4;
    %tempSize = 'subj';
    templateSize = 'mni';
else
    tpm = fullfile(template_home,'TPM.nii');
    spline = 2;
    templateSize = 'mni';
end

%% T1 Coregistration
%t1 definitions are global, if running from preproc_fmri...
%[settings.subj_t1_dir, settings.subj_t1_file, t1_ext] = locate_t1(subj_dir); %Need this line regardless of version,
%  b/c it identifies which of the many timepoints has the T1

if strcmp(settings.ver,'8')
    if isempty(y_img) && exist(settings.subj_t1_file); %The t1 existing is a second check that the
        %  correct t1 dir was identified and is will pass along an image to segment.
        fprintf('Performing Unified Segmentation: %s.\n',settings.subj_t1_file);
        segmentation_spm8(subj,settings);
    end
elseif eq(settings.redo_segment, 1)
    segmentation_spm12(subj,settings);
    brain_img = rdir([settings.subj_t1_dir,filesep,'*brain.nii']); % took out " subj(1:3),'*brain*', since some of the images were not renamed with subjid
    settings.redo_segment = 0; % Don't keep re-segmenting
elseif isempty(arrayfun(@(x) isempty(x.name),brain_img))
    segmentation_spm12(subj,settings);
    brain_img = rdir([settings.subj_t1_dir,filesep,'*brain.nii']); % took out " subj(1:3),'*brain*', since some of the images were not renamed with subjid
    settings.redo_segment = 0;% Don't keep re-segmenting
elseif isempty(settings.subj_t1_file)
    disp('>> ERROR: Didn''t find T1. Cannot continue processing!');
end

if length(coreg_check) < 1 || eq(settings.ignore_preproc,1);
    savefile = [subj_dir,filesep,'realign2smooth_' subj '_' task '.mat'];
    %% Realignment
    try
      matlabbatch{1}.spm.spatial.realign.estwrite.data = scan_set;
    catch
      scan_set = {selected_proc_files}';
      matlabbatch{1}.spm.spatial.realign.estwrite.data = scan_set;
    end
    % matlabbatch{1}.spm.spatial.realign.estwrite.eoptions.quality = 0.9;
    % matlabbatch{1}.spm.spatial.realign.estwrite.eoptions.sep = 4;
    % matlabbatch{1}.spm.spatial.realign.estwrite.eoptions.fwhm = 5;
    % matlabbatch{1}.spm.spatial.realign.estwrite.eoptions.rtm = 1;
    % matlabbatch{1}.spm.spatial.realign.estwrite.eoptions.interp = spline; %Spline for rp
    % matlabbatch{1}.spm.spatial.realign.estwrite.eoptions.wrap = [0 0 0];
    % matlabbatch{1}.spm.spatial.realign.estwrite.eoptions.weight = '';
    % matlabbatch{1}.spm.spatial.realign.estwrite.roptions.which = [0 1];
    % matlabbatch{1}.spm.spatial.realign.estwrite.roptions.interp = 4;
    % matlabbatch{1}.spm.spatial.realign.estwrite.roptions.wrap = [0 0 0];
    % matlabbatch{1}.spm.spatial.realign.estwrite.roptions.mask = 1;
    matlabbatch{1}.spm.spatial.realign.estwrite.roptions.prefix = 'r';

    save(savefile, 'matlabbatch');

    y_img = dir(strcat(settings.subj_t1_dir,filesep,'y_*',settings.subj_t1_file));
    y_file = cellstr(fullfile(settings.subj_t1_dir,y_img.name));

    if isempty(brain_img)
        fprintf('Did not find unzipped brain for %s. Does it exist?\n',subj)
        return
    else
        brain_file = fullfile(brain_img.name);
    end

    if ~isempty(settings.subj_t1_file)
        disp('Can continue with realignment and coregistration');
        %% Continue matlabbatch setup
        %Common setup

        % matlabbatch{2}.spm.spatial.coreg.estimate.eoptions.cost_fun = 'nmi';
        % matlabbatch{2}.spm.spatial.coreg.estimate.eoptions.sep = [4 2];
        % matlabbatch{2}.spm.spatial.coreg.estimate.eoptions.tol = [0.02 0.02 0.02 0.001 0.001 0.001 0.01 0.01 0.01 0.001 0.001 0.001];
        % matlabbatch{2}.spm.spatial.coreg.estimate.eoptions.fwhm = [7 7];

        if ~strcmp(settings.ver, '8')
            %SPM12 version
            matlabbatch{2}.spm.spatial.coreg.estimate.ref = {brain_file};
            matlabbatch{2}.spm.spatial.coreg.estimate.source(1) = cfg_dep('Realign: Estimate & Reslice: Mean Image',...
                substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}),...
                substruct('.','rmean'));
            matlabbatch{2}.spm.spatial.coreg.estimate.other(1) = cfg_dep('Realign: Estimate & Reslice: Realigned Images (Sess 1)',...
                substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}),...
                substruct('.','sess', '()',{1}, '.','cfiles'));
            %matlabbatch{2}.spm.spatial.coreg.estimate.roptions.interp = 4;
            %matlabbatch{2}.spm.spatial.coreg.estimate.roptions.wrap = [0 0 0];
            %matlabbatch{2}.spm.spatial.coreg.estimate.roptions.mask = 0;
            %matlabbatch{2}.spm.spatial.coreg.estimate.roptions.prefix = 'r';
            save(savefile, 'matlabbatch');


            matlabbatch{3}.spm.spatial.normalise.estwrite.subj.vol = {strcat(settings.subj_t1_dir, filesep, settings.subj_t1_file, ',1')};
            matlabbatch{3}.spm.spatial.normalise.estwrite.subj.resample(1) = cfg_dep('Coregister: Estimate: Coregistered Images', substruct('.','val', '{}',{2}, '.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','cfiles'));
            % matlabbatch{3}.spm.spatial.normalise.estwrite.eoptions.biasreg = 0.0001;
            % matlabbatch{3}.spm.spatial.normalise.estwrite.eoptions.biasfwhm = 60;
            matlabbatch{3}.spm.spatial.normalise.estwrite.eoptions.tpm = {tpm};
            matlabbatch{3}.spm.spatial.normalise.estwrite.eoptions.affreg = templateSize; %'mni' or 'subj'
            % matlabbatch{3}.spm.spatial.normalise.estwrite.eoptions.reg = [0 0.001 0.5 0.05 0.2];
            % matlabbatch{3}.spm.spatial.normalise.estwrite.eoptions.fwhm = 0;
            % matlabbatch{3}.spm.spatial.normalise.estwrite.eoptions.samp = 3;
            % matlabbatch{3}.spm.spatial.normalise.estwrite.woptions.bb = [-78 -112 -70
            %     78 76 85];
            matlabbatch{3}.spm.spatial.normalise.estwrite.woptions.vox = [3 3 3];
            matlabbatch{3}.spm.spatial.normalise.estwrite.woptions.interp = 4;

            matlabbatch{4}.spm.spatial.smooth.data(1) = cfg_dep('Normalise: Estimate & Write: Normalised Images (Subj 1)',...
                substruct('.','val', '{}',{3}, '.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('()',{1}, '.','files'));
            save(savefile, 'matlabbatch');
            %end 12
        else
            %% SPM8 version - coreg
            matlabbatch{2}.spm.spatial.coreg.estimate.ref = {strcat(settings.subj_t1_dir, filesep, settings.subj_t1_file)};
            matlabbatch{2}.spm.spatial.coreg.estimate.source(1) = cfg_dep;
            matlabbatch{2}.spm.spatial.coreg.estimate.source(1).tname = 'Source Image';
            % matlabbatch{2}.spm.spatial.coreg.estimate.source(1).tgt_spec{1}(1).name = 'filter';
            % matlabbatch{2}.spm.spatial.coreg.estimate.source(1).tgt_spec{1}(1).value = 'image';
            % matlabbatch{2}.spm.spatial.coreg.estimate.source(1).tgt_spec{1}(2).name = 'strtype';
            % matlabbatch{2}.spm.spatial.coreg.estimate.source(1).tgt_spec{1}(2).value = 'e';
            matlabbatch{2}.spm.spatial.coreg.estimate.source(1).sname = 'Realign: Estimate & Reslice: Mean Image';
            matlabbatch{2}.spm.spatial.coreg.estimate.source(1).src_exbranch = substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1});
            matlabbatch{2}.spm.spatial.coreg.estimate.source(1).src_output = substruct('.','rmean');
            matlabbatch{2}.spm.spatial.coreg.estimate.other(1) = cfg_dep;
            matlabbatch{2}.spm.spatial.coreg.estimate.other(1).tname = 'Other Images';
            % matlabbatch{2}.spm.spatial.coreg.estimate.other(1).tgt_spec{1}(1).name = 'filter';
            % matlabbatch{2}.spm.spatial.coreg.estimate.other(1).tgt_spec{1}(1).value = 'image';
            % matlabbatch{2}.spm.spatial.coreg.estimate.other(1).tgt_spec{1}(2).name = 'strtype';
            % matlabbatch{2}.spm.spatial.coreg.estimate.other(1).tgt_spec{1}(2).value = 'e';
            matlabbatch{2}.spm.spatial.coreg.estimate.other(1).sname = 'Realign: Estimate & Reslice: Realigned Images (Sess 1)';
            matlabbatch{2}.spm.spatial.coreg.estimate.other(1).src_exbranch = substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1});
            matlabbatch{2}.spm.spatial.coreg.estimate.other(1).src_output = substruct('.','sess', '()',{1}, '.','cfiles');
            save(savefile, 'matlabbatch');
            %% 8 Deformations
            %variable for this section are defined while in the t1 directory for
            %section T1 Coregisteration

            matlabbatch{3}.spm.util.defs.comp{1}.def = y_file;
            matlabbatch{3}.spm.util.defs.ofname = '';
            matlabbatch{3}.spm.util.defs.fnames(1) = cfg_dep;
            % matlabbatch{3}.spm.util.defs.fnames(1).tname = 'Apply to';
            % matlabbatch{3}.spm.util.defs.fnames(1).tgt_spec{1}(1).name = 'filter';
            % matlabbatch{3}.spm.util.defs.fnames(1).tgt_spec{1}(1).value = 'image';
            % matlabbatch{3}.spm.util.defs.fnames(1).tgt_spec{1}(2).name = 'strtype';
            % matlabbatch{3}.spm.util.defs.fnames(1).tgt_spec{1}(2).value = 'e';
            matlabbatch{3}.spm.util.defs.fnames(1).sname = 'Coregister: Estimate: Coregistered Images';
            matlabbatch{3}.spm.util.defs.fnames(1).src_exbranch = substruct('.','val', '{}',{2}, '.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1});
            matlabbatch{3}.spm.util.defs.fnames(1).src_output = substruct('.','cfiles');
            matlabbatch{3}.spm.util.defs.savedir.saveusr = save_folder;
            % matlabbatch{3}.spm.util.defs.interp = 1;
            save(savefile,'matlabbatch')
            %end 8
            %% 8 smooth
            matlabbatch{4}.spm.spatial.smooth.data(1) = cfg_dep;
            % matlabbatch{4}.spm.spatial.smooth.data(1).tname = 'Images to Smooth';
            % matlabbatch{4}.spm.spatial.smooth.data(1).tgt_spec{1}.name = 'filter';
            % matlabbatch{4}.spm.spatial.smooth.data(1).tgt_spec{1}.value = 'image';
            matlabbatch{4}.spm.spatial.smooth.data(1).sname = 'Deformations: Warped images';
            matlabbatch{4}.spm.spatial.smooth.data(1).src_exbranch = substruct('.','val', '{}',{3}, '.','val', '{}',{1}, '.','val', '{}',{1});
            matlabbatch{4}.spm.spatial.smooth.data(1).src_output = substruct('.','warped');
            matlabbatch{4}.spm.spatial.smooth.fwhm = [8 8 8];
            % matlabbatch{4}.spm.spatial.smooth.dtype = 0;
            % matlabbatch{4}.spm.spatial.smooth.im = 0;
            matlabbatch{4}.spm.spatial.smooth.prefix = 's';
            save(savefile,'matlabbatch')
        end

    else
        return
    end
else
    savefile = ['norm2smooth_' subj '.mat'];
    matlabbatch{1}.spm.spatial.normalise.estwrite.subj.vol = {strcat(settings.subj_t1_dir, filesep, settings.subj_t1_file, ',1')};
    matlabbatch{1}.spm.spatial.normalise.estwrite.subj.resample =  {coreg_check(1:end-1).name}';
    % matlabbatch{1}.spm.spatial.normalise.estwrite.eoptions.biasreg = 0.0001;
    % matlabbatch{1}.spm.spatial.normalise.estwrite.eoptions.biasfwhm = 60;
    matlabbatch{1}.spm.spatial.normalise.estwrite.eoptions.tpm = {tpm};
    % matlabbatch{1}.spm.spatial.normalise.estwrite.eoptions.affreg = 'mni';
    % matlabbatch{1}.spm.spatial.normalise.estwrite.eoptions.reg = [0 0.001 0.5 0.05 0.2];
    % matlabbatch{1}.spm.spatial.normalise.estwrite.eoptions.fwhm = 0;
    % matlabbatch{1}.spm.spatial.normalise.estwrite.eoptions.samp = 3;
    % matlabbatch{1}.spm.spatial.normalise.estwrite.woptions.bb = [-78 -112 -70
    %     78 76 85];
    matlabbatch{1}.spm.spatial.normalise.estwrite.woptions.vox = [3 3 3];
    matlabbatch{1}.spm.spatial.normalise.estwrite.woptions.interp = 4;

    matlabbatch{2}.spm.spatial.smooth.data(1) = cfg_dep('Normalise: Estimate & Write: Normalised Images (Subj 1)',...
        substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('()',{1}, '.','files'));
    save(savefile, 'matlabbatch');
end

%% Run the batch
spm_jobman('run',matlabbatch)

end

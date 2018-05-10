function ppi_voi_extract_physio(subjs,task,voi,reg_var, results_dir)

%defaults
maxima_type = ('supra'); % Change this to supra or local
get_mtn_reg = 'yes'; %Can change and will enter the 6 regressors for the rp file along with PPI regressors

tool_dir = fileparts(fileparts(which('ppi_voi_extraction')));

addpath([tool_dir filesep 'general_utilities']);
[spm_home, mni_home] = update_script_paths(tool_dir); %make sure that we're getting into SPM12b


%% Choose the mask
if nargin < 3
    disp('Please select the VOI');
    tempfile = cellstr(spm_select([1,Inf],'image','Select the VOI for this analysis','',pwd));
    tempfile = textscan(tempfile{1,1}, '%s', 'Delimiter',',');
    voi_file = tempfile{1,1}{1}; %Must have the ",1" removed for accurate handling elsewhere
    voi_dir = fileparts(voi_file);
    [cwd, voi] = fileparts(voi_file)
    cd(cwd)
else
    sprintf('VOI: %s was passed to ppi_voi_extract_physio\n',voi)
end

%% Grab the potential subject locations
switch exist ('subjs')
    case 1
        [cwd, pth_subjdirs, subjList] = file_selector(subjs);
    otherwise
        [cwd, pth_subjdirs, subjList] = file_selector;
end

projName = textscan(cwd,'%s','Delimiter','/'); %Does this break in some cases?
projName = projName{1,1}{end}; %subset of the name (e.g., adhd_2018)

cd(pth_subjdirs{1,1})

%% Find the tasks
switch exist('task','var')
    case 1
        [pth_taskdirs, task] = file_selector_task(pth_subjdirs, task);
    otherwise
        [pth_taskdirs, task] = file_selector_task(pth_subjdirs);
end

cd (cwd)
if ~exist('reg_var')
    reg_var = ('on') %overrides the default
end

%% Start setting up the individual's script
for nSubj = 1:length(pth_subjdirs);
    subj_pth = pth_subjdirs{nSubj};
    if exist('subjList','var') && length(subjList) >= 1;
        %subjList must come with nSubj
        subjs = char(subjList{nSubj});
    end
    [projDir, subj, subj_prefix] = find_subj_pths (subj_pth,subjs); %common script

    %% Hard coded just to speed up for K and J
    results_dir = [subj_pth,filesep,'model_eats_ar_mvmnt_s6_ppiEx'];
    subj_prefix=subj_prefix(1:end-3)
    %%
    masks = {'wm' 'csf' voi};

    check_spm  = glob(strcat(results_dir,filesep,'SPM.mat')); % cannot extract eigenvariates, if the model has not been estimated
    if isempty(check_spm)
        sprintf('Was the design matrix evaluated for %s?',subj)
        disp('Did not extract eigenvariates')
    else

        %% Figure out where the t1 directory is (b/c it isn't always in the same timepoint
        [subj_t1_dir, subj_t1_file, t1_ext] = locate_scan_file('t1', subj);%checks if there is a more recent T1
        if isempty(subj_t1_file); %won't override the global "reset" back to the first T1, if there has been an more recent one, but also supplies a scan, if none was defined.
            [subj_t1_dir, subj_t1_file, t1_ext] = locate_scan_file('t1',subj_prefix);
        end
        if isempty(subj_t1_file)
            [subj_t1_dir, subj_t1_file, t1_ext] = locate_scan_file('anat', subj);
        end

        %% Extract from masks
        for j = (1:length(masks))
            mask = masks{j};
            %% Get Number of runs
            runs = file_selector_task({subj_pth}, task);
            check_voi = strcat(results_dir,filesep,'VOI_',mask,'_',num2str(length(runs)),'.mat');
            if ~exist(check_voi,'file')
                sprintf('Extracting values for %s', mask)
                reg_out = strcat(mask, '_thresh');
                if strcmp(mask,'csf')
                    mask_file = glob([subj_t1_dir,filesep,'mwc3',subj_t1_file]); %csf
                elseif strcmp(mask, 'wm')
                    mask_file = glob([subj_t1_dir,filesep,'mwc2',subj_t1_file]); %wm
                else
                    mask_file = glob([projDir,filesep, mask,'*nii']);
                end

                %% Escape to segment, if mask is missing
                if isempty(mask_file) & ((strfind ('csf', mask) | strfind('wm', mask)))
                    %% CHANGE BACK TO SEGMENTATION_SPM12
                    segmentation_spm12_eats(subj,0,0); %for single subject, don't redo segmentation, and don't use weird template
                else
                    disp ('Found mask')
                end

                mask_file = cellstr(strcat(mask_file, ',1'));

                clear matlabbatch
                spm_jobman('initcfg');
                matlabbatch{1}.spm.util.imcalc.input = mask_file;
                matlabbatch{1}.spm.util.imcalc.output = reg_out;
                matlabbatch{1}.spm.util.imcalc.outdir = {results_dir};
                matlabbatch{1}.spm.util.imcalc.expression = 'i1 > .8'; % want it to be fairly restrictive, but still sample highly likely areas
                matlabbatch{1}.spm.util.imcalc.options.dmtx = 0;
                matlabbatch{1}.spm.util.imcalc.options.mask = -1;
                matlabbatch{1}.spm.util.imcalc.options.interp = 1;
                matlabbatch{1}.spm.util.imcalc.options.dtype = 4;
                    savefile = [subj_pth,filesep,mask,'_maskBin_',subj,'.mat'];
                    save(savefile,'matlabbatch');
                    spm_jobman('run',matlabbatch)

                for sess = 1:length(runs);
                    clear matlabbatch
                    spm_jobman('initcfg');
                    matlabbatch{1}.spm.util.voi.spmmat = check_spm;
                    matlabbatch{1}.spm.util.voi.adjust = NaN; % adjust for everything, so that you get the time courses that are only related to your mask/condition of interest
                    matlabbatch{1}.spm.util.voi.session = sess; %has to be per session to go with the correct mtn and physio regressors.
                    matlabbatch{1}.spm.util.voi.name = mask;
                    matlabbatch{1}.spm.util.voi.roi{1}.mask.image = {[results_dir,filesep,reg_out,'.nii,1']};
                    matlabbatch{1}.spm.util.voi.roi{1}.mask.threshold = 0.99; % include all the voxels in the mask
                    matlabbatch{1}.spm.util.voi.roi{2}.spm.spmmat = {''};
                    matlabbatch{1}.spm.util.voi.roi{2}.spm.contrast = 3; % CHANGE per analysis - what condition are you interested in modeling with the interaction
                    matlabbatch{1}.spm.util.voi.roi{2}.spm.conjunction = 1;
                    matlabbatch{1}.spm.util.voi.roi{2}.spm.threshdesc = 'none';
                    matlabbatch{1}.spm.util.voi.roi{2}.spm.thresh = 0.99; % the point is to get a timecourse, but not have all noise present
                    matlabbatch{1}.spm.util.voi.roi{2}.spm.extent = 0;
                    matlabbatch{1}.spm.util.voi.roi{2}.spm.mask = struct('contrast', {}, 'thresh', {}, 'mtype', {});
                    matlabbatch{1}.spm.util.voi.expression = 'i2&i1'; % Consider just the masked area


                    %% save
                    savefile = [subj_pth,filesep,mask,'_voi_extract_',subj,'.mat'];
                    save(savefile,'matlabbatch');
                    spm_jobman('run',matlabbatch)
                end
            end
            temp = load(check_voi);
            extra_regs{j} = [temp.Y];
        end
    end
end

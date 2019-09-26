function first_level_spm12_denoised(subjs, taskArray)

% Purpose: Create first-level designs and contrasts for task-based fMRI
% Created: June 2017 by Brianne Sutton, PhD
% This function should handle single and multiple runs (with separate rp
% files)
% Required input: *design and constrast spreadsheets in the study folder*; smoothed and
% normalized EPIs
% NOTE: Not intended to run pre/post designs together. The script expects
% that the entered task folders are part of the same experiment.

%% Preliminary path and defaults
tool_dir = fileparts(fileparts(which('preproc_fmri')));
addpath([tool_dir filesep 'general_utilities']);

[spm_home, template_home] = update_script_paths(tool_dir);

hpf = 128; % High-pass filter value in Hz
tr = 2; % might be definable by spm_vol(image) > variable(a).private.timing.tspace, but I'm not sure
aggLevels = {'_agg', '_nonagg'}; % to accomodate FSL denoising

%% Set options
[special_templates runArt stc discard_dummies unwarp ignore_preproc dirName] = preproc_fmri_firstLevel_inputVars_GUI; %allows for non-scripting users to alter the settings easily.
close(gcf);

%% Get subject and study folder definitions
switch exist ('subjs')
    case 1
        [cwd,pth_subjdirs] = file_selector(subjs);
    otherwise
        [cwd,pth_subjdirs] = file_selector; %GUI to choose the main study directory
end

switch exist ('taskArray')
    case 1
        [pth_taskdirs, taskArray] = file_selector_task(pth_subjdirs, taskArray);
    otherwise
        [pth_taskdirs, taskArray] = file_selector_task(pth_subjdirs);
end

runIx = strfind(taskArray,taskArray{1,1}(1:3));
runIx = ~cellfun('isempty',runIx);
nRuns = max(find(runIx==1));
nTasks = max(find(runIx==0));
if isempty (nTasks)
    nTasks = 1;
end

projName = textscan(cwd,'%s','Delimiter','/');
projName = projName{1,1}{end};

for a = 1:length(aggLevels)
    if eq(unwarp,1)
        prefix = 'swu'; % Can set the letters that are expected prior to standard naming scheme on the data (e.g., 'aruPerson1_task1_scanDate.nii')
        regs = 'none';
    else
        prefix = 'sw';  % need to empty the variable option to make sure no blanks are propogated.
        %regs = 'none' % b/c don't want the rp's in the first-level, as AROMA has taken care of them... theoretically
    end
    aggLevel = aggLevels{a};
    prefix = ['denoised_func_data',aggLevel];
    %% Setup basics of the first-level
    for iTask = 1:nTasks;
        task    = pth_taskdirs(iTask).task; %stored from file_selector_task
        nFiles  = length(pth_taskdirs(iTask).fileDirs);
        for iSubj = 1:nFiles;
            fprintf('\nWorking with subject %u of %u\nTask:%s\n',iSubj,nFiles,task);
            subj_pth = char(pth_subjdirs{iSubj});
            [proj_dir subj unk] = fileparts(subj_pth(1,1:end-1)); %defines various pieces that are used to build paths and checks elsewhere.
            if ~ischar(unk) || isempty(unk)
                tmp = textscan(subj_pth,'%s','Delimiter','/');
                subj = tmp{1,1}{end};
                clear tmp
            end

            subj_prefix = (subj(1:end-1)); %Also for multiple timepoints, where T1 is not collected at all timepoints

            ix = strfind(task,'_run'); %Specific to dir names with 'run' in them.
            if isempty(ix)
                taskName=task
            else
                taskName = task(1:ix-1);
            end

            if eq(runArt,1) %from the checkcdbox setup
                results_dir = [subj_pth,filesep,taskName, aggLevel,'_resultsArt'];
            else
                results_dir = [subj_pth,filesep,taskName, aggLevel,'_results'];
            end

            if eq(unwarp,1)
                results_dir = [results_dir, '_unwarp'];
            end


            if ~isempty (dirName) %capability to quickly run experiments on other processing options w/o overwriting the original results
                if ~contains(dirName,'Enter'); %'Enter special suffix here' doesn't need to be added... so skip changing the directory name, if the default was unchanged
                    results_dir = [results_dir,aggLevel,'_',dirName];
                    regs = 'none'; %To make sure that there are no motion regressors
                end
            end

            check = rdir(results_dir);
            if isempty(check());
                mkdir (results_dir);
            end

            check_spm = rdir ([results_dir, filesep, 'beta_0001.nii']);
            spm_exists = (arrayfun(@(x) ~isempty(x.name),check_spm) == 1);
            if ~isempty(spm_exists) &&  eq(ignore_preproc,0)
                disp('Continue with next participant');
                continue
            else
                if exist(strcat(results_dir, filesep, 'SPM.mat'),'file')
                    delete (strcat(results_dir, filesep, 'SPM.mat')); %Or else GUI will pop up asking to overwrite. Supremely inconvenient for batching overnight
                end

                %% Check that all runs have been processed
                for r = 1: nRuns
                    locateImg = [subj_pth,filesep,taskArray{r},filesep,'ica_test_nowarpFile',filesep,[prefix,'*.nii']];

                    imgFiles = rdir(locateImg);
                end

                if length(imgFiles) < 1
                    fprintf ('Oops. Missing image files called: \n%s\n',locateImg)
                    fprintf('Please process first: %s\n',subj);
                    %preproc_fmri(ver, templates, subjs, taskArray, stc)
                    %preproc_fmri('12b','no', subj, taskName, 'no',0); % 0 for NO prefix

                    continue
                else
                    %% Continue with loading files for 2nd level
                    sw_files = cell(length(taskArray),1); % just initializing cell array for the smoothed, normalized files; should be empty

                    for t = 1: length(taskArray)
                        locateImg = [subj_pth,filesep,taskArray{t},'*',filesep,'ica_test_nowarpFile',filesep,[prefix,'*.nii']];

                        imgFiles = rdir(locateImg);
                        findShort = cellfun(@(x) numel(x), {imgFiles.name}); % in case there are multiple processing pipelines completed on the same brain
                        imgNames = imgFiles(findShort == min(findShort));

                        if length(imgNames) > 1 %The ANALYZE and 3D NII condition
                            nVols = length(imgNames);
                            tmp_sw_files = cell(1,nVols);

                            for iOF = 1: nVols
                                tmp_sw_files{1,iOF} = imgNames(iOF).name;
                            end
                        elseif length(spm_vol(imgNames.name))>1 % The 4D NIFTI condition
                            nVols = spm_vol(imgNames.name);
                            nVols = length(nVols);
                            tmp_sw_files = cell(1,nVols);

                            for iOF = 1: nVols
                                tmp_sw_files{1,iOF} =char(strcat(imgNames.name,',', int2str(iOF)));
                            end
                        end
                        sw_files{t,1} = tmp_sw_files;
                    end

                    %% Best practice matlabbatch setup
                    clear matlabbatch
                    disp('Initializing SPM batch variables');
                    spm_jobman('initcfg');
                    spm('defaults','FMRI');

                    %% Clean the file list
                    for sw = 1: length(sw_files);
                        dropIx = []; %cleaning step
                        for w = 1:numel(sw_files{sw,1})
                            meanImg = [prefix,'mean'];
                            drop = strfind(sw_files{sw,1}(w),meanImg); % check each cell to see if it is a mean img
                            if ~isempty(drop{1,1})
                                dropIx = [dropIx w];
                            end
                        end
                        sw_files{sw,1}(dropIx) = []; %removes any entries fitting the exclusion criteria for that scan series
                    end

                    %% Defining the contrasts
                    contrast_design_file = rdir([proj_dir,filesep,taskName,'*_contrasts*']);
                    if arrayfun(@(x) isempty(x.name),(contrast_design_file)) == 1
                        fprintf('No contrasts defined for %s in %s\nPlease correct before continuing\n',taskName, proj_dir);
                        break
                    end
                    [~,~, raw] = xlsread(contrast_design_file.name); % Must contain the headers listed below, with data stacked vertically underneath.
                    tIx = find(strcmp('titles',raw(1,:))); %names for the top of the glass brains
                    cIx = find(strcmp('contrasts',raw(1,:))); %contrast vectors
                    kindIx = find(strcmp('type',raw(1,:))); % tcon or fcon (to increase flexibility

                    contrast_array = struct();
                    contrast_array(1,1).title = raw(:,tIx);
                    contrast_array(1,1).con = raw(:,cIx);
                    contrast_array(1,1).kind = raw(:,kindIx);

                    nCons = length(contrast_array(1,1).con)-1;
                    fprintf('Discovered %d contrasts to create\n',nCons);

                    %% Entering the variables
                    matlabbatch{1}.spm.stats.fmri_spec.dir = {results_dir};
                    matlabbatch{1}.spm.stats.fmri_spec.timing.units = 'secs';
                    matlabbatch{1}.spm.stats.fmri_spec.timing.RT = tr;
                    matlabbatch{1}.spm.stats.fmri_spec.timing.fmri_t = 16;
                    matlabbatch{1}.spm.stats.fmri_spec.timing.fmri_t0 = 8;
                    matlabbatch{1}.spm.stats.fmri_spec.fact = struct('name', {}, 'levels', {});
                    matlabbatch{1}.spm.stats.fmri_spec.bases.hrf.derivs = [0 0];
                    matlabbatch{1}.spm.stats.fmri_spec.volt = 1;
                    matlabbatch{1}.spm.stats.fmri_spec.global = 'None';
                    matlabbatch{1}.spm.stats.fmri_spec.mthresh = 0.8;
                    matlabbatch{1}.spm.stats.fmri_spec.mask = {''};
                    matlabbatch{1}.spm.stats.fmri_spec.cvi = 'AR(1)';
                    matlabbatch{2}.spm.stats.fmri_est.spmmat(1) = cfg_dep('fMRI model specification: SPM.mat File', substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','spmmat'));
                    matlabbatch{2}.spm.stats.fmri_est.write_residuals = 0;
                    matlabbatch{2}.spm.stats.fmri_est.method.Classical = 1;

                    %% Find smoothed files, condition regressors, and contrast files
                    % Customized for number of runs

                    study_design_file = rdir([proj_dir,filesep,taskName,'*_param*']);
                    if arrayfun(@(x) isempty(x.name),(study_design_file)) == 1
                        fprintf('Design parameters for %s in %s\nPlease correct before continuing\n',taskName, proj_dir);
                        return
                    end
                    [~,~, raw] = xlsread(study_design_file.name); % Must contain the headers listed below, with data stacked vertically underneath.
                    nIx = find(strcmp('names',raw(1,:)));
                    onIx = find(strcmp('onsets',raw(1,:)));
                    durIx = find(strcmp('durations',raw(1,:)));

                    for r = 1:nRuns
                        %% Set the parameters
                        nEntries = (length(raw(:,1))-1)/nRuns; %subtract one for header
                        lastEntry  = int8(nEntries*r)+1;%plus one for header
                        firstEntry = lastEntry-(nEntries-1);
                        nVals = raw(firstEntry:lastEntry,nIx);
                        onVals = raw(firstEntry:lastEntry,onIx);
                        durVals = raw(firstEntry:lastEntry,durIx);

                        cndtn_array = struct();
                        cndtn_array(1,1).name = nVals;
                        cndtn_array(1,1).onset = onVals;
                        cndtn_array(1,1).dur = durVals;

                        %Obsolete code that is not super flexible for different numbers of collected volumes
                        %               nVols = numel(sw_files)/nRuns;
                        %               lastVol = nVols*r; %The number of scans that go with each run times the run number
                        %               firstVol = (nVols*(r-1))+1;
                        %               scan_files = cell(1,nVols);
                        %              for v = firstVol:lastVol
                        %                   tmp = v-firstVol+1;
                        %                  scan_files{tmp} = char(sw_files(v));
                        %               end
                        % Better solution (which required the sw_files to be defined with a cell):
                        scan_files = sw_files{r,1};

                        q = taskArray{r};
                        taskNum = q(end);

                        raw_dir = [subj_pth,filesep,taskName,'_run', taskNum];
                        if isempty(ls(raw_dir))
                            raw_dir = [subj_pth,filesep,taskName];
                        end

                        if eq(runArt,1)
                            rp_file = rdir(strcat(raw_dir,filesep,'art_regression_outliers_w*'));
                            if isempty(arrayfun(@(x) ~isempty(x),rp_file))
                                disp('Executing ART protocol');
                                art_mtncorr(subj, raw_dir);
                                rp_file = rdir(strcat(raw_dir,filesep,'art_regression_outliers_w*'));
                            end

                            if exist('regs','var') %for unwarped analyses
                                rp_file = rdir(strcat(raw_dir,filesep,'art_regression_outliers_w*'));
                                if isempty(rp_file)
                                    rp_file = rdir(strcat(raw_dir,filesep,'art_regression_outliers_sw*'));
                                end
                            end

                            load(rp_file.name);

                            if (r==1)
                                nMtnRegs = size(R,2); %R is the name of the matrix from the rp_file (runArt sets the name)
                            end

                        else
                            if ~exist('regs','var')
                                rp_file = rdir(strcat(raw_dir,filesep,'rp*','.txt'));
                                findShort = cellfun(@(x) numel(x), {rp_file.name});
                                rp_file = rp_file(findShort == min(findShort));
                                nMtnRegs = 6; %standard motion regressors
                            else
                                rp_file = []; % for unwarping
                                rp_file.name = '';
                                nMtnRegs = 0;
                            end
                        end


                        %% Record the parameters in the batch
                        matlabbatch{1}.spm.stats.fmri_spec.sess(r).scans = scan_files';
                        for c = 1:(length(cndtn_array(1,1).name))
                            matlabbatch{1}.spm.stats.fmri_spec.sess(r).cond(c).name = (cndtn_array(1,1).name{c});
                            matlabbatch{1}.spm.stats.fmri_spec.sess(r).cond(c).onset = str2num(cndtn_array(1,1).onset{c});
                            matlabbatch{1}.spm.stats.fmri_spec.sess(r).cond(c).duration = str2num(cndtn_array(1,1).dur{c});
                        end
                        matlabbatch{1}.spm.stats.fmri_spec.sess(r).multi = {''};
                        matlabbatch{1}.spm.stats.fmri_spec.sess(r).regress = struct('name', {}, 'val', {});
                        matlabbatch{1}.spm.stats.fmri_spec.sess(r).multi_reg = {rp_file.name};
                        matlabbatch{1}.spm.stats.fmri_spec.sess(r).hpf = hpf;

                        savefile = [subj_pth,filesep,'firstLevel_' taskName aggLevel '_' subj '.mat'];
                        save(savefile, 'matlabbatch');
                    end

                    if nCons >1
                        matlabbatch{3}.spm.stats.con.spmmat(1) = cfg_dep('Model estimation: SPM.mat File', substruct('.','val', '{}',{2}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','spmmat'));
                        for j = 1:nCons
                            if strcmpi(contrast_array(1,1).kind{j+1},'tcon')
                                matlabbatch{3}.spm.stats.con.consess{j}.tcon.name = contrast_array(1,1).title{j+1};
                                matlabbatch{3}.spm.stats.con.consess{j}.tcon.weights = [str2num(contrast_array(1,1).con{j+1})]; %currently only accommodates 2 runs...
                                matlabbatch{3}.spm.stats.con.consess{j}.tcon.sessrep = 'repl';
                            elseif strcmpi(contrast_array(1,1).kind{j+1},'fcon')
                                matlabbatch{3}.spm.stats.con.consess{j}.fcon.name = contrast_array(1,1).title{j+1};
                                matlabbatch{3}.spm.stats.con.consess{j}.fcon.weights = [str2num(contrast_array(1,1).con{j+1})
                                ];
                                matlabbatch{3}.spm.stats.con.consess{j}.fcon.sessrep = 'repl';
                            else
                                fprintf('Missing contrast type (tcon or fcon) for %s\n', contrast_array(1,1).title{j+1});
                            end

                        end
                        matlabbatch{3}.spm.stats.con.delete = 0; %Add the SPM batch setup

                        matlabbatch{4}.spm.stats.results.spmmat(1) = cfg_dep('Contrast Manager: SPM.mat File', substruct('.','val', '{}',{3}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','spmmat'));
                        for k = 1:nCons;
                            matlabbatch{4}.spm.stats.results.conspec(k).titlestr = contrast_array(1,1).title{k+1};
                            matlabbatch{4}.spm.stats.results.conspec(k).contrasts = k;
                            matlabbatch{4}.spm.stats.results.conspec(k).threshdesc = 'none';
                            matlabbatch{4}.spm.stats.results.conspec(k).thresh = 0.001;
                            matlabbatch{4}.spm.stats.results.conspec(k).extent = 25;
                            matlabbatch{4}.spm.stats.results.conspec(k).mask = struct('contrasts', {}, 'thresh', {}, 'mtype', {});
                        end
                        matlabbatch{4}.spm.stats.results.units = 1;
                        matlabbatch{4}.spm.stats.results.print = 'ps';
                        matlabbatch{4}.spm.stats.results.write.none = 1;
                    else
                        disp('Please run contrast manager and results report manually')
                    end

                    save(savefile, 'matlabbatch');

                    spm_jobman('run',matlabbatch)
                end
            end
        end
    end
end
end

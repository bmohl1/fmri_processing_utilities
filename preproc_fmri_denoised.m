function [subj,taskArray] = preproc_fmri(ver, templates, subjs, taskArray, stc,prefix)
%% batch for preprocessing fMRI data in SPM8
%-------------------------------------------------------------
%  Purpose: Process fMRI data for the PD Machine Learning study from slice
%  time through smoothing.  Steps are outlined below.
%  Author: Brianne Mohl, PhD
% Version: 0.1 (10.17)
% -------------------------------------------------------------
%  input variable is a string that specifis subject ID and task
%  This batch utilize the SPM batch system, matlabbatch. Each step will be saved as a
%  batch fiv)le for review. go through the list and make changes to
%  parameters as you need.
%
%  preparation before start:
%  a. data should be organized as follows:
%  home_dir\subject\task\raw - All fields are flexible except for "raw"
%
%  b. reorient images using display tool in SPM
%  origin at AC point, horizontal plane through AC-PC plane

% Note: If running from command line, one must be in the project directory.

%% What does it do?
%   1) Slice-timing for interleaved acquisition and reference of slice 31
%   2) New segmentation of the T1 (this is an external script, which can be
%   run on its own prior to this script.)
%   3) Realignment with reslicing of mean
%   4) Coregistration of mean resliced image to subject's T1 and
%   deformation applied to other resliced images.
%   5) Deformations - from the New Segmentation step (this is also
%   normalization)
%   6) Smoothing - 6 FWHM kernel


%% set defaults
tool_dir = fileparts(fileparts(which('preproc_fmri')));
addpath([tool_dir filesep 'general_utilities']);

[spm_home, template_home] = update_script_paths(tool_dir);

runArt  = 0; %default
discard_dummies = 0; %default
aggLevels = {'_nonagg', '_agg'}; %default, leave the _ so that _agg and _nonagg are distinguishable

clear -global special_templates subj_t1_dir subj_t1_file ignore_preproc redo_segment
global special_templates subj_t1_dir subj_t1_file ignore_preproc redo_segment; % helpful, since there are multiple scripts that are hunting the same subject's data

%% Set options
if ~exist('stc','var')
    [special_templates runArt stc discard_dummies prefix ignore_preproc redo_segment cancel] = preproc_fmri_inputVars_GUI; %allows for non-scripting users to alter the settings easily.
    settings = {};
    settings.art = runArt;
    settings.stc = stc;
    settings.dummies = discard_dummies;
    settings.unwarp = prefix;
    close(gcf);
    if eq(prefix,1)
        prefix = 'u'; % Can set the letters that are expected prior to standard naming scheme on the data (e.g., 'aruPerson1_task1_scanDate.nii')
    else
        clear prefix; % need to empty the variable option to make sure no blanks are propogated.
    end
end

if eq(cancel,1)
    return
else
    %% Choose the template
    if eq(special_templates,1)
        global template_file
        disp('Please select a 4D Tissue Probability Map.');
        tempfile = cellstr(spm_select([1,Inf],'image','Select the 4D TPM to use throughout the analysis','',pwd));
        tempfile = textscan(tempfile{1,1}, '%s', 'Delimiter',',');
        template_file = tempfile{1,1}{1}; %Must have the ",1" removed for accurate handling elsewhere
        settings.template = template_file;
    end
    
    %% specify subject directory
    switch exist('subjs','var')
        case 1
            [cwd,pth_subjdirs] = file_selector(subjs);
        otherwise
            [cwd,pth_subjdirs] = file_selector;
    end
    
    ver=spm('ver');ver(4:end); %takes off the "spm" part
    
    %% specify fMRI directory
    %structure pth_taskdirs stores .task (string), .rawDir (universal for task),
    %and .fileDirs (tailored to individual)
    switch exist('taskArray')
        case 1
            taskArray = {taskArray};
            [pth_taskdirs, taskArray] = file_selector_task(pth_subjdirs, taskArray);
        otherwise
            [pth_taskdirs, taskArray] = file_selector_task(pth_subjdirs);
    end
    
    projName = textscan(cwd,'%s','Delimiter','/');
    projName = projName{1,1}{end};
    
    %% Example of single prompt
    %prompt = 'Use child templates?';
    %title = 'Templates';
    %x = questdlg(prompt, title ,'Yes', 'No', 'No'); %order of arguments matters
    %if strncmpi(x,'y',1)
    %    special_templates = 'yes'; %passed along to unified segmentation for template selection
    %else
    %    special_templates = 'no';
    %end
    
    for a = 1:length(aggLevels)
        aggLevel = aggLevels{a};
        %% Start setting up the individual's script
        pFiles = size(pth_subjdirs);
        pFiles = pFiles(1);
        for iSubj = 1:pFiles;
            
            for iTask = 1:length(taskArray);
                if eq(redo_segment,1) && iTask == 1
                    subj_redo_segment = redo_segment; % so that it is a semi-global variable that can be reset at each loop to avoid an accidental, infinite loop
                    disp('Redoing the segmentation.');
                else
                    subj_redo_segment = 0;
                end
                task    = pth_taskdirs(iTask).task; %stored from file_selector_task
                rawDirName = pth_taskdirs(iTask).rawDir;
                pth_taskdirs(iTask).fileDirs = unique(pth_taskdirs(iTask).fileDirs);
                nFiles  = length(pth_taskdirs(iTask).fileDirs);
                fprintf('\nWorking with subject %u of %u\nTask:%s\n',iSubj,nFiles,task);
                if isempty(pth_taskdirs(iTask).fileDirs{iSubj})
                    disp('No matching data located. Moving along.')
                    continue
                else
                    subj_pth = textscan(pth_taskdirs(iTask).fileDirs{iSubj,1},'%s','Delimiter','/');
                    spIx = strfind(subj_pth{1,1},task);
                    spIx = find(~cellfun('isempty',spIx)==1);
                    subj_pth = subj_pth{1,1}(2:spIx-1);
                    [proj_dir subj unk] = fileparts(strtrim(sprintf('/%s',subj_pth{:}))); %defines various pieces that are used to build paths and checks elsewhere.
                    
                    subj_prefix = (subj(1:end-1)); %Also for multiple timepoints, where T1 is not collected at all timepoints.
                    
                    task_dir = strcat(pth_taskdirs(iTask).fileDirs{iSubj}); %,filesep, subj,filesep,task);
                    if isempty(pth_taskdirs(iTask).rawDir);
                        raw_dir = task_dir
                    elseif strcmp(task,rawDirName)
                        raw_dir = task_dir
                    else
                        raw_dir = strcat(task_dir,filesep, rawDirName)
                    end
                    
                    %% Find the Images
                    imgFiles = dir(strcat(raw_dir,filesep,'*nii'));
                    findShort = cellfun(@(x) numel(x), {imgFiles.name});
                    imgNames = imgFiles(findShort == min(findShort));
                    
                    if length(imgNames) > 1
                        dims = '3d';
                        ext = textscan(imgNames(1).name,'%s','Delimiter','.');
                        ext = ext{1,1}{end};
                        nVols = length(imgNames);
                    else
                        dims = '4d';
                        ext = textscan(imgNames.name,'%s','Delimiter','.');
                        ext = ext{1,1}{end};
                        nVols = length(spm_vol([raw_dir,filesep, imgNames(1).name]));
                    end
                    
                    if exist('prefix', 'var');
                        inputImg = strcat(char(prefix),imgNames(end).name);
                    else
                        inputImg = imgNames(end).name;
                    end
                    inputImg = strcat(inputImg(1:end-7),'*'); %backs off the extension and up to 999 volumes
                    
                    if exist('prefix', 'var');
                        check_if_unwarped = rdir(strcat(raw_dir,filesep,inputImg));
                        if isempty(check_if_unwarped);
                            orig_files = cell(1,nVols);
                            if strcmp(dims,'4d')
                                for iOF = 1: nVols %counter for "Original Files"
                                    orig_files{1,iOF} = [fullfile(raw_dir,imgNames.name),',', int2str(iOF) ];
                                end
                            else
                                for iOF = 1: nVols
                                    orig_files{1,iOF} = [fullfile(raw_dir,imgNames(iOF).name),',1']; %unwarping
                                end
                            end
                            cd (raw_dir)
                            fmri_unwarp(orig_files, subj, discard_dummies, ver)
                        end
                    end
                    
                    
                    finalFiles = dir(strcat(raw_dir,filesep,'denoised*',aggLevel,'*.nii'));
                    if isempty(finalFiles)
                        finalFiles = dir(strcat(raw_dir,filesep,'denoised*',aggLevel,'*.img'));
                    end
                    
                    if eq(stc,1);
                        check_if_processed = rdir(strcat(raw_dir,filesep,'swa',inputImg));
                    else
                        check_if_processed = rdir(strcat(raw_dir,filesep,'sw',inputImg));
                    end
                    
                    if isempty(check_if_processed) || eq(ignore_preproc,1) ; %meaning if the files have not been smoothed, the rest of the process should also be validated/run
                        %% find t1
                        cd (proj_dir)
                        [subj_t1_dir, subj_t1_file, t1_ext] = locate_scan_file ('t1', subj);%checks if there is a more recent T1
                        if isempty(subj_t1_file)  && ~isempty(strfind(subj, subj_prefix)); %checks to make sure that the same subject is still being processed
                            try
                                display('Warning: trying to match with prefixes')
                                [subj_t1_dir, subj_t1_file, t1_ext] = locate_scan_file ('t1', subj_prefix);
                            catch
                                disp('Did not find T1.');
                            end
                        end
                        
                        if eq(special_templates,1) %Allie's study has a different structure.
                            if isempty(strfind(subj_t1_dir,subj))
                                clear subj_t1_dir subj_t1_file; %need to clear the variables, b/c won't be aligning to the correct brain.
                            end
                        end
                        
                        %% STC
                        
                        if eq(stc,1); %only runs if you selected STC
                            
                            orig_files = cell(1,nVols);
                            if  strcmp(dims,'4d');
                                
                                if exist('prefix','var');
                                    for iOF = 1: nVols %counter for "Original Files"
                                        orig_files{1,iOF} = (fullfile(raw_dir,[prefix,imgNames.name,',',int2str(iOF)])); %unwarping NII
                                    end
                                else
                                    for iOF = 1: nVols;
                                        orig_files{1,iOF} = (fullfile(raw_dir,imgNames.name,',',int2str(iOF))); % normal NII
                                    end
                                end
                            else
                                if exist('prefix','var');
                                    for iOF = 1: nVols %counter for "Original Files"
                                        orig_files{1,iOF} = (fullfile(raw_dir,[prefix,imgNames(iOF).name])); %unwarping ANALYZE
                                    end
                                else
                                    for iOF = 1: nVols;
                                        orig_files{1,iOF} = (fullfile(raw_dir,imgNames(iOF).name)); % normal ANALYZE
                                    end
                                end
                            end
                            
                            
                            check_stc  = dir(strcat(raw_dir,filesep,'a',inputImg));
                            if isempty(check_stc);
                                cd (raw_dir) %ensure starting point
                                disp('Initiating STC');
                                fmri_stc(orig_files,discard_dummies);
                            end
                        end
                        
                        %% Find files for realignment through smoothing
                        
                        display('Finding files to realign, coregister, and smooth...')
                        if eq(stc,1);
                            files_to_process = dir((strcat(raw_dir,filesep,'a',inputImg))); %unwarping
                            
                            proc_files = cell(1,length(files_to_process));
                            for iPF = 1: length(files_to_process); %counter for "Processed Files"
                                proc_files{1,iPF} = fullfile(raw_dir,files_to_process(iPF).name);
                            end
                        else
                            find_files = rdir(char(strcat(raw_dir,filesep,inputImg))); %go find everything %unwarping
                            val=cellfun(@(x) numel(x),{find_files.name}); %compare the length of all the nii's
                            files_to_process =  find_files(val==min(val)); %take the shortest ones, since SPM appends
                            for iPF = 1: length(files_to_process)
                                proc_files{1,iPF} = fullfile(files_to_process(iPF).name);
                            end
                        end
                        
                        
                        cd (raw_dir) %prevents having to pass extra arguments to fmri_realign2smooth
                        %% Realignment through smoothing
                        fprintf('Subject: %s\n',subj);
                        
                        fmri_realign2smooth (proc_files, subj, subj_redo_segment, discard_dummies, ver);
                        
                        settingsFile = strcat(raw_dir,filesep,'fmri_analysis_settings.mat');
                        save(settingsFile,'settings');
                        
                    end
                    
                    if isempty(finalFiles)
                        try
                            icaOut = strcat(raw_dir,filesep,'ICA_testout');
                            mkdir(icaOut);
                            rpFile = glob(strcat(raw_dir,filesep,'rp*'));
                            findShort = cellfun(@(x) numel(x), {imgFiles.name});
                            rpFile= char(rpFile(findShort == min(findShort)));
                            inFile = fullfile(imgNames(1).folder,strcat('sw',imgNames(1).name));
                            cmd = sprintf('/home/brianne/tools/ICA-AROMA-master/ICA_AROMA.py -tr 2.00 -den both -i %s  -mc  %s -o ICA_testout', inFile, rpFile);
                            system(cmd);
                        catch
                            disp('Simply cannot find the necessary denoised files.')
                        end
                    else
                        fprintf('Located  %d processed image(s) \n', length( check_if_processed));
                    end
                    
                    
                    if eq(runArt,1) && isempty(rdir(strcat(raw_dir,filesep,'*art_graphs*')));
                        disp('Attempting to run ART motion correction.');
                        art_mtncorr(subj, raw_dir);
                    end
                end
            end
            disp('Processing complete. Exiting.')
        end
    end
end

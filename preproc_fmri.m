function [subj,taskArray] = preproc_fmri(subjs, taskArray, settings_dict)
%% batch for preprocessing fMRI data in SPM8
%-------------------------------------------------------------
% Purpose: Process fMRI data for the PD Machine Learning study from slice
% time through smoothing.  Steps are outlined below.
% Author: Brianne Sutton, PhD
% Version: 0.2 (07.18)
% -------------------------------------------------------------
% To override any of the scripted structure for settings, one needs to supply the structure argument (e.g., settings.art = ‘art’) and new value (e.g., 1, because you want to run the script with the ART option)
% To create a dictionary type input in MATLAB, use containers.Map({keys},{values}).
% Example dictionary set up: new_settings = containers.Map({'art'},{1})
% Example preproc call...
% >>preproc_fmri('trn003',{'fp_run1', 'fp_run2'}, new_settings)

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
%   run on its own prior to this script.)exit

%   3) Realignment with reslicing of mean
%   4) Coregistration of mean resliced image to subject's T1 and
%   deformation applied to other resliced images.
%   5) Deformations - from the New Segmentation step (this is also
%   normalization)
%   6) Smoothing - 8 FWHM kernel


%For FUTURE: make a log of "exceptions" that will pop up for users after a batch is completed.

%% set defaults
tool_dir = fileparts(fileparts(which('preproc_fmri')));
addpath([tool_dir filesep 'general_utilities']);
img_home = '/data/images';
[spm_home, template_home] = update_script_paths(tool_dir, '12');
motionCheck =1;

persistent settings;

settings = struct('art', 0, 'cancel', 0, 'dummies', 0, 'ignore_preproc', 0, ...
'special_templates', 0,'subj_t1_dir', '', 'subj_t1_file', '',  'redo_segment', 0, ...
'stc', 0, 'unwarp', 0, 'aCompCorr', 0, 'ver', '12');


%% specify subject directory
switch exist('subjs','var')
    case 1
        if ~contains(string(pwd),subjs)
            cd (img_home);
        end
        try
            [cwd,settings.pth_subjdirs] = file_selector(subjs);
        catch
            fprintf('Script exited with errors in file_selector.\n')
            return
        end
    otherwise
        try
            [cwd,settings.pth_subjdirs] = file_selector;
        catch
            fprintf('Either error in file_selector or user exited subject selection\n')
            return %User exited
        end
end

settings.pth_subjdirs= settings.pth_subjdirs(~cellfun('isempty', settings.pth_subjdirs));
settings.ver = spm('ver');settings.ver(4:end); %takes off the "spm" part

%% specify fMRI directory
% structure pth_taskdirs stores .task (string), .rawDir (universal for task),
% and .fileDirs (tailored to individual)
switch exist('taskArray','var')
    case 1
        % The user has provided inputs for specific files to be analyzed.
        try
             %The taskArray is decomposed in file_selector_task. Leave as
             % cell array.
              [settings.pth_taskdirs, settings.taskArray] = file_selector_task(settings.pth_subjdirs, taskArray);
        catch
          fprint('Error defining task directories. (fmri_preproc line 87)')
          return
        end

    otherwise
        try
            % Pop open a GUI that will allow them to select the scans to
            % process.
            [settings.pth_taskdirs, settings.taskArray] = file_selector_task(settings.pth_subjdirs);
        catch
            % User changes his/her mind and exits the GUI
            fprintf('User exited task selection\n')
            return
        end
end

% Eliminate duplicate folders
for l = 1:length(settings.pth_taskdirs)
    settings.pth_taskdirs(l).fileDirs = unique(settings.pth_taskdirs(l).fileDirs);
    settings.pth_taskdirs(l).fileDirs = settings.pth_taskdirs(l).fileDirs(~cellfun('isempty', settings.pth_taskdirs(l).fileDirs));
end

projName = textscan(settings.pth_subjdirs{1},'%s','Delimiter','/');
settings.projName = projName{1,1}{end-1};

if exist('settings_dict','var')
    % If options have been described, load them into the settings structure
    k = keys(settings_dict);
    v = values(settings_dict);
    for x = 1 : length(settings_dict)
        settings = setfield(settings,k{x},v{x});
    end
    fprintf('Updated settings.')
    if contains(string(pwd), subjs)
        % Double checks where you are, since pwd is called later
        cd ..
    end
end

%% Set options
if ~exist('settings_dict','var')
    [settings.special_templates settings.art settings.stc ...
        settings.dummies settings.unwarp settings.ignore_preproc ...
        settings.redo_segment settings.cancel settings.aCompCorr settings.alt_pipeline] = preproc_fmri_inputVars_GUI; %allows for non-scripting users to alter the settings easily
    close(gcf);
    if eq(settings.unwarp,1)
        % Unwarping used for geometric distortion correction
        unwarp_prefix = 'u'; % Can set the letters that are expected prior to standard naming scheme on the data (e.g., 'aruPerson1_task1_scanDate.nii')
    else
        clear unwarp_prefix; % need to empty the variable option to make sure no blanks are propogated.
    end
end

if eq(settings.cancel,1)
    return
else

    %% Choose the template
    if eq(settings.special_templates,1)
        global template_file
        disp('Please select a 4D Tissue Probability Map.');
        [tempfile,sts] = spm_select([1,Inf],'image','Select the template to use throughout the analysis','',pwd);
        if sts == 0
            fprintf('User exited TPM selection\n');
            return
        end
        tempfile = cellstr(tempfile);
        tempfile = textscan(tempfile{1,1}, '%s', 'Delimiter',',');
        template_file = tempfile{1,1}{1}; %Must have the ",1" removed for accurate handling elsewhere
        settings.template = template_file;
    end

    %% Example of single prompt
    %prompt = 'Use child templates?';
    %title = 'Templates';
    %x = questdlg(prompt, title ,'Yes', 'No', 'No'); %order of arguments matters
    %if strncmpi(x,'y',1)
    %    special_templates = 'yes'; %passed along to unified segmentation for template selection
    %else
    %    special_templates = 'no';
    %end

    %% Start setting up the individual's script
    pFiles = size(settings.pth_subjdirs);
    pFiles = pFiles(1);
    for iSubj = 1:pFiles        
        for iTask = 1:length(settings.taskArray)           
            if eq(settings.redo_segment,1) && iTask == 1
                disp('Redoing the segmentation.');
            end
            if iSubj <= length(settings.pth_taskdirs(iTask).fileDirs)
                task    = settings.pth_taskdirs(iTask).task; %stored from file_selector_task
                rawDirName = settings.pth_taskdirs(iTask).rawDir;
                nFiles  = length(settings.pth_taskdirs(iTask).fileDirs);
                fprintf('\nWorking with subject %u of %u\nTask: %s\n',iSubj,nFiles,task);
                if isempty(settings.pth_taskdirs(iTask).fileDirs{iSubj})
                    disp('No matching data located. Moving along.')
                    continue
                else
                    subj_pth = textscan(settings.pth_taskdirs(iTask).fileDirs{iSubj,1},'%s','Delimiter','/');
                    spIx = strfind(subj_pth{1,1},task);
                    spIx = find(~cellfun('isempty',spIx)==1,1,'last');
                    subj_pth = subj_pth{1,1}(2:spIx-1);
                    [proj_dir subj unk] = fileparts(strtrim(sprintf('/%s',subj_pth{:}))); %defines various pieces that are used to build paths and checks elsewhere.
                    cd(proj_dir);
                    % Some participants will have disjointed functional and anatomical scans. The following lines dismantle the file path of the scans enough that locate_scan_file or locate_t1 can build a useful filepath.
                    subj_prefixIx = strfind(subj,'_');
                    if ~isempty(subj_prefixIx)
                        subj_prefix = (subj(1:subj_prefixIx(1))); %Also for multiple timepoints, where T1 is not collected at all timepoints.
                        timepoint = str2num(subj(subj_prefixIx(1)+1));
                        alt_subjId = strcat(subj_prefix,num2str(timepoint-1)); % This will break, if the timepoint is a,b,c,etc.
                        alt_subjId2 = strcat(subj_prefix,num2str(timepoint+1));
                    end

                    task_dir = strcat(settings.pth_taskdirs(iTask).fileDirs{iSubj}); %,filesep, subj,filesep,task);
                    if isempty(settings.pth_taskdirs(iTask).rawDir);
                        raw_dir = task_dir
                    elseif strcmp(task,rawDirName)
                        raw_dir = task_dir
                    else
                        raw_dir = strcat(task_dir,filesep, rawDirName)
                    end


                    [settings.subj_t1_dir, settings.subj_t1_file, settings.t1_ext] = locate_scan_file ('t1', subj); %checks if there is a more recent T1
                    if isempty(settings.subj_t1_file)  && ~isempty(strfind(subj, subj_prefix)); %checks to make sure that the same subject is still being processed
                        try
                            fprintf('Warning: T1 not associated with this task.\nTrying to find proximal T1 in %s \n', alt_subjId);
                            [settings.subj_t1_dir, settings.subj_t1_file, settings.t1_ext] = locate_scan_file ('t1', alt_subjId);
                        catch
                          try
                            fprintf('Warning: T1 not associated with this task.\nTrying to find proximal T1 in %s \n', alt_subjId2);
                            [settings.subj_t1_dir, settings.subj_t1_file, settings.t1_ext] = locate_scan_file ('t1', alt_subjId2);
                          catch
                            disp('Did not find T1.');
                          end
                        end
                    end

                    %% Find the Images
                    if contains (settings.ver, '8')
                        imgFiles = dir(fullfile(raw_dir,strcat('*spm8.nii')))
                    else
                         imgFiles = dir(fullfile(raw_dir,'*.nii'));
                    end
                    if isempty(imgFiles)
                        imgFiles = dir(fullfile(raw_dir,'*.img'));
                    end

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
                        nVols = length(spm_vol([raw_dir, filesep, imgNames(1).name]));
                    end
 
                    %% ACPC autodetection
                    if isempty(dir(strcat(raw_dir,filesep,'touch_acpc.txt')))
                        acpc_autodetect([raw_dir, filesep, imgNames(1).name]);
                    end

                    %% Unwarping
                    if eq(settings.unwarp,1)
                        inputImg = strcat(char(unwarp_prefix),imgNames(end).name);
                    else
                        inputImg = imgNames(end).name;
                    end
                    inputImg = strcat(inputImg(1:end-7),'*'); %backs off the extension and up to 999 volumes

                    if eq(settings.unwarp,1);
                        check_if_unwarped = rdir(strcat(raw_dir,filesep,inputImg));
                        if isempty(check_if_unwarped);
                            orig_files = cell(1,nVols);
                            if strcmp(dims,'4d')
                                for iOF = 1: nVols %counter for "Original Files"
                                    orig_files{1,iOF} = [strcat(raw_dir,filesep,imgNames.name),',', int2str(iOF) ];
                                end
                            else
                                for iOF = 1: nVols
                                    orig_files{1,iOF} = [strcat(raw_dir,filesep,imgNames(iOF).name),',1']; %unwarping
                                end
                            end
                            cd (raw_dir)
                            fmri_unwarp(orig_files, subj, settings)
                        end
                    end
                    
                    %% STC
                    if eq(settings.stc,1);
                        check_if_processed = rdir(strcat(raw_dir,filesep,'swa',inputImg));
                    elseif eq(settings.alt_pipeline,1);
                        check_if_processed = rdir(strcat(raw_dir,filesep,'sv',inputImg));           
                    else
                        check_if_processed = rdir(strcat(raw_dir,filesep,'sw',inputImg));
                    end
                    
                    %% Main options - only carried out, if the files have not been processed
                    if isempty(check_if_processed) || eq(settings.ignore_preproc,1); %meaning if the files have not been smoothed, the rest of the process should also be validated/run
                        % find t1
                        cd (proj_dir)
                        
                        % STC
                        if eq(settings.stc,1); %only runs if you selected STC

                            orig_files = cell(1,nVols);
                            if  strcmp(dims,'4d');

                                if eq(settings.unwarp,1);
                                    for iOF = 1: nVols %counter for "Original Files"
                                        orig_files{1,iOF} = (strcat(raw_dir,filesep,[unwarp_prefix,imgNames.name,',',int2str(iOF)])); %unwarping NII
                                    end
                                else
                                    for iOF = 1: nVols;
                                        orig_files{1,iOF} = (strcat(raw_dir,filesep,imgNames.name,',',int2str(iOF))); % normal NII
                                    end
                                end
                            else
                                if eq(settings.unwarp,1);
                                    for iOF = 1: nVols %counter for "Original Files"
                                        orig_files{1,iOF} = (strcat(raw_dir,filesep,[unwarp_prefix,imgNames(iOF).name])); %unwarping ANALYZE
                                    end
                                else
                                    for iOF = 1: nVols;
                                        orig_files{1,iOF} = (strcat(raw_dir,filesep,imgNames(iOF).name)); % normal ANALYZE
                                    end
                                end
                            end


                            check_stc  = dir(strcat(raw_dir,filesep,'a',inputImg));
                            if isempty(check_stc);
                                cd (raw_dir) %ensure starting point
                                disp('Initiating STC');
                                fmri_stc(orig_files,settings);
                            end
                        end

                        %% Find files for realignment through smoothing

                        display('Finding files to realign, coregister, and smooth...')
                        if eq(settings.stc,1);
                            files_to_process = dir((strcat(raw_dir,filesep,'a',inputImg))); %unwarping

                            proc_files = cell(1,length(files_to_process));
                            for iPF = 1: length(files_to_process); %counter for "Processed Files"
                                proc_files{1,iPF} = strcat(raw_dir,filesep,files_to_process(iPF).name);
                            end
                        else
                            find_files = rdir(char(strcat(raw_dir,filesep,inputImg))); %go find everything %unwarping
                            tmp = cellfun(@(x) strfind(x,'.mat'), {find_files.name}, 'UniformOutput',false);
                            find_files = find_files(find(cellfun('isempty',tmp)));
                            val=cellfun(@(x) numel(x),{find_files.name}); %compare the length of all the nii's
                            files_to_process =  find_files(val==min(val)); %take the shortest ones, since SPM appends
                            for iPF = 1: length(files_to_process)
                                proc_files{1,iPF} = fullfile(files_to_process(iPF).name);
                            end
                        end


                        cd (raw_dir) %prevents having to pass extra arguments to fmri_realign2smooth
                        %% Realignment through smoothing
                        fprintf('Subject: %s\n',subj);
                        fprintf('T1: %s\n', settings.subj_t1_file)
                        if length(proc_files) > 0 && settings.alt_pipeline == 0
                            % Only processes participants with identified
                            % volumes.
                            fmri_realign2smooth (proc_files,subj, settings);
                        elseif length(proc_files) > 0
                            fmri_irepi_pipeline(proc_files,subj, settings);
                        end

                        settingsFile = strcat(raw_dir,filesep,'fmri_analysis_settings.mat');
                        save(settingsFile,'settings');
%                     elseif eq(motionCheck,1)
%                         find_files = rdir(char(strcat(raw_dir,filesep,inputImg))); %go find everything %unwarping
%                         tmp = cellfun(@(x) strfind(x,'.mat'), {find_files.name}, 'UniformOutput',false);
%                         find_files = find_files(find(cellfun('isempty',tmp)));
%                         val=cellfun(@(x) numel(x),{find_files.name}); %compare the length of all the nii's
%                         files_to_process =  find_files(val==min(val)); %take the shortest ones, since SPM appends
%                         for iPF = 1: length(files_to_process)
%                             proc_files{1,iPF} = fullfile(files_to_process(iPF).name);
%                         end
%                         calculateQCmeasures(proc_files{:}, settings.subj_t1_file, 8, spm_home, raw_dir, subj)
                    else
                        fprintf('Located  %d processed image(s) \n', length( check_if_processed));
                    end
                end

                if (eq(settings.art,1) && isempty(rdir(strcat(raw_dir,filesep,'*_art_graphs*')))...
                        || eq(settings.art,1) && eq(settings.ignore_preproc,1));
                    if ~isempty(check_if_processed )
                        disp('Attempting to run ART motion correction.');
                        art_mtncorr(subj, raw_dir, settings.ignore_preproc);
                    end
                end

                if (eq(settings.aCompCorr,1) && isempty(rdir(strcat(raw_dir,filesep,'aCompCorr_regs.txt')))...
                    || eq(settings.aCompCorr,1) && eq(settings.ignore_preproc,1));

                    %% Find files for realignment through smoothing
                    display('Finding WM, CSF and normalized files for signal extraction')
                    if eq(settings.stc,1);
                        files_to_process = dir((strcat(raw_dir,filesep,'wa',inputImg))); %unwarping
                        proc_files = cell(1,length(files_to_process));
                        for iPF = 1: length(files_to_process); %counter for "Processed Files"
                            proc_files{1,iPF} = strcat(raw_dir,filesep,files_to_process(iPF).name);
                        end
                    else
                        find_files = rdir(char(strcat(raw_dir,filesep,'w',inputImg))); %go find everything %unwarping
                        tmp = cellfun(@(x) strfind(x,'.mat'), {find_files.name}, 'UniformOutput',false);
                        find_files = find_files(find(cellfun('isempty',tmp)));
                        val=cellfun(@(x) numel(x),{find_files.name}); %compare the length of all the nii's
                        files_to_process =  find_files(val==min(val)); %take the shortest ones, since SPM appends
                        for iPF = 1: length(files_to_process)
                            proc_files{1,iPF} = fullfile(files_to_process(iPF).name);
                        end
                    end
                %    if isempty(settings.subj_t1_file)  && ~isempty(strfind(subj, subj_prefix)); %checks to make sure that the same subject is still being processed
                %        try
                %            fprintf('Warning: T1 not associated with this task.\nTrying to find proximal T1 in %s \n', alt_subjId);
                %            [settings.subj_t1_dir, settings.subj_t1_file, settings.t1_ext] = locate_scan_file ('t1', alt_subjId);
                %        catch
                %            disp('Did not find T1.');
                %            continue
                %        end
                  %  end
                    gm = rdir(fullfile(settings.subj_t1_dir,strcat('mwc1',settings.subj_t1_file)));
                    wm = rdir(fullfile(settings.subj_t1_dir,strcat('mwc2',settings.subj_t1_file)));
                    csf = rdir(fullfile(settings.subj_t1_dir,strcat('mwc3',settings.subj_t1_file)));
                    vois = create_threshold_mask({gm.name, wm.name,csf.name}); %Can enter alternate threshold if desired
                    acompcorr = extract_voi_ts_compCorr(proc_files,{wm.name,csf.name});
                   save(fullfile(raw_dir, 'aCompCorr_regs.txt'),'acompcorr','-ascii')
                   cd(proj_dir)
            end
        end
    end
    end
cd(proj_dir)
end

function art_mtncorr(subjs, raw_dir, swFiles)

%#######################################################################
%Loads variables into a configure file that can be passed on to Art
%May 2013 BMM
% Modifications made through 2017
%Enter variables per the example.cfg in /opt/bin/spm/spm8/toolbox/art
% Originally scripted in tcsh...
%
%Common errors: "?" padding for file definitions; two or more rp files that
%are not the same length as the processed files
%#######################################################################

if isempty(which('art_bmm'))
    rmpath(which('art'));
    addpath('/home/brianne/tools/toolboxes/art');
end


switch nargin
    case 2
            rawDirPieces = textscan(raw_dir,'%s','Delimiter','/');
            cwd = fullfile(filesep,rawDirPieces{1,1}{1:end-1});
            pth_subjdirs = {cwd};
    case 1
         [cwd,pth_subjdirs] = file_selector(subjs); %cwd is the root of the study
    otherwise
        [cwd,pth_subjdirs] = file_selector;
end

switch exist ('raw_dir','var')
    case 1
        tmp = textscan(raw_dir,'%s','Delimiter','/');
        taskArray = tmp{1,1}(end);
        [pth_taskdirs, taskArray] = file_selector_task(pth_subjdirs, taskArray); %I think this is duplicating a bunch of efforts
    otherwise
        [pth_taskdirs, taskArray] = file_selector_task(pth_subjdirs);
end
projName = textscan(cwd,'%s','Delimiter','/');
if strcmp(subjs,projName{1,1}{end})
projName = projName{1,1}{end-1};
else
projName = projName{1,1}{end};
end

%% Setup basics of the first-level

for iSubj = 1:length(pth_subjdirs)
    pth = textscan(pth_subjdirs{iSubj},'%s','Delimiter','/');
    spIxN = strfind(pth{:},projName);
    spIx = find(~cellfun('isempty',spIxN)==1);
    if eq(spIx, length(spIxN))
        pth = pth{1,1}(2:spIx);
    else
    pth = pth{1,1}(2:spIx+1);
    end

    [proj_dir subj unk] = fileparts(strtrim(sprintf('/%s',pth{:})));

    %for iTask = 1:length(taskArray);
        task    = pth_taskdirs.task; %stored from file_selector_task
        rawDirName = pth_taskdirs.rawDir; % if "raw" exists in file structure

        if isempty(glob(char(strcat(pth_subjdirs{iSubj}, filesep,task,filesep,'*_art_graphs*')))); % has the ART correction already been applied?
            fprintf('Processing %s task %d \n', subj);
            tmp = strfind(pth,subj); % Scan all the parts of the path to find which pieces should be put together for the raw directory path
            ix = find(cellfun(@(x) ~isempty(x),tmp)); %Trying to locate the path correctly
            if ix == length(pth);
                raw_dir = strcat(strtrim(sprintf('/%s',pth{:})),filesep,task);
            else
                raw_dir = strcat(strtrim(sprintf('/%s',pth{:})),filesep,task, filesep, rawDirName);
            end


            find_files = rdir(strcat(raw_dir,filesep,'w','*.nii'));
            findShort  = cellfun(@(x) numel(x),{find_files.name}); %compare the length of all the nii's
            find_files = find_files(findShort==min(findShort));

            [ ~, ~, ext ] =fileparts(find_files(1).name);
            if strcmp (ext, '.nii')
                ftmp = {};
                for jj = 1: length(spm_vol(find_files.name));
                    swFiles{1,jj} = strcat( find_files(1).name, ',', int2str(jj));
                end
            elseif length(find_files) < 2
                fprintf('Found %d files\n',length(find_files));
                return
            else
                for iSwF = 1: numel(find_files)
                    swFiles{1,iSwF} = fullfile(find_files(iSwF).name);
                end
            end

            if numel(swFiles) > 0
                %% Load parameters
                fileName = (strcat(raw_dir,filesep,subj,'_art.cfg'));
                fid = fopen(fileName,'w+');

                fprintf(fid, 'sessions: 1\n' );
                fprintf(fid, 'global_mean: 1\n');
                % global mean type (1: Standard 2: User-defined mask)
                fprintf(fid, 'global_threshold: 5.0\n');
                % threhsolds for outlier detection
                fprintf(fid, 'motion_threshold: 1.0\n' );
                fprintf(fid, 'motion_file_type: 0\n' );
                % motion file type (0: SPM .txt file 1: FSL .par file 2:Siemens .txt file)
                fprintf(fid, 'motion_fname_from_image_fname: 0\n' );
                % 1/0: derive motion filename from data filename
                fprintf(fid, 'use_diff_motion: 1\n' );

                %set spm_file_out = `ls ${long_name}/results_unwarp/SPM.mat`
                % location of SPM.mat file (comment this line if you do not wish to estimate number of outliers per condition)
                %fprintf(fid, 'spm_file: ${spm_file_out} ' >> ${basename}_art.cfg
                fprintf(fid, 'subj_dir: %s\n', strcat(filesep,fullfile(pth{:})));
                fprintf(fid, 'output_dir: %s\n', raw_dir  );
                fprintf(fid, 'image_dir: %s\n', raw_dir  );          % functional and movement data folders (comment these lines if functional/movement filenames below contain full path information)
                fprintf(fid, 'motion_dir: %s\n', raw_dir  );

                rp_file = rdir([raw_dir, filesep, 'rp_','*txt']);
                rpIx = textscan(rp_file(1,1).name,'%s','Delimiter', '/');
                rp_file = rpIx{1,1}{end};
                if ~isempty(rp_file)
                    fprintf(fid, 'end\n\n'); %needed halfway through for ART script
                    nameIx =  rdir([raw_dir, filesep, 'w*']);
                    findShort = cellfun(@(x) numel(x), {nameIx.name}); % don't want to have the wmean file interrupting the pipeline, if it exists.
                    nameIx = nameIx(findShort==min(findShort));

                    [ ~ , img_file, ext] = fileparts(nameIx.name);
                    repQs = repmat('?',1,length(img_file)-5);

                    fprintf(fid, 'session 1 image %s%s.nii\n', img_file(1:5),repQs); %CHECK THE NUMBER OF ???'s if you are having trouble.
                    fprintf(fid, 'session 1 motion %s\n\n', rp_file );
                    %fprintf(fid, 'output_dir: %s\n', raw_dir ); %Don't send to cfg file
                    %    fprintf(fid, 'stats_dir:  ${long_name}'
                    fprintf(fid, 'end\n');
                end
                fclose('all');
                art_bmm(char(fileName)); %Almost always, errors in loading files here are due to how many question marks there are within the config file path definitions. Cannot be relative path.
                close('all');
            end
        else
            fprintf('Already evaluated: %s Task:%d\n',subj);
        end
    end
end
%end

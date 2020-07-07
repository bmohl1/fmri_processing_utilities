function ppi_proc(subjs,task,voi,reg_var)
% Purpose: Extract and deconvolve timeseries from PPI ROI. Includes correction for first-level regressors, average WM, and average CSF. Reconvolve and set up PPI first-level
% Author: Brianne Sutton, PhD
% Summer 2016

%defaults
get_mtn_reg = 'yes'; %Can change and will enter the 6 regressors for the rp file along with PPI regressors
spcfc_rslts_dir = 'no'; %'yes';

%paths
tool_dir = fileparts(fileparts(which('ppi_proc')));
addpath([tool_dir filesep 'general_utilities']);

persistent settings;

[spm_home, mni_home] = update_script_paths(tool_dir); %make sure that we're getting into SPM12

%% Choose the mask
if ~exist('voi','var')
    disp('Please select the VOI');
    [vois,sts] = spm_select([1,Inf],'image','Select the VOI for this analysis','',pwd);
    if sts == 0
      return
    end
    vois = cellstr(vois);
end

%% Grab the potential subjects
switch exist ('subjs','var')
    case 1
        [projDir,pth_subjDirs, subjList] = file_selector(subjs);
    otherwise
        [projDir,pth_subjDirs, subjList] = file_selector;
end

cd(pth_subjDirs{1,1}(1))
%% locate the corresponding task files
switch exist('task','var')
    case 1
        [pth_taskDirs, taskArray] = file_selector_task(pth_subjDirs, task);
    otherwise
        [pth_taskDirs, taskArray] = file_selector_task(pth_subjDirs);
end

for l = 1:length(pth_taskDirs)
    pth_taskDirs(l).fileDirs = unique(pth_taskDirs(l).fileDirs);
    pth_taskDirs(l).fileDirs = pth_taskDirs(l).fileDirs(~cellfun('isempty', pth_taskDirs(l).fileDirs));
end

projName = textscan(projDir,'%s','Delimiter','/');
projName = projName{1,1}{end};
cd(projDir)

if ~exist('reg_var','var')
    reg_var = ('on'); %provides a default
end

for v = 1:length(vois)
    temp = textscan(vois{v,1}, '%s', 'Delimiter',',');
    voi_file = temp{1,1}{1}; %Must have the ",1" removed for accurate handling elsewhere
    [voi_dir, voi] = fileparts(voi_file);

    %% Start setting up the individual's script
    for iTask = 1:length(taskArray)
        for nSubj = 1:length(pth_subjDirs);
            subj_pth = pth_subjDirs{nSubj};
            %subj_taskpth = pth_taskDirs(iTask).fileDirs{nSubj};
            check = textscan(subj_pth,'%s','Delimiter','/'); 
            if exist('subjList','var') && length(subjList) >= 1;
                subjs = char(subjList{nSubj});
            elseif length(subjList) == 1
                subjs = subjList;
            end

            ix = strfind(check{1,1},projName); %locate where the subj is in the string
            ix = ~cellfun('isempty',ix);
            ix = find(ix,1,'first');
            subj = check{1,1}{ix+1};
            %Future - make this the length of the non-unique ID
            subj_prefix = (subj(1:end-1)); %Need to back off one character to accomodate finding the T1

            cd(subj_pth)

            if strcmp(spcfc_rslts_dir, 'yes')
                %% Hard coded just to speed up for K and J
                results_dir = [subj_pth,filesep,'model_eats_ar_mvmnt_s6_ppiEx'];
                subj_prefix=subj_prefix(1:end-3);
                %results_dir = [subj_pth,filesep,'results_art'];
            else
                results_dir = [subj_pth,filesep,taskArray{iTask}];  % When the option was to make an ART directory, there was an if/then to switch the results_art dir
            end

            check_spm  = char(glob(strcat(results_dir,filesep,'SPM.mat')));
            if length(check_spm) < 1
                sprintf('Was the design matrix evaluated for %s?',subj);
                disp('Did not evalutate PPI')
            else
                spm_mat = {check_spm};

                %% Run extraction, if not already complete
                task = taskArray{iTask};
                runs = file_selector_task({subj_pth}, {task});
                for r = 1:length(runs)
                    run = num2str(r);
                    check_extracted = glob(strcat(results_dir,filesep,'VOI_',voi,'_',run,'.mat'));
                    if isempty(check_extracted)
                        try
                            cd(projDir)
                            ppi_voi_extract_physio(subj,task,voi,reg_var,results_dir, voi_dir);
                            check_extracted = glob(strcat(results_dir,filesep,'VOI_',voi,'_',run,'.mat'));
                        catch
                            sprintf('Timecourse extractions were unsuccessful for %s\n',subj)
                            continue
                        end
                    end

                    %% Skip reconvolution, if already complete
                    voi_output = strcat(voi,'_',run);
                    check_reconvolved  = char(glob(strcat(results_dir,filesep,'PPI_',voi_output,'.mat')));

                    %% Reconvolution
                    if ~isempty(check_reconvolved)
                        fprintf( '%s PPI ready \n',results_dir);
                    elseif ~isempty(check_spm)
                        disp('Reconvolving the extracted signal')
                        % In the FUTURE, read in the regressors from a text file to make more flexible across studies.
                        task_regressors = [1 1 1; 2 1 0; 3 1 0; 4 1 0]; %Definitions for the PPI. (1) Condition, (2) Include condition?, (3) How to weight the condition
                        % For EATS data, ignore "objects", subtract effect of basics, add effect of hedonics, and ingore baseline
                        if ~isempty(check_extracted)
                            clear matlabbatch
                            spm_jobman('initcfg');
                            matlabbatch{1}.spm.stats.ppi.spmmat = spm_mat;
                            matlabbatch{1}.spm.stats.ppi.type.ppi.voi = check_extracted;
                            matlabbatch{1}.spm.stats.ppi.type.ppi.u = task_regressors;
                            matlabbatch{1}.spm.stats.ppi.name = voi_output;
                            matlabbatch{1}.spm.stats.ppi.disp = 1;

                            if strcmp(reg_var, 'off')
                                savefile = [voi,'_ppi_build_',subj,'sess_',run, '.mat'];
                            else
                                savefile = [voi,'_ppi_build_',subj,'_rp',run, '.mat'];
                            end

                            save(savefile,'matlabbatch');
                            spm_jobman('run',matlabbatch)
                        else
                            fprintf('Timeseries could not be extracted from %s for %s\n', voi, subj)
                            err_file = strcat(projDir,filesep,'error_',voi,'_extraction')
                            fid = fopen(err_file,'a');
                            fprintf(fid,'Missing %s timeseries for %s\n',voi,subj);
                            fclose(fid);
                        end
                    end
                end

                if ~exist('voi_output','var')
                    continue
                else
                    %% First-level PPI processing
                    ppi_name      = strcat('ppi_',voi);
                    if strcmp (reg_var, 'off')
                        ppi_name      = strcat('ppi_',voi);
                    else
                        ppi_name      = strcat('ppi_',voi,'_rp');
                    end

                    %% Setup and check whether the PPI has been run
                    ppi_con_dir   = fullfile(subj_pth,ppi_name);
                    if isempty(char(glob(ppi_con_dir)))
                        mkdir (ppi_con_dir);
                    end
                    check_ppi_con = char(glob(strcat(ppi_con_dir,filesep,'con_0001.img'))); %the con image ensures that the SPM was estimated.
                    check_reconvolved = char(glob(strcat(results_dir,filesep,'PPI_',voi_output,'.mat')));

                    if isempty(check_ppi_con) && ~isempty(check_reconvolved)
                        disp('Loading PPI estimation variables')
                        ppi_spm = (strcat(ppi_con_dir,filesep,'SPM.mat'));
                        if exist (ppi_spm, 'file');
                            delete (ppi_spm); % Automates it, so you don't get the dialog box
                        end

                        clear matlabbatch
                        spm_jobman('initcfg');
                        savefile = [voi,'_ppi_est_',subj, '.mat'];
                        %% Get the ppi regressors
                        for r = 1: length(runs)
                            run = num2str(r);
                            voi_output = strcat(voi,'_',run);
                            reconv  = check_reconvolved;
                            csf_file = char(glob(strcat(results_dir,filesep,'VOI_csf_',run,'.mat')));
                            wm_file = char(glob(strcat(results_dir,filesep,'VOI_wm_',run,'.mat')));
                            try
                                rp_file = char(glob(strcat(subj_pth,filesep,runs(1,r).task,filesep,'rp*txt')));
                            catch
                                print('Are the rp files copied into the results directories?')
                            end
                                                        
                            load(reconv);
                            reg1 = PPI.ppi;
                            reg2 = PPI.Y;
                            reg3 = PPI.P;
                            %load(csf_file);
                            %csf_sig = Y;
                            %load(wm_file);
                            %wm_sig = Y;

                            rp_sig = load(rp_file);

                            %% Get the motion regressors
                            %if strcmp (spcfc_rslts_dir, 'yes')
                            %find_rp_file = char(glob(strcat(subj_pth,filesep,'trimmed*')));
                            %else
                            %find_rp_file = char(glob(strcat(subj_pth,filesep,task_dir,filesep,'raw',filesep,'rp_*')));

                            [scan_files] = gather_sw_files(subj_pth,{runs(1,r).task});
                            matlabbatch{1}.spm.stats.fmri_spec.dir = {ppi_con_dir};
                            matlabbatch{1}.spm.stats.fmri_spec.timing.units = 'secs';
                            matlabbatch{1}.spm.stats.fmri_spec.timing.RT = 2;
                            matlabbatch{1}.spm.stats.fmri_spec.timing.fmri_t = 16;
                            matlabbatch{1}.spm.stats.fmri_spec.timing.fmri_t0 = 8;
                            matlabbatch{1}.spm.stats.fmri_spec.sess(r).scans = scan_files;
                            %%
                            matlabbatch{1}.spm.stats.fmri_spec.sess(r).cond = struct('name', {}, 'onset', {}, 'duration', {}, 'tmod', {}, 'pmod', {}, 'orth', {});
                            matlabbatch{1}.spm.stats.fmri_spec.sess(r).multi = {''};
                            matlabbatch{1}.spm.stats.fmri_spec.sess(r).regress(1).name = 'interaction';
                            %%
                            matlabbatch{1}.spm.stats.fmri_spec.sess(r).regress(1).val = reg1;
                            %%
                            matlabbatch{1}.spm.stats.fmri_spec.sess(r).regress(2).name = 'physio';
                            %%
                            matlabbatch{1}.spm.stats.fmri_spec.sess(r).regress(2).val = reg2;
                            %%
                            matlabbatch{1}.spm.stats.fmri_spec.sess(r).regress(3).name = 'psycho';
                            %%
                            matlabbatch{1}.spm.stats.fmri_spec.sess(r).regress(3).val = reg3;
                            %%
                            %matlabbatch{1}.spm.stats.fmri_spec.sess(r).regress(4).name = 'wm';
                            %%
                            %matlabbatch{1}.spm.stats.fmri_spec.sess(r).regress(4).val = wm_sig;
                            %%
                            %matlabbatch{1}.spm.stats.fmri_spec.sess(r).regress(5).name = 'csf';
                            %%
                            %matlabbatch{1}.spm.stats.fmri_spec.sess(r).regress(5).val = csf_sig;
                            %%
                            %matlabbatch{1}.spm.stats.fmri_spec.sess(r).multi_reg = {''};
                            matlabbatch{1}.spm.stats.fmri_spec.sess(r).multi_reg = {rp_file};
                            matlabbatch{1}.spm.stats.fmri_spec.sess(r).hpf = 128;
                            matlabbatch{1}.spm.stats.fmri_spec.fact = struct('name', {}, 'levels', {});
                            matlabbatch{1}.spm.stats.fmri_spec.bases.hrf.derivs = [0 0];
                            matlabbatch{1}.spm.stats.fmri_spec.volt = 1;
                            matlabbatch{1}.spm.stats.fmri_spec.global = 'None';
                            matlabbatch{1}.spm.stats.fmri_spec.mthresh = 0.2;
                            matlabbatch{1}.spm.stats.fmri_spec.mask = {''};
                            matlabbatch{1}.spm.stats.fmri_spec.cvi = 'FAST'; %'AR(1)';
                            save(savefile,'matlabbatch');
                        end

                        %% Model estimation
                        matlabbatch{2}.spm.stats.fmri_est.spmmat(1) = cfg_dep('fMRI model specification: SPM.mat File', substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','spmmat'));
                        matlabbatch{2}.spm.stats.fmri_est.write_residuals = 0;
                        matlabbatch{2}.spm.stats.fmri_est.method.Classical = 1;

                        %% Contrast manager
                        % Using 'repl' allows for flexiblity betweeen subjects on the number of covariates for each session
                        % No need for tricky zero-padding schemes (plus, probably accounts for variance correctly.)
                        matlabbatch{3}.spm.stats.con.spmmat(1) = cfg_dep('Model estimation: SPM.mat File', substruct('.','val', '{}',{2}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','spmmat'));
                        matlabbatch{3}.spm.stats.con.consess{1}.tcon.name = 'increasing interaction';
                        matlabbatch{3}.spm.stats.con.consess{1}.tcon.weights = 1;
                        matlabbatch{3}.spm.stats.con.consess{1}.tcon.sessrep = 'repl';
                        matlabbatch{3}.spm.stats.con.consess{2}.tcon.name = 'decreasing interaction';
                        matlabbatch{3}.spm.stats.con.consess{2}.tcon.weights = -1;
                        matlabbatch{3}.spm.stats.con.consess{2}.tcon.sessrep = 'repl';
                        matlabbatch{3}.spm.stats.con.consess{3}.tcon.name = 'increased fc (in general)';
                        matlabbatch{3}.spm.stats.con.consess{3}.tcon.weights = [0 1];
                        matlabbatch{3}.spm.stats.con.consess{3}.tcon.sessrep = 'repl';
                        matlabbatch{3}.spm.stats.con.consess{4}.tcon.name = 'decreased fc (in general)';
                        matlabbatch{3}.spm.stats.con.consess{4}.tcon.weights = [0 -1];
                        matlabbatch{3}.spm.stats.con.consess{4}.tcon.sessrep = 'repl';
                        matlabbatch{3}.spm.stats.con.consess{5}.tcon.name = sprintf('High Cal activation w/ %s',voi);
                        matlabbatch{3}.spm.stats.con.consess{5}.tcon.weights = [0 0 1];
                        matlabbatch{3}.spm.stats.con.consess{5}.tcon.sessrep = 'repl';
                        matlabbatch{3}.spm.stats.con.consess{6}.tcon.name = sprintf('High Cal deactivation w/ %s',voi);
                        matlabbatch{3}.spm.stats.con.consess{6}.tcon.weights = [0 0 -1];
                        matlabbatch{3}.spm.stats.con.consess{6}.tcon.sessrep = 'repl';
                        matlabbatch{3}.spm.stats.con.delete = 0;

                        save(savefile,'matlabbatch');
                        spm_jobman('run',matlabbatch);
                    end
                end
            end
        end
    end
    end
end

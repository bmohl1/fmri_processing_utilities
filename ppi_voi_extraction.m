function ppi_voi_extraction(subjs,task,voi,reg_var)

%defaults
voi_name = 'nAcc';
reg_var = ('on');
maxima_type = ('global'); % Change this to supra or local
get_mtn_reg = 'yes'; %Can change and will enter the 6 regressors for the rp file along with PPI regressors
spcfc_rslts_dir = 'no';

tool_dir = fileparts(fileparts(which('ppi_voi_extraction')));
addpath([tool_dir filesep 'general_utilities']);

[spm_home, mni_home] = update_script_paths(tool_dir); %make sure that we're getting into SPM12b

%% Grab the files
switch exist ('subjs')
    case 1
        [cwd,pth_subjdirs] = file_selector(subjs);
        pth_subjdirs = unique(pth_subjdirs);
        for tt=1:length(pth_subjdirs)
            tmp = textscan(pth_subjdirs{tt},'%s','Delimiter','/');
            subjList{tt} = tmp{1,1}{end-1};
            pth_subjdirs{tt} = strcat(filesep,fullfile(tmp{1,1}{1:end-1})); %otherwise loops through the subject multiple times
        end

    otherwise
        [cwd,pth_subjdirs] = file_selector;
        for tt=1:length(pth_subjdirs)
            tmp = textscan(pth_subjdirs{tt},'%s','Delimiter','/');
            subjList{tt} = tmp{1,1}{end};
        end
end

pth_subjdirs = unique(pth_subjdirs);

%% Choose the mask
if ~exist('voi','var')
    disp('Please select the VOI');
    tempfile = cellstr(spm_select([1,Inf],'image','Select the VOI for this analysis','',pwd));
    tempfile = textscan(tempfile{1,1}, '%s', 'Delimiter',',');
    voi_file = tempfile{1,1}{1}; %Must have the ",1" removed for accurate handling elsewhere
    voi_dir = fileparts(voi_file);
end

switch exist('task','var')
    case 1
        task = {task};
        [pth_taskdirs, task] = file_selector_task(pth_subjdirs, task);
    otherwise
        [pth_taskdirs, task] = file_selector_task(pth_subjdirs);
end

projName = textscan(cwd,'%s','Delimiter','/');
projName = projName{1,1}{end};

%%
home_dir = cwd;
cd(home_dir)

switch nargin
    case 4
        reg_var = (reg_var); %overrides the default
    case 3
        voi_name = (voi);
    case 2
        display('Did not choose VOI. Using default.');
end



%% Start setting up the individual's script
for nSubj = 1:length(pth_subjdirs);
    subj_pth = pth_subjdirs{nSubj};
    check = textscan(subj_pth,'%s','Delimiter','/');

    if exist('subjList','var') && length(subjList) >= 1;
        subjs = char(subjList{nSubj});
    end

    ix = strfind(check{1,1},subjs); %locate where the subj is in the string
    if isempty(arrayfun(@(x) isempty(x),ix));
        ix = strfind(check{1,1},subjs(1:3)); %if the subj name isn't in the string, try to at least find the project
    end
    ix = ~cellfun('isempty',ix);
    ix = find(ix==1);
    ix = (max(ix)); %finds the last instance
    if sum(~isnan(ix)) > 1; %if there are multiple matches...
        proj_dir = fullfile(filesep,check{1,1}{1:ix-2});
        subj = check{1,1}{ix-1};
    else
        proj_dir = fullfile(filesep,check{1,1}{1:ix-1});
        subj = check{1,1}{ix};
    end


    if isempty(strfind(subj,subjs));
        [proj_dir subj ~] = fileparts(subj_pth(1,1:end));
    end
    subj_prefix = (subj(1:end-1)); %Need to back off one character to accomodate finding the T1

    cd(subj_pth)
    voi_output = strcat(voi_name,'_',maxima_type);

    if strcmp(spcfc_rslts_dir, 'yes')
        results_dir = [subj_pth,filesep,'results_art'];
    else
        results_dir = [subj_pth,filesep,'results'];  % When the option was to make an ART directory, there was an if/then to switch the results_art dir
    end
    check_spm  = dir(strcat(results_dir,filesep,'SPM.mat'));
    if isempty(check_spm.name)
        sprintf('Was the design matrix evaluated for %s?',subj)
        disp('Did not evalutate PPI')
    else
        spm_mat = {fullfile(results_dir,check_spm.name)};
        check_extract  = dir(strcat(results_dir,filesep,'PPI_',voi_output,'.mat'));

        %% Get the subj's CSF and WM masks
        %Figure out where the t1 directory is (b/c it isn't always in the same
        %timepoint
        if strcmp(reg_var, 'on')
            display('Gathering CSF and WM information')
            [subj_t1_dir, subj_t1_file, t1_ext] = locate_scan_file('t1', subj);%checks if there is a more recent T1
            if isempty(subj_t1_file); %won't override the global "reset" back to the first T1, if there has been an more recent one, but also supplies a scan, if none was defined.
                [subj_t1_dir, subj_t1_file, t1_ext] = locate_scan_file('t1',subj_prefix);
            end
            if isempty(subj_t1_file)
                try
                    [subj_t1_dir, subj_t1_file, t1_ext] = locate_scan_file('anat', subj);
                catch
                    disp ('Naming scheme for the T1 directory does not follow the convention of "t1" or "anat". Please rename.')
                end
            end

            regressors = {'wm' 'csf'};

            for j = (1:length(regressors))
                reg = regressors{j};
                check_voi = strcat(results_dir,filesep,'VOI_',reg,'_1.mat')
                if ~exist(check_voi,'file')
                    disp ('Extracting CSF and WM')
                    reg_out = strcat(reg, '_thresh');
                    if strcmp(reg,'csf')
                        reg_mask_file = {strcat(subj_t1_dir,filesep,'c3',subj_t1_file,',1')} %csf
                    else
                        reg_mask_file  = {strcat(subj_t1_dir,filesep,'c2',subj_t1_file,',1')} %wm
                    end
                    dependency = strcat('Image Calculator: Imcalc Computed Image:',reg_out);

                    clear matlabbatch
                    spm_jobman('initcfg');
                    matlabbatch{1}.spm.util.imcalc.input = reg_mask_file;
                    matlabbatch{1}.spm.util.imcalc.output = reg_out;
                    matlabbatch{1}.spm.util.imcalc.outdir = {results_dir};
                    matlabbatch{1}.spm.util.imcalc.expression = 'i1 > .99';
                    matlabbatch{1}.spm.util.imcalc.options.dmtx = 0;
                    matlabbatch{1}.spm.util.imcalc.options.mask = -1;
                    matlabbatch{1}.spm.util.imcalc.options.interp = 1;
                    matlabbatch{1}.spm.util.imcalc.options.dtype = 4;
                    matlabbatch{2}.spm.util.voi.spmmat = spm_mat;
                    matlabbatch{2}.spm.util.voi.adjust = 1;
                    matlabbatch{2}.spm.util.voi.session = 1;
                    matlabbatch{2}.spm.util.voi.name = reg; %regressor
                    matlabbatch{2}.spm.util.voi.roi{1}.mask.image(1) = cfg_dep;
                    matlabbatch{2}.spm.util.voi.roi{1}.mask.image(1).tname = 'Image file';
                    matlabbatch{2}.spm.util.voi.roi{1}.mask.image(1).tgt_spec{1}(1).name = 'filter';
                    matlabbatch{2}.spm.util.voi.roi{1}.mask.image(1).tgt_spec{1}(1).value = 'image';
                    matlabbatch{2}.spm.util.voi.roi{1}.mask.image(1).tgt_spec{1}(2).name = 'strtype';
                    matlabbatch{2}.spm.util.voi.roi{1}.mask.image(1).tgt_spec{1}(2).value = 'e';
                    matlabbatch{2}.spm.util.voi.roi{1}.mask.image(1).sname = dependency;
                    matlabbatch{2}.spm.util.voi.roi{1}.mask.image(1).src_exbranch = substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1});
                    matlabbatch{2}.spm.util.voi.roi{1}.mask.image(1).src_output = substruct('.','files');
                    matlabbatch{2}.spm.util.voi.roi{1}.mask.threshold = 0.99;
                    matlabbatch{2}.spm.util.voi.roi{2}.spm.spmmat = {''};
                    matlabbatch{2}.spm.util.voi.roi{2}.spm.contrast = 1;
                    matlabbatch{2}.spm.util.voi.roi{2}.spm.conjunction = 1;
                    matlabbatch{2}.spm.util.voi.roi{2}.spm.threshdesc = 'none';
                    matlabbatch{2}.spm.util.voi.roi{2}.spm.thresh = 0.5;
                    matlabbatch{2}.spm.util.voi.roi{2}.spm.extent = 0;
                    matlabbatch{2}.spm.util.voi.roi{2}.spm.mask = struct('contrast', {}, 'thresh', {}, 'mtype', {});
                    matlabbatch{2}.spm.util.voi.expression = 'i1.*i2';
                    savefile = [reg,'_voi_extract_',subj];
                    save(savefile,'matlabbatch');
                    spm_jobman('run',matlabbatch)
                end
                temp = load(check_voi);
                extra_regs{j} = [temp.Y];
            end
        end


        if ~isempty(check_extract)
            fprintf( '%s PPI ready \n',results_dir);
        end

        if ~isempty(check_spm) && isempty(check_extract)
            disp('Setting extraction variables.')
            %% Set variables
            if strcmp ('nAcc',voi_name)
                %Enter the x,y,z of the VOI

            else
                center = [];
                disp('I do not know where to start...')
                break
            end
            task_regressors = [1 1 1;2 1 -1];


            %% Fill in spm batches
            cd(strcat(inputdir,filesep,task_dir));
            clear matlabbatch;
            matlabbatch{1}.spm.util.voi.spmmat = spm_mat;
            matlabbatch{1}.spm.util.voi.adjust = 1;
            matlabbatch{1}.spm.util.voi.session = 1;
            matlabbatch{1}.spm.util.voi.name = voi_output;
            matlabbatch{1}.spm.util.voi.roi{1}.spm.spmmat = spm_mat;
            matlabbatch{1}.spm.util.voi.roi{1}.spm.contrast = 2;
            matlabbatch{1}.spm.util.voi.roi{1}.spm.conjunction = 1;
            matlabbatch{1}.spm.util.voi.roi{1}.spm.threshdesc = 'none';
            matlabbatch{1}.spm.util.voi.roi{1}.spm.thresh = 0.999; % Whole timeseries = .999
            matlabbatch{1}.spm.util.voi.roi{1}.spm.extent = 3;
            matlabbatch{1}.spm.util.voi.roi{1}.spm.mask = struct('contrast', {}, 'thresh', {}, 'mtype', {});
            % matlabbatch{1}.spm.util.voi.roi{3}.sphere.centre = center;
            % matlabbatch{1}.spm.util.voi.roi{3}.sphere.radius = 5;
            % matlabbatch{1}.spm.util.voi.roi{3}.sphere.move.global.spm = 1;
            % matlabbatch{1}.spm.util.voi.roi{3}.sphere.move.global.mask = 'i2';
            matlabbatch{1}.spm.util.voi.roi{2}.mask.image = {voi_file};
            matlabbatch{1}.spm.util.voi.roi{2}.mask.threshold = 0; % Closer to zero is inclusive. Closer to 1 runs a binary to run with voxels greater than 1.
            matlabbatch{1}.spm.util.voi.expression = 'i1&i2'; %Adding a mask makes sure that the VOI is in the putamen, but has been too restrictive


            if strcmp(voi_name, 'pigdPut')
                matlabbatch{1}.spm.util.voi.roi{2}.sphere.radius = 3;
                %matlabbatch{1}.spm.util.voi.roi{1}.spm.thresh = 0.2; %overwrites the threshold value to be more inclusive
                %matlabbatch{1}.spm.util.voi.roi{3}.mask.image = {voi_file};
                %matlabbatch{1}.spm.util.voi.roi{3}.mask.threshold = .2; % Closer to zero is inclusive. Closer to 1 runs a binary to run with voxels greater than 1...
                %matlabbatch{1}.spm.util.voi.expression = 'i1&i2&i3'; %Adding a mask makes sure that the VOI is in the putamen, but has been too restrictive
                %elseif strcmp(voi_name, 'lpPut')
                %    matlabbatch{1}.spm.util.voi.roi{3}.sphere.radius = 10;
                %    display('Radius 10mm')
            end

            savefile = [voi_name,'_voi_extract_',subj];
            save(savefile,'matlabbatch');
            spm_jobman('run',matlabbatch)

            new_voi_file = strcat(results_dir,filesep,'VOI_',voi_output,'_1.mat');
            check_voi = dir(new_voi_file);
            if ~isempty(check_voi)
                clear matlabbatch

                matlabbatch{1}.spm.stats.ppi.spmmat = spm_mat;
                matlabbatch{1}.spm.stats.ppi.type.ppi.voi = {new_voi_file};
                matlabbatch{1}.spm.stats.ppi.type.ppi.u = task_regressors;
                matlabbatch{1}.spm.stats.ppi.name = voi_output;
                matlabbatch{1}.spm.stats.ppi.disp = 1;

                if strcmp(reg_var, 'off')
                    savefile = [voi_name,'_ppi_build_',subj];
                else
                    savefile = [voi_name,'_ppi_build_',subj,'_regs'];
                end

                save(savefile,'matlabbatch');
                spm_jobman('run',matlabbatch)
            else
                fprintf('Timeseries could not be extracted from %s for %s\n', voi_name, subj)
                err_file = strcat(home_dir,filesep,'error_',voi_name,'_extraction')
                fid = fopen(err_file,'a');
                fprintf(fid,'Missing %s timeseries for %s\n',voi_name,subj);
                fclose(fid);
            end
        end

        ppi_name      = strcat('ppi_',voi_name);
        if strcmp (reg_var, 'off')
            ppi_name      = strcat('ppi_',voi_name,'_',maxima_type);
        elseif strcmp (spcfc_rslts_dir, 'yes')
            ppi_name      = strcat('ppi_',voi_name,'_art_',maxima_type,'_regs');
        else
            ppi_name      = strcat('ppi_',voi_name,'_',maxima_type,'_regs');
        end
        ppi_con_dir   = fullfile(home_dir,subj,task,ppi_name);
        check_ppi_con = dir(strcat(ppi_con_dir,filesep,'con_0001.img')); %the con image ensures that the SPM was estimated.
        check_extract     = dir(strcat(results_dir,filesep,'PPI_',voi_output,'.mat'));

        if isempty(check_ppi_con) && ~isempty(check_extract)
            disp('Loading PPI estimation variables')
            ppi_spm = (strcat(ppi_con_dir,filesep,'SPM.mat'));
            if exist (ppi_spm, 'file')
                delete (ppi_spm); % Automates it, so you don't get the dialog box
            end

            %% Get the ppi regressors
            ppi_reg = fullfile(results_dir,check_extract.name);
            load(ppi_reg);
            reg1 = PPI.ppi;
            reg2 = PPI.Y;
            reg3 = PPI.P;

            %% Get the motion regressors
            if strcmp (spcfc_rslts_dir, 'yes')
                find_rp_file = dir(strcat(inputdir,filesep,task_dir,filesep,'raw',filesep,'trimmed*'));
            else
                find_rp_file = dir(strcat(inputdir,filesep,task_dir,filesep,'raw',filesep,'rp_*'));
            end

            rp_file = [strcat(inputdir,filesep,task_dir,filesep,'raw',filesep,find_rp_file.name)];
            [filepath rp_reg] = fileparts(rp_file);

            if strcmp(get_mtn_reg, 'yes')
                rp_reg = load(rp_file);
                if strcmp(reg_var,'on')
                    grand_reg = [PPI.ppi PPI.Y PPI.P rp_reg extra_regs{1:2}];
                else
                    disp('NO PHYSIO REGRESSORS')
                    grand_reg = [PPI.ppi PPI.Y PPI.P rp_reg];
                end
                grand_reg_file = [strcat(filepath,filesep,voi_name,'_grand_regressor_mtnregs.txt')];
                save(grand_reg_file,'grand_reg','-ascii');
            elseif strcmp(reg_var,'on') && strcmp(get_mtn_reg, 'no')
                grand_reg = [reg1 reg2 reg3 extra_regs{1:2}]; % wm and csf
                grand_reg_file = [strcat(filepath,filesep,voi_name,'_grand_regressor_regs.txt')];
                save(grand_reg_file,'grand_reg','-ascii');
            else
                grand_reg = [reg1 reg2 reg3];
                grand_reg_file = [strcat(filepath,filesep,voi_name,'_grand_regressor.txt')];
                save(grand_reg_file,'grand_reg','-ascii');
            end


            %% Setup the directory structure
            if ~isdir(ppi_con_dir)
                mkdir(ppi_con_dir);
            end

            raw_dir = strcat(inputdir,filesep,task,filesep,'raw');
            scan_files = dir(strcat(raw_dir,filesep,'swa',subj,'*.nii'));
            grand_reg_file = cellstr(grand_reg_file);

            if isempty(scan_files)
                fprintf ('Could not find files for: %s \n', subj)
            end

            if ~isempty(scan_files)
                fprintf('Finding files: %s\n',subj)
                scan_name = {};
                trs=length(spm_vol(scan_files.name));
                for x = 1:trs;
                    if 2 > length(scan_files)
                        scan_name{x} = [strcat(raw_dir,filesep,scan_files.name,',',int2str(x))]; %must be square brackets, so there are no quotes in the cell
                    else
                        scan_name{x} = [raw_dir,filesep,scan_files(x).name,',1']; % accomodates the 3D nii's
                    end
                end
                scan_names = [scan_name]';
                scan_set = [];
                scan_set{1,1}= scan_names;
                brainmask = {strcat(spm_home,filesep,'apriori',filesep,'brainmask.nii,1')};


                clear matlabbatch
                spm_jobman('initcfg');
                matlabbatch{1}.spm.stats.fmri_spec.dir = {ppi_con_dir};
                matlabbatch{1}.spm.stats.fmri_spec.timing.units = 'secs';
                matlabbatch{1}.spm.stats.fmri_spec.timing.RT = 2;
                matlabbatch{1}.spm.stats.fmri_spec.timing.fmri_t = 16;
                matlabbatch{1}.spm.stats.fmri_spec.timing.fmri_t0 = 1;
                matlabbatch{1}.spm.stats.fmri_spec.sess.scans = scan_names;
                matlabbatch{1}.spm.stats.fmri_spec.mask = brainmask;
                matlabbatch{1}.spm.stats.fmri_spec.sess.cond = struct('name', {}, 'onset', {}, 'duration', {}, 'tmod', {}, 'pmod', {});
                matlabbatch{1}.spm.stats.fmri_spec.sess.multi = {''};
                matlabbatch{1}.spm.stats.fmri_spec.sess.regress = struct('name', {}, 'val', {});
                matlabbatch{1}.spm.stats.fmri_spec.sess.multi_reg = grand_reg_file;
                matlabbatch{1}.spm.stats.fmri_spec.sess.hpf = 128;
                matlabbatch{1}.spm.stats.fmri_spec.fact = struct('name', {}, 'levels', {});
                matlabbatch{1}.spm.stats.fmri_spec.bases.hrf.derivs = [0 0];
                matlabbatch{1}.spm.stats.fmri_spec.volt = 1;
                matlabbatch{1}.spm.stats.fmri_spec.global = 'None';
                matlabbatch{1}.spm.stats.fmri_spec.mask = brainmask;
                matlabbatch{1}.spm.stats.fmri_spec.cvi = 'AR(1)';

                if strcmp(reg_var, 'off')
                    savefile = [voi_name,'_ppi_est_',subj];
                elseif strcmp (spcfc_rslts_dir, 'yes')
                    savefile = [voi_name,'_ppi_estArt_',subj,'_regs'];
                else
                    savefile = [voi_name,'_ppi_est_',subj,'_regs'];
                end

                save(savefile,'matlabbatch');

                matlabbatch{2}.spm.stats.fmri_est.spmmat(1) = cfg_dep;
                matlabbatch{2}.spm.stats.fmri_est.spmmat(1).tname = 'Select SPM.mat';
                matlabbatch{2}.spm.stats.fmri_est.spmmat(1).tgt_spec{1}(1).name = 'filter';
                matlabbatch{2}.spm.stats.fmri_est.spmmat(1).tgt_spec{1}(1).value = 'mat';
                matlabbatch{2}.spm.stats.fmri_est.spmmat(1).tgt_spec{1}(2).name = 'strtype';
                matlabbatch{2}.spm.stats.fmri_est.spmmat(1).tgt_spec{1}(2).value = 'e';
                matlabbatch{2}.spm.stats.fmri_est.spmmat(1).sname = 'fMRI model specification: SPM.mat File';
                matlabbatch{2}.spm.stats.fmri_est.spmmat(1).src_exbranch = substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1});
                matlabbatch{2}.spm.stats.fmri_est.spmmat(1).src_output = substruct('.','spmmat');
                matlabbatch{2}.spm.stats.fmri_est.method.Classical = 1;

                save(savefile,'matlabbatch');

                matlabbatch{3}.spm.stats.con.spmmat(1) = cfg_dep;
                matlabbatch{3}.spm.stats.con.spmmat(1).tname = 'Select SPM.mat';
                matlabbatch{3}.spm.stats.con.spmmat(1).tgt_spec{1}(1).name = 'filter';
                matlabbatch{3}.spm.stats.con.spmmat(1).tgt_spec{1}(1).value = 'mat';
                matlabbatch{3}.spm.stats.con.spmmat(1).tgt_spec{1}(2).name = 'strtype';
                matlabbatch{3}.spm.stats.con.spmmat(1).tgt_spec{1}(2).value = 'e';
                matlabbatch{3}.spm.stats.con.spmmat(1).sname = 'Model estimation: SPM.mat File';
                matlabbatch{3}.spm.stats.con.spmmat(1).src_exbranch = substruct('.','val', '{}',{2}, '.','val', '{}',{1}, '.','val', '{}',{1});
                matlabbatch{3}.spm.stats.con.spmmat(1).src_output = substruct('.','spmmat');
                matlabbatch{3}.spm.stats.con.consess{1}.tcon.name = 'Increasing - interaction';
                matlabbatch{3}.spm.stats.con.consess{1}.tcon.convec = 1;
                matlabbatch{3}.spm.stats.con.consess{1}.tcon.sessrep = 'none';
                matlabbatch{3}.spm.stats.con.consess{2}.tcon.name = 'Decreasing - interaction';
                matlabbatch{3}.spm.stats.con.consess{2}.tcon.convec = -1;
                matlabbatch{3}.spm.stats.con.consess{2}.tcon.sessrep = 'none';
                matlabbatch{3}.spm.stats.con.consess{3}.tcon.name = 'Increased general fc';
                matlabbatch{3}.spm.stats.con.consess{3}.tcon.convec = [0 1];
                matlabbatch{3}.spm.stats.con.consess{3}.tcon.sessrep = 'none';
                matlabbatch{3}.spm.stats.con.consess{4}.tcon.name = 'Decreased general fc';
                matlabbatch{3}.spm.stats.con.consess{4}.tcon.convec = [0 -1];
                matlabbatch{3}.spm.stats.con.consess{4}.tcon.sessrep = 'none';
                matlabbatch{3}.spm.stats.con.consess{5}.tcon.name = 'tapping > rest';
                matlabbatch{3}.spm.stats.con.consess{5}.tcon.convec = [0 0 1];
                matlabbatch{3}.spm.stats.con.consess{5}.tcon.sessrep = 'none';
                matlabbatch{3}.spm.stats.con.consess{6}.tcon.name = 'tapping < rest';
                matlabbatch{3}.spm.stats.con.consess{6}.tcon.convec = [0 0 -1];
                matlabbatch{3}.spm.stats.con.consess{6}.tcon.sessrep = 'none';
                matlabbatch{3}.spm.stats.con.delete = 0;

                save(savefile,'matlabbatch');
                spm_jobman('run',matlabbatch);

            end

        end
    end
end

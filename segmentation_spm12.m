function [subjs] = segmentation_spm12(subjs, subj_redo_segment, child_temp)
% Purpose: Run the DARTEL-based new segmentation from SPM.  The forward
% deformations are saved so that the co-registered EPIs can be transformed
% into standard space with relative few issues
%
% Future part of modular preprocessing pipeline
% Author: Brianne Mohl,PhD
% Date: March 2016

%%

global special_templates subj_t1_dir subj_t1_file ignore_preproc;
spm_home=fileparts(which('spm'));
template_home = [spm_home, filesep, 'tpm'];

%% Grab the files
switch exist ('subjs')
    case 1
        [cwd,pth_subjdirs] = file_selector(subjs);
    otherwise
        [cwd,pth_subjdirs] = file_selector;
        for tt=1:length(pth_subjdirs)
            tmp = textscan(pth_subjdirs{tt},'%s','Delimiter','/');
            subjList{tt} = tmp{1,1}{end};
        end
end

switch exist ('child_temp','var')
    case 1
        special_templates = child_temp;
    otherwise
        if isempty(special_templates)
            prompt = 'Use child templates?';
            title = 'Templates';
            x = questdlg(prompt, title ,'Yes', 'No', 'No'); %order of arguments matters
            if strncmpi(x,'y',1)
                special_templates = 1;
            else
                special_templates = 0;
            end
        end
end
cd (cwd);
%Set defaults
if ~exist('subj_redo_segment','var')
    subj_redo_segment = 0;
end

if isempty(ignore_preproc)
    ignore_preproc = 0;
end

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
    
    %% T1 Coregistration
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
    
    
    
    cd (subj_t1_dir)
    
    brain_img = rdir([subj_t1_dir,filesep,'*brain*']);
    check_never_processed = (isempty(arrayfun(@(x) isempty(x.name),brain_img)) && exist ('subj_t1_file'));
    if eq(check_never_processed, 1) || eq(subj_redo_segment,1)
        if strfind(subj_t1_dir, subj);
            fprintf('Subroutine: Running segmentation_spm12 on %s \n', subj)
            c1_img = dir(char(glob(strcat(subj_t1_dir, filesep, 'c1*', subj_t1_file))));
            if isempty(arrayfun(@(y) isempty(y.name), c1_img)) || eq(subj_redo_segment,1);
                %%
                clear matlabbatch
                spm_jobman('initcfg');
                t1_raw_input = []; %Don't know why, but batch req's cell with the file name (t1_name) as one of potentially many cells. Follow this template to get the array/cell structure correct.bmm
                t1_name = [strcat(subj_t1_dir, filesep, subj_t1_file, ',1')];
                t1_raw_input{1,1} = t1_name;
                
                templates = {};
                if eq (special_templates,1)
                    global template_file                  
                    for i = 1:6;
                        %templates{1,i} = {strcat(template_home,filesep,'genR_Template_',int2str(i),'_IXI550_MNI152.nii')};
                        templates{1,i} = {strcat(char(template_file),',',int2str(i))};
                    end
                else
                    for i = 1:6;
                        templates{1,i} = {strcat(template_home,filesep,'TPM.nii,',int2str(i))};
                    end
                end
                %insert the matlabbatch variables for the new segment
                matlabbatch{1}.spm.spatial.preproc.channel.vols = t1_raw_input;
                matlabbatch{1}.spm.spatial.preproc.channel.biasreg = 0.0001;
                matlabbatch{1}.spm.spatial.preproc.channel.biasfwhm = 60;
                matlabbatch{1}.spm.spatial.preproc.channel.write = [1 1];
                matlabbatch{1}.spm.spatial.preproc.tissue(1).tpm = templates{1,1};
                matlabbatch{1}.spm.spatial.preproc.tissue(1).ngaus = 2;
                matlabbatch{1}.spm.spatial.preproc.tissue(1).native = [1 0];
                matlabbatch{1}.spm.spatial.preproc.tissue(1).warped = [0 1];
                matlabbatch{1}.spm.spatial.preproc.tissue(2).tpm = templates{1,2};
                matlabbatch{1}.spm.spatial.preproc.tissue(2).ngaus = 2;
                matlabbatch{1}.spm.spatial.preproc.tissue(2).native = [1 0];
                matlabbatch{1}.spm.spatial.preproc.tissue(2).warped = [0 1];
                matlabbatch{1}.spm.spatial.preproc.tissue(3).tpm = templates{1,3};
                matlabbatch{1}.spm.spatial.preproc.tissue(3).ngaus = 2;
                matlabbatch{1}.spm.spatial.preproc.tissue(3).native = [1 0];
                matlabbatch{1}.spm.spatial.preproc.tissue(3).warped = [0 1];
                matlabbatch{1}.spm.spatial.preproc.tissue(4).tpm = templates{1,4};
                matlabbatch{1}.spm.spatial.preproc.tissue(4).ngaus = 3;
                matlabbatch{1}.spm.spatial.preproc.tissue(4).native = [1 0];
                matlabbatch{1}.spm.spatial.preproc.tissue(4).warped = [0 1];
                matlabbatch{1}.spm.spatial.preproc.tissue(5).tpm = templates{1,5};
                matlabbatch{1}.spm.spatial.preproc.tissue(5).ngaus = 4;
                matlabbatch{1}.spm.spatial.preproc.tissue(5).native = [1 0];
                matlabbatch{1}.spm.spatial.preproc.tissue(5).warped = [0 1];
                matlabbatch{1}.spm.spatial.preproc.tissue(6).tpm = templates{1,6};
                matlabbatch{1}.spm.spatial.preproc.tissue(6).ngaus = 2;
                matlabbatch{1}.spm.spatial.preproc.tissue(6).native = [0 0];
                matlabbatch{1}.spm.spatial.preproc.tissue(6).warped = [0 1];
                matlabbatch{1}.spm.spatial.preproc.warp.mrf = 1;
                matlabbatch{1}.spm.spatial.preproc.warp.cleanup = 1;
                matlabbatch{1}.spm.spatial.preproc.warp.reg = [0 0.001 0.5 0.05 0.2];
                matlabbatch{1}.spm.spatial.preproc.warp.affreg = 'mni';
                matlabbatch{1}.spm.spatial.preproc.warp.fwhm = 0;
                matlabbatch{1}.spm.spatial.preproc.warp.samp = 3;
                matlabbatch{1}.spm.spatial.preproc.warp.write = [1 1];
                
                
                savefile = strcat(subj_t1_dir,filesep,'segmentation_',subj);
                save(savefile,'matlabbatch');
                % run batch
                spm_jobman('run',matlabbatch)
                disp('Completed Segmentation')
            else
                disp('Segmentation already done. Moving along.')
            end
            
            disp('Creating skull-stripped image')
            
            brainName = [subj,'_brain.nii'];
            clear matlabbatch;
            spm_jobman('initcfg');
            
            matlabbatch{1}.spm.util.imcalc.input = {
                strcat(subj_t1_dir,filesep,subj_t1_file,',1')
                strcat(subj_t1_dir,filesep,'c1',subj_t1_file,',1')
                strcat(subj_t1_dir,filesep,'c2',subj_t1_file,',1')
                strcat(subj_t1_dir,filesep,'c3',subj_t1_file,',1')
                };
            matlabbatch{1}.spm.util.imcalc.output = brainName;
            matlabbatch{1}.spm.util.imcalc.outdir = {subj_t1_dir};
            matlabbatch{1}.spm.util.imcalc.expression = 'i1.*((i2+i3+i4)>.1)';
            matlabbatch{1}.spm.util.imcalc.var = struct('name', {}, 'value', {});
            matlabbatch{1}.spm.util.imcalc.options.dmtx = 0;
            matlabbatch{1}.spm.util.imcalc.options.mask = 0;
            matlabbatch{1}.spm.util.imcalc.options.interp = 1;
            matlabbatch{1}.spm.util.imcalc.options.dtype = 4;
            savefile = strcat(subj_t1_dir,filesep,'skullstrip_',subj);
            save(savefile,'matlabbatch');
            spm_jobman('run',matlabbatch)
        else
            fprintf('***%s does not match %s***\n Please ensure there is a structural scan and re-run\n',subj_t1_dir, subj);
        end
    end
end

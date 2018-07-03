function  fmri_stc (scan_files, discard_dummies)
% Purpose: Subroutine of preproc_fmri that handles any request for slice-timing correction
display('Start STC')
scan_name = {};
clear matlabbatch
spm_jobman('initcfg');
raw_dir = pwd;
cd ..
subj_dir = pwd;
cd (raw_dir);

trs = length(scan_files); %if the nii's are split out, this will pick up the number of volumes
if trs < 2;
    trs = length(spm_vol(scan_files{1,1})); % if the nii's are self-contained (as with dcm2nii), this option will enumerate.
    scan_files = char(scan_files{1,1});
    %% Define volumes to process
    if eq(discard_dummies, 1)
        for x = 5:(trs);
            scan_name{x} = strcat(scan_files,',',int2str(x)); %must be square brackets, so there are no quotes in the cell
            %scan_files.name must be called as scan_files(x), if the 4D nii
            %has been split
        end
        scan_names = scan_name(5:end);
    else
        for x = 1:(trs);
            scan_names{x} = strcat(scan_files,',',int2str(x)); %must be square brackets, so there are no quotes in the cell
            %scan_files.name must be called as scan_files(x), if the 4D nii
            %has been split
        end
    end
else
    if eq(discard_dummies, 1)

        scan_names = scan_files(5:end)'; %must be square brackets, so there are no quotes in the cell
        %scan_files.name must be called as scan_files(x), if the 4D nii
        %has been split
    else
        scan_names = scan_files';
    end
end
fprintf('Detected %u volumes in:\n %s\n.',trs,raw_dir);
scan_set{1,1} = scan_names;
tmp=spm_vol_nifti(scan_names{1,1});
slices = tmp.dim(1,3);
%% Initialize batch
clear matlabbatch
spm_jobman('initcfg');
% fill in fields of structure matlabbatch
matlabbatch{1}.spm.temporal.st.scans = scan_set;
% number of slices
matlabbatch{1}.spm.temporal.st.nslices = slices;
% TR in seconds
matlabbatch{1}.spm.temporal.st.tr = 2;
% TE = TR - (TR/nslices)
tr = matlabbatch{1}.spm.temporal.st.tr;
nslices = matlabbatch{1}.spm.temporal.st.nslices;
matlabbatch{1}.spm.temporal.st.ta = tr - (tr/nslices);

% slice order very important. depends on EPI sequence used
% here it's interleaved
% Berman's instructions say 31 - bmm
if exist ('scanner') %backwards compatability for any remaining GE scans. will require adding another variable
    matlabbatch{1}.spm.temporal.st.so = [1:2:slices 2:2:slices];
    % reference slice
    matlabbatch{1}.spm.temporal.st.refslice = 31;
else
    matlabbatch{1}.spm.temporal.st.so = [2:2:slices 1:2:slices]; %interleaved, starting with slice 2. siemens standard
    matlabbatch{1}.spm.temporal.st.refslice = slices;
end
savefile = [subj_dir,filesep,'stc_batch.mat'];
save(savefile, 'matlabbatch');
spm_jobman('run',matlabbatch);
end

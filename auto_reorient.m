function auto_reorient(inputScan, scan_type)
set_spm('8');
spmDir=which('spm');
spmDir=spmDir(1:end-5);
%scan_type = 'fmri';
if exist('scan_type')
    template=[spmDir 'canonical/EPI.nii'];
else
    template=[spmDir 'canonical/single_subj_T1.nii'];
end

standardTemplate=spm_vol(template);
flags.regtype='rigid';
if ~exist('inputScan','var')
    input=spm_select(inf,'image');
    input = cellstr(input);
else
    input = cellstr(inputScan);
end

for j = 1:length(input)
    scanFile = input{j};
[subjDir subj] = fileparts(scanFile);
touchFile = [subjDir, filesep, 'touch_acpc.txt'];
if ~exist (touchFile, 'file')
    cd (subjDir)
    fprintf('Working on: %s\n',subj);
    for i=1:size(scanFile,1)
        trimmedScan=strtrim(scanFile(i,:));
        spm_smooth(trimmedScan,'temp.nii',[12 12 12]);
        vtrimmedScan=spm_vol('temp.nii');
        [M,scal] = spm_affreg(standardTemplate,vtrimmedScan(1),flags); %BMM added vtrimmedScan(1), because was loading with duplicates of the image.
        M3=M(1:3,1:3);
        [u s v]=svd(M3);
        M3=u*v';
        M(1:3,1:3)=M3;
        N=nifti(trimmedScan);
        N.mat=M*N.mat;
        fprintf('Creating shifted matrix:%s\n', subj);
        create(N);
    end
        delete('temp.nii');
        fclose(fopen('touch_acpc.txt', 'w'));
else
    fprintf('%s was aligned\n', subj);
end
end


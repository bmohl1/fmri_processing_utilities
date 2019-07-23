function [regressors] = extract_voi_ts(imgs,roi_files)

% Extract physiologic regressors for fMRI analysis. Currently, the script
% is set to run white matter and csf eroded masks, but the input should be
% modified to allow for flexible regressor naming.
%
% Summer 2019
% Brianne Sutton, PhD

imgs = char(imgs);

if ~exist ('roi_files','var')
    csf_file = fullfile(which('ecsf_45.nii'));
    wm_file  = fullfile(which('ewhite_45.nii'));
    roi_files = char(wm_file, csf_file);
elseif ~iscell(roi_files)
    display('Formatting array')
    [n_rows,~] = size(roi_files);
    rowDist = ones(n_rows,1);
    roi_files = char(mat2cell(roi_files,rowDist));
end
templates = 'yes';
[out_dir,~,~]=fileparts(imgs);

if ~isempty(which('rex'))
    fields = {
        'sources', imgs,...
        'rois',roi_files,...
        'summary_measure','mean',...        % [{'mean'},'eigenvariate','weighted mean','median','sum','weighted sum','count','max',min']
        'output_type','save',...                % ['none','save','saverex']
        'level','rois',...                  % ['rois','clusters','peaks','voxels']
        'dims',1,...                        % (for eigenvariate measure: number of dimensions to extract)
        'mindist',20,...                    %
        'maxpeak',32,...                    %
        'roi_threshold',0,...               %
        'disregard_zeros',1,...             %
        'output_files',{'data.txt'},...
        'output_folder',char(out_dir)};
     params=[]; for n1=1:2:length(fields), if ~isfield(params,fields{n1}), params=setfield(params,fields{n1},fields{n1+1}); end; end %from REX
disp('Starting extraction')
     regressors=rex(params); 
end

function [regressors] = extract_voi_ts(smImg, vois)

%Specifically as a single-subject script that can be wrapped, this script
%extracts physiological regressors for PPI or ICA

if exist ('vois')
    regressors = {vois};
else
    regressors = {'wm' 'csf'};
    csf_file = fullfile(which('ecsf_45.nii'));
    wm_file  = fullfile(which('ewhite_45.nii'));
    roi_files = char(csf_file, wm_file);
end
templates = 'yes';


if ~isempty(which('rex'))
    fields = {
        'sources',smImg,...
        'rois',roi_files,...
        'summary_measure','mean',...        % [{'mean'},'eigenvariate','weighted mean','median','sum','weighted sum','count','max',min']
        'output_type','save',...                % ['none','save','saverex']
        'level','rois',...                  % ['rois','clusters','peaks','voxels']
        'dims',1,...                        % (for eigenvariate measure: number of dimensions to extract)
        'mindist',20,...                    %
        'maxpeak',32,...                    %
        'roi_threshold',0,...               %
        'disregard_zeros',1,...             %
        'output_files',{'data.txt'}};
     params=[]; for n1=1:2:length(fields), if ~isfield(params,fields{n1}), params=setfield(params,fields{n1},fields{n1+1}); end; end %from REX
disp('Starting extraction')
     varargout{1}=rex(params);

end
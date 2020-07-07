settings.dummies = 0;
switch exist ('subjs')
    case 1
        [cwd,pth_subjdirs] = file_selector(subjs);
    otherwise
        [cwd,pth_subjdirs] = file_selector; %GUI to choose the main study directory
end

switch exist ('taskArray')
    case 1
        [pth_taskdirs, taskArray] = file_selector_task(pth_subjdirs, taskArray);
    otherwise
        [pth_taskdirs, taskArray] = file_selector_task(pth_subjdirs);
end

for s = 1:length(pth_subjdirs)
    fprintf('%s, number %d of %d\n',string(pth_subjdirs{s}),s,length(pth_subjdirs));
    for t = 1:length(taskArray)
        check = glob(fullfile(pth_subjdirs{s},taskArray{t},'rp_*txt'));
        if isempty(check)
            all_proc_files = glob(fullfile(pth_subjdirs{s},taskArray{t},'ex*nii'));  % TODO need to make this flexible. Currently, must change for each study.
            trs = length(all_proc_files); %If no STC, this will have 4 extra volumes
            selected_proc_files = {};

            if trs == 0
                disp('Hmmm... not finding the necessary files. Check search criteria in preproc_fmri')
            elseif trs < 2; %need to split out nii file with ",number_of_volume"
                trs = length(spm_vol(all_proc_files{1,1})); % accommodates the conventional naming, even though the first four volumes are empty
                all_proc_files = char(all_proc_files{1,1});
                if eq(settings.dummies,1)
                    for x = 5:(trs);
                        selected_proc_files{x} = [strcat(all_proc_files,',',int2str(x))]; %must be square brackets, so there are no quotes in the cell
                    end
                    selected_proc_files = selected_proc_files(5:end); %discards the first four scans
                else
                    for x = 1:(trs);
                        selected_proc_files{x} = [strcat(all_proc_files,',',int2str(x))]; %must be square brackets, so there are no quotes in the cell
                    end
                end
            else %individual files for the volumes exist and need to be loaded sequentially
                selected_proc_files = {all_proc_files{:}};
            end

            if isempty(selected_proc_files)
                fprintf('Not locating files for %s\nfmri_realign2smooth (line 48):\n ',all_proc_files);
                return
            end

            scan_set = [];
            scan_set{1,1} = selected_proc_files'; % the column cellstr is necessary for SPM12 (SPM12b uses the non-transposed, row cellstr version)
            cd(pth_subjdirs{s});

            clear matlabbatch
            display('Please wait.');
            spm_jobman('initcfg');

            matlabbatch{1}.spm.spatial.realign.estimate.data = scan_set;
            spm_jobman('run', matlabbatch);
        end
    end
end

#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Fri Aug  9 10:45:13 2019
@author: brianne
"""
# Create paradigm object
# contrast type
# statistic
# groups
# files
# io directories
# just load in experimental paradigm contrasts csv. ['comparison type','contrast name','statistic','conditions','matrix']

# Two sample
   if strcmp(comp_type, 'one_sample')
      matlabbatch{1}.spm.stats.factorial_design.des.t1.scans = groupA_set{1}
        matlabbatch{3}.spm.stats.con.spmmat(1) = cfg_dep('Model estimation: SPM.mat File', substruct('.', 'val', '{}', {2}, '.', 'val', '{}', {1}, '.', 'val', '{}', {1}), substruct('.', 'spmmat'));
        matlabbatch{3}.spm.stats.con.consess{1}.tcon.name = [groupA_name ' activation increases']
        matlabbatch{3}.spm.stats.con.consess{1}.tcon.weights = [1]
        matlabbatch{3}.spm.stats.con.consess{2}.tcon.name = [groupA_name ' activation decreases']
        matlabbatch{3}.spm.stats.con.consess{2}.tcon.weights = [-1]
    elseif strcmp(comp_type, 'two_sample')
      matlabbatch{1}.spm.stats.factorial_design.des.t2.scans1 = groupA_set{1}
       matlabbatch{1}.spm.stats.factorial_design.des.t2.scans2 = groupB_set{1}
        matlabbatch{3}.spm.stats.con.spmmat(1) = cfg_dep('Model estimation: SPM.mat File', substruct('.', 'val', '{}', {2}, '.', 'val', '{}',{1}, '.','val', '{}',{1}), substruct('.','spmmat'));
        matlabbatch{3}.spm.stats.con.consess{1}.tcon.name = [groupA_name ' > ' groupB_name]
        matlabbatch{3}.spm.stats.con.consess{1}.tcon.weights = [1 - 1]
        matlabbatch{3}.spm.stats.con.consess{2}.tcon.name = [groupA_name ' < ' groupB_name]
        matlabbatch{3}.spm.stats.con.consess{2}.tcon.weights = [-1 1]
        # Full factorial
    elseif strcmp(comp_type, 'full_factorial')
     # Design conditions
      matlabbatch{1}.spm.stats.factorial_design.des.fd.fact(1).name = factor1
       matlabbatch{1}.spm.stats.factorial_design.des.fd.fact(1).dept = 1  # one for dependent
        matlabbatch{1}.spm.stats.factorial_design.des.fd.fact(1).levels = 2
        matlabbatch{1}.spm.stats.factorial_design.des.fd.fact(2).name = 'experimental manipulation'
        matlabbatch{1}.spm.stats.factorial_design.des.fd.fact(2).levels = 2
        matlabbatch{1}.spm.stats.factorial_design.des.fd.fact(2).dept = 0
        matlabbatch{1}.spm.stats.factorial_design.des.fd.icell(1).levels = [1 1]
        matlabbatch{1}.spm.stats.factorial_design.des.fd.icell(1).scans = groupA_set{1}
        matlabbatch{1}.spm.stats.factorial_design.des.fd.icell(2).levels = [1 2]
        matlabbatch{1}.spm.stats.factorial_design.des.fd.icell(2).scans = groupB_set{1}
        matlabbatch{1}.spm.stats.factorial_design.des.fd.icell(3).levels = [2 1]
        matlabbatch{1}.spm.stats.factorial_design.des.fd.icell(3).scans = groupC_set{1}
        matlabbatch{1}.spm.stats.factorial_design.des.fd.icell(4).levels = [2 2]
        matlabbatch{1}.spm.stats.factorial_design.des.fd.icell(4).scans = groupD_set{1}
        matlabbatch{3}.spm.stats.con.spmmat(1) = cfg_dep('Model estimation: SPM.mat File', substruct('.', 'val', '{}', {2}, '.', 'val', '{}',{1}, '.','val', '{}',{1}), substruct('.','spmmat'));
        matlabbatch{3}.spm.stats.con.consess{1}.tcon.name = [contrasts{j}, ': ', groupA_name, ' dec. rel. to ',  groupB_name, ' vs. ', groupC_name, ' to ', groupD_name]
        matlabbatch{3}.spm.stats.con.consess{1}.tcon.weights = [1 - 1 - 1 1]
        matlabbatch{3}.spm.stats.con.consess{2}.tcon.name = [contrasts{j}, ': ', groupA_name, ' inc. rel. to ',  groupB_name, ' vs. ', groupC_name, ' to ', groupD_name]
        matlabbatch{3}.spm.stats.con.consess{2}.tcon.weights = [-1 1 1 - 1]
        matlabbatch{3}.spm.stats.con.consess{3}.tcon.name = [contrasts{j}, ': ', groupA_name, ' > ', groupC_name]
        matlabbatch{3}.spm.stats.con.consess{3}.tcon.weights = [1 0 - 1]
        matlabbatch{3}.spm.stats.con.consess{4}.tcon.name = [contrasts{j}, ': ', groupB_name, ' > ', groupD_name]
        matlabbatch{3}.spm.stats.con.consess{4}.tcon.weights = [0 1 0 - 1]
        matlabbatch{3}.spm.stats.con.consess{5}.tcon.name = [contrasts{j}, ': ', groupA_name, ' < ', groupC_name]
        matlabbatch{3}.spm.stats.con.consess{5}.tcon.weights = [-1 0 1]
        matlabbatch{3}.spm.stats.con.consess{6}.tcon.name = [contrasts{j}, ': ', groupB_name, ' < ', groupD_name]
        matlabbatch{3}.spm.stats.con.consess{6}.tcon.weights = [0 - 1 0 1]
        matlabbatch{3}.spm.stats.con.consess{7}.tcon.name = [contrasts{j}, ': ', groupA_name, ' > ', groupB_name]
        matlabbatch{3}.spm.stats.con.consess{7}.tcon.weights = [1 - 1]
        matlabbatch{3}.spm.stats.con.consess{8}.tcon.name = [contrasts{j}, ': ', groupC_name, ' > ', groupD_name]
        matlabbatch{3}.spm.stats.con.consess{8}.tcon.weights = [0 0 1 - 1]
        matlabbatch{3}.spm.stats.con.consess{9}.tcon.name = [contrasts{j}, ': ', groupA_name, ' < ', groupB_name]
        matlabbatch{3}.spm.stats.con.consess{9}.tcon.weights = [-1 1]
        matlabbatch{3}.spm.stats.con.consess{10}.tcon.name = [contrasts{j}, ':', groupC_name, ' < ', groupD_name]
        matlabbatch{3}.spm.stats.con.consess{10}.tcon.weights = [0 0 - 1 1]
    end

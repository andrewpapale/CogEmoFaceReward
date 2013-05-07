clear all
Use_Drug_Data=0;  % set to 1 if running subjects on/off drugs

global j k o p l q z r;
j=0;k=0;o=0;p=0;q=0;z=0;l=0; r=0;
global CEV_misc1 CEVR_misc1 DEV_misc1 IEV_misc1;
global CEV_misc2 CEVR_misc2 DEV_misc2 IEV_misc2;
global CEV_misc3 CEVR_misc3 DEV_misc3 IEV_misc3;
global CEV_misc4 CEVR_misc4 DEV_misc4 IEV_misc4;
global CEV_misc5 CEVR_misc5 DEV_misc5 IEV_misc5;

%initialize global definitions
globdefs

%initialize behavior of fitting function
ModelUsed = 'TC';
generative =0; % generative model that makes its own choices and gets reward rather than fitting subject data.
multstart=1; % use multiple starting points for gradient descent.

%initialize optimizer settings
options = optimset(@fmincon);
%options = optimset(options, 'LargeScale', 'off');

%get a list of subject data to fit

%subject directory is relative to this fit_behavior directory.
subjdir='../subjects/';
subjfiles=dir(strcat(subjdir, '*.mat'));

if length(subjfiles) == 0
    error(strcat('Could not find any subject data files in: ', subjdir));
end

subjdata=[];
subjconcat=[]; %stores all subject data in 
for f = 1:length(subjfiles)
    subjdata(f) = loadTCRun(strcat(subjdir, subjfiles(f).name));
    subjconcat = vertcat(subjconcat, subjdata(f));    
end

x = 1;




for jj=1000:1035 % subjects
    
    for kk = 1:1 % session
        
        CEV_misc1 = [];
        CEV_misc2 = [];
        CEV_misc3 = [];
        CEV_misc4 = [];
        CEV_misc5 = [];
        
        CEVR_misc1 = [];
        CEVR_misc2 = [];
        CEVR_misc3 = [];
        CEVR_misc4 = [];
        CEVR_misc5 = [];
        
        DEV_misc1 = [];
        DEV_misc2 = [];
        DEV_misc3 = [];
        DEV_misc4 = [];
        DEV_misc5 = [];
        
        IEV_misc1 = [];
        IEV_misc2 = [];
        IEV_misc3 = [];
        IEV_misc4 = [];
        IEV_misc5 = [];
        

        %determine whether the mat contains 1 or > 1 subjects
        SubjNumbers = unique(v_trn(:,1));
        
        %how many sessions per subject?
        Subj_Sess = unique(v_trn(:,1:2), 'rows');
        
        Filenames_TC
                
        %Fit model to group or individual?
        gp_fit =0; % gp_fit =1 if want to find one best fitting set of params across all subjects
        
        maxloop =  size(Subj_Sess,1); %loop over subjects and sessions
        if gp_fit == 1, maxloop = 1;
        end
        
        %only one loop for group fit
        for subsessnum = 1:maxloop
            
            %identify the subject and session
            this_subj = Subj_Sess(subsessnum, 1);
            
            %s is session number
            s = Subj_Sess(subsessnum, 2);
            
            %Print which subject we're fitting
            if maxloop > 1
                disp(['Subject ' num2str(this_subj)]);
            else
                disp('Group fit');
            end
            
            % pick out the trials corresponding to this subject
            subj_trn = v_trn(v_trn(:,1) == this_subj, :);
            
            % pick out the trials corresponding to this session
            sess_trn = subj_trn(subj_trn(:,2) == s, :);
            
            
            SubjTrials = sess_trn(:,TrlType_Colmn);
            if(Use_Drug_Data ==1)    
                d = sess_trn(1,Drug_Colmn);
                disp(['Drug ' num2str(d)]);
            end;
            
            %model parameter initialization
            init_params = [ 0.3 ; 2000 ; 0.2 ; 0.2 ; 1000 ; 0.1 ; 0.5 ; 300 ];
            lower_limits = [ 0 ; 0 ; 0.01 ; 0.01 ; .1 ; 0 ; .1 ; 0 ];
            upper_limits = [1 ; 100000 ; 5 ; 5 ; 5000 ; 5000 ; 5000 ; 10000 ]; % for rmsearch set min/max to 0 for unused params (otherwise spits out weird values that aren't used)
            
            if generative ==0
                
                if gp_fit==0
                    
                    params =[];
                    
                    %use multiple starting values?
                    if multstart == 1
                        num_start_pts =5; % number of initial starting points
                        DiffFmOptimal(subsessnum,:) = zeros(num_start_pts,1);
                        
                        opts = optimset('fmincon');
                        opts.LargeScale = 'off';
                        opts.Algorithm = 'active-set';
                        opts.Display = 'none';
                        
                        %core fitting function -- returns results of length num_start_pts (5) above.
                        %These contain fit estimates for each starting point.
                        %Then identify the best-fitting output for use in analyses.
                        [params, SE, exitflag, xstart] = rmsearch(@(params) TC_minSE(params, sess_trn), 'fmincon', init_params, ...
                            lower_limits, upper_limits, 'initialsample', num_start_pts,'options',opts) ;
                        SEmin(subsessnum)= min(SE);
                        DiffFmOptimal(subsessnum,:) = SE - SEmin(subsessnum); % how different are the SSE values for each starting pt from optimal one
                        
                        [SE1 PE exp std_f std_s mn_f mn_s Go NoGo ] = SavePredsFmBest(params(min(find(SE == min(SE))),:), sess_trn); % save predictions from best run of rmsearch
                        
                        if(kk==1)
                            save(strcat('modelVars_',num2str(jj),'a'), 'subject',  'PE', 'exp', 'std_f', 'std_s', 'mn_f', 'mn_s', 'Go', 'NoGo');
                            
                        else
                            save(strcat('modelVars_',num2str(jj),'b'), 'subject',  'PE', 'exp', 'std_f', 'std_s', 'mn_f', 'mn_s', 'Go', 'NoGo');
                        end
                        %save PE PE;
                        
                        
                    else
                        % use below line if just want to run one starting point (faster and
                        % usually not far off from optimal.)
                        [params, SE(subsessnum), exitflag] = fmincon(@(params) TC_minSE(params, sess_trn), init_params, [], [], [], [], lower_limits, upper_limits, [],options) ;
                        SavePredsFmBest(params, sess_trn);
                        
                    end
                    
                    RTGene_preds; % save rts and predictions for each genotype and condition...
                    %% (Note here Cev etc get overridden and only count 2nd cev block - if want this need to add code to combine or average blocks of same type)
                    
                else
                    [params, SE(subsessnum), exitflag, output,lambda,grad,hessian] = fmincon(@(params) TC_minSE(params, v_trn), init_params, [], [], [], [],lower_limits, upper_limits, [],options);
                    SavePredsFmBest(params, sess_trn);
                    
                end
                
                if(Use_Drug_Data ==1)
                    Best_fit_params_Trn(subsessnum, :) = [this_subj s d params' sqrt(SE(subsessnum))]
                else
                    
                    if multstart==1
                        Best_fit_params_Trn(ii, :) = [str2num(subject.subj_id(1:4)) params(min(find(SE == min(SE))),:) (SEmin(subsessnum))]
                        
                        % sess_val == 'b' returns 0 if session a and 1 if session b
                    else
                        Best_fit_params_Trn(subsessnum, :) = [this_subj s params' sqrt(SE(subsessnum))] % note these are sqrt of sum!
                        SEmin(subsessnum) = SE(subsessnum);
                    end
                    
                end;
                
            else % generative model, used for generating agent-based behavior
                
                SE = TC_minSE(init_params, sess_trn);
                RTGene_preds;
                Best_fit_params_Trn(subsessnum, :) = [this_subj s sqrt(SE)] % note these are sqrt of sum!
                
                SEmin = SE;
            end
            
            
            
        end
        %% Save params
        
    end
end

fname_Best_Fit_Param_Trn='SubjsSummary.txt';
hdr = {'Subject','Session','lambda','explore','alphaG','alphaL','K','nu','ignore','rho','SSE'};
txt=sprintf('%s\t',hdr{:});
txt(end)='';
dlmwrite(fname_Best_Fit_Param_Trn,txt,'');
dlmwrite(fname_Best_Fit_Param_Trn, Best_fit_params_Trn,'-append','delimiter','\t','precision', '%6.5f');
%%% PROBLEM
% size(Best_fit_params_Trn) => 3    10
% size(hdr)                 => 1    11
% Looks like subj_session is missing or not needed in hdr


fid_Trn =fopen(fname_trn,'w');
rSE_Trn_mean = mean(sqrt(SEmin))
rSE_Trn_std = std(sqrt(SEmin))

fprintf(fid_Trn,'%s \t', 'rSE_Trn_mean = ');
fprintf(fid_Trn,'%f \n', rSE_Trn_mean);
fprintf(fid_Trn,'%s \t', 'rSE_Trn_std = ');
fprintf(fid_Trn,'%f \n', rSE_Trn_std);


fclose(fid_Trn);



if gp_fit==0
    MakeFigs_noDNA; %% this automatically generates a bunch of relevant figs
else
    MakeFigs_met;
end

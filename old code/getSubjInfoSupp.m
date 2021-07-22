%% helper function to get subject info and reload after failed run
function [order, runTotals, filename] = getSubjInfoSupp(taskname)

global subject facenumC blockC emotionC rewardC ITIC experiment totalBlocks trialsPerBlock current_contingency reversal_flag...
    reverse_count;

if nargin < 1
    taskname='fMRIEmoClock';
end

if nargin < 2
    trialsPerBlock = 50; %assume 50
end

subject=[]; %clear out any cached subject information

%determine subject number
%if .mat file exists for this subject, then likely a reload and continue
subject.subj_id = NaN;
while isnan(subject.subj_id)
    idInput = str2double(input('Enter the subject ID number: ','s')); %force to be numeric
    if ~isnan(idInput)
        subject.subj_id = idInput;
    else
        fprintf('\n  Subject id must be a number\n\n');
    end
end

%determine subject group number
%1-Control 2-DepressedControl 3-Ideator 4-Attempter
subject.group_id = NaN;
while isnan(subject.group_id)
    idInput = str2double(input('Enter the subject group number: ','s')); %force to be numeric
    if ~isnan(idInput)  && abs(idInput)<=4 && idInput~=0 %Force to be category
        subject.group_id = idInput;
    else
        fprintf('\n  Subject group number...must be a number\n\n');
        fprintf('\n  1-CON 2-DEP 3-IDE 4-ATT \n\n');
    end
end

%determine which version of the clock task to run
%rev-Reversal norm - Normal 2x2 design
subject.task_ver = NaN;
reversal_flag = [];
while (strcmpi(subject.task_ver ,'rev')==0 && strcmp(subject.task_ver ,'norm')==0)

    subject.task_ver  = input('Which task version, Reversal or Normal 2x2 (rev or norm): ','s');
    
    %Which Reversal
    if strcmpi(subject.task_ver, 'rev')
        reversal_flag = NaN;
        while isnan(reversal_flag) || abs(reversal_flag)>=2 
            idInput = str2double(input('Which reversal 0-Fixed 1-Adaptive: ','s'));
            if ~isnan(idInput)   %Force to be category
                reversal_flag = idInput;
                subject.reversal_flag = reversal_flag;
            else
                fprintf('\n Come on it''s either a 0 or a 1!.... \n\n');
                fprintf('\n  0-Fixed 1-Adaptive \n\n');
            end
        end
    end
    
end


%If adaptive reversal set reversal counter to 0 else the while loop in the
%main script will just run once drawing from the csv file.
if reversal_flag ==1
    reverse_count = 2;
else 
    reverse_count = 2;
end


%determine session number (for repeated behavioral visits)
subject.session = NaN;
while isnan(subject.session)
    idInput = str2double(input('Enter the session number: ','s')); %force to be numeric
    if ~isnan(idInput)
        subject.session = idInput;
    else
        fprintf('\n  Session must be a number\n\n');
    end
end


%Grab what the file names should be
filename = ['subjects/' taskname '_' num2str(subject.subj_id) '_' num2str(subject.session) '_tc'];
txtfile=[filename '.txt'];


if strcmpi(taskname, 'BehavEmoClock')
    if subject.session == 1
        csvfile='FaceBehavOrder.csv';
    elseif subject.session == 2
        csvfile='FaceBehavOrder_Followup.csv';
    elseif subject.session == 3
        csvfile='FaceBehavOrder_Followup.csv';
    else
        error(['unable to identify design file for session ' subject.session]);
    end

    fid=fopen(csvfile);
    indexes={1,2,3,4};
    [ facenumC, blockC, emotionC, rewardC ] = indexes{:};
    experiment=textscan(fid,'%d %d %s %s','HeaderLines',1,'Delimiter', ',');
    fclose(fid);
elseif strcmpi(taskname, 'fMRIEmoClock')
    csvfile='FaceFMRIOrder.csv'; %not checking for session at this time
    
    fid=fopen(csvfile);
    indexes={1,2,3,4,5};
    [ facenumC, blockC, emotionC, rewardC, ITIC ] = indexes{:};
    experiment=textscan(fid,'%d %d %s %s','HeaderLines',1,'Delimiter', ',');
    fclose(fid);
elseif strcmpi(taskname, 'fMRIEmoClockBPD')
    %Grab file names based on version chosen
    if strcmpi(subject.task_ver ,'norm')
        fname = 'BPDLookupTable.xlsx';
        csvfile='FaceBehavOrderBPD.csv';
        contingency1 = 'D2';
        contingency2 = 'I2';
    elseif strcmpi(subject.task_ver ,'rev')
        fname = 'REVLookupTable.xlsx';
        if reversal_flag ==1
            csvfile='FaceBehavOrderREV_adaptive.csv';
        else
            csvfile='FaceBehavOrderREV.csv';
        end
        contingency1 = 'DID';
        contingency2 = 'IDI';
    else
        error('What in the Wild World of Sports is going on? How did this Happen!?\n')
    end
    
    %File pointer
    fid = fopen(csvfile);
    
    %Take care of csv file
    indexes={1,2,3,4,5};
    [ facenumC, blockC, emotionC, rewardC, ITIC ] = indexes{:};
    experiment=textscan(fid,'%d %d %s %s','HeaderLines',1,'Delimiter', ',');
    %Allow up to 50 subjects per group, think about this...
    switch subject.group_id 
        case 1
            xlrange = 'A1:A50';
        case 2
            xlrange = 'B1:B50';
        case 3
            xlrange = 'C1:C50';
        case 4
            xlrange = 'D1:D50';
    end

    [num,txt,raw]=xlsread(fname,xlrange);
    last_data_point=length(txt);
    
    %This will get re-written on subsequent runs
    subject.lookup_table_value = txt{last_data_point};
    %current_contingency = experiment{rewardC}{1};
    
    %Switch contingency for next subject
    %I2 = IEV twice first
    %D2 = DEV twice first
    %DID = DEV->IEV->DEV with either fixed or adaptive switches
    %IDI = IEV->DEV->IEV with either fixed or adaptive switches
    if strcmpi(txt(last_data_point),contingency1)
        txt{last_data_point+1} = contingency2;
    else
        txt{last_data_point+1} = contingency1;
    end
        
    %Write it to file but only if subject didn't exist and it's the first
    %session
    if subject.session==1 && ~exist(txtfile,'file')
        display_warning_message(subject)
        xlrange = strcat(xlrange(1:4),num2str(last_data_point+1)); %New range
        xlswrite(fname,txt,xlrange);
    end
    

    fclose(fid);
    
else
    %MEG currently uses forked copies of utility scripts, so don't check
    error(['Unable to determine what to do for task ' taskname]);
end

fprintf('Reading design from %s\n', csvfile);

% how long (trials) is a block
[~,blockchangeidx] = unique(experiment{blockC});
trialsPerBlock     = unique(diff(blockchangeidx));
if(length(trialsPerBlock) > 1)
    error('Whoa?! Different block lengths? I dont know what''s going on!\n')
end

totalBlocks = length(experiment{blockC})/trialsPerBlock;

% initialize the order of events
order=cell(trialsPerBlock*totalBlocks,1);

%initialize run totals
runTotals = zeros(totalBlocks, 1);

%whether to prompt user for run to execute
askRun=false;


%filename = ['subjects/' taskname '_' num2str(subject.subj_id) '_' num2str(subject.session) '_tc'];

% is the subject new? should we resume from existing?
% set t accordingly, maybe load subject structure
%txtfile=[filename '.txt'];
backup=[txtfile '.' num2str(GetSecs()) '.bak'];

% we did something with this subject before?
if exist(txtfile,'file')
    % check that we have a matching mat file
    % if not, backup txt file and restart
    if ~ exist([filename '.mat'],'file')
        fprintf('%s exists, but .mat does not!\n', txtfile)
        fprintf('moving %s to %s, start from top\n', txtfile, backup)
        movefile(txtfile, backup);
    else
        localVar = load(filename);
        
        % sanity check --ADD in more sanity checks!!!
        if localVar.subject.subj_id ~= subject.subj_id
            error('mat file data conflicts with name!: %d != %d',...
                localVar.subject.subj_id, subject.subj_id);
        end
        
        run_sanity_checker(localVar, subject)
        
        %load previous information: place below above check to preserve user input
        subject=localVar.subject;
        order=localVar.order;
        runTotals=localVar.runTotals;
        
        if localVar.blockTrial < trialsPerBlock
            fprintf('It appears only %d trials were completed in run %d.\n', localVar.blockTrial, subject.run_num);
            redoRun=[];
            while isempty(redoRun)
                redoRun = input(['Do you want to redo run ', num2str(subject.run_num), ' ? (y or n) '],'s');
                if ~(strcmpi(redoRun, 'y') || strcmpi(redoRun, 'n'))
                    redoRun=[];
                end
            end
            
            if strcmpi(redoRun, 'n')
                askRun=true;
            end
        else
            continueRun=[];
            while isempty(continueRun)
                continueRun = input(['Continue with run ', num2str(subject.run_num + 1), ' ? (y or n) '], 's');
                if ~(strcmpi(continueRun, 'y') || strcmpi(continueRun, 'n'))
                    continueRun=[];
                end
            end
            
            if (strcmpi(continueRun, 'y'))
                subject.run_num = subject.run_num + 1;
            else
                askRun=true;
            end
            
        end
        
        if askRun
            chooseRun = input(['Specify the run to be completed (1 - ', num2str(totalBlocks), ') '], 's');
            if str2double(chooseRun) > totalBlocks || str2double(chooseRun) < 1
                error(['Must specify run 1 - ', num2str(totalBlocks)]);
            end
            
            subject.run_num = str2double(chooseRun);
        end
        
        %for the run about to be completed, clear out any prior responses and run totals
        runTotals(subject.run_num) = 0; %reset total points in this run
        for l = ((subject.run_num-1)*trialsPerBlock+1):(subject.run_num*trialsPerBlock)
            order{l} = [];
        end
        
    end
end

if ~ismember('run_num', fields(subject)), subject.run_num = 1; end %if new participant, assume run1 start and don't prompt

%% fill out the subject struct if any part of it is still empty

if ~ismember('age', fields(subject)) || isnan(subject.age)
    subject.age = NaN;
    while isnan(subject.age)
        ageInput = str2double(input('Enter the subject''s age: ','s')); %force to be numeric
        if ~isnan(ageInput)
            subject.age = ageInput;
        else
            fprintf('\n  Subject age must be a number\n\n');
        end
    end
else
    fprintf('using old age: %d\n', subject.age);
end

if ~ismember('gender', fields(subject))
    subject.gender=[];
    while isempty(subject.gender)
        subject.gender = input(['Enter subject''s gender (m or f): '], 's');
        if ~(strcmpi(subject.gender, 'm') || strcmpi(subject.gender, 'f'))
            subject.gender=[];
        end
    end
else
    fprintf('using old gender: %s\n', subject.gender);
end

%% Customizations for fMRI version of task
if strcmpi(taskname, 'fMRIEmoClock') || strcmpi(taskname, 'fMRIEmoClockBPD')
    % For first run of fMRI task, need to sample the 8 orders from the mat file here.
    % Only sample if we have not populated the ITIs before (i.e., don't resample for re-running run 1)
    if subject.run_num==1 && ~ismember('runITI_indices', fields(subject))
        locV=load('fMRIOptITIs_284s_38pct.mat');
        subject.runITI_indices = randsample(size(locV.itimat,1), totalBlocks);
        subject.runITIs=locV.itimat(subject.runITI_indices, :);
        clear locV;
    end
    
    if subject.run_num==1 && ~ismember('blockColors', fields(subject))
        %Set1 from Color Brewer
        %provides 8 colors
        blockColors = [228 26 28; ...
            55 126 184; ...
            77 175 74; ...
            152 78 163; ...
            255 127 0; ...
            255 255 51; ...
            166 86 40; ...
            247 129 191];
        
        blockColors = blockColors(randperm(8),:); %permute per subject
        subject.blockColors=blockColors;
        
        %Set3 from Color Brewer
        %only provides 12 colors
        % blockColors = [141 211 199; ...
        %     255 255 179; ...
        %     190 186 218; ...
        %     251 128 114; ...
        %     128 177 211; ...
        %     253 180 98; ...
        %     179 222 105; ...
        %     252 205 229; ...
        %     217 217 217; ...
        %     188 128 189; ...
        %     204 235 197; ...
        %     255 237 111];
        %blockColors = round(255*hsv(24)); % a different color for each block of trials
        %blockColors = blockColors(randperm(24),:); % randperm(24) should prob be replaced by a pre-made vector
    end
    
elseif strcmpi(taskname, 'BehavEmoClock')
    %use randomized colors
    blockColors = round(240*hsv(totalBlocks)); % a different color for each block of trials
    blockColors = blockColors(randperm(totalBlocks),:);
    subject.blockColors=blockColors;
end


%% set sex to a standard
if ismember(lower(subject.gender),{'male';'dude';'guy';'m';'1'} )
    subject.gender = 'male';
else
    subject.gender = 'female';
end

% print out determined sex, give user a chance to correct
fprintf('Subject is %s\n', subject.gender);


end



function run_sanity_checker(localVar, subject)

%All  user inputted fields besides age and gender, they already
%have checking contingencies
fields = {'subj_id', 'group_id', 'task_ver'};

%Compare subject history and inputted data, if error is through
%instructor most likely inputted data incorrectly!
for i = 1: numel(fields)
    if localVar.subject.(fields{i}) ~= subject.(fields{i})
        error(['mat file data conflicts with ', fields{i},'!: %d != %d'],...
            localVar.subject.(fields{i}), subject.(fields{i}));
    end
end

%If they chose reversal make sure it's the right one
if strcmpi(subject.task_ver, 'rev')
    if localVar.subject.reversal_flag ~= subject.reversal_flag
        error('mat file data conflicts with reversal_flag !: %d != %d',...
            localVar.subject.reversal_flag, subject.reversal_flag);
    end
end

end


function display_warning_message(subject)
%This function is to review and ask the user if they want to proceed in
%running the script when writing to the lookup table is on the line

global reversal_flag

    fprintf('#Subj:\t%i\n', subject.subj_id);
    fprintf('#Session:\t%i\n',  subject.session);
    fprintf('#Group:\t%i\n',subject.group_id);
    fprintf('#Task Version:\t%s\n',subject.task_ver);
    fprintf('#Reversal:\t%i\n',reversal_flag);
    fprintf('If the info is correct hit enter to continue\n')
    fprintf('Otherwise hit ctrl+c to exit')
    
    %Prompt instructor to continue
    prmt=' ';
    input(prmt);
    
    

end

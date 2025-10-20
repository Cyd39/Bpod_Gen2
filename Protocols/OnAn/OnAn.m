function OnAn()
    global BpodSystem

    %% Session Setup

    % Create trial manager object
    trialManager = BpodTrialManager;

    % Initialize HiFi module
    H = BpodHiFi('COM3'); 
    H.SamplingRate = 192000; 

    % get parameters from StimParamGui
    StimParams = BpodSystem.ProtocolSettings.StimParams;
    NumTrials = StimParams.Behave.NumTrials;
    StimDur = StimParams.Duration/1000;
    
    % Generate Stimuli parameter table
    StimTable = GenStimSeq(StimParams);

    % Load calibration table
    CalFile = 'Calibration Files\CalTable_20250923.mat';
    load(CalFile,'CalTable');
    
    % Setup default parameters
    S = struct;
    % use the behavior parameters from StimParamGui as default values
    S.GUI.MinITI = StimParams.Behave.MinITI; % seconds
    S.GUI.MaxITI = StimParams.Behave.MaxITI; % seconds
    S.GUI.MinQuietTime = StimParams.Behave.MinQuietTime; % seconds
    S.GUI.MaxQuietTime = StimParams.Behave.MaxQuietTime; % seconds
    S.GUI.RewardAmount = StimParams.Behave.RewardAmount; % µL
    S.GUI.ResWin = StimParams.Behave.ResWin; % seconds
    % Cut-off period for NoLick state
    S.CutOffPeriod = 60; % seconds

    % Initialize parameter GUI
    BpodParameterGUI('init', S);
    % Create update button
    uicontrol('Style', 'pushbutton', ...
        'String', 'Update Parameters', ...
        'Position', [160 240 150 30], ...  % [left bottom width height]
        'FontSize', 12, ...
        'Callback', @updateParams);

    % Initialize update flag
    updateFlag = false;

    % Update button callback function
    function updateParams(~, ~)
        updateFlag = true;
        disp('Parameters updated');
    end

    % Save the StimTable and StimParams to SessionData
    BpodSystem.Data.StimTable = StimTable;
    BpodSystem.Data.StimParams = StimParams;
    
    %% Initialize plots
    % Initialize the outcome plot 1
    trialTypes = ones(1, NumTrials);% Only one trial type, all outcomes are 1
    outcomePlot = LiveOutcomePlot(1, {'Outcome'}, trialTypes, NumTrials); % Create an instance of the LiveOutcomePlot GUI
    % Arg1 = trialTypeManifest, a list of possible trial types (even if not yet in trialTypes).
    % Arg2 = trialTypeNames, a list of names for each trial type in trialTypeManifest
    % Arg3 = trialTypes, a list of integers denoting precomputed trial types in the session
    % Arg4 = nTrialsToShow, the number of trials to show
    outcomePlot.RewardStateNames = {'Reward'}; % List of state names where reward was delivered
    outcomePlot.CorrectStateNames = {'Reward'}; % States where correct response was made
    outcomePlot.ErrorStateNames = {'Checking'}; % States where incorrect response was made (timeout)
    outcomePlot.PunishStateNames = {}; % No punishment states in this protocol

    %% Prepare and start first trial
    genAndLoadStimulus(1);
    [sma, S, updateFlag, ThisITI, QuietTime,isCatchTrial, RewardAmount] = PrepareStateMachine(S, 1, updateFlag); % Prepare state machine for trial 1 with empty "current events" variable
    
    % Store trial parameters before starting the trial
    BpodSystem.Data.ThisITI(1) = ThisITI;
    BpodSystem.Data.QuietTime(1) = QuietTime;
    BpodSystem.Data.isCatchTrial(1) = isCatchTrial;
    BpodSystem.Data.RewardAmount(1) = RewardAmount;
    
    displayTrialInfo(1, ThisITI, QuietTime,isCatchTrial);
    trialManager.startTrial(sma); % Sends & starts running first trial's state machine. A MATLAB timer object updates the 
                                  % console UI, while code below proceeds in parallel.

    %% Main loop, runs once per trial
    for currentTrial = 1:NumTrials       
        %currentTrialEvents = trialManager.getCurrentEvents({'LeftReward', 'RightReward', 'TimeOutState', 'PunishTimeout'}); 
        if BpodSystem.Status.BeingUsed == 0; return; end % If user hit console "stop" button, end session
        if currentTrial < NumTrials
            genAndLoadStimulus(currentTrial+1);
            [sma, S, updateFlag, NextITI, NextQuietTime, NextisCatchTrial, NextRewardAmount] = PrepareStateMachine(S, currentTrial+1, updateFlag); 
            
            % Store next trial parameters
            BpodSystem.Data.ThisITI(currentTrial+1) = NextITI;
            BpodSystem.Data.QuietTime(currentTrial+1) = NextQuietTime;
            BpodSystem.Data.isCatchTrial(currentTrial+1) = NextisCatchTrial;
            BpodSystem.Data.RewardAmount(currentTrial+1) = NextRewardAmount;
            
            SendStateMachine(sma, 'RunASAP');   % Send the next trial's state machine during the current trial
        end
        RawEvents = trialManager.getTrialData; % Hangs here until trial is over, then retrieves full trial's raw data
        if BpodSystem.Status.BeingUsed == 0; return; end % If user hit console "stop" button, end session 
        HandlePauseCondition; % Checks to see if the protocol is paused. If so, waits until user resumes.
        if currentTrial < NumTrials
            trialManager.startTrial(); % Start processing the next trial's events (call with no argument since SM was already sent)
        end

        % If trial data was returned from last trial, update plots and save data
        if ~isempty(fieldnames(RawEvents)) 
            BpodSystem.Data = AddTrialEvents(BpodSystem.Data,RawEvents); % Computes trial events from raw data(had before)
            %BpodSystem.Data = BpodNotebook('sync', BpodSystem.Data); % Sync with Bpod notebook plugin
            BpodSystem.Data.TrialSettings(currentTrial) = S; % Adds the settings used for the current trial to the Data struct(had before)
            % Save trial timestamp
            BpodSystem.Data.TrialStartTimestamp(currentTrial) = RawEvents.TrialStartTimestamp;
            % Trial parameters were already stored before the trial started
            % Update plots
            %PokesPlot('update'); % Update Pokes Plot
            %outcomePlot.update(trialTypes, BpodSystem.Data); % Update the outcome plot

            % Save data
            SaveBpodSessionData; % Saves the field BpodSystem.Data to the current data file
        end  
        outcomePlot.update(trialTypes, BpodSystem.Data); % Update the outcome plot
    end

    function [sma, S, updateFlag, ThisITI, QuietTime,isCatchTrial, RewardAmount] = PrepareStateMachine(S, currentTrial, updateFlag)
        if updateFlag
            S = BpodParameterGUI('sync', S); % Sync parameters with BpodParameterGUI plugin
            updateFlag = false; % reset flag
        end

        % Generate random ITI and quiet time for this trial
        ITIBefore = S.GUI.MinITI/2;
        ITIAfter = S.GUI.MinITI/2 + rand() * (S.GUI.MaxITI - S.GUI.MinITI);
        ThisITI = ITIBefore + ITIAfter;
        QuietTime = S.GUI.MinQuietTime + rand() * (S.GUI.MaxQuietTime - S.GUI.MinQuietTime);
        TimerDuration = ITIAfter+StimDur;
        RewardAmount = S.GUI.RewardAmount;
        disp(['Trial ' num2str(currentTrial) ': Reward Amount = ' num2str(RewardAmount) ' µL']);
        ValveTime = BpodLiquidCalibration('GetValveTimes', RewardAmount, 1);
        ValveTime = ValveTime(1);
        ResWin = S.GUI.ResWin;
        CutOff = S.CutOffPeriod;

        % Create state machine
         sma = NewStateMachine();
      
         % Set condition for BNC1 state
         sma = SetCondition(sma, 1, 'BNC1', 0); % Condition 1: BNC1 is HIGH (licking detected)
         sma = SetCondition(sma, 2, 'BNC1', 1); % Condition 2: BNC1 is LOW (no licking detected)
 
         % Set timer and condition for the cut-off period
         sma = SetGlobalTimer(sma, 'TimerID', 1, 'Duration', CutOff);
         sma = SetCondition(sma, 3, 'GlobalTimer1', 0); % Condition 3: GlobalTimer1 has ended
         
         % Add states
         % Ready state under different conditions
         if ITIBefore-QuietTime > 0
             sma = AddState(sma, 'Name', 'Ready', ...
                 'Timer', ITIBefore-QuietTime, ...
                 'StateChangeConditions', {'Tup', 'NoLick'}, ...
                 'OutputActions', {'GlobalTimerTrig', 1});
             sma = AddState(sma, 'Name', 'NoLick', ...
                 'Timer', QuietTime, ...
                 'StateChangeConditions', {'Condition1', 'ResetNoLick','BNC1High','ResetNoLick','Tup', 'Stimulus','Condition3', 'Stimulus'}, ... % Use condition to detect BNC1 state
                 'OutputActions', {});
             sma = AddState(sma, 'Name', 'ResetNoLick', ...
                 'Timer', 0, ...
                 'StateChangeConditions', {'Condition2', 'NoLick','Condition3', 'Stimulus'}, ... % Reset NoLick Timer
                 'OutputActions', {});
         else
             sma = AddState(sma, 'Name', 'Ready', ...
                 'Timer', ITIBefore, ...
                 'StateChangeConditions', {'Condition1', 'ResetNoLick','BNC1High','ResetNoLick','Tup', 'Stimulus'}, ...
                 'OutputActions', {'GlobalTimerTrig', 1});
             sma = AddState(sma, 'Name', 'NoLick', ...
                 'Timer', QuietTime, ...
                 'StateChangeConditions', {'Condition1', 'ResetNoLick','BNC1High','ResetNoLick', 'Tup', 'Stimulus','Condition3', 'Stimulus'}, ... % Use condition to detect BNC1 state
                 'OutputActions', {});
             sma = AddState(sma, 'Name', 'ResetNoLick', ...
                 'Timer', 0, ...
                 'StateChangeConditions', {'Condition2', 'NoLick','Condition3', 'Stimulus'}, ... % Reset NoLick Timer
                 'OutputActions', {});
         end
 
         % the timer begins at the stimulus state， the duration is Stimulus+ITI
         sma = SetGlobalTimer(sma, 'TimerID', 2, 'Duration', TimerDuration); 
 
         % Stimulus state
         sma = AddState(sma, 'Name', 'Stimulus', ...
             'Timer', 0.2, ... % Using sound duration as stimulus time
             'StateChangeConditions', {'Tup', 'Response'}, ...
             'OutputActions', {'HiFi1', ['P' 0],'GlobalTimerTrig', 2});
 
         % If it is a catch trial, there is no jumping into the reward state
         isCatchTrial = false;
         if strcmp(char(StimTable.MMType(currentTrial)), 'OO')
             isCatchTrial = true;
         end
         
         if isCatchTrial
             % NoReward state
             sma = AddState(sma, 'Name', 'Response', ...
                 'Timer', ResWin, ...
                 'StateChangeConditions', {'Tup', 'Checking'}, ...
                 'OutputActions', {});
         else
             % Response state
             sma = AddState(sma, 'Name', 'Response', ...
                 'Timer', ResWin, ...
                 'StateChangeConditions', {'BNC1High', 'Reward', 'Tup', 'Checking'}, ...
                 'OutputActions', {});
         end
 
         % Reward state
         sma = AddState(sma, 'Name', 'Reward', ...
             'Timer', ValveTime, ...
             'StateChangeConditions', {'Tup', 'Checking'}, ...
             'OutputActions', {'Valve1', 1});
 
         
         % Set condition to check if GlobalTimer1 has ended
         sma = SetCondition(sma, 4, 'GlobalTimer2', 0); % Condition 4: GlobalTimer2 has ended
         
         % Here is the part need to be modified(maybe need to set a timer for the checking state)
         sma = AddState(sma, 'Name', 'Checking', ...
             'Timer', 0, ...  
             'StateChangeConditions', {'Condition4', 'exit'}, ...
             'OutputActions', {});
    end

    function genAndLoadStimulus(currentTrial)
        % Generate sound&vibration waveform
        soundWave = GenStimWave(StimTable(currentTrial,:),CalTable);
        disp(StimTable(currentTrial,:));

        % Load the sound wave into BpodHiFi
        H.load(1, soundWave); 
        H.push();
        disp(['Trial ' num2str(currentTrial) ': Sound loaded to buffer 1']);
    end

    function displayTrialInfo(currentTrial, ThisITI, QuietTime,isCatchTrial)
        % Display the trial number
        disp(['Trial ' num2str(currentTrial) ':']);  
        % Display the ITI and QuietTime
        disp(['ITI = ' num2str(ThisITI) ' seconds, QuietTime = ' num2str(QuietTime) ' seconds']);  
        % Display the trial type
        if isCatchTrial
            disp('Catch trial')
        end
    end
end 
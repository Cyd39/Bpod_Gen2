function Detection()
    global BpodSystem

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
    CalFile = 'Calibration Files\CalTable_20250707.mat';
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
    CutOffPeriod = 60; % seconds

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
    
    % Main trial loop
    for currentTrial = 1:NumTrials
        % Check if update button was pressed
        if updateFlag
            % get parameters from GUI
            S = BpodParameterGUI('sync', S);
            updateFlag = false; % reset flag
        end
        
        % Generate sound&vibration waveform
        soundWave = GenStimWave(StimTable(currentTrial,:),CalTable);
        disp(StimTable(currentTrial,:));

        % Load the sound wave into BpodHiFi
        H.load(1, soundWave); 
        H.push();
        disp(['Trial ' num2str(currentTrial) ': Sound loaded to buffer 1']);

        % Generate random ITI and quiet time for this trial
        ITIBefore = S.GUI.MinITI/2;
        ITIAfter = S.GUI.MinITI/2 + rand() * (S.GUI.MaxITI - S.GUI.MinITI);
        ThisITI = ITIBefore + ITIAfter;
        QuietTime = S.GUI.MinQuietTime + rand() * (S.GUI.MaxQuietTime - S.GUI.MinQuietTime);
        TimerDuration = ITIAfter+StimDur;
        RewardAmount = S.GUI.RewardAmount;
        disp(['Trial ' num2str(currentTrial) ': Liquid Volume = ' num2str(RewardAmount) ' µL']);
        ValveTime = BpodLiquidCalibration('GetValveTimes', RewardAmount, 1);
        ValveTime = ValveTime(1);
        ResWin = S.GUI.ResWin;
        CutOff = CutOffPeriod;
        
        % Display the trial information
        disp(['Trial ' num2str(currentTrial) ': ITI = ' num2str(ThisITI) ' seconds, QuietTime = ' num2str(QuietTime) ' seconds']);  

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
            disp('catch trial')
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
        
        % Send state machine to Bpod device
        SendStateMachine(sma);
        
        % Run state machine
        RawEvents = RunStateMachine;
        
        % Save trial data
        if ~isempty(fieldnames(RawEvents))
            BpodSystem.Data = AddTrialEvents(BpodSystem.Data, RawEvents);
            BpodSystem.Data.TrialSettings(currentTrial) = S;
            
            % Save trial timestamp
            BpodSystem.Data.TrialStartTimestamp(currentTrial) = RawEvents.TrialStartTimestamp;

            % Save timing of the trial
            BpodSystem.Data.ITIBefore(currentTrial) = ITIBefore;
            BpodSystem.Data.ITIAfter(currentTrial) = ITIAfter;
            BpodSystem.Data.ThisITI(currentTrial) = ThisITI;
            BpodSystem.Data.QuietTime(currentTrial) = QuietTime;
            BpodSystem.Data.TimerDuration(currentTrial) = TimerDuration;
            BpodSystem.Data.RewardAmount(currentTrial) = RewardAmount;
            BpodSystem.Data.ValveTime(currentTrial) = ValveTime;
            BpodSystem.Data.ResWin(currentTrial) = ResWin;
            BpodSystem.Data.CutOff(currentTrial) = CutOff;
                        
            SaveBpodSessionData;
        end
        
        % Handle pause condition
        HandlePauseCondition;
        
        % Check if session should end
        if BpodSystem.Status.BeingUsed == 0
            disp('End of session');
            return
        end
    end
    
end 
% SwitchWhenNCorrect protocol (TrialManager version)
% This protocol is used to switch the correct side when the animal has corrected N times
function SwitchWhenNCorrect()
    global BpodSystem

    %% Session Setup

    % Create trial manager object
    trialManager = BpodTrialManager;

    % Initialize HiFi module
    H = BpodHiFi('COM3');
    H.SamplingRate = 192000;

    % Get parameters from StimParamGui
    StimParams = BpodSystem.ProtocolSettings.StimParams;
    NumTrials = StimParams.Behave.NumTrials; 
    StimDur = StimParams.Duration/1000;
    
    % Generate LeftRight stimulus sequence tables
    LeftRightSeq = GenLeftRightSeq(StimParams);
    
    % Load calibration table
    CalFile = 'Calibration Files\CalTable_20250923.mat';
    load(CalFile,'CalTable');
    
    % Setup default parameters for BpodParameterGUI
    S = struct;
    S.GUI.MinITI = StimParams.Behave.MinITI; % seconds
    S.GUI.MaxITI = StimParams.Behave.MaxITI; % seconds
    S.GUI.MinQuietTime = StimParams.Behave.MinQuietTime; % seconds
    S.GUI.MaxQuietTime = StimParams.Behave.MaxQuietTime; % seconds
    S.GUI.RewardAmount = StimParams.Behave.RewardAmount; % µL
    S.GUI.ResWin = StimParams.Behave.ResWin; % seconds
    S.GUI.NCorrectToSwitch = 5; % Number of correct trials needed to switch sides
    
    % Initialize parameter GUI
    BpodParameterGUI('init', S);
    
    % Create update button
    uicontrol('Style', 'pushbutton', ...
        'String', 'Update Parameters', ...
        'Position', [160 240 150 30], ...
        'FontSize', 12, ...
        'Callback', @updateParams);
    
    % Initialize update flag
    updateFlag = false;
    
    % Update button callback function
    function updateParams(~, ~)
        updateFlag = true;
        disp('Parameters updated');
    end
    
    % Save the LeftRightSeq and StimParams to SessionData
    BpodSystem.Data.LeftRightSeq = LeftRightSeq;
    BpodSystem.Data.StimParams = StimParams;
    
    % Initialize trial tracking variables
    currentSide = 1; % 1 = low frequency (left), 2 = high frequency (right)
    correctCount = 0; % Counter for correct trials on current side
    highFreqIndex = 1; % Index for high frequency table (continuous)
    lowFreqIndex = 1; % Index for low frequency table (continuous)
    
    % Cut-off period for NoLick state
    CutOffPeriod = 60; % seconds
    
    % Initialize data arrays
    BpodSystem.Data.CurrentSide = [];
    BpodSystem.Data.CorrectSide = [];
    BpodSystem.Data.IsCorrect = [];
    BpodSystem.Data.CorrectCount = [];
    BpodSystem.Data.IsCatchTrial = [];
    BpodSystem.Data.CurrentStimRow = [];
    
    %% Prepare and start first trial
    [sma, S] = PrepareStateMachine(S, LeftRightSeq, CalTable, H, currentSide, highFreqIndex, lowFreqIndex, correctCount, CutOffPeriod, StimDur);
    trialManager.startTrial(sma);
    
    %% Main loop, runs once per trial
    for currentTrial = 1:NumTrials
        % Check if update button was pressed
        if updateFlag
            % Get parameters from GUI
            S = BpodParameterGUI('sync', S);
            updateFlag = false; % reset flag
        end
        
        % Wait for trigger states (Reward, Checking, TimeOutState)
        trialManager.getCurrentEvents({'Reward', 'Checking', 'TimeOutState'});
        if BpodSystem.Status.BeingUsed == 0; return; end % If user hit console "stop" button, end session
        
        % Prepare next trial's state machine if not the last trial
        if currentTrial < NumTrials
            [sma, S] = PrepareStateMachine(S, LeftRightSeq, CalTable, H, currentSide, highFreqIndex, lowFreqIndex, correctCount, CutOffPeriod, StimDur);
            SendStateMachine(sma, 'RunASAP'); % Send next trial's state machine during current trial
        end
        
        % Get trial data
        RawEvents = trialManager.getTrialData();
        if BpodSystem.Status.BeingUsed == 0; return; end % If user hit console "stop" button, end session
        
        % Handle pause condition
        HandlePauseCondition;
        
        % Start next trial if not the last one
        if currentTrial < NumTrials
            trialManager.startTrial(); % Start processing the next trial's events
        end
        
        % Process trial data if available
        if ~isempty(fieldnames(RawEvents))
            BpodSystem.Data = AddTrialEvents(BpodSystem.Data, RawEvents);
            BpodSystem.Data.TrialSettings(currentTrial) = S;
            
            % Save trial timestamp
            BpodSystem.Data.TrialStartTimestamp(currentTrial) = RawEvents.TrialStartTimestamp;
            
            % Get current trial parameters from S
            currentStimRow = S.CurrentStimRow;
            correctSide = S.CorrectSide;
            isCatchTrial = S.IsCatchTrial;
            ITIBefore = S.ITIBefore;
            ITIAfter = S.ITIAfter;
            ThisITI = S.ThisITI;
            QuietTime = S.QuietTime;
            TimerDuration = S.TimerDuration;
            RewardAmount = S.RewardAmount;
            ValveTime = S.ValveTime;
            ResWin = S.ResWin;
            CutOff = S.CutOff;
            
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
            
            % Save stimulus information
            BpodSystem.Data.CurrentStimRow(currentTrial) = currentStimRow;
            BpodSystem.Data.CorrectSide(currentTrial) = correctSide;
            BpodSystem.Data.CurrentSide(currentTrial) = currentSide;
            BpodSystem.Data.IsCatchTrial(currentTrial) = isCatchTrial;
            
            % Check if response was correct (only for non-catch trials)
            if ~isCatchTrial
                % Check if animal licked during response window
                if isfield(RawEvents.States, 'Reward')
                    % Animal licked and got reward - correct response
                    isCorrect = true;
                    correctCount = correctCount + 1;
                    disp(['Trial ' num2str(currentTrial) ': Correct response! Count: ' num2str(correctCount)]);
                else
                    % Animal did not lick - incorrect response
                    isCorrect = false;
                    correctCount = 0; % Reset counter on incorrect response
                    disp(['Trial ' num2str(currentTrial) ': Incorrect response. Count reset to 0.']);
                end
            else
                % Catch trial - no response expected
                isCorrect = true; % Don't count catch trials
                disp(['Trial ' num2str(currentTrial) ': Catch trial - no response expected.']);
            end
            
            % Save response information
            BpodSystem.Data.IsCorrect(currentTrial) = isCorrect;
            BpodSystem.Data.CorrectCount(currentTrial) = correctCount;
            
            % Check if we need to switch sides
            if correctCount >= S.GUI.NCorrectToSwitch
                % Switch to the other side
                if currentSide == 1
                    currentSide = 2; % Switch to high frequency
                    disp(['Switching to high frequency side after ' num2str(correctCount) ' correct trials']);
                else
                    currentSide = 1; % Switch to low frequency
                    disp(['Switching to low frequency side after ' num2str(correctCount) ' correct trials']);
                end
                correctCount = 0; % Reset counter
            end
            
            % Update indices for next trial (independent continuous indexing, no cycling)
            if currentSide == 1 % Low frequency side
                lowFreqIndex = lowFreqIndex + 1;
                % Continue reading beyond table length if needed
            else % High frequency side
                highFreqIndex = highFreqIndex + 1;
                % Continue reading beyond table length if needed
            end
            
            SaveBpodSessionData;
        end
    end
    
    % Clean up trial manager
    clear trialManager;
end

function [sma, S] = PrepareStateMachine(S, LeftRightSeq, CalTable, H, currentSide, highFreqIndex, lowFreqIndex, ~, CutOffPeriod, StimDur)
    % Prepare state machine for the current trial
    
    % Sync parameters with GUI
    S = BpodParameterGUI('sync', S);
    
    % Determine which stimulus table to use based on current side
    if currentSide == 1 % Low frequency side
        % Direct indexing (table length matches trial count)
        currentStimRow = LeftRightSeq.LowFreqTable(lowFreqIndex, :);
        correctSide = 1; % Left side for low frequency
    else % High frequency side
        % Direct indexing (table length matches trial count)
        currentStimRow = LeftRightSeq.HighFreqTable(highFreqIndex, :);
        correctSide = 2; % Right side for high frequency
    end
    
    % Generate sound&vibration waveform
    soundWave = GenStimWave(currentStimRow, CalTable);
    disp(['Current side = ' num2str(currentSide) ', Correct side = ' num2str(correctSide)]);
    if currentSide == 1
        disp(['Low freq index: ' num2str(lowFreqIndex)]);
    else
        disp(['High freq index: ' num2str(highFreqIndex)]);
    end
    disp(currentStimRow);

    % Load the sound wave into BpodHiFi
    H.load(1, soundWave); 
    H.push();
    disp('Sound loaded to buffer 1');

    % Generate random ITI and quiet time for this trial
    ITIBefore = S.GUI.MinITI/2;
    ITIAfter = S.GUI.MinITI/2 + rand() * (S.GUI.MaxITI - S.GUI.MinITI);
    ThisITI = ITIBefore + ITIAfter;
    QuietTime = S.GUI.MinQuietTime + rand() * (S.GUI.MaxQuietTime - S.GUI.MinQuietTime);
    TimerDuration = ITIAfter+StimDur;
    RewardAmount = S.GUI.RewardAmount;
    disp(['Liquid Volume = ' num2str(RewardAmount) ' µL']);
    ValveTime = BpodLiquidCalibration('GetValveTimes', RewardAmount, 1);
    ValveTime = ValveTime(1);
    ResWin = S.GUI.ResWin;
    CutOff = CutOffPeriod;
    
    % Display the trial information
    disp(['ITI = ' num2str(ThisITI) ' seconds, QuietTime = ' num2str(QuietTime) ' seconds']);  

    % Check if it is a catch trial
    isCatchTrial = false;
    if strcmp(char(currentStimRow.MMType), 'OO')
        isCatchTrial = true;
        disp('Catch trial');
    end
    
    % Store trial parameters in S for later use
    S.CurrentStimRow = currentStimRow;
    S.CorrectSide = correctSide;
    S.IsCatchTrial = isCatchTrial;
    S.ITIBefore = ITIBefore;
    S.ITIAfter = ITIAfter;
    S.ThisITI = ThisITI;
    S.QuietTime = QuietTime;
    S.TimerDuration = TimerDuration;
    S.RewardAmount = RewardAmount;
    S.ValveTime = ValveTime;
    S.ResWin = ResWin;
    S.CutOff = CutOff;

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
            'StateChangeConditions', {'Condition1', 'ResetNoLick','BNC1High','ResetNoLick','Tup', 'Stimulus','Condition3', 'Stimulus'}, ...
            'OutputActions', {});
        sma = AddState(sma, 'Name', 'ResetNoLick', ...
            'Timer', 0, ...
            'StateChangeConditions', {'Condition2', 'NoLick','Condition3', 'Stimulus'}, ...
            'OutputActions', {});
    else
        sma = AddState(sma, 'Name', 'Ready', ...
            'Timer', ITIBefore, ...
            'StateChangeConditions', {'Condition1', 'ResetNoLick','BNC1High','ResetNoLick','Tup', 'Stimulus'}, ...
            'OutputActions', {'GlobalTimerTrig', 1});
        sma = AddState(sma, 'Name', 'NoLick', ...
            'Timer', QuietTime, ...
            'StateChangeConditions', {'Condition1', 'ResetNoLick','BNC1High','ResetNoLick', 'Tup', 'Stimulus','Condition3', 'Stimulus'}, ...
            'OutputActions', {});
        sma = AddState(sma, 'Name', 'ResetNoLick', ...
            'Timer', 0, ...
            'StateChangeConditions', {'Condition2', 'NoLick','Condition3', 'Stimulus'}, ...
            'OutputActions', {});
    end

    % The timer begins at the stimulus state, the duration is Stimulus+ITI
    sma = SetGlobalTimer(sma, 'TimerID', 2, 'Duration', TimerDuration); 

    % Stimulus state
    sma = AddState(sma, 'Name', 'Stimulus', ...
        'Timer', 0.2, ... % Using sound duration as stimulus time
        'StateChangeConditions', {'Tup', 'Response'}, ...
        'OutputActions', {'HiFi1', ['P' 0],'GlobalTimerTrig', 2});
    
    if isCatchTrial
        % NoReward state for catch trials
        sma = AddState(sma, 'Name', 'Response', ...
            'Timer', ResWin, ...
            'StateChangeConditions', {'Tup', 'Checking'}, ...
            'OutputActions', {});
    else
        % Response state for regular trials
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

    % Set condition to check if GlobalTimer2 has ended
    sma = SetCondition(sma, 4, 'GlobalTimer2', 0); % Condition 4: GlobalTimer2 has ended
    
    % Checking state
    sma = AddState(sma, 'Name', 'Checking', ...
        'Timer', 0, ...  
        'StateChangeConditions', {'Condition4', 'exit'}, ...
        'OutputActions', {});
    
    % TimeOutState for trials that timeout
    sma = AddState(sma, 'Name', 'TimeOutState', ...
        'Timer', 0.25, ...
        'StateChangeConditions', {'Tup', 'exit'}, ...
        'OutputActions', {});
end

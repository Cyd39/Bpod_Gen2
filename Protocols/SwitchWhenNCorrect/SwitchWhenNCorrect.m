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
    Ramp = StimParams.Ramp;
    
    NumTrials = StimParams.Behave.NumTrials; 
    StimDur = StimParams.Duration/1000;
    
    % Generate LeftRight stimulus sequence tables
    LeftRightSeq = GenLeftRightSeq(StimParams);
    
    % Get side configuration from StimParamGui (once at the beginning)
    if isfield(StimParams.Behave, 'CorrectSpout')
        highFreqSpout = StimParams.Behave.CorrectSpout; % 1 = left, 2 = right
        lowFreqSpout = 3 - highFreqSpout; % Opposite of high frequency spout
    else
        % Default configuration if not specified
        highFreqSpout = 2; % Default: high frequency -> right
        lowFreqSpout = 1;  % Default: low frequency -> left
        warning('CorrectSpout not found in StimParams.Behave, using default configuration (high freq -> right, low freq -> left)');
    end
    
    % Display configuration for user verification
    spoutNames = {'left', 'right'};
    disp(['=== Side Configuration ===']);
    disp(['High frequency -> ' spoutNames{highFreqSpout} ' spout']);
    disp(['Low frequency -> ' spoutNames{lowFreqSpout} ' spout']);
    disp(['==========================']);
    
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
    S.GUI.NCorrectToSwitch = NumTrials; % Number of correct trials needed to switch sides；by default, it is the total number of trials
    S.GUI.CutOffPeriod = 60; % seconds
    
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
    
    % Initialize StimTable as empty table (will be populated trial by trial)
    BpodSystem.Data.StimTable = table();
    
    %% Initialize plots
    % Initialize the outcome plot with different trial types for left/right spouts
    trialTypes = ones(1, NumTrials); % Will be updated based on correctSide (1=left, 2=right)
    outcomePlot = LiveOutcomePlot([1 2], {'Left Spout', 'Right Spout'}, trialTypes, NumTrials); % Create an instance of the LiveOutcomePlot GUI
    % Arg1 = trialTypeManifest, a list of possible trial types (1=left, 2=right).
    % Arg2 = trialTypeNames, a list of names for each trial type in trialTypeManifest
    % Arg3 = trialTypes, a list of integers denoting precomputed trial types in the session
    % Arg4 = nTrialsToShow, the number of trials to show
    outcomePlot.RewardStateNames = {'LeftReward', 'RightReward'}; % List of state names where reward was delivered
    outcomePlot.CorrectStateNames = {'LeftReward', 'RightReward'}; % States where correct response was made 
    
    % Initialize trial tracking variables
    currentSide = 1; % 1 = low frequency side, 2 = high frequency side (left/right mapping determined by highFreqSpout/lowFreqSpout configuration)
    correctCount = 0; % Counter for correct trials on current side
    highFreqIndex = 1; % Index for high frequency table (continuous)
    lowFreqIndex = 1; % Index for low frequency table (continuous)
    
    % Initialize data arrays
    BpodSystem.Data.CurrentSide = [];
    BpodSystem.Data.CorrectSide = [];
    BpodSystem.Data.IsCorrect = [];
    BpodSystem.Data.CorrectCount = [];
    BpodSystem.Data.IsCatchTrial = [];
    BpodSystem.Data.CurrentStimRow = cell(1, NumTrials);
    
    %% Initialize custom figure for lick interval, response latency histograms, raster plot, and session summary
    customPlotFig = figure('Name', 'Behavior Analysis', 'Position', [100 100 1000 420]);
    % Upper left subplot for lick intervals
    lickIntervalAx = subplot(2, 3, 1);
    title(lickIntervalAx, 'Lick Intervals Distribution');
    xlabel(lickIntervalAx, 'Lick Interval (seconds)');
    ylabel(lickIntervalAx, 'Count');
    grid(lickIntervalAx, 'on');
    hold(lickIntervalAx, 'on');
    % Lower left subplot for response latency
    resLatencyAx = subplot(2, 3, 4);
    title(resLatencyAx, 'Response Latency Distribution');
    xlabel(resLatencyAx, 'Response Latency (seconds)');
    ylabel(resLatencyAx, 'Count');
    grid(resLatencyAx, 'on');
    hold(resLatencyAx, 'on');
    % Middle panel (spans both rows) for raster plot
    rasterAx = subplot(2, 3, [2, 5]);
    title(rasterAx, 'Licks aligned to stimulus onset');
    xlabel(rasterAx, 'Time re stim. onset (s)');
    ylabel(rasterAx, 'Trial number');
    grid(rasterAx, 'on');
    hold(rasterAx, 'on');
    % Right panel (spans both rows) for session summary
    summaryAx = subplot(2, 3, [3, 6]);
    axis(summaryAx, 'off');
    title(summaryAx, 'Session Summary', 'FontSize', 12, 'FontWeight', 'bold');
    % Register figure with BpodSystem so it closes when protocol ends
    BpodSystem.ProtocolFigures.CustomPlotFig = customPlotFig;
    
    

    %% Prepare and start first trial
    [sma, S] = PrepareStateMachine(S, LeftRightSeq, CalTable, H, currentSide, highFreqIndex, lowFreqIndex, correctCount, CutOffPeriod, StimDur, highFreqSpout, lowFreqSpout, Ramp);
    trialManager.startTrial(sma);
    
    %% Main loop, runs once per trial
    for currentTrial = 1:NumTrials
        % Check if update button was pressed
        if updateFlag
            % Get parameters from GUI
            S = BpodParameterGUI('sync', S);
            updateFlag = false; % reset flag
        end
        
        % Wait for trigger states (LeftReward, RightReward, WaitToFinish)
        trialManager.getCurrentEvents({'LeftReward', 'RightReward', 'WaitToFinish'});
        if BpodSystem.Status.BeingUsed == 0; return; end % If user hit console "stop" button, end session
        
        % Prepare next trial's state machine if not the last trial
        if currentTrial < NumTrials
            [sma, S] = PrepareStateMachine(S, LeftRightSeq, CalTable, H, currentSide, highFreqIndex, lowFreqIndex, correctCount, CutOffPeriod, StimDur, highFreqSpout, lowFreqSpout, Ramp);
            SendStateMachine(sma, 'RunASAP'); % Send next trial's state machine during current trial
        end
        
        % Get trial data
        RawEvents = trialManager.getTrialData;
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
            ResWin = S.ResWin;
            CutOff = S.GUI.CutOffPeriod;
            
            % Save timing of the trial
            BpodSystem.Data.ITIBefore(currentTrial) = ITIBefore;
            BpodSystem.Data.ITIAfter(currentTrial) = ITIAfter;
            BpodSystem.Data.ThisITI(currentTrial) = ThisITI;
            BpodSystem.Data.QuietTime(currentTrial) = QuietTime;
            BpodSystem.Data.TimerDuration(currentTrial) = TimerDuration;
            BpodSystem.Data.RewardAmount(currentTrial) = RewardAmount;
            BpodSystem.Data.ResWin(currentTrial) = ResWin;
            BpodSystem.Data.CutOff(currentTrial) = CutOff;
            
            % Save stimulus information
            BpodSystem.Data.CurrentStimRow{currentTrial} = currentStimRow;
            BpodSystem.Data.CorrectSide(currentTrial) = correctSide;
            BpodSystem.Data.CurrentSide(currentTrial) = currentSide;
            BpodSystem.Data.IsCatchTrial(currentTrial) = isCatchTrial;
            
            % Check if response was correct (only for non-catch trials)
            if ~isCatchTrial
                % Check if animal licked correct side and got reward
                % Need to check if state was actually visited (not just exists as NaN)
                leftRewardVisited = isfield(BpodSystem.Data.RawEvents.Trial{currentTrial}.States, 'LeftReward') && ...
                    ~isnan(BpodSystem.Data.RawEvents.Trial{currentTrial}.States.LeftReward(1));
                rightRewardVisited = isfield(BpodSystem.Data.RawEvents.Trial{currentTrial}.States, 'RightReward') && ...
                    ~isnan(BpodSystem.Data.RawEvents.Trial{currentTrial}.States.RightReward(1));
                
                if leftRewardVisited || rightRewardVisited
                    % Animal licked correct side and got reward - correct response
                    isCorrect = true;
                    correctCount = correctCount + 1;
                    disp(['Trial ' num2str(currentTrial) ': Correct response! Count: ' num2str(correctCount)]);
                else
                    % Animal did not lick correct side - incorrect response
                    isCorrect = false;
                    % Do NOT reset counter - keep cumulative count
                    disp(['Trial ' num2str(currentTrial) ': Incorrect response. Count remains: ' num2str(correctCount)]);
                end
            else
                % Catch trial - no response expected
                isCorrect = true; % Don't count catch trials
                disp(['Trial ' num2str(currentTrial) ': Catch trial - no response expected.']);
            end
            
            % Save response information
            BpodSystem.Data.IsCorrect(currentTrial) = isCorrect;
            BpodSystem.Data.CorrectCount(currentTrial) = correctCount;
            
            % Update trial type for outcome plot based on correct side
            trialTypes(currentTrial) = correctSide; % 1 = left spout, 2 = right spout
            
            % Extend trialTypes array to prevent index out of bounds in LiveOutcomePlot
            % The plot window may extend beyond NumTrials, so we need extra elements
            % Calculate maximum possible index: currentTrial + nTrialsToShow - 1
            maxPossibleIndex = currentTrial + outcomePlot.nTrialsToShow - 1;
            if length(trialTypes) < maxPossibleIndex
                % Extend array with default value (1 = left spout) for future trials
                trialTypes(end+1:maxPossibleIndex) = 1;
            end
            
            % Add current trial's stimRow to StimTable
            currentStimRow = BpodSystem.Data.CurrentStimRow{currentTrial};
            if ~isempty(currentStimRow)
                if height(BpodSystem.Data.StimTable) == 0
                    % First trial - create table
                    BpodSystem.Data.StimTable = currentStimRow;
                else
                    % Append to existing table
                    BpodSystem.Data.StimTable = [BpodSystem.Data.StimTable; currentStimRow];
                end
            end
            
            % Check if we need to switch sides
            if correctCount >= S.GUI.NCorrectToSwitch
                % Switch to the other side
                if currentSide == 1
                    currentSide = 2; % Switch to high frequency
                    disp(['Switching to high frequency side after ' num2str(correctCount) ' cumulative correct trials']);
                else
                    currentSide = 1; % Switch to low frequency
                    disp(['Switching to low frequency side after ' num2str(correctCount) ' cumulative correct trials']);
                end
                correctCount = 0; % Reset counter for new side
            end
            
            % Update indices for next trial (independent continuous indexing, no cycling)
            if currentSide == 1 % Low frequency side
                lowFreqIndex = lowFreqIndex + 1;
                % Continue reading beyond table length if needed
            else % High frequency side
                highFreqIndex = highFreqIndex + 1;
                % Continue reading beyond table length if needed
            end
            
            % Update outcome plot
            outcomePlot.update(trialTypes, BpodSystem.Data);
            
            % Update lick interval, response latency histograms, raster plot, and session summary
            try
                OnlineLickInterval(customPlotFig, lickIntervalAx, BpodSystem.Data);
                OnlineResLatency(customPlotFig, resLatencyAx, BpodSystem.Data);
                OnlineRasterPlot(customPlotFig, rasterAx, BpodSystem.Data);
                OnlineSessionSummary(customPlotFig, summaryAx, BpodSystem.Data);
            catch ME
                % Silent error handling - don't let plot errors interrupt the protocol
                disp(['Plot update error: ' ME.message]);
            end
            
            SaveBpodSessionData;
        end
    end
    
    % Session completed successfully
    disp(' ');
    disp('========================================');
    disp(['Session completed: ' num2str(NumTrials) ' trials finished']);
    disp('========================================');
    
    % Calculate session statistics
    nRewards = 0;
    nHits = 0;
    nCatchTrials = 0;
    for i = 1:NumTrials
        if isfield(BpodSystem.Data.RawEvents.Trial{i}, 'States')
            % Check if animal received reward (either left or right)
            leftRewardVisited = isfield(BpodSystem.Data.RawEvents.Trial{i}.States, 'LeftReward') && ...
                ~isnan(BpodSystem.Data.RawEvents.Trial{i}.States.LeftReward(1));
            rightRewardVisited = isfield(BpodSystem.Data.RawEvents.Trial{i}.States, 'RightReward') && ...
                ~isnan(BpodSystem.Data.RawEvents.Trial{i}.States.RightReward(1));
            if leftRewardVisited || rightRewardVisited
                nRewards = nRewards + 1;
            end
            % Count hits (correct responses, excluding catch trials)
            if BpodSystem.Data.IsCatchTrial(i)
                nCatchTrials = nCatchTrials + 1;
            elseif leftRewardVisited || rightRewardVisited
                nHits = nHits + 1;
            end
        end
    end
    
    % Display session statistics
    disp(' ');
    disp('--- Session Statistics ---');
    disp(['Total trials: ' num2str(NumTrials)]);
    disp(['Catch trials: ' num2str(nCatchTrials)]);
    nRegularTrials = NumTrials - nCatchTrials;
    if nRegularTrials > 0
        disp(['Regular trials: ' num2str(nRegularTrials)]);
        disp(['Correct trials (hits): ' num2str(nHits)]);
        disp(['Rewarded in ' num2str(nRewards) ' trials']);
        disp(['Hit rate: ' sprintf('%.1f', nHits/nRegularTrials*100) '%']);
    else
        disp(['Rewarded in ' num2str(nRewards) ' trials']);
    end
    disp('==========================');
    disp(' ');
    
    % Final save to ensure all data is persisted
    SaveBpodSessionData;
end

function [sma, S] = PrepareStateMachine(S, LeftRightSeq, CalTable, H, currentSide, highFreqIndex, lowFreqIndex, ~, CutOffPeriod, StimDur, highFreqSpout, lowFreqSpout, Ramp)
    % Prepare state machine for the current trial
    
    % Sync parameters with GUI
    S = BpodParameterGUI('sync', S);
    
    % Determine which stimulus table to use based on current side
    if currentSide == 1 % Low frequency side
        % Direct indexing (table length matches trial count)
        currentStimRow = LeftRightSeq.LowFreqTable(lowFreqIndex, :);
        correctSide = lowFreqSpout; % Use configured low frequency spout
    else % High frequency side
        % Direct indexing (table length matches trial count)
        currentStimRow = LeftRightSeq.HighFreqTable(highFreqIndex, :);
        correctSide = highFreqSpout; % Use configured high frequency spout
    end
    
    % Generate sound&vibration waveform
    soundWave = GenStimWave(currentStimRow, CalTable);
    soundWave = ApplySinRamp(soundWave, Ramp, H.SamplingRate);
    
    % Display trial info with configuration
    spoutNames = {'left', 'right'};
    if currentSide == 1
        sideName = 'low freq';
    else
        sideName = 'high freq';
    end
    disp(['Current side = ' num2str(currentSide) ' (' sideName '), Correct side = ' num2str(correctSide) ' (' spoutNames{correctSide} ')']);
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
    % Get valve times for both left (valve 1) and right (valve 2) ports
    ValveTimes = BpodLiquidCalibration('GetValveTimes', RewardAmount, [1 2]);
    LeftValveTime = ValveTimes(1);
    RightValveTime = ValveTimes(2);
    ResWin = S.GUI.ResWin;
    CutOff = CutOffPeriod;
    
    % Convert CorrectSide to response direction
    if correctSide == 1
        correctResponse = 'left';
    elseif correctSide == 2
        correctResponse = 'right';
    elseif correctSide == 3
        correctResponse = 'boundary'; % Special case for boundary frequency
    else
        correctResponse = 'left'; % Default fallback
    end
    
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
    S.LeftValveTime = LeftValveTime;
    S.RightValveTime = RightValveTime;
    S.ResWin = ResWin;
    S.CutOff = CutOff;

    % Create state machine
    sma = NewStateMachine();
  
    % Set condition for BNC1 state
    sma = SetCondition(sma, 1, 'BNC1', 0); % Condition 1: BNC1 is HIGH (licking detected)
    sma = SetCondition(sma, 2, 'BNC1', 1); % Condition 2: BNC1 is LOW (no licking detected)
    sma = SetCondition(sma, 3, 'BNC2', 0); % Condition 1: BNC1 is HIGH (licking detected)
    sma = SetCondition(sma, 4, 'BNC2', 1); % Condition 2: BNC1 is LOW (no licking detected)
    

    % Set timer and condition for the cut-off period
    sma = SetGlobalTimer(sma, 'TimerID', 1, 'Duration', CutOff);
    sma = SetCondition(sma, 5, 'GlobalTimer1', 0); % Condition 3: GlobalTimer1 has ended

    % Set Condition for Port1In as manual Switch for reward given together with stimulus
    sma = SetCondition(sma, 6, 'Port1In', 0);
    
    % Add states
    % Ready state under different conditions
    if ITIBefore-QuietTime > 0
        sma = AddState(sma, 'Name', 'Ready', ...
            'Timer', ITIBefore-QuietTime, ...
            'StateChangeConditions', {'Tup', 'NoLick'}, ...
            'OutputActions', {'GlobalTimerTrig', 1});
        sma = AddState(sma, 'Name', 'NoLick', ...
            'Timer', QuietTime, ...
            'StateChangeConditions', {'Condition1', 'ResetNoLick','Condition3', 'ResetNoLick', 'Tup', 'Stimulus','Condition5', 'Stimulus'}, ...
            'OutputActions', {});
        sma = AddState(sma, 'Name', 'ResetNoLick', ...
            'Timer', 0, ...
            'StateChangeConditions', {'Condition2', 'NoLick','Condition4', 'NoLick','Condition5', 'Stimulus'}, ...
            'OutputActions', {});
    else
        sma = AddState(sma, 'Name', 'Ready', ...
            'Timer', ITIBefore, ...
            'StateChangeConditions', {'Condition1', 'ResetNoLick','Condition3', 'ResetNoLick','Tup', 'Stimulus'}, ...
            'OutputActions', {'GlobalTimerTrig', 1});
        sma = AddState(sma, 'Name', 'NoLick', ...
            'Timer', QuietTime, ...
            'StateChangeConditions', {'Condition1', 'ResetNoLick', 'Condition3', 'ResetNoLick','Tup', 'Stimulus'}, ...
            'OutputActions', {});
        sma = AddState(sma, 'Name', 'ResetNoLick', ...
            'Timer', 0, ...
            'StateChangeConditions', {'Condition2', 'NoLick','Condition4', 'NoLick','Condition5', 'Stimulus'}, ...
            'OutputActions', {});
    end

    % The timer begins at the stimulus state, the duration is Stimulus+ITI
    sma = SetGlobalTimer(sma, 'TimerID', 2, 'Duration', TimerDuration); 

    % Stimulus state - plays stimulus until animal licks correct side
    if isCatchTrial
        % Catch trial - no response expected, just play stimulus for fixed duration
        sma = AddState(sma, 'Name', 'Stimulus', ...
            'Timer', 0.2, ... % Fixed duration for catch trials
            'StateChangeConditions', {'Tup', 'WaitToFinish'}, ...
            'OutputActions', {'HiFi1', ['P' 0],'GlobalTimerTrig', 2});
    else
        % Regular trial - stimulus plays until correct lick
        if strcmp(correctResponse, 'left')
            % Left is correct - only respond to left lick (BNC1High)
            sma = AddState(sma, 'Name', 'Stimulus', ...
                'Timer', ResWin, ... % Response window
                'StateChangeConditions', {'BNC1High', 'LeftReward', 'BNC2High', 'WaitToFinish', 'Tup', 'WaitToFinish','Condition6', 'LeftReward'}, ...
                'OutputActions', {'HiFi1', ['P' 0],'GlobalTimerTrig', 2});
        elseif strcmp(correctResponse, 'right')
            % Right is correct - only respond to right lick (BNC2High)
            sma = AddState(sma, 'Name', 'Stimulus', ...
                'Timer', ResWin, ... 
                'StateChangeConditions', {'BNC1High', 'WaitToFinish', 'BNC2High', 'RightReward', 'Tup', 'WaitToFinish','Condition6', 'RightReward'}, ...
                'OutputActions', {'HiFi1', ['P' 0],'GlobalTimerTrig', 2});
        elseif strcmp(correctResponse, 'boundary')
            % Boundary frequency - both sides are correct
            sma = AddState(sma, 'Name', 'Stimulus', ...
                'Timer', ResWin, ... 
                'StateChangeConditions', {'BNC1High', 'LeftReward', 'BNC2High', 'RightReward', 'Tup', 'WaitToFinish'}, ...
                'OutputActions', {'HiFi1', ['P' 0],'GlobalTimerTrig', 2});
        end
        
        % Left reward state - always reward for correct left lick
        sma = AddState(sma, 'Name', 'LeftReward', ...
            'Timer', LeftValveTime, ...
            'StateChangeConditions', {'Tup', 'WaitToFinish'}, ...
            'OutputActions', {'ValveState', 1}); % Valve 1 for left port
        
        % Right reward state - always reward for correct right lick
        sma = AddState(sma, 'Name', 'RightReward', ...
            'Timer', RightValveTime, ...
            'StateChangeConditions', {'Tup', 'WaitToFinish'}, ...
            'OutputActions', {'ValveState', 2}); % Valve 2 for right port
    end

    % Set condition to check if GlobalTimer2 has ended
    sma = SetCondition(sma, 7, 'GlobalTimer2', 0); % Condition 7: GlobalTimer2 has ended
    
    % Checking state
    sma = AddState(sma, 'Name', 'WaitToFinish', ...
        'Timer', 0, ...  
        'StateChangeConditions', {'Condition7', 'exit'}, ...
        'OutputActions', {});
    
end

    % AntiBias protocol (TrialManager version)
    % This protocol is used to train the animal to respond to the correct side with anti-bias logic
function AntiBias()
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
 
    % Save Protocol name and Subject name to Data.Info
    BpodSystem.Data.Info.ProtocolName = BpodSystem.GUIData.ProtocolName;
    BpodSystem.Data.Info.SubjectName = BpodSystem.GUIData.SubjectName;
    
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
    S.GUI.CutOffPeriod = 60; % seconds
    CutOffPeriod = S.GUI.CutOffPeriod;

    % Initialize parameter GUI
    BpodParameterGUI('init', S);
    
    % Create update button
    uicontrol('Style', 'pushbutton', ...
        'String', 'Update Parameters', ...
        'Position', [250 310 150 30], ...
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
    currentSide = 1; % 1 = low frequency side, 2 = high frequency side (spout determined by highFreqSpout/lowFreqSpout configuration)
    highFreqIndex = 1; % Index for high frequency table (continuous)
    lowFreqIndex = 1; % Index for low frequency table (continuous)
    
    % Generate catch trial sequence based on PropCatch
    propCatch = StimParams.Behave.PropCatch;
    catchTrialSequence = false(1, NumTrials);
    if propCatch > 0
        % calculate grouping parameters
        trialsPerBlock = round(1 / propCatch); % trials per block
        nBlocks = floor(NumTrials / trialsPerBlock); % total number of blocks
        if nBlocks > 0
            % generate random positions for each block (vectorized operation)
            blockOffsets = (0:nBlocks-1)' * trialsPerBlock;
            randomPositions = randi(trialsPerBlock, nBlocks, 1);
            % calculate all catch trial positions
            catchTrialIndices = blockOffsets + randomPositions;
            % Ensure indices don't exceed NumTrials
            catchTrialIndices = catchTrialIndices(catchTrialIndices <= NumTrials);
            catchTrialSequence(catchTrialIndices) = true;
        end
    end
    
    % Initialize data arrays
    BpodSystem.Data.CurrentSide = [];
    BpodSystem.Data.CorrectSide = [];
    BpodSystem.Data.IsCatchTrial = [];
    BpodSystem.Data.CurrentStimRow = cell(1, NumTrials);
    
    %% Initialize custom figure with layout matching MainAn_v2 combined figure
    % Layout: 3 rows x 3 columns
    % Row 1: PlotLickIntervals, PlotResLatency, PlotLickRaster
    % Row 2: PlotSessionSummary, PlotCDFHitRate, PlotBarResponse
    % Row 3: PlotHitResponseRate (centered), empty, empty
    customPlotFig = figure('Name', 'Behavior Analysis', 'Position', [100, 100, 1500, 800]);
    
    % Subplot 1: Session Summary (1,1) - left column, spans 2 rows
    summaryAx = subplot(3, 3, [1,4]);
    axis(summaryAx, 'off');
    
    % Subplot 2: Lick Intervals (1,2) - middle column, row 2
    lickIntervalAx = subplot(3, 3, 5);
    title(lickIntervalAx, 'Lick Intervals Distribution');
    xlabel(lickIntervalAx, 'Lick Interval (seconds)');
    ylabel(lickIntervalAx, 'Count');
    grid(lickIntervalAx, 'on');
    hold(lickIntervalAx, 'on');
    
    % Subplot 3: Response Latency (1,3) - middle column, row 3
    resLatencyAx = subplot(3, 3, 6);
    title(resLatencyAx, 'Response Latency Distribution');
    xlabel(resLatencyAx, 'Response Latency (seconds)');
    ylabel(resLatencyAx, 'Count');
    grid(resLatencyAx, 'on');
    hold(resLatencyAx, 'on');
    
    % Subplot 4: Lick Raster (2,1) - top 2 rows, spans 2 columns (split into 2 subplots)
    rasterAx1 = subplot(3, 3, 2);
    title(rasterAx1, 'Licks aligned to stimulus onset (full range)');
    xlabel(rasterAx1, 'Time re stim. onset (s)');
    ylabel(rasterAx1, 'Trial number');
    grid(rasterAx1, 'on');
    hold(rasterAx1, 'on');
    
    rasterAx2 = subplot(3, 3, 3);
    title(rasterAx2, 'Licks aligned to stimulus onset (response window)');
    xlabel(rasterAx2, 'Time re stim. onset (s)');
    ylabel(rasterAx2, 'Trial number');
    grid(rasterAx2, 'on');
    hold(rasterAx2, 'on');
    
    % Subplot 5: CDF Hit Rate (2,2) - middle column, row 3
    cdfHitRateAx = subplot(3, 3, 8);
    title(cdfHitRateAx, 'CDF of Hit Rate');
    xlabel(cdfHitRateAx, 'Reaction Time (s)');
    ylabel(cdfHitRateAx, 'Cumulative Proportion');
    grid(cdfHitRateAx, 'on');
    hold(cdfHitRateAx, 'on');
    
    % Subplot 6: Bar Response (2,3) - right column, row 2
    barResponseAx = subplot(3, 3, 7);
    title(barResponseAx, 'Response Rate by Condition');
    xlabel(barResponseAx, 'Condition');
    ylabel(barResponseAx, 'Response Rate');
    grid(barResponseAx, 'on');
    hold(barResponseAx, 'on');
    
    % Subplot 7: Hit Response Rate (3,2) - right column, row 3
    responseRateAx = subplot(3, 3, 9);
    title(responseRateAx, 'Hit Rate and Response Rate');
    xlabel(responseRateAx, 'Trial number');
    ylabel(responseRateAx, 'Rate');
    grid(responseRateAx, 'on');
    hold(responseRateAx, 'on');
    
    % Adjust subplot spacing for better layout
    set(customPlotFig, 'Units', 'normalized');
    
    % Add overall title
    sgtitle(customPlotFig, ['Behavior Analysis: ' BpodSystem.GUIData.SubjectName], ...
        'FontSize', 14, 'FontWeight', 'bold', 'Interpreter', 'none');
    
    % Register figure with BpodSystem so it closes when protocol ends
    BpodSystem.ProtocolFigures.CustomPlotFig = customPlotFig;
    
    

    %% Prepare and start first trial
    % Use catchTrialSequence(1) for the first trial
    [sma, S] = PrepareStateMachine(S, LeftRightSeq, CalTable, H, currentSide, highFreqIndex, lowFreqIndex, 0, CutOffPeriod, StimDur, highFreqSpout, lowFreqSpout, Ramp, catchTrialSequence(1));
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
        
        % Get trial data
        RawEvents = trialManager.getTrialData;
        if BpodSystem.Status.BeingUsed == 0; return; end % If user hit console "stop" button, end session
        
        % Save all trial parameters from S BEFORE preparing next trial
        % For subsequent trials, S was set in previous iteration.
        if ~isempty(fieldnames(RawEvents))
            BpodSystem.Data.CurrentSide(currentTrial) = currentSide;
            % Derive correctSide from currentSide using configuration
            if currentSide == 1  % Low frequency side
                correctSideForThisTrial = lowFreqSpout;
            else % High frequency side
                correctSideForThisTrial = highFreqSpout;
            end
            BpodSystem.Data.CorrectSide(currentTrial) = correctSideForThisTrial;
            % Save all other parameters from S (before S gets updated for next trial)
            BpodSystem.Data.IsCatchTrial(currentTrial) = S.IsCatchTrial;
            BpodSystem.Data.CurrentStimRow{currentTrial} = S.CurrentStimRow;
            BpodSystem.Data.ITIBefore(currentTrial) = S.ITIBefore;
            BpodSystem.Data.ITIAfter(currentTrial) = S.ITIAfter;
            BpodSystem.Data.ThisITI(currentTrial) = S.ThisITI;
            BpodSystem.Data.QuietTime(currentTrial) = S.QuietTime;
            BpodSystem.Data.TimerDuration(currentTrial) = S.TimerDuration;
            BpodSystem.Data.RewardAmount(currentTrial) = S.RewardAmount;
            BpodSystem.Data.ResWin(currentTrial) = S.ResWin;
            BpodSystem.Data.CutOff(currentTrial) = S.GUI.CutOffPeriod;
        end
        
        % Process trial data if available (needed for PickSideAntiBias)
        if ~isempty(fieldnames(RawEvents))
            BpodSystem.Data = AddTrialEvents(BpodSystem.Data, RawEvents);
            BpodSystem.Data.TrialSettings(currentTrial) = S;
            
            % Save trial timestamp
            BpodSystem.Data.TrialStartTimestamp(currentTrial) = RawEvents.TrialStartTimestamp;
            
            % Get current trial parameters from saved data (all were saved earlier to avoid shift)         
            correctSide = BpodSystem.Data.CorrectSide(currentTrial);
            
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
        end
        
        % Determine next side based on trial number (BEFORE preparing next trial's state machine)
        if currentTrial < NumTrials
            % Determine next side based on anti-bias logic
            % PickSideAntiBias returns left/right spout (1=left, 2=right)
            nextSpout = PickSideAntiBias(BpodSystem.Data);
                
            % Convert spout selection to frequency side (1=low freq, 2=high freq)
            % Here currentSide is the frequency side, not the spout side（for the next trial）
            if nextSpout == lowFreqSpout
                currentSide = 1; % Low frequency side
            else 
                currentSide = 2; % High frequency side
            end
                
            % Update indices for next trial (independent continuous indexing, no cycling)
            if currentSide == 1 % Low frequency side
                lowFreqIndex = lowFreqIndex + 1;
                % Continue reading beyond table length if needed
            else % High frequency side
                highFreqIndex = highFreqIndex + 1;
                % Continue reading beyond table length if needed
            end
            
            % Prepare next trial's state machine (using the updated currentSide)
            [sma, S] = PrepareStateMachine(S, LeftRightSeq, CalTable, H, currentSide, highFreqIndex, lowFreqIndex, 0, CutOffPeriod, StimDur, highFreqSpout, lowFreqSpout, Ramp, catchTrialSequence(currentTrial + 1));
            SendStateMachine(sma, 'RunASAP'); % Send next trial's state machine during current trial
        end
        
        % Handle pause condition
        HandlePauseCondition;
        
        % Start next trial if not the last one
        if currentTrial < NumTrials
            trialManager.startTrial(); % Start processing the next trial's events
        end
        
        % Update plots and save data
        if ~isempty(fieldnames(RawEvents))
            
            % Update outcome plot
            outcomePlot.update(trialTypes, BpodSystem.Data);
            
            % Update all plots with layout matching MainAn_v2 combined figure
            try
                PlotSessionSummary(BpodSystem.Data, 'FigureHandle', customPlotFig, 'Axes', summaryAx);
                PlotLickIntervals(BpodSystem.Data, 'FigureHandle', customPlotFig, 'Axes', lickIntervalAx);
                PlotResLatency(BpodSystem.Data, 'FigureHandle', customPlotFig, 'Axes', resLatencyAx);
                PlotLickRaster(BpodSystem.Data, 'FigureHandle', customPlotFig, 'Axes', {rasterAx1, rasterAx2});
                PlotCDFHitRate(BpodSystem.Data, 'FigureHandle', customPlotFig, 'Axes', cdfHitRateAx);
                PlotBarResponse(BpodSystem.Data, 'FigureHandle', customPlotFig, 'Axes', barResponseAx);
                PlotHitResponseRate(BpodSystem.Data, 'FigureHandle', customPlotFig, 'Axes', responseRateAx);
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
    
    % Final save to ensure all data is persisted
    SaveBpodSessionData;

    %Save Custom Plot Figure with subject name and date
    sessionDate = datetime(BpodSystem.Data.Info.SessionStartTime_MATLAB, ...
                      'ConvertFrom', 'datenum', ...
                      'Format', 'yyyyMMdd_HHmmss');
    savefig(customPlotFig, [BpodSystem.GUIData.SubjectName '_' char(sessionDate) '_CustomPlotFig.fig']);
end

function [sma, S] = PrepareStateMachine(S, LeftRightSeq, CalTable, H, currentSide, highFreqIndex, lowFreqIndex, ~, CutOffPeriod, StimDur, highFreqSpout, lowFreqSpout, Ramp, isCatchTrial)
    % Prepare state machine for the current trial
    % Input:
    %   isCatchTrial - boolean indicating if this is a catch trial
    
    % Sync parameters with GUI
    S = BpodParameterGUI('sync', S);
    
    % If catch trial, use CatchTrialTable
    if isCatchTrial
        currentStimRow = LeftRightSeq.CatchTrialTable(1, :);
        % For catch trials, correctSide doesn't matter (no reward), but we'll use currentSide for consistency
        if currentSide == 1
            correctSide = lowFreqSpout;
        else
            correctSide = highFreqSpout;
        end
    else
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

    if isCatchTrial
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
    sma = SetCondition(sma, 6, 'Port1', 0);
    
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
            'Timer', ResWin, ... % "Response window"
            'StateChangeConditions', {'Tup', 'WaitToFinish'}, ...
            'OutputActions', {'GlobalTimerTrig', 2});
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

    % Set condition to check if GlobalTimer2 has ended
    sma = SetCondition(sma, 7, 'GlobalTimer2', 0); % Condition 7: GlobalTimer2 has ended
    
    % Checking state
    sma = AddState(sma, 'Name', 'WaitToFinish', ...
        'Timer', 0, ...  
        'StateChangeConditions', {'Condition7', 'exit'}, ...
        'OutputActions', {});
    
end

% Conditioning protocol
% This protocol is used to condition the animal to the stimuli
% Water suspension is at the same time and side as the stimulus
% Stimuli will be played until the animal licks the spout
% Animal will be rewarded for licking the correct spout
% Animal will not be punished for licking the wrong spout
function Conditioning()
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
    % Initialize the outcome plot
    trialTypes = ones(1, NumTrials); % Only one trial type, all outcomes are 1
    outcomePlot = LiveOutcomePlot(1, {'Outcome'}, trialTypes, NumTrials); % Create an instance of the LiveOutcomePlot GUI
    % Arg1 = trialTypeManifest, a list of possible trial types (even if not yet in trialTypes).
    % Arg2 = trialTypeNames, a list of names for each trial type in trialTypeManifest
    % Arg3 = trialTypes, a list of integers denoting precomputed trial types in the session
    % Arg4 = nTrialsToShow, the number of trials to show
    outcomePlot.RewardStateNames = {'LeftReward', 'RightReward'}; % List of state names where reward was delivered
    outcomePlot.CorrectStateNames = {'LeftReward', 'RightReward'}; % States where correct response was made
    outcomePlot.ErrorStateNames = {'Checking'}; % States where incorrect response was made (timeout)
    outcomePlot.PunishStateNames = {}; % No punishment states in this protocol
    
    % Initialize reaction time plot
    figure('Name', 'Reaction Time Analysis', 'Position', [100, 100, 800, 400]);
    reactionTimePlot = axes;
    reactionTimes = []; % Store reaction times
    trialNumbers = [];  % Store trial numbers
    correctSides = [];  % Store correct sides for color coding
    hold(reactionTimePlot, 'on');
    xlabel('Trial Number');
    ylabel('Reaction Time (s)');
    title('Real-time Reaction Time Analysis');
    grid on;

    %% Prepare and start first trial
    genAndLoadStimulus(1);
    [sma, S, updateFlag, ThisITI, QuietTime, correctSide, RewardAmount] = PrepareStateMachine(S, 1, updateFlag); % Prepare state machine for trial 1 with empty "current events" variable
    
    % Store trial parameters before starting the trial
    BpodSystem.Data.ThisITI(1) = ThisITI;
    BpodSystem.Data.QuietTime(1) = QuietTime;
    BpodSystem.Data.CorrectSide(1) = correctSide;
    BpodSystem.Data.RewardAmount(1) = RewardAmount;
    
    displayTrialInfo(1, ThisITI, QuietTime, correctSide);
    trialManager.startTrial(sma); % Sends & starts running first trial's state machine. A MATLAB timer object updates the 
                                  % console UI, while code below proceeds in parallel.

    %% Main loop, runs once per trial
    for currentTrial = 1:NumTrials       
        if BpodSystem.Status.BeingUsed == 0; return; end % If user hit console "stop" button, end session
        if currentTrial < NumTrials
            genAndLoadStimulus(currentTrial+1);
            [sma, S, updateFlag, NextITI, NextQuietTime, NextCorrectSide, NextRewardAmount] = PrepareStateMachine(S, currentTrial+1, updateFlag); 
            
            % Store next trial parameters
            BpodSystem.Data.ThisITI(currentTrial+1) = NextITI;
            BpodSystem.Data.QuietTime(currentTrial+1) = NextQuietTime;
            BpodSystem.Data.CorrectSide(currentTrial+1) = NextCorrectSide;
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
            BpodSystem.Data = AddTrialEvents(BpodSystem.Data,RawEvents); % Computes trial events from raw data
            BpodSystem.Data.TrialSettings(currentTrial) = S; % Adds the settings used for the current trial to the Data struct
            % Save trial timestamp
            BpodSystem.Data.TrialStartTimestamp(currentTrial) = RawEvents.TrialStartTimestamp;
            % Trial parameters were already stored before the trial started
            
            % Calculate and store reaction time
            reactionTime = calculateReactionTime(RawEvents, currentTrial);
            if ~isnan(reactionTime)
                reactionTimes(end+1) = reactionTime;
                trialNumbers(end+1) = currentTrial;
                correctSides(end+1) = BpodSystem.Data.CorrectSide(currentTrial);
                BpodSystem.Data.ReactionTime(currentTrial) = reactionTime;
                
                % Update reaction time plot
                updateReactionTimePlot(reactionTimePlot, trialNumbers, reactionTimes, correctSides);
            end
            
            % Save data
            SaveBpodSessionData; % Saves the field BpodSystem.Data to the current data file
        end  
        outcomePlot.update(trialTypes, BpodSystem.Data); % Update the outcome plot
    end

    function [sma, S, updateFlag, ThisITI, QuietTime, correctSide, RewardAmount] = PrepareStateMachine(S, currentTrial, updateFlag)
        if updateFlag
            S = BpodParameterGUI('sync', S); % Sync parameters with BpodParameterGUI plugin
            updateFlag = false; % reset flag
        end

        % Generate random ITI for this trial
        ITIBefore = S.GUI.MinITI/2;
        ITIAfter = S.GUI.MinITI/2 + rand() * (S.GUI.MaxITI - S.GUI.MinITI);
        ThisITI = ITIBefore + ITIAfter;
        QuietTime = S.GUI.MinQuietTime + rand() * (S.GUI.MaxQuietTime - S.GUI.MinQuietTime);
        RewardAmount = S.GUI.RewardAmount;
        disp(['Trial ' num2str(currentTrial) ': Reward Amount = ' num2str(RewardAmount) ' µL']);
        
        % Get valve times for both left (valve 1) and right (valve 2) ports
        ValveTimes = BpodLiquidCalibration('GetValveTimes', RewardAmount, [1 2]);
        LeftValveTime = ValveTimes(1);
        RightValveTime = ValveTimes(2);

        % Determine correct response from StimTable
        correctSide = StimTable.CorrectSide(currentTrial);
        
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

        % Create state machine
        sma = NewStateMachine();

        % Set condition for BNC1 state
        sma = SetCondition(sma, 1, 'BNC1', 0); % Condition 1: BNC1 is HIGH (licking detected on left spout)
        sma = SetCondition(sma, 2, 'BNC1', 1); % Condition 2: BNC1 is LOW (no licking detected on left spout)
        sma = SetCondition(sma, 3, 'BNC2', 0); % Condition 3: BNC2 is HIGH (licking detected on right spout)
        sma = SetCondition(sma, 4, 'BNC2', 1); % Condition 4: BNC2 is LOW (no licking detected on right spout)
      
        % Add states
        % Ready state - simple ITI before stimulus
        sma = AddState(sma, 'Name', 'Ready', ...
            'Timer', ITIBefore, ...
            'StateChangeConditions', {'Tup', 'Stimulus'}, ...
            'OutputActions', {}); 

        % Stimulus state - plays stimulus until animal licks correct side
        if strcmp(correctResponse, 'left')
            % Left is correct - only respond to left lick
            sma = AddState(sma, 'Name', 'Stimulus', ...
                'Timer', 0, ... % No timer - stimulus plays until correct lick
                'StateChangeConditions', {'Condition1', 'LeftReward', 'Condition3', 'WrongLick'}, ...
                'OutputActions', {'HiFi1', ['P' 0]});
        elseif strcmp(correctResponse, 'right')
            % Right is correct - only respond to right lick
            sma = AddState(sma, 'Name', 'Stimulus', ...
                'Timer', 0, ... % No timer - stimulus plays until correct lick
                'StateChangeConditions', {'Condition1', 'WrongLick', 'Condition3', 'RightReward'}, ...
                'OutputActions', {'HiFi1', ['P' 0]});
        elseif strcmp(correctResponse, 'boundary')
            % Boundary frequency - both sides are correct
            sma = AddState(sma, 'Name', 'Stimulus', ...
                'Timer', 0, ... % No timer - stimulus plays until any lick
                'StateChangeConditions', {'Condition1', 'LeftReward', 'Condition3', 'RightReward'}, ...
                'OutputActions', {'HiFi1', ['P' 0]});
        end

        % Wrong lick state - animal licked wrong side, continue stimulus
        sma = AddState(sma, 'Name', 'WrongLick', ...
            'Timer', 0, ... % No timer - continue stimulus
            'StateChangeConditions', {'Tup', 'Stimulus'}, ...
            'OutputActions', {}); % Continue stimulus playback

        % Left reward state - always reward for correct left lick
        sma = AddState(sma, 'Name', 'LeftReward', ...
            'Timer', LeftValveTime, ...
            'StateChangeConditions', {'Tup', 'Checking'}, ...
            'OutputActions', {'ValveState', 1, 'HiFi1', 'X'}); % Valve 1 for left port, stop stimulus
        
        % Right reward state - always reward for correct right lick
        sma = AddState(sma, 'Name', 'RightReward', ...
            'Timer', RightValveTime, ...
            'StateChangeConditions', {'Tup', 'Checking'}, ...
            'OutputActions', {'ValveState', 2, 'HiFi1', 'X'}); % Valve 2 for right port, stop stimulus
    
        
        % Checking state - wait for trial to complete
        sma = AddState(sma, 'Name', 'Checking', ...
            'Timer', ITIAfter, ... % Brief pause before trial ends
            'StateChangeConditions', {'Tup', 'exit'}, ...
            'OutputActions', {});
    end

    function genAndLoadStimulus(currentTrial)
        % Generate sound&vibration waveform
        soundWave = GenStimWave(StimTable(currentTrial,:),CalTable);
        disp(StimTable(currentTrial,:));

        % Load the sound wave into BpodHiFi with loop mode
        % LoopMode = 1 (on), LoopDuration = 0 (loop indefinitely until stopped)
        H.load(1, soundWave, 'LoopMode', 1, 'LoopDuration', 0); 
        H.push();
        disp(['Trial ' num2str(currentTrial) ': Sound loaded to buffer 1 with infinite loop']);
    end

    function displayTrialInfo(currentTrial, ThisITI, QuietTime, correctSide)
        disp(['Trial ' num2str(currentTrial) ': CorrectSide = ' num2str(correctSide) ' (always rewarded)']);
        disp(['Trial ' num2str(currentTrial) ': ITI = ' num2str(ThisITI) ' seconds, QuietTime = ' num2str(QuietTime) ' seconds']);  
    end

    function reactionTime = calculateReactionTime(RawEvents, currentTrial)
        % Calculate reaction time from stimulus start to first lick
        reactionTime = NaN;
        
        try
            % Find stimulus start time (Stimulus state start)
            stimulusStartTime = NaN;
            if isfield(RawEvents.States, 'Stimulus')
                stimulusStartTime = RawEvents.States.Stimulus(1, 1);
            end
            
            % Find first lick time (BNC1 or BNC2 event)
            firstLickTime = NaN;
            if isfield(RawEvents.Events, 'BNC1')
                firstLickTime = RawEvents.Events.BNC1(1);
            elseif isfield(RawEvents.Events, 'BNC2')
                firstLickTime = RawEvents.Events.BNC2(1);
            end
            
            % Calculate reaction time
            if ~isnan(stimulusStartTime) && ~isnan(firstLickTime)
                reactionTime = firstLickTime - stimulusStartTime;
                disp(['Trial ' num2str(currentTrial) ': Reaction Time = ' num2str(reactionTime, '%.3f') ' seconds']);
            else
                disp(['Trial ' num2str(currentTrial) ': Could not calculate reaction time']);
            end
            
        catch ME
            disp(['Error calculating reaction time for trial ' num2str(currentTrial) ': ' ME.message]);
        end
    end

    function updateReactionTimePlot(plotHandle, trialNumbers, reactionTimes, correctSides)
        % Update the reaction time plot with new data
        try
            % Clear previous plot
            cla(plotHandle);
            
            % Define colors for different correct sides
            colors = [1 0 0; 0 0 1; 0 1 0]; % Red for left(1), Blue for right(2), Green for boundary(3)
            
            % Plot points with different colors based on correct side
            for i = 1:length(trialNumbers)
                colorIdx = min(correctSides(i), 3); % Ensure index is within bounds
                plot(plotHandle, trialNumbers(i), reactionTimes(i), 'o', ...
                    'Color', colors(colorIdx, :), 'MarkerSize', 8, 'MarkerFaceColor', colors(colorIdx, :));
            end
            
            % Add trend line
            if length(trialNumbers) > 1
                p = polyfit(trialNumbers, reactionTimes, 1);
                trendLine = polyval(p, trialNumbers);
                plot(plotHandle, trialNumbers, trendLine, 'k--', 'LineWidth', 2);
            end
            
            % Add legend
            legend(plotHandle, {'Left (1)', 'Right (2)', 'Boundary (3)', 'Trend'}, 'Location', 'best');
            
            % Update axis limits
            if ~isempty(reactionTimes)
                ylim(plotHandle, [0, max(reactionTimes) * 1.1]);
            end
            
            % Refresh plot
            drawnow;
            
        catch ME
            disp(['Error updating reaction time plot: ' ME.message]);
        end
    end

end
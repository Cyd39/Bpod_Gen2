% Conditioning protocol
% This protocol is used to condition the animal to the stimuli
% Water suspension is at the same time and side as the stimulus
% Stimuli will be played until the animal licks the spout
% Animal will be rewarded for licking the correct spout
% Animal will not be punished for licking the wrong spout
% Ramp duration should be set to 0.
function Conditioning()
    global BpodSystem

    %% Session Setup

    % Create trial manager object
    trialManager = BpodTrialManager;

    % get parameters from StimParamGui first
    StimParams = BpodSystem.ProtocolSettings.StimParams;

    % Initialize HiFi module with error handling
    try
        H = BpodHiFi('COM3'); 
        H.SamplingRate = 192000;
        disp('HiFi module connected successfully');
        
        % Set up HiFi envelope for both sound and vibration ramping
        % This envelope applies to both channels of the stereo output
        if isfield(StimParams, 'Ramp') && StimParams.Ramp > 0
            hifiEnvelope = GenHiFiEnvelope(StimParams.Ramp, H.SamplingRate);
            H.AMenvelope = hifiEnvelope;
            disp(['HiFi envelope set: ' num2str(StimParams.Ramp) 'ms ramps for both sound and vibration']);
        else
            H.AMenvelope = []; % No envelope
            disp('No HiFi envelope - no ramping applied');
        end
        
        % Set up automatic cleanup when function exits
        cleanupObj = onCleanup(@() cleanupHiFiConnection(H));
        
    catch ME
        disp(['Error connecting to HiFi: ' ME.message]);
        error('Failed to connect to HiFi module. Please check COM3 port and restart MATLAB.');
    end
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
    
    % Setup default parameters
    S = struct;
    % use the behavior parameters from StimParamGui as default values
    S.GUI.MinITI = StimParams.Behave.MinITI; % seconds
    S.GUI.MaxITI = StimParams.Behave.MaxITI; % seconds
    S.GUI.MinQuietTime = StimParams.Behave.MinQuietTime; % seconds
    S.GUI.MaxQuietTime = StimParams.Behave.MaxQuietTime; % seconds
    S.GUI.RewardAmount = StimParams.Behave.RewardAmount; % µL
    S.GUI.NCorrectToSwitch = 5; % Number of correct trials needed to switch sides
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

    % Save the LeftRightSeq and StimParams to SessionData
    BpodSystem.Data.LeftRightSeq = LeftRightSeq;
    BpodSystem.Data.StimParams = StimParams;
    
    % Initialize trial tracking variables for side switching
    currentSide = 1; % 1 = low frequency side, 2 = high frequency side (spout determined by CorrectSpout setting)
    correctCount = 0; % Counter for correct trials on current side
    highFreqIndex = 1; % Index for high frequency table (continuous)
    lowFreqIndex = 1; % Index for low frequency table (continuous)
    
    % Initialize data arrays for side tracking
    BpodSystem.Data.CurrentSide = [];
    BpodSystem.Data.CorrectCount = [];
    
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
    
    % Reaction time calculation variables (no plotting)
    % reactionTime is calculated and stored in BpodSystem.Data.ReactionTime

    %% Prepare and start first trial
    genAndLoadStimulus(1, currentSide, highFreqIndex, lowFreqIndex);
    [sma, S, updateFlag, ThisITI, QuietTime, correctSide, RewardAmount] = PrepareStateMachine(S, 1, updateFlag, currentSide, highFreqIndex, lowFreqIndex, highFreqSpout, lowFreqSpout); % Prepare state machine for trial 1 with empty "current events" variable
    
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
        if BpodSystem.Status.BeingUsed == 0
            % Clean up HiFi connection before exiting
            CleanupHiFi();
            return; 
        end % If user hit console "stop" button, end session
        if currentTrial < NumTrials
            genAndLoadStimulus(currentTrial+1, currentSide, highFreqIndex, lowFreqIndex);
            [sma, S, updateFlag, NextITI, NextQuietTime, NextCorrectSide, NextRewardAmount] = PrepareStateMachine(S, currentTrial+1, updateFlag, currentSide, highFreqIndex, lowFreqIndex, highFreqSpout, lowFreqSpout); 
            
            % Store next trial parameters
            BpodSystem.Data.ThisITI(currentTrial+1) = NextITI;
            BpodSystem.Data.QuietTime(currentTrial+1) = NextQuietTime;
            BpodSystem.Data.CorrectSide(currentTrial+1) = NextCorrectSide;
            BpodSystem.Data.RewardAmount(currentTrial+1) = NextRewardAmount;
            
            SendStateMachine(sma, 'RunASAP');   % Send the next trial's state machine during the current trial
        end
        RawEvents = trialManager.getTrialData; % Hangs here until trial is over, then retrieves full trial's raw data
        if BpodSystem.Status.BeingUsed == 0
            % Clean up HiFi connection before exiting
            CleanupHiFi();
            return; 
        end % If user hit console "stop" button, end session 
        HandlePauseCondition; % Checks to see if the protocol is paused. If so, waits until user resumes.
        if currentTrial < NumTrials
            trialManager.startTrial(); % Start processing the next trial's events (call with no argument since SM was already sent)
        end

        % If trial data was returned from last trial, update plots and save data
        if ~isempty(fieldnames(RawEvents)) 
            % Critical data processing (must be fast)
            BpodSystem.Data = AddTrialEvents(BpodSystem.Data,RawEvents); % Computes trial events from raw data
            BpodSystem.Data.TrialSettings(currentTrial) = S; % Adds the settings used for the current trial to the Data struct
            BpodSystem.Data.TrialStartTimestamp(currentTrial) = RawEvents.TrialStartTimestamp;
            
            % Calculate reaction time (fast operation)
            reactionTime = calculateReactionTime(RawEvents, currentTrial);
            if ~isnan(reactionTime)
                BpodSystem.Data.ReactionTime(currentTrial) = reactionTime;
            end
            
            % Every trial ends with correct response (stimulus plays until animal licks correctly)
            % So we always increment the counter
            correctCount = correctCount + 1;
            disp(['Trial ' num2str(currentTrial) ': Completed! Count: ' num2str(correctCount)]);
            
            % Save side tracking information
            BpodSystem.Data.CurrentSide(currentTrial) = currentSide;
            BpodSystem.Data.CorrectCount(currentTrial) = correctCount;
            
            % Check if we need to switch sides
            if correctCount >= S.GUI.NCorrectToSwitch
                % Switch to the other side
                if currentSide == 1
                    currentSide = 2; % Switch to high frequency
                    disp(['Switching to high frequency side after ' num2str(correctCount) ' completed trials']);
                else
                    currentSide = 1; % Switch to low frequency
                    disp(['Switching to low frequency side after ' num2str(correctCount) ' completed trials']);
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
            
            % Save data (critical for data integrity)
            SaveBpodSessionData;
            
            % Non-critical plotting operations (can be deferred)
            if mod(currentTrial, 5) == 0 || currentTrial == NumTrials % Update plots every 5 trials or at end
                try
                    % Update outcome plot
                    outcomePlot.update(trialTypes, BpodSystem.Data);
                catch ME
                    disp(['Plot update error: ' ME.message]);
                end
            end
        end

        % Handle pause condition
        HandlePauseCondition;  

        % Check if session should end
        if BpodSystem.Status.BeingUsed == 0
            disp('End of session');
            % Stop HiFi playback and clean up
            CleanupHiFi();
            
            % No custom figures to close
            
            return
        end
    end

    function [sma, S, updateFlag, ThisITI, QuietTime, correctSide, RewardAmount] = PrepareStateMachine(S, currentTrial, updateFlag, currentSide, highFreqIndex, lowFreqIndex, highFreqSpout, lowFreqSpout)
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

        % Determine correct response based on current side and configuration
        if currentSide == 1 % Low frequency side
            correctSide = lowFreqSpout; % Use configured low frequency spout
        else % High frequency side
            correctSide = highFreqSpout; % Use configured high frequency spout
        end
        
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
      
        % Add states
        sma = AddState(sma, 'Name', 'Ready', ...
            'Timer', ITIBefore, ...
            'StateChangeConditions', {'Tup', 'Stimulus'}, ...
            'OutputActions', {});

        % Stimulus state - plays stimulus until animal licks correct side
        if strcmp(correctResponse, 'left')
            % Left is correct - only respond to left lick
            sma = AddState(sma, 'Name', 'Stimulus', ...
                'Timer', 0, ... % No timer - stimulus plays until correct lick
                'StateChangeConditions', {'BNC1High', 'LeftReward', 'BNC2High', 'WrongLick'}, ...
                'OutputActions', {'HiFi1', ['P' 0]});
        elseif strcmp(correctResponse, 'right')
            % Right is correct - only respond to right lick
            sma = AddState(sma, 'Name', 'Stimulus', ...
                'Timer', 0, ... % No timer - stimulus plays until correct lick
                'StateChangeConditions', {'BNC1High', 'WrongLick', 'BNC2High', 'RightReward'}, ...
                'OutputActions', {'HiFi1', ['P' 0]});
        elseif strcmp(correctResponse, 'boundary')
            % Boundary frequency - both sides are correct
            sma = AddState(sma, 'Name', 'Stimulus', ...
                'Timer', 0, ... % No timer - stimulus plays until any lick
                'StateChangeConditions', {'BNC1High', 'LeftReward', 'BNC2High', 'RightReward'}, ...
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

    function genAndLoadStimulus(currentTrial, currentSide, highFreqIndex, lowFreqIndex)
        % Generate sound&vibration waveform based on current side
        if currentSide == 1 % Low frequency side
            currentStimRow = LeftRightSeq.LowFreqTable(lowFreqIndex, :);
        else % High frequency side
            currentStimRow = LeftRightSeq.HighFreqTable(highFreqIndex, :);
        end
        
        soundWave = GenStimWave(currentStimRow, CalTable);
        soundWave = soundWave(:,1:end-1); % remove the last sample.
        
        % Display trial info with configuration
        spoutNames = {'left', 'right'};
        if currentSide == 1
            sideName = 'low freq';
        else
            sideName = 'high freq';
        end
        disp(['Trial ' num2str(currentTrial) ': Current side = ' num2str(currentSide) ' (' sideName ')']);
        if currentSide == 1
            disp(['Low freq index: ' num2str(lowFreqIndex)]);
        else
            disp(['High freq index: ' num2str(highFreqIndex)]);
        end
        disp(currentStimRow);

        % Load the sound wave into BpodHiFi with loop mode
        % LoopMode = 1 (on), LoopDuration = 0 (loop indefinitely until stopped)
        H.load(1, soundWave, 'LoopMode', 1, 'LoopDuration', 0); 
        H.push();
        disp(['Trial ' num2str(currentTrial) ': Sound loaded to buffer 1 with infinite loop']);
    end

    function displayTrialInfo(currentTrial, ThisITI, QuietTime, correctSide)
        disp(['Trial ' num2str(currentTrial) ': CorrectSide = ' num2str(correctSide) ' (always rewarded)']);
        disp(['Trial ' num2str(currentTrial) ': ITI = ' num2str(ThisITI) ' seconds, QuietTime = ' num2str(QuietTime) ' seconds']);
        if currentTrial == 1
            disp(['Trial ' num2str(currentTrial) ': Water suspension enabled for first trial']);
        end
    end

    function reactionTime = calculateReactionTime(RawEvents, currentTrial)
        % Calculate reaction time from stimulus start to first lick (optimized)
        reactionTime = NaN;
        
        try
            % Quick check for required fields
            if ~isfield(RawEvents, 'States') || ~isfield(RawEvents, 'Events')
                return;
            end
            
            % Find stimulus start time (Stimulus state start)
            if isfield(RawEvents.States, 'Stimulus') && ~isempty(RawEvents.States.Stimulus)
                stimulusStartTime = RawEvents.States.Stimulus(1, 1);
            else
                return;
            end
            
            % Find first lick time (BNC1 or BNC2 event) - check both simultaneously
            firstLickTime = NaN;
            if isfield(RawEvents.Events, 'BNC1') && ~isempty(RawEvents.Events.BNC1)
                firstLickTime = RawEvents.Events.BNC1(1);
            end
            if isfield(RawEvents.Events, 'BNC2') && ~isempty(RawEvents.Events.BNC2)
                bnc2Time = RawEvents.Events.BNC2(1);
                if isnan(firstLickTime) || bnc2Time < firstLickTime
                    firstLickTime = bnc2Time;
                end
            end
            
            % Calculate reaction time
            if ~isnan(firstLickTime)
                reactionTime = firstLickTime - stimulusStartTime;
                % Only display every 10th trial to reduce console output
                if mod(currentTrial, 10) == 0
                    disp(['Trial ' num2str(currentTrial) ': Reaction Time = ' num2str(reactionTime, '%.3f') ' seconds']);
                end
            end
            
        catch
            % Silent error handling to avoid console spam
        end
    end


    %% Session cleanup
    % Ensure HiFi playback is stopped and resources are cleaned up
    try
        H.stop();
        disp('Session ended - HiFi playback stopped');
    catch
        disp('Warning: Could not stop HiFi playback at session end');
    end
    
    % Clear HiFi object to release serial port
    try
        clear H;
        disp('HiFi object cleared');
    catch
        disp('Warning: Could not clear HiFi object');
    end
    
    % No custom figures to close

end

function cleanupHiFiConnection(H)
% Cleanup function for HiFi connection
% This function is called automatically when the main function exits
    try
        if exist('H', 'var') && ~isempty(H)
            H.stop();
            clear H;
            disp('HiFi connection automatically cleaned up');
        end
    catch
        disp('Warning: Could not automatically clean up HiFi connection');
    end
end
% Categorization protocol
% This protocol is used to categorize the stimuli into different categories
% Currently this is a copy of the Detection protocol.
function Categorization()
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
    S.GUI.RewardAmount = StimParams.Behave.RewardAmount; % seconds
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
        % Get valve times for both left (valve 1) and right (valve 2) ports
        ValveTimes = BpodLiquidCalibration('GetValveTimes', RewardAmount, [1 2]);
        LeftValveTime = ValveTimes(1);
        RightValveTime = ValveTimes(2);
        ResWin = S.GUI.ResWin;
        CutOff = CutOffPeriod;
        
        % Display the trial information
        disp(['Trial ' num2str(currentTrial) ': ITI = ' num2str(ThisITI) ' seconds, QuietTime = ' num2str(QuietTime) ' seconds']);  

        % Create state machine
        sma = NewStateMachine();
      
        % Set conditions for lick detection
        sma = SetCondition(sma, 1, 'Port1', 0); % Condition 1: Port1 is LOW (left lick port out)
        sma = SetCondition(sma, 2, 'Port2', 0); % Condition 2: Port2 is LOW (right lick port out)
        sma = SetCondition(sma, 3, 'Port1', 1); % Condition 3: Port1 is HIGH (left lick port in)
        sma = SetCondition(sma, 4, 'Port2', 1); % Condition 4: Port2 is HIGH (right lick port in)

        % Set timer and condition for the cut-off period
        sma = SetGlobalTimer(sma, 'TimerID', 1, 'Duration', CutOff);
        sma = SetCondition(sma, 5, 'GlobalTimer1', 0); % Condition 5: GlobalTimer1 has ended
        
        % Add states
        % Ready state under different conditions
        if ITIBefore-QuietTime > 0
            sma = AddState(sma, 'Name', 'Ready', ...
                'Timer', ITIBefore-QuietTime, ...
                'StateChangeConditions', {'Tup', 'NoLick'}, ...
                'OutputActions', {'GlobalTimerTrig', 1});
            sma = AddState(sma, 'Name', 'NoLick', ...
                'Timer', QuietTime, ...
                'StateChangeConditions', {'Port1In', 'ResetNoLick','Port2In', 'ResetNoLick','Tup', 'Stimulus','Condition5', 'Stimulus'}, ... % Use port detection for lick monitoring
                'OutputActions', {});
            sma = AddState(sma, 'Name', 'ResetNoLick', ...
                'Timer', 0, ...
                'StateChangeConditions', {'Condition1', 'NoLick','Condition2', 'NoLick','Condition5', 'Stimulus'}, ... % Reset NoLick Timer when both ports are out
                'OutputActions', {});
        else
            sma = AddState(sma, 'Name', 'Ready', ...
                'Timer', ITIBefore, ...
                'StateChangeConditions', {'Port1In', 'ResetNoLick','Port2In', 'ResetNoLick','Tup', 'Stimulus'}, ...
                'OutputActions', {'GlobalTimerTrig', 1});
            sma = AddState(sma, 'Name', 'NoLick', ...
                'Timer', QuietTime, ...
                'StateChangeConditions', {'Port1In', 'ResetNoLick','Port2In', 'ResetNoLick', 'Tup', 'Stimulus','Condition5', 'Stimulus'}, ... % Use port detection for lick monitoring
                'OutputActions', {});
            sma = AddState(sma, 'Name', 'ResetNoLick', ...
                'Timer', 0, ...
                'StateChangeConditions', {'Condition1', 'NoLick','Condition2', 'NoLick','Condition5', 'Stimulus'}, ... % Reset NoLick Timer when both ports are out
                'OutputActions', {});
        end

        % the timer begins at the stimulus state， the duration is Stimulus+ITI
        sma = SetGlobalTimer(sma, 'TimerID', 2, 'Duration', TimerDuration); 

        % Stimulus state
        sma = AddState(sma, 'Name', 'Stimulus', ...
            'Timer', 0.2, ... % Using sound duration as stimulus time
            'StateChangeConditions', {'Tup', 'Response'}, ...
            'OutputActions', {'HiFi1', ['P' 0],'GlobalTimerTrig', 2});

        % Determine correct response and reward status from StimTable
        correctSide = StimTable.CorrectSide(currentTrial);
        isRewarded = StimTable.Rewarded(currentTrial);
        isCatchTrial = (StimTable.VibFreq(currentTrial) == 0); % Catch trial if VibFreq = 0
        
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
        
        % Display trial information
        if isCatchTrial
            disp(['Trial ' num2str(currentTrial) ': Catch trial (VibFreq = 0)']);
        else
            disp(['Trial ' num2str(currentTrial) ': CorrectSide = ' num2str(correctSide) ', Correct response = ' correctResponse ', Rewarded = ' num2str(isRewarded)]);
        end
        
        if isCatchTrial
            % Catch trial - no reward for any response
            sma = AddState(sma, 'Name', 'Response', ...
                'Timer', ResWin, ...
                'StateChangeConditions', {'Port1In', 'Checking', 'Port2In', 'Checking', 'Tup', 'Checking'}, ...
                'OutputActions', {});
        else
            % Response state with left/right choice based on CorrectSide
            if strcmp(correctResponse, 'left')
                % Left is correct
                if isRewarded
                    sma = AddState(sma, 'Name', 'Response', ...
                        'Timer', ResWin, ...
                        'StateChangeConditions', {'Port1In', 'LeftReward', 'Port2In', 'WrongChoice', 'Tup', 'Checking'}, ...
                        'OutputActions', {});
                else
                    sma = AddState(sma, 'Name', 'Response', ...
                        'Timer', ResWin, ...
                        'StateChangeConditions', {'Port1In', 'LeftNoReward', 'Port2In', 'WrongChoice', 'Tup', 'Checking'}, ...
                        'OutputActions', {});
                end
            elseif strcmp(correctResponse, 'right')
                % Right is correct
                if isRewarded
                    sma = AddState(sma, 'Name', 'Response', ...
                        'Timer', ResWin, ...
                        'StateChangeConditions', {'Port1In', 'WrongChoice', 'Port2In', 'RightReward', 'Tup', 'Checking'}, ...
                        'OutputActions', {});
                else
                    sma = AddState(sma, 'Name', 'Response', ...
                        'Timer', ResWin, ...
                        'StateChangeConditions', {'Port1In', 'WrongChoice', 'Port2In', 'RightNoReward', 'Tup', 'Checking'}, ...
                        'OutputActions', {});
                end
            elseif strcmp(correctResponse, 'boundary')
                % Boundary frequency - both responses are correct, but reward depends on isRewarded
                if isRewarded
                    sma = AddState(sma, 'Name', 'Response', ...
                        'Timer', ResWin, ...
                        'StateChangeConditions', {'Port1In', 'LeftReward', 'Port2In', 'RightReward', 'Tup', 'Checking'}, ...
                        'OutputActions', {});
                else
                    sma = AddState(sma, 'Name', 'Response', ...
                        'Timer', ResWin, ...
                        'StateChangeConditions', {'Port1In', 'LeftNoReward', 'Port2In', 'RightNoReward', 'Tup', 'Checking'}, ...
                        'OutputActions', {});
                end
            end
        end

        % Left reward state
        sma = AddState(sma, 'Name', 'LeftReward', ...
            'Timer', LeftValveTime, ...
            'StateChangeConditions', {'Tup', 'DrinkingLeft'}, ...
            'OutputActions', {'ValveState', 1}); % Valve 1 for left port
        
        % Right reward state
        sma = AddState(sma, 'Name', 'RightReward', ...
            'Timer', RightValveTime, ...
            'StateChangeConditions', {'Tup', 'DrinkingRight'}, ...
            'OutputActions', {'ValveState', 2}); % Valve 2 for right port (bit 2 = 2)
        
        % Wrong choice state (timeout)
        sma = AddState(sma, 'Name', 'WrongChoice', ...
            'Timer', 2, ... % 2 second timeout for wrong choice
            'StateChangeConditions', {'Tup', 'Checking'}, ...
            'OutputActions', {});
        
        % Left no reward state (correct response but no reward)
        sma = AddState(sma, 'Name', 'LeftNoReward', ...
            'Timer', 0.5, ... % Brief pause for correct response without reward
            'StateChangeConditions', {'Tup', 'DrinkingLeft'}, ...
            'OutputActions', {});
        
        % Right no reward state (correct response but no reward)
        sma = AddState(sma, 'Name', 'RightNoReward', ...
            'Timer', 0.5, ... % Brief pause for correct response without reward
            'StateChangeConditions', {'Tup', 'DrinkingRight'}, ...
            'OutputActions', {});
        
        % Drinking states
        sma = AddState(sma, 'Name', 'DrinkingLeft', ...
            'Timer', 0, ...
            'StateChangeConditions', {'Port1Out', 'DrinkingGrace'}, ...
            'OutputActions', {});
        
        sma = AddState(sma, 'Name', 'DrinkingRight', ...
            'Timer', 0, ...
            'StateChangeConditions', {'Port2Out', 'DrinkingGrace'}, ...
            'OutputActions', {});
        
        sma = AddState(sma, 'Name', 'DrinkingGrace', ...
            'Timer', 0.5, ... % 0.5 second grace period
            'StateChangeConditions', {'Tup', 'Checking', 'Port1In', 'DrinkingLeft', 'Port2In', 'DrinkingRight'}, ...
            'OutputActions', {});

        
        % Set condition to check if GlobalTimer2 has ended
        sma = SetCondition(sma, 6, 'GlobalTimer2', 0); % Condition 6: GlobalTimer2 has ended
        
        % Checking state - wait for trial to complete
        sma = AddState(sma, 'Name', 'Checking', ...
            'Timer', 0, ...  
            'StateChangeConditions', {'Condition6', 'exit'}, ...
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
            BpodSystem.Data.LeftValveTime(currentTrial) = LeftValveTime;
            BpodSystem.Data.RightValveTime(currentTrial) = RightValveTime;
            BpodSystem.Data.ResWin(currentTrial) = ResWin;
            BpodSystem.Data.CutOff(currentTrial) = CutOff;
            BpodSystem.Data.CorrectSide(currentTrial) = correctSide;
            BpodSystem.Data.CorrectResponse(currentTrial) = correctResponse;
            BpodSystem.Data.IsRewarded(currentTrial) = isRewarded;
            BpodSystem.Data.IsCatchTrial(currentTrial) = isCatchTrial;
                        
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
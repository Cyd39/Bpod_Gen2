% Categorization protocol
% This protocol is used to categorize the stimuli into different categories by frequency
% Stimuli will be played in a random order, and the animal will be rewarded for licking the correct spout
function Categorization()
    global BpodSystem

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
    StimTable = GenLeftRightSeq(StimParams);

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

    % Prepare and start first trial
    genAndLoadStimulus(1);
    [sma, S, updateFlag, ThisITI, QuietTime, correctSide, RewardAmount, TrialInfo] = PrepareStateMachine(S, 1, updateFlag);

    % Store trial parameters before starting the trial
    BpodSystem.Data.ThisITI(1) = ThisITI;
    BpodSystem.Data.QuietTime(1) = QuietTime;
    BpodSystem.Data.CorrectSide(1) = correctSide;
    BpodSystem.Data.RewardAmount(1) = RewardAmount;

    displayTrialInfo(1, ThisITI, QuietTime, TrialInfo);
    trialManager.startTrial(sma);

    % Main loop, runs once per trial
    for currentTrial = 1:NumTrials
        if BpodSystem.Status.BeingUsed == 0
            CleanupHiFi();
            return;
        end

        if currentTrial < NumTrials
            genAndLoadStimulus(currentTrial+1);
            [sma, S, updateFlag, NextITI, NextQuietTime, NextCorrectSide, NextRewardAmount, NextTrialInfo] = PrepareStateMachine(S, currentTrial+1, updateFlag);

            % Store next trial parameters
            BpodSystem.Data.ThisITI(currentTrial+1) = NextITI;
            BpodSystem.Data.QuietTime(currentTrial+1) = NextQuietTime;
            BpodSystem.Data.CorrectSide(currentTrial+1) = NextCorrectSide;
            BpodSystem.Data.RewardAmount(currentTrial+1) = NextRewardAmount;

            SendStateMachine(sma, 'RunASAP');
        end

        RawEvents = trialManager.getTrialData; % waits until current trial is finished
        if BpodSystem.Status.BeingUsed == 0
            CleanupHiFi();
            return;
        end

        HandlePauseCondition;
        if currentTrial < NumTrials
            trialManager.startTrial();
        end

        % Save trial data
        if ~isempty(fieldnames(RawEvents))
            BpodSystem.Data = AddTrialEvents(BpodSystem.Data, RawEvents);
            BpodSystem.Data.TrialSettings(currentTrial) = S;
            BpodSystem.Data.TrialStartTimestamp(currentTrial) = RawEvents.TrialStartTimestamp;

            SaveBpodSessionData;
        end

        HandlePauseCondition;
        if BpodSystem.Status.BeingUsed == 0
            disp('End of session');
            CleanupHiFi();
            return
        end
    end

    % Nested helpers
    function [sma, S, updateFlag, ThisITI, QuietTime, correctSide, RewardAmount, TrialInfo] = PrepareStateMachine(S, currentTrial, updateFlag)
        if updateFlag
            S = BpodParameterGUI('sync', S);
            updateFlag = false;
        end

        % Generate random ITI and quiet time for this trial
        ITIBefore = S.GUI.MinITI/2;
        ITIAfter = S.GUI.MinITI/2 + rand() * (S.GUI.MaxITI - S.GUI.MinITI);
        ThisITI = ITIBefore + ITIAfter;
        QuietTime = S.GUI.MinQuietTime + rand() * (S.GUI.MaxQuietTime - S.GUI.MinQuietTime);
        TimerDuration = ITIAfter + StimDur; % GlobalTimer2 covers stimulus + ITI after
        RewardAmount = S.GUI.RewardAmount;
        ResWin = S.GUI.ResWin;
        CutOff = CutOffPeriod;

        % Get valve times
        ValveTimes = BpodLiquidCalibration('GetValveTimes', RewardAmount, [1 2]);
        LeftValveTime = ValveTimes(1);
        RightValveTime = ValveTimes(2);

        % Determine trial conditions
        correctSide = StimTable.CorrectSide(currentTrial);
        isRewarded = StimTable.Rewarded(currentTrial);
        isCatchTrial = (StimTable.VibFreq(currentTrial) == 0);

        if correctSide == 1
            correctResponse = 'left';
        elseif correctSide == 2
            correctResponse = 'right';
        elseif correctSide == 3
            correctResponse = 'boundary';
        else
            correctResponse = 'left';
        end

        TrialInfo = struct('ITIBefore', ITIBefore, 'ITIAfter', ITIAfter, 'TimerDuration', TimerDuration, ...
                           'ResWin', ResWin, 'CutOff', CutOff, 'LeftValveTime', LeftValveTime, ...
                           'RightValveTime', RightValveTime, 'CorrectResponse', correctResponse, ...
                           'IsRewarded', isRewarded, 'IsCatchTrial', isCatchTrial);

        % Build state machine
        sma = NewStateMachine();

        % Lick conditions
        sma = SetCondition(sma, 1, 'Port1', 0);
        sma = SetCondition(sma, 2, 'Port2', 0);
        sma = SetCondition(sma, 3, 'Port1', 1);
        sma = SetCondition(sma, 4, 'Port2', 1);

        % Cut-off
        sma = SetGlobalTimer(sma, 'TimerID', 1, 'Duration', CutOff);
        sma = SetCondition(sma, 5, 'GlobalTimer1', 0);

        % Ready / NoLick
        if ITIBefore-QuietTime > 0
            sma = AddState(sma, 'Name', 'Ready', ...
                'Timer', ITIBefore-QuietTime, ...
                'StateChangeConditions', {'Tup', 'NoLick'}, ...
                'OutputActions', {'GlobalTimerTrig', 1});
            sma = AddState(sma, 'Name', 'NoLick', ...
                'Timer', QuietTime, ...
                'StateChangeConditions', {'Port1In', 'ResetNoLick','Port2In', 'ResetNoLick','Tup', 'Stimulus','Condition5', 'Stimulus'}, ...
                'OutputActions', {});
            sma = AddState(sma, 'Name', 'ResetNoLick', ...
                'Timer', 0, ...
                'StateChangeConditions', {'Condition1', 'NoLick','Condition2', 'NoLick','Condition5', 'Stimulus'}, ...
                'OutputActions', {});
        else
            sma = AddState(sma, 'Name', 'Ready', ...
                'Timer', ITIBefore, ...
                'StateChangeConditions', {'Port1In', 'ResetNoLick','Port2In', 'ResetNoLick','Tup', 'Stimulus'}, ...
                'OutputActions', {'GlobalTimerTrig', 1});
            sma = AddState(sma, 'Name', 'NoLick', ...
                'Timer', QuietTime, ...
                'StateChangeConditions', {'Port1In', 'ResetNoLick','Port2In', 'ResetNoLick', 'Tup', 'Stimulus','Condition5', 'Stimulus'}, ...
                'OutputActions', {});
            sma = AddState(sma, 'Name', 'ResetNoLick', ...
                'Timer', 0, ...
                'StateChangeConditions', {'Condition1', 'NoLick','Condition2', 'NoLick','Condition5', 'Stimulus'}, ...
                'OutputActions', {});
        end

        % Trial global timer: stimulus + ITI after
        sma = SetGlobalTimer(sma, 'TimerID', 2, 'Duration', TimerDuration);

        % Stimulus: single playback for StimDur
        sma = AddState(sma, 'Name', 'Stimulus', ...
            'Timer', StimDur, ...
            'StateChangeConditions', {'Tup', 'Response'}, ...
            'OutputActions', {'HiFi1', ['P' 0], 'GlobalTimerTrig', 2});

        % Response mapping
        if isCatchTrial
            sma = AddState(sma, 'Name', 'Response', ...
                'Timer', ResWin, ...
                'StateChangeConditions', {'Port1In', 'Checking', 'Port2In', 'Checking', 'Tup', 'Checking'}, ...
                'OutputActions', {});
        else
            if strcmp(correctResponse, 'left')
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

        % Reward / no reward / wrong choice
        sma = AddState(sma, 'Name', 'LeftReward', ...
            'Timer', LeftValveTime, ...
            'StateChangeConditions', {'Tup', 'DrinkingLeft'}, ...
            'OutputActions', {'ValveState', 1});
        sma = AddState(sma, 'Name', 'RightReward', ...
            'Timer', RightValveTime, ...
            'StateChangeConditions', {'Tup', 'DrinkingRight'}, ...
            'OutputActions', {'ValveState', 2});
        sma = AddState(sma, 'Name', 'WrongChoice', ...
            'Timer', 2, ...
            'StateChangeConditions', {'Tup', 'Checking'}, ...
            'OutputActions', {});
        sma = AddState(sma, 'Name', 'LeftNoReward', ...
            'Timer', 0.5, ...
            'StateChangeConditions', {'Tup', 'DrinkingLeft'}, ...
            'OutputActions', {});
        sma = AddState(sma, 'Name', 'RightNoReward', ...
            'Timer', 0.5, ...
            'StateChangeConditions', {'Tup', 'DrinkingRight'}, ...
            'OutputActions', {});

        % Drinking and grace
        sma = AddState(sma, 'Name', 'DrinkingLeft', ...
            'Timer', 0, ...
            'StateChangeConditions', {'Port1Out', 'DrinkingGrace'}, ...
            'OutputActions', {});
        sma = AddState(sma, 'Name', 'DrinkingRight', ...
            'Timer', 0, ...
            'StateChangeConditions', {'Port2Out', 'DrinkingGrace'}, ...
            'OutputActions', {});
        sma = AddState(sma, 'Name', 'DrinkingGrace', ...
            'Timer', 0.5, ...
            'StateChangeConditions', {'Tup', 'Checking', 'Port1In', 'DrinkingLeft', 'Port2In', 'DrinkingRight'}, ...
            'OutputActions', {});

        % End-of-trial condition (GlobalTimer2 ends)
        sma = SetCondition(sma, 6, 'GlobalTimer2', 0);
        sma = AddState(sma, 'Name', 'Checking', ...
            'Timer', 0, ...
            'StateChangeConditions', {'Condition6', 'exit'}, ...
            'OutputActions', {});
    end

    function genAndLoadStimulus(currentTrial)
        % Generate sound&vibration waveform
        soundWave = GenStimWave(StimTable(currentTrial,:), CalTable);
        soundWave = soundWave(:,1:end-1); % remove last sample for safety
        disp(StimTable(currentTrial,:));

        % Load to HiFi without loop to ensure single playback
        H.load(1, soundWave); % default is single shot
        H.push();
        disp(['Trial ' num2str(currentTrial) ': Sound loaded to buffer 1 (single playback)']);
    end

    function displayTrialInfo(currentTrial, ThisITI, QuietTime, TrialInfo)
        disp(['Trial ' num2str(currentTrial) ': ITI = ' num2str(ThisITI) ' s, QuietTime = ' num2str(QuietTime) ' s']);
        if TrialInfo.IsCatchTrial
            disp(['Trial ' num2str(currentTrial) ': Catch trial']);
        else
            disp(['Trial ' num2str(currentTrial) ': Correct response = ' TrialInfo.CorrectResponse ', Rewarded = ' num2str(TrialInfo.IsRewarded)]);
        end
    end

    % Session cleanup
    function CleanupHiFi()
        try
            H.stop();
        catch
        end
        try
            clear H;
        catch
        end
    end
end
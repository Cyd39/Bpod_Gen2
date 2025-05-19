function TestEverything()
    global BpodSystem

    % Initialize HiFi module
    % H = BpodHiFi('COM7'); 
    % H.SamplingRate = 192000; 

    % get parameters from StimParamGui
    StimParams = BpodSystem.ProtocolSettings.StimParams;
    NumTrials = StimParams.Behave.NumTrials;
    
    % Generate Stimuli parameter table
    StimTable = GenStimSeq(StimParams);
    
    % Setup default parameters
    S = struct;
    % use the behavior parameters from StimParamGui as default values
    S.GUI.MinITI = StimParams.Behave.MinITI; % seconds
    S.GUI.MaxITI = StimParams.Behave.MaxITI; % seconds
    S.GUI.MinQuietTime = StimParams.Behave.MinQuietTime; % seconds
    S.GUI.MaxQuietTime = StimParams.Behave.MaxQuietTime; % seconds
    S.GUI.ValveTime = StimParams.Behave.ValveTime; % seconds
    S.GUI.ResWin = StimParams.Behave.ResWin; % seconds


    % Initialize parameter GUI
    BpodParameterGUI('init', S);
    % Create update button
    h = struct();
    h.updateButton = uicontrol('Style', 'pushbutton', ...
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

    % Main trial loop
    for currentTrial = 1:NumTrials
        % Check if update button was pressed
        if updateFlag
            % get parameters from GUI
            S = BpodParameterGUI('sync', S);
            updateFlag = false; % reset flag
        end
        
        % Generate sound&vibration waveform
        soundWave = GenStimWave(StimTable(currentTrial,:));

         % Load the sound wave into BpodHiFi
         H.load(1, soundWave); 
         H.push();
         disp('Sound loaded to buffer 1');

        % Generate random ITI and quiet time for this trial
        ThisITI = S.GUI.MinITI + rand() * (S.GUI.MaxITI - S.GUI.MinITI);
        QuietTime = S.GUI.MinQuietTime + rand() * (S.GUI.MaxQuietTime - S.GUI.MinQuietTime);
        TimerDuration = ThisITI+BpodSystem.ProtocolSettings.StimParams.Duration;
        ValveTime = S.GUI.ValveTime;
        ResWin = S.GUI.ResWin;
        
        % Display the trial information
        disp(['Trial ' num2str(currentTrial) ': ITI = ' num2str(ThisITI) ' seconds, QuietTime = ' num2str(QuietTime) ' seconds']);  

        % Determine stimulus for this trial
        %switch TrialTypes(currentTrial)
        %    case 1 % Sound only
        %        StimActions = {'PWM1', 255}; % Sound trigger
        %    case 2 % Vibration only  
        %        StimActions = {'PWM2', 255}; % Vibration trigger
        %    case 3 % Both
        %        StimActions = {'PWM1', 255, 'PWM2', 255}; % Both triggers
        %end
        
        % Create state machine
        sma = NewStateMachine();
      
        % Set to record all BNC1High events
        sma = SetCondition(sma, 1, 'BNC1', 1); % Condition 1: Port 1 low (is out)
        
        % Add states
        % Ready state under different conditions
        if ThisITI-QuietTime > 0
            sma = AddState(sma, 'Name', 'Ready', ...
                'Timer', ThisITI-QuietTime, ...
                'StateChangeConditions', {'Tup', 'NoLick'}, ...
                'OutputActions', {});
            sma = AddState(sma, 'Name', 'NoLick', ...
                'Timer', QuietTime, ...
                'StateChangeConditions', {'BNC1High', 'ResetNoLick', 'Tup', 'Stimulus'}, ...
                'OutputActions', {});
            sma = AddState(sma, 'Name', 'ResetNoLick', ...
                'Timer', 0, ...
                'StateChangeConditions', {'Tup', 'NoLick'}, ...
                'OutputActions', {});
        else
            sma = AddState(sma, 'Name', 'Ready', ...
                'Timer', ThisITI, ...
                'StateChangeConditions', {'Tup', 'Stimulus','BNC1High', 'NoLick'}, ...
                'OutputActions', {});
            sma = AddState(sma, 'Name', 'NoLick', ...
                'Timer', QuietTime, ...
                'StateChangeConditions', {'BNC1High', 'ResetNoLick', 'Tup', 'Stimulus'}, ...
                'OutputActions', {});
            sma = AddState(sma, 'Name', 'ResetNoLick', ...
                'Timer', 0, ...
                'StateChangeConditions', {'Tup', 'NoLick'}, ...
                'OutputActions', {});
        end

        % the timer begins at the stimulus state
        % Duration needs to be set.
        sma = SetGlobalTimer(sma, 'TimerID', 1, 'Duration', TimerDuration); 
        %sma = SetGlobalTimer(sma, 'TimerID', 1, 'Duration', 3); 

        % Stimulus state
        sma = AddState(sma, 'Name', 'Stimulus', ...
            'Timer', 0.2, ... % Using sound duration as stimulus time
            'StateChangeConditions', {'Tup', 'Response'}, ...
            'OutputActions', {'HiFi1', ['P' 0],'GlobalTimerTrig', 1});

        % If it is a catch trial, there is no jumping into the reward state
        isCatchTrial = false;
        if ismember('SndTypeName', StimTable.Properties.VariableNames)
            isCatchTrial = isCatchTrial | strcmp(StimTable.SndTypeName(currentTrial), 'null');
        end
        if ismember('VibTypeName', StimTable.Properties.VariableNames)
            isCatchTrial = isCatchTrial | strcmp(StimTable.VibTypeName(currentTrial), 'null');
        end
        
        if isCatchTrial
            % NoReward state
            sma = AddState(sma, 'Name', 'NoReward', ...
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
        sma = SetCondition(sma, 2, 'GlobalTimer1', 0); % Condition 2: GlobalTimer1 has ended
        
        % Here is the part need to be modified(maybe need to set a timer for the checking state)
        sma = AddState(sma, 'Name', 'Checking', ...
            'Timer', 0, ...  
            'StateChangeConditions', {'Condition2', 'exit'}, ...
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
                        
            SaveBpodSessionData;
        end
        
        % Handle pause condition
        HandlePauseCondition;
        
        % Check if session should end
        if BpodSystem.Status.BeingUsed == 0
            return
        end
    end
    end 
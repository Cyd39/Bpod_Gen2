function BimodalStimuli()
    global BpodSystem
    
    % Setup default parameters
    %S = struct;
    %S.GUI.SoundFrequency = 5000; % Hz
    %S.GUI.SoundDuration = 0.5; % seconds  
    %S.GUI.SoundVolume = 0.5; % 0-1
    %S.GUI.VibrationFrequency = 100; % Hz
    %S.GUI.VibrationDuration = 0.5; % seconds
    %S.GUI.VibrationIntensity = 0.5; % 0-1
    %S.GUI.RewardAmount = 3; % ul
    %S.GUI.ResponseTimeAllowed = 5; % seconds
    S.GUI.MinITI = 1; % seconds
    S.GUI.MaxITI = 3; % seconds
    S.GUI.MinQuietTime = 1; % seconds
    S.GUI.MaxQuietTime = 2; % seconds
    
    % Initialize parameter GUI
    podParameterGUI('init', S);
    
    % Define trial types
    % 1 = Sound only
    % 2 = Vibration only  
    % 3 = Sound + Vibration
    %TrialTypes = randperm(90);
    %TrialTypes = reshape(TrialTypes, 30, 3); % 30 trials of each type
    %TrialTypes = TrialTypes(:);
    
    % Set reward valve time
    ValveTime = 1;
    % Set response time allowed
    ResWin = 5;

    % Prepare sound(need to be modified)
    H = BpodHiFi(BpodSystem.ModuleUSB.HiFi1);
    H.SamplingRate = 192000;
    sf = 192000; 
    soundDuration = 0.5; 
    sounds = [set of 160 sounds];   

    % Prepare vibration
    % need to prepare vibration to be played in the stimulus state

    % Main trial loop
    for currentTrial = 1:160
        S = BpodParameterGUI('sync', S);
        
        % Generate random ITI and quiet time for this trial
        ThisITI = S.GUI.MinITI + rand() * (S.GUI.MaxITI - S.GUI.MinITI);
        QuietTime = S.GUI.MinQuietTime + rand() * (S.GUI.MaxQuietTime - S.GUI.MinQuietTime);
        
        % Set sound stimulus
        H.load(1, sounds(currentTrial));
        H.push;

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

        % Add states
        % Ready state under different conditions
        if ThisITI-QuietTime > 0
            sma = AddState(sma, 'Name', 'Ready', ...
                'Timer', ThisITI-QuietTime, ...
                'StateChangeConditions', {'Tup', 'NoLick'}, ...
                'OutputActions', {});
            sma = AddState(sma, 'Name', 'NoLick', ...
                'Timer', QuietTime, ...
                'StateChangeConditions', {'BCN1High', 'NoLick', 'Tup', 'Stimulus'}, ...
                'OutputActions', {});
        else
            sma = AddState(sma, 'Name', 'Ready', ...
                'Timer', ThisITI, ...
                'StateChangeConditions', {'Tup', 'Stimulus','BCN1High', 'NoLick'}, ...
                'OutputActions', {});
            sma = AddState(sma, 'Name', 'NoLick', ...
                'Timer', QuietTime, ...
                'StateChangeConditions', {'BCN1High', 'NoLick', 'Tup', 'Stimulus'}, ...
                'OutputActions', {});
        end

        % the timer begins at the stimulus state
        % Duration needs to be set.
        sma = SetGlobalTimer(sma, 'TimerID', 1, 'Duration', 5);         
        % Stimulus state
        sma = AddState(sma, 'Name', 'Stimulus', ...
            'Timer', 0, ... % Using sound duration as stimulus time
            'StateChangeConditions', {'Tup', 'Response'}, ...
            'OutputActions', {'HiFi1', ['P' 1],'GlobalTimerTrig', 1});

        % Response state
        sma = AddState(sma, 'Name', 'Response', ...
            'Timer', ResWin, ...
            'StateChangeConditions', {'BCN1High', 'Reward', 'Tup', 'Checking'}, ...
            'OutputActions', {});

        % Reward state
        sma = AddState(sma, 'Name', 'Reward', ...
            'Timer', ValveTime, ...
            'StateChangeConditions', {'Tup', 'Checking'}, ...
            'OutputActions', {'Valve1', 1});
        
        % Here is the part need to be modified(maybe need to set a timer for the checking state)
        sma = AddState(sma, 'Name', 'Checking', ...
            'Timer', 10, ...
            'StateChangeConditions', {'GlobalTimer1_End', 'exit'}, ...
            'OutputActions', {});

        
        % Send state machine to Bpod device
        SendStateMachine(sma);
        
        % Run state machine
        RawEvents = RunStateMachine;
        
        % Save trial data
        if ~isempty(fieldnames(RawEvents))
            BpodSystem.Data = AddTrialEvents(BpodSystem.Data, RawEvents);
            BpodSystem.Data.TrialTypes(currentTrial) = TrialTypes(currentTrial);
            BpodSystem.Data.TrialSettings(currentTrial) = S;
            
            % Save trial timestamp
            BpodSystem.Data.TrialStartTimestamp(currentTrial) = RawEvents.TrialStartTimestamp;
            
            % Calculate response time if response occurred
            if ~isnan(RawEvents.States.WaitForResponse(1))
                responseTime = RawEvents.States.WaitForResponse(2) - RawEvents.States.WaitForResponse(1);
                BpodSystem.Data.ResponseTime(currentTrial) = responseTime;
            else
                BpodSystem.Data.ResponseTime(currentTrial) = NaN;
            end
            
            SaveBpodSessionData;
        end
        
        % Handle pause condition
        HandlePauseCondition;
        
        % Check if session should end
        if BpodSystem.BeingUsed == 0
            return
        end
    end
    end 
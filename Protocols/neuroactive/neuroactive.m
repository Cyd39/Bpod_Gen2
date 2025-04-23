% This protocol is used to test the neuroactive code interaction with the Bpod system
% Input Stimuli properties in the GUI
% AM frequency,depth, volume, duration

% Trial loop
function neuroactive()
    global BpodSystem
    global StimParams
    
    % Setup default parameters
    S = struct;
    S.GUI.SoundFrequency = 523; % Hz
    S.GUI.SoundDuration = 1; % seconds  
    S.GUI.SoundVolume = 0.3; % 0-1
    %S.GUI.VibrationFrequency = 100; % Hz
    %S.GUI.VibrationDuration = 0.5; % seconds
    %S.GUI.VibrationIntensity = 0.5; % 0-1
    %S.GUI.RewardAmount = 3; % ul
    %S.GUI.ResponseTimeAllowed = 5; % seconds
    S.GUI.MinITI = 2; % seconds
    S.GUI.MaxITI = 3; % seconds
    S.GUI.MinQuietTime = 1; % seconds
    S.GUI.MaxQuietTime = 2; % seconds
    
    % Initialize parameter GUI
    BpodParameterGUI('init', S);
    
    
    % Set reward valve time
    ValveTime = 0.5;
    % Set response time allowed
    ResWin = 5;

    % Prepare sound
    H = BpodHiFi('COM7'); 
    H.SamplingRate = 192000;
    
    % generate a fixed length sound
    sound = GenerateSineWave(H.SamplingRate, S.GUI.SoundFrequency, S.GUI.SoundDuration);
    sound = sound * S.GUI.SoundVolume;  % adjust volume
    
    
    % load sound
    H.load(1, sound);
    H.push;

    % Prepare vibration
    % need to prepare vibration to be played in the stimulus state

    % Main trial loop
    for currentTrial = 1:160
        S = BpodParameterGUI('sync', S);
        
        % Generate random ITI and quiet time for this trial
        ThisITI = S.GUI.MinITI + rand() * (S.GUI.MaxITI - S.GUI.MinITI);
        QuietTime = S.GUI.MinQuietTime + rand() * (S.GUI.MaxQuietTime - S.GUI.MinQuietTime);
        TimerDuration = ThisITI+S.GUI.SoundDuration;
        
        % Display the trial information
        disp(['Trial ' num2str(currentTrial) ': ITI = ' num2str(ThisITI) ' seconds, QuietTime = ' num2str(QuietTime) ' seconds']);  

        % Set sound stimulus
        %H.load(1, sounds(currentTrial));
        %H.push;

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
        %sma = SetGlobalTimer(sma, 'TimerID', 1, 'Duration', TimerDuration); 
        sma = SetGlobalTimer(sma, 'TimerID', 1, 'Duration', 3); 

        % Stimulus state
        sma = AddState(sma, 'Name', 'Stimulus', ...
            'Timer', 0.2, ... % Using sound duration as stimulus time
            'StateChangeConditions', {'Tup', 'Response'}, ...
            'OutputActions', {'HiFi1', ['P' 0],'GlobalTimerTrig', 1});

        % Response state
        sma = AddState(sma, 'Name', 'Response', ...
            'Timer', ResWin, ...
            'StateChangeConditions', {'BNC1High', 'Reward', 'Tup', 'Checking'}, ...
            'OutputActions', {});

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
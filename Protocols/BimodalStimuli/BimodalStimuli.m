function BimodalStimuli()
global BpodSystem

% Setup default parameters
S = struct;
S.GUI.SoundFrequency = 5000; % Hz
S.GUI.SoundDuration = 0.5; % seconds  
S.GUI.SoundVolume = 0.5; % 0-1
S.GUI.VibrationFrequency = 100; % Hz
S.GUI.VibrationDuration = 0.5; % seconds
S.GUI.VibrationIntensity = 0.5; % 0-1
S.GUI.RewardAmount = 3; % ul
S.GUI.ResponseTimeAllowed = 5; % seconds
S.GUI.MinITI = 1; % seconds
S.GUI.MaxITI = 3; % seconds
S.GUI.MinQuietTime = 0.5; % seconds
S.GUI.MaxQuietTime = 1; % seconds

% Initialize parameter GUI
BpodParameterGUI('init', S);

% Define trial types
% 1 = Sound only
% 2 = Vibration only  
% 3 = Sound + Vibration
TrialTypes = randperm(90);
TrialTypes = reshape(TrialTypes, 30, 3); % 30 trials of each type
TrialTypes = TrialTypes(:);

% Get reward valve time
R = GetValveTimes(S.GUI.RewardAmount, 1);
ValveTime = R;

% Main trial loop
for currentTrial = 1:length(TrialTypes)
    S = BpodParameterGUI('sync', S);
    
    % Generate random ITI and quiet time for this trial
    ThisITI = S.GUI.MinITI + rand() * (S.GUI.MaxITI - S.GUI.MinITI);
    QuietTime = S.GUI.MinQuietTime + rand() * (S.GUI.MaxQuietTime - S.GUI.MinQuietTime);
    
    % Determine stimulus for this trial
    switch TrialTypes(currentTrial)
        case 1 % Sound only
            StimActions = {'PWM1', 255}; % Sound trigger
        case 2 % Vibration only  
            StimActions = {'PWM2', 255}; % Vibration trigger
        case 3 % Both
            StimActions = {'PWM1', 255, 'PWM2', 255}; % Both triggers
    end
    
    % Create state machine
    sma = NewStateMachine();
    
    sma = AddState(sma, 'Name', 'WaitForQuiet', ...
        'Timer', QuietTime, ...
        'StateChangeConditions', {'Port1In', 'WaitForQuiet', 'Tup', 'DeliverStimulus'}, ...
        'OutputActions', {});
    
    sma = AddState(sma, 'Name', 'DeliverStimulus', ...
        'Timer', S.GUI.SoundDuration, ... % Using sound duration as stimulus time
        'StateChangeConditions', {'Tup', 'WaitForResponse'}, ...
        'OutputActions', StimActions);
    
    sma = AddState(sma, 'Name', 'WaitForResponse', ...
        'Timer', S.GUI.ResponseTimeAllowed, ...
        'StateChangeConditions', {'Port1In', 'Reward', 'Tup', 'NoResponse'}, ...
        'OutputActions', {});
    
    sma = AddState(sma, 'Name', 'Reward', ...
        'Timer', ValveTime, ...
        'StateChangeConditions', {'Tup', 'ITI'}, ...
        'OutputActions', {'Valve1', 1});
    
    sma = AddState(sma, 'Name', 'NoResponse', ...
        'Timer', 0, ...
        'StateChangeConditions', {'Tup', 'ITI'}, ...
        'OutputActions', {});
        
    sma = AddState(sma, 'Name', 'ITI', ...
        'Timer', ThisITI, ...
        'StateChangeConditions', {'Tup', 'exit'}, ...
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
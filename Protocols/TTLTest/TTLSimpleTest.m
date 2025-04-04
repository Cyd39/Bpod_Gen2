function TTLSimpleTest
global BpodSystem

%% Setup
S = BpodSystem.ProtocolSettings;

if isempty(fieldnames(S))
    S.GUI.DetectionDuration = 3;  % Detection duration (seconds)
end

BpodParameterGUI('init', S);


%% Main loop
for currentTrial = 1:100  % Run 100 trials maximum
    S = BpodParameterGUI('sync', S);
    
    sma = NewStateMachine();
    
    % State 1: Wait for touch (signal goes HIGH)
    sma = AddState(sma, 'Name', 'WaitForTouch', ...
        'Timer', S.GUI.DetectionDuration, ...
        'StateChangeConditions', {'BNC1High', 'TouchDetected', 'Tup', 'exit'}, ...
        'OutputActions', {'PWM1', 0,'BNC2',0}); % LED off while waiting
        
    % State 2: Touch detected (signal is HIGH)
    sma = AddState(sma, 'Name', 'TouchDetected', ...
        'Timer', 0.25, ...
        'StateChangeConditions', {'Tup', 'WaitForTouch'}, ... % Stay in this state until touch released
        'OutputActions', {'PWM1', 255,'ValveState', 1,'BNC2',1}); % LED on when touched
    
    % Send state machine and run
    SendStateMachine(sma);

    disp(['Trial ', num2str(currentTrial), ':']);
    RawEvents = RunStateMachine;
    
    
    
    % Handle pause condition
    HandlePauseCondition;
    if BpodSystem.Status.BeingUsed == 0
        return
    end
    
    % Shorter trial interval
    pause(0.1);
end 
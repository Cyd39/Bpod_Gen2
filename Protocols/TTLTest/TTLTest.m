function TTLTest
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
        'OutputActions', {'PWM1', 255, 'SoftCode', 1}); % LED off while waiting
        
    % State 2: Touch detected (signal is HIGH)
    sma = AddState(sma, 'Name', 'TouchDetected', ...
        'Timer', 0.5, ...
        'StateChangeConditions', {'Tup', 'WaitForTouch'}, ... % Stay in this state until touch released
        'OutputActions', {'PWM1', 255, 'SoftCode', 2}); % LED on when touched
    
    % Send state machine and run
    SendStateMachine(sma);

    disp(['Trial ', num2str(currentTrial), ': Detection duration: ', num2str(S.GUI.DetectionDuration), ' seconds']);
    RawEvents = RunStateMachine;
    
    
    
    % Handle pause condition
    HandlePauseCondition;
    if BpodSystem.Status.BeingUsed == 0
        return
    end
    
    % Shorter trial interval
    pause(0.1);
end 
end

function SoftCodeHandler(Byte)
    global BpodSystem % 使用全局变量
    
    currentTime = datestr(now, 'HH:MM:SS.FFF');
    
    switch Byte
        case 1
            message = ['[' currentTime '] State: Wait for touch'];
        case 2
            message = ['[' currentTime '] State: Touch detected'];
        otherwise
            message = ['[' currentTime '] Warning: Unknown SoftCode (' num2str(Byte) ')'];
    end
    
    % 存储消息并显示
    BpodSystem.Status.CurrentStateMessage = message;
    fprintf('%s\n', message); % 使用 fprintf 并添加换行符
end
function TouchTest
global BpodSystem

%% Setup
S = BpodSystem.ProtocolSettings;

if isempty(fieldnames(S))
    S.GUI.DetectionDuration = 5;  % Detection duration (seconds)
    S.GUI.ITI = 0.5;  % Inter-trial interval (seconds)
    S.GUI.TouchThreshold = 0.1;  % Touch detection threshold (seconds)
    S.GUI.LEDBrightness = 255;  % LED brightness (0-255)
end

BpodParameterGUI('init', S);

% Initialize plots
BpodSystem.ProtocolFigures.TouchPlot = figure('Position', [50 540 1000 400], ...
    'name', 'Touch Detection', 'numbertitle', 'off', 'MenuBar', 'none');

subplot(2,1,1);
title('Touch Events Timeline');
xlabel('Trial Number');
ylabel('Time in Trial (s)');
hold on;

subplot(2,1,2);
title('Touch Count per Trial');
xlabel('Trial Number');
ylabel('Number of Touches');
hold on;

BpodSystem.Data.TouchEvents = cell(1,1000);
BpodSystem.Data.TouchCount = zeros(1,1000);

%% Main loop
maxTrials = 1000;
for currentTrial = 1:maxTrials
    S = BpodParameterGUI('sync', S);
    
    sma = NewStateMachine();
    
    % Waiting for touch state - LED off
    sma = AddState(sma, 'Name', 'DetectTouch', ...
        'Timer', S.GUI.DetectionDuration, ...
        'StateChangeConditions', {'Tup', 'ITI', 'BNC1High', 'TouchDetected'}, ...
        'OutputActions', {'PWM1', 0}); % LED off while waiting
    
    % Touch detected state - LED on
    sma = AddState(sma, 'Name', 'TouchDetected', ...
        'Timer', S.GUI.TouchThreshold, ...
        'StateChangeConditions', {'Tup', 'DetectTouch', 'BNC1Low', 'DetectTouch'}, ...
        'OutputActions', {'PWM1', S.GUI.LEDBrightness}); % LED on when touch detected
    
    % ITI state - LED off
    sma = AddState(sma, 'Name', 'ITI', ...
        'Timer', S.GUI.ITI, ...
        'StateChangeConditions', {'Tup', 'exit'}, ...
        'OutputActions', {'PWM1', 0}); % LED off during ITI
    
    % Send state machine and run
    SendStateMachine(sma);
    RawEvents = RunStateMachine;
    
    % Save data
    if ~isempty(fieldnames(RawEvents))
        BpodSystem.Data = AddTrialEvents(BpodSystem.Data, RawEvents);
        BpodSystem.Data.TrialSettings(currentTrial) = S;
        
        % Record touch events
        if isfield(RawEvents.Events, 'BNC1High')
            touchTimes = RawEvents.Events.BNC1High;
            BpodSystem.Data.TouchEvents{currentTrial} = touchTimes;
            BpodSystem.Data.TouchCount(currentTrial) = length(touchTimes);
        else
            BpodSystem.Data.TouchEvents{currentTrial} = [];
            BpodSystem.Data.TouchCount(currentTrial) = 0;
        end
        
        % Update display
        figure(BpodSystem.ProtocolFigures.TouchPlot);
        
        % Update touch events timeline
        subplot(2,1,1);
        cla;
        for trial = 1:currentTrial
            events = BpodSystem.Data.TouchEvents{trial};
            if ~isempty(events)
                plot(trial * ones(size(events)), events, 'k.', 'MarkerSize', 10);
            end
        end
        xlim([0 currentTrial+1]);
        ylim([0 S.GUI.DetectionDuration]);
        
        % Update touch count per trial
        subplot(2,1,2);
        bar(1:currentTrial, BpodSystem.Data.TouchCount(1:currentTrial));
        xlim([0 currentTrial+1]);
        drawnow;
        SaveBpodSessionData;
    end
    
    % Handle pause condition
    HandlePauseCondition;
    if BpodSystem.Status.BeingUsed == 0
        return
    end
end 
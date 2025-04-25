function BimodalStim()
    % This protocol is used for bimodal stimulation experiments
    % Delivers sound and vibration stimuli with precise timing
    % Records response times and delivers rewards
    
    global BpodSystem
    
    % Setup default parameters
    S = struct;
    
    % Sound parameters
    S.GUI.SoundType = 'AM'; % 'AM' or 'Click'
    S.GUI.SoundFrequency = 1000; % Hz, carrier frequency for AM
    S.GUI.SoundDuration = 0.5; % seconds
    S.GUI.SoundVolume = 0.3; % 0-1
    S.GUI.AMFrequency = 20; % Hz, modulation frequency
    S.GUI.AMDepth = 0.8; % 0-1
    
    % Vibration parameters  
    S.GUI.VibrationWaveform = 'BiSine'; % 'Square','UniSine','BiSine'
    S.GUI.VibrationFrequency = 100; % Hz
    S.GUI.VibrationDuration = 0.5; % seconds
    S.GUI.VibrationAmplitude = 0.5; % Volts
    S.GUI.VibrationRamp = 5; % ms
    
    % Trial timing parameters
    S.GUI.MinITI = 2; % seconds
    S.GUI.MaxITI = 3; % seconds
    S.GUI.MinQuietTime = 0.5; % seconds
    S.GUI.MaxQuietTime = 1; % seconds
    S.GUI.RewardValveTime = 0.03; % seconds
    
    % Initialize parameter GUI
    BpodParameterGUI('init', S);
    
    % Prepare sound device
    H = BpodHiFi('COM7');
    H.SamplingRate = 192000;
    
    % Main trial loop
    for currentTrial = 1:160
        S = BpodParameterGUI('sync', S);
        
        % Generate random ITI and quiet time for this trial
        ThisITI = S.GUI.MinITI + rand() * (S.GUI.MaxITI - S.GUI.MinITI);
        QuietTime = S.GUI.MinQuietTime + rand() * (S.GUI.MaxQuietTime - S.GUI.MinQuietTime);
        
        % Generate sound stimulus
        if strcmp(S.GUI.SoundType, 'AM')
            % Generate AM noise
            sound = genamnoise(S.GUI.SoundDuration, S.GUI.SoundVolume,...
                             S.GUI.AMFrequency, S.GUI.AMDepth,...
                             S.GUI.SoundFrequency-100, S.GUI.SoundFrequency+100,... % frequency band
                             1, 0, 0, 0, 5, 5,... % other parameters
                             H.SamplingRate, 1, 1, [1 70 10]); % hardware settings
        else
            % Generate click train
            [sound, ~] = poisson_click_waveform(0, S.GUI.SoundFrequency,...
                                              S.GUI.SoundDuration, H.SamplingRate,...
                                              S.GUI.SoundVolume, 0.1);
        end
        
        % Load sound
        H.load(1, sound);
        H.push;
        
        % Generate vibration waveform
        [vib_waveform, ~] = gensomwaveform(S.GUI.VibrationWaveform,...
                                          S.GUI.VibrationDuration*1000,... % convert to ms
                                          S.GUI.VibrationAmplitude,...
                                          S.GUI.VibrationFrequency,...
                                          S.GUI.VibrationRamp,...
                                          H.SamplingRate);
                                          
        % Create state machine
        sma = NewStateMachine();
        
        % Add states
        sma = AddState(sma, 'Name', 'WaitForQuiet',...
            'Timer', QuietTime,...
            'StateChangeConditions', {'Port1In', 'WaitForQuiet',...
                                    'Port3In', 'WaitForQuiet',...
                                    'Tup', 'DeliverStimulus'},...
            'OutputActions', {});
            
        sma = AddState(sma, 'Name', 'DeliverStimulus',...
            'Timer', S.GUI.SoundDuration,...
            'StateChangeConditions', {'Port1In', 'Reward',...
                                    'Port3In', 'Reward',...
                                    'Tup', 'NoResponse'},...
            'OutputActions', {'HiFi1', 1,... % Play sound
                            'PWM1', 255}); % Deliver vibration
                            
        sma = AddState(sma, 'Name', 'Reward',...
            'Timer', S.GUI.RewardValveTime,...
            'StateChangeConditions', {'Tup', 'ITI'},...
            'OutputActions', {'Valve1', 1});
            
        sma = AddState(sma, 'Name', 'NoResponse',...
            'Timer', 0,...
            'StateChangeConditions', {'Tup', 'ITI'},...
            'OutputActions', {});
            
        sma = AddState(sma, 'Name', 'ITI',...
            'Timer', ThisITI,...
            'StateChangeConditions', {'Tup', 'exit'},...
            'OutputActions', {});
            
        % Send state machine to Bpod device
        SendStateMachine(sma);
        
        % Run state machine
        RawEvents = RunStateMachine;
        
        % Save trial data
        if ~isempty(fieldnames(RawEvents))
            BpodSystem.Data = AddTrialEvents(BpodSystem.Data, RawEvents);
            
            % Save trial outcome
            if ~isnan(RawEvents.States.Reward(1))
                BpodSystem.Data.TrialOutcome(currentTrial) = 1; % Responded
            else
                BpodSystem.Data.TrialOutcome(currentTrial) = 0; % No response
            end
            
            % Save trial timing
            BpodSystem.Data.TrialStartTime(currentTrial) = RawEvents.TrialStartTimestamp;
            BpodSystem.Data.StimStartTime(currentTrial) = RawEvents.States.DeliverStimulus(1);
            if BpodSystem.Data.TrialOutcome(currentTrial)
                BpodSystem.Data.ResponseTime(currentTrial) = ...
                    RawEvents.States.Reward(1) - RawEvents.States.DeliverStimulus(1);
            else
                BpodSystem.Data.ResponseTime(currentTrial) = NaN;
            end
            
            % Save parameters for this trial
            BpodSystem.Data.TrialSettings(currentTrial) = S.GUI;
            
            % Autosave
            SaveBpodSessionData;
        end
        
        % Update online plot
        if currentTrial == 1
            % Initialize performance plot
            BpodSystem.ProtocolFigures.PerformancePlot = figure('Position', [50 540 1000 250],'name','Performance plot');
            BpodSystem.GUIHandles.PerformancePlot.ResponsePlot = subplot(1,2,1);
            BpodSystem.GUIHandles.PerformancePlot.ResponseTimePlot = subplot(1,2,2);
        end
        
        % Update response plot
        subplot(BpodSystem.GUIHandles.PerformancePlot.ResponsePlot);
        plot(1:currentTrial, BpodSystem.Data.TrialOutcome(1:currentTrial), 'k-');
        xlabel('Trial #'); ylabel('Response');
        ylim([-0.1 1.1]); xlim([0 currentTrial+1]);
        
        % Update response time plot  
        subplot(BpodSystem.GUIHandles.PerformancePlot.ResponseTimePlot);
        plot(1:currentTrial, BpodSystem.Data.ResponseTime(1:currentTrial), 'b.');
        xlabel('Trial #'); ylabel('Response time (s)');
        ylim([0 S.GUI.SoundDuration]); xlim([0 currentTrial+1]);
        
        if BpodSystem.Status.BeingUsed == 0
            return
        end
    end
end 
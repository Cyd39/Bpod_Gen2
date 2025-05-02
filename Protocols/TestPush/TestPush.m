function TestPush()
    global BpodSystem

    % Initialize HiFi module
    H = BpodHiFi('COM7'); 
    H.SamplingRate = 192000;   

    % Create a structure to store sound waves
    soundWaves = struct();
    
    % Generate 10 different sound waves
    for i = 1:10
        % Generate sine wave with different frequencies
        freq = 261.63 + (i-1)*100; % Frequency increases by 50Hz for each wave
        soundWaves(i).waveform = GenerateSineWave(192000, freq, 4) * 0.3;
        soundWaves(i).frequency = freq;
        soundWaves(i).amplitude = 0.3;
        
        % Check waveform data
        disp(['Waveform ' num2str(i) ':']);
        disp([soundWaves(i).waveform(5:10)]);
    end

    % Run 10 trials
    for trial = 1:10
        disp(['Trial: ' num2str(trial)]);
        
        % Load the sound wave into BpodHiFi
        H.load(1, soundWaves(trial).waveform); % Give more time for the sound to load
        H.push();
        disp('Sound loaded to buffer 1');
        
        % Create a new state machine for this trial
        sma = NewStateMachine();
        
        % Add prepare state
        sma = AddState(sma, 'Name', 'Prepare', ...
            'Timer', 0.1, ...
            'StateChangeConditions', {'Tup', 'Sound'}, ...
            'OutputActions', {});
        
        % Add sound presentation state
        sma = AddState(sma, 'Name', 'Sound', ...
            'Timer', 2, ... % Play sound for 2 seconds
            'StateChangeConditions', {'Tup', 'Silence'}, ...
            'OutputActions', {'HiFi1', ['P' 0]}); % Play sound from buffer 1

        % Add silence state
        sma = AddState(sma, 'Name', 'Silence', ...
            'Timer', 1, ... % Silence for 1 second
            'StateChangeConditions', {'Tup', 'exit'}, ...
            'OutputActions', {'HiFi1', 'X'}); % Stop playback

        % Send state machine to Bpod
        SendStateMachine(sma);

        % Run state machine
        RawEvents = RunStateMachine;
        
        % Save trial data
        if ~isempty(fieldnames(RawEvents))
            BpodSystem.Data = AddTrialEvents(BpodSystem.Data, RawEvents);
            SaveBpodSessionData;
        end
    end
end


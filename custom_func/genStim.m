% GenStim generates a stimulus based on the stimulus parameters
% 1. randomize the stimulus parameters
% 2. generate the stimulus
% 3. save the stimulus to the stimulus set  
function Stim = GenStim(stimParams)
    % 1. randomize the stimulus parameters
    % Get sampling frequency
    Fs = 192000; % Hz sampling frequency 
    
    % Extract parameters from stimParams
    stimType = stimParams.stimType; % 'Auditory', 'Somatosensory', or 'Bimodal'
    duration = stimParams.duration; % ms
    amplitude = stimParams.amplitude; % V or dB SPL
    frequency = stimParams.frequency; % Hz
    waveform = stimParams.waveform; % 'Square', 'UniSine', 'BiSine' for somatosensory
    ramp = stimParams.ramp; % ms
    offset = stimParams.offset; % V
    
    % 2. generate the stimulus
    switch stimType
        case 'Somatosensory'
            % Generate somatosensory stimulus
            [stimWaveform, timeAxis] = gensomwaveform(waveform, duration, amplitude, frequency, ramp, Fs);
            
        case 'Auditory'
            % Generate auditory stimulus
            % For simplicity, we'll use a simple tone for now
            % In a real implementation, you would use more sophisticated audio generation
            timeAxis = 0:1/Fs:(duration/1000);
            stimWaveform = amplitude * sin(2*pi*frequency*timeAxis);
            
            % Apply envelope
            if ramp > 0
                Nenv = round(ramp * 10^-3 * Fs);
                stimWaveform = envelope(stimWaveform', Nenv)';
            end
            
        case 'Bimodal'
            % Generate both auditory and somatosensory stimuli
            % Somatosensory component
            [somWaveform, timeAxis] = gensomwaveform(waveform, duration, amplitude.som, frequency.som, ramp.som, Fs);
            
            % Auditory component
            audTimeAxis = 0:1/Fs:(duration/1000);
            audWaveform = amplitude.aud * sin(2*pi*frequency.aud*audTimeAxis);
            
            % Apply envelope to auditory component
            if ramp.aud > 0
                Nenv = round(ramp.aud * 10^-3 * Fs);
                audWaveform = envelope(audWaveform', Nenv)';
            end
            
            % Combine waveforms
            stimWaveform = struct('som', somWaveform, 'aud', audWaveform);
            
        otherwise
            error('Unknown stimulus type');
    end
    
    % 3. save the stimulus to the stimulus set
    Stim = struct();
    Stim.waveform = stimWaveform;
    Stim.timeAxis = timeAxis;
    Stim.params = stimParams;
    Stim.samplingRate = Fs;
end

% Helper function to generate somatosensory waveform
function [waveform, timeAxis] = gensomwaveform(waveformType, duration, amplitude, frequency, ramp, Fs)
    durationSamp = ceil(duration * 0.001 * Fs);
    timeAxis = 0:1/Fs:(duration/1000);
    waveform = nan(1, durationSamp);
    
    switch waveformType
        case 'Square'
            waveform = amplitude .* ones(1, durationSamp);
            waveform(1) = 0; waveform(end) = 0; % zero at beginning and end
            
        case 'UniSine'
            waveform = 0.5 * amplitude .* (1 - cos(2*pi*frequency .* timeAxis));
            
        case 'BiSine'
            waveform = amplitude .* sin(2*pi*frequency .* timeAxis);
            
        otherwise
            error('Unknown waveform type');
    end
    
    % Apply envelope (On-/Off-ramps)
    if ramp > 0
        Nenv = round(ramp * 10^-3 * Fs);
        waveform = envelope(waveform', Nenv)';
    end
end

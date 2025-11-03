function waveform = ApplySinRamp(waveform, ramp_ms, samplingRate)
% ApplySinRamp - Apply a sine-squared ramp envelope to a waveform
% This function applies smooth on- and off-ramps using a sine-squared envelope,
% similar to the implementation in NeuroPassiveFcns.m
% 
% Inputs:
%   waveform - Waveform to apply the ramp to (column vector or matrix)
%              If matrix, each column represents a channel
%   ramp_ms - Ramp duration in milliseconds (scalar or [on_ramp_ms, off_ramp_ms])
%             If scalar, same ramp duration is applied to both on and off
%   samplingRate - Sampling rate in Hz
% 
% Output:
%   waveform - Waveform with the ramp envelope applied (same size as input)
%
% Example:
%   waveform = ApplySinRamp(waveform, 5, 192000);  % 5ms ramp on both ends
%   waveform = ApplySinRamp(waveform, [5, 10], 192000);  % 5ms on-ramp, 10ms off-ramp

    % Convert ramp duration from milliseconds to samples
    if length(ramp_ms) == 1
        % Same ramp duration for both on and off
        rampSamples = round(ramp_ms * 1e-3 * samplingRate);
        NEnv = [rampSamples, rampSamples];
    else
        % Different ramp durations for on and off
        NEnv = [round(ramp_ms(1) * 1e-3 * samplingRate), ...
                round(ramp_ms(2) * 1e-3 * samplingRate)];
    end
    
    % Ensure waveform is column vector or column-major matrix
    [sigLen, nChannels] = size(waveform);
    
    % Check if signal is long enough for the envelope
    if sigLen < 2 * max(NEnv)
        error('ApplySinRamp: Signal length (%d samples) is too short for ramp duration (max %d samples)', ...
              sigLen, max(NEnv));
    end
    
    % Create on-ramp envelope (sine-squared)
    % Envelope goes from 0 to 1 over NEnv(1) samples
    Env1 = (sin(0.5 * pi * (0:NEnv(1)) / NEnv(1))).^2;
    
    % Create off-ramp envelope (sine-squared, flipped)
    % Envelope goes from 1 to 0 over NEnv(2) samples
    Env2 = flip((sin(0.5 * pi * (0:NEnv(2)) / NEnv(2))).^2);
    
    % Define indices for head and tail
    head = 1:(NEnv(1) + 1);
    tail = (sigLen - NEnv(2)):sigLen;
    
    % Apply envelope to each channel
    for i = 1:nChannels
        % Apply on-ramp to head
        waveform(head, i) = Env1' .* waveform(head, i);
        
        % Apply off-ramp to tail
        waveform(tail, i) = Env2' .* waveform(tail, i);
    end
end

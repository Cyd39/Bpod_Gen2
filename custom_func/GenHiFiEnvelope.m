function envelope = GenHiFiEnvelope(duration_ms, ramp_ms, samplingRate)
% GenHiFiEnvelope - Generate envelope for HiFi module AMenvelope
% This function creates a fade-in/fade-out envelope for both sound and vibration ramping
% The envelope applies to both channels of the stereo output (sound and vibration)
% 
% Inputs:
%   duration_ms - Total duration of the stimulus in milliseconds
%   ramp_ms - Ramp duration in milliseconds (fade-in and fade-out)
%   samplingRate - Sampling rate in Hz (default: 192000)
%
% Output:
%   envelope - Vector of amplitude coefficients (0-1) for HiFi AMenvelope
%
% Usage:
%   envelope = GenHiFiEnvelope(1000, 50, 192000); % 1s stimulus with 50ms ramps
%   H.AMenvelope = envelope; % Applies to both sound and vibration channels

    if nargin < 3
        samplingRate = 192000; % Default HiFi sampling rate
    end
    
    % Convert to samples
    totalSamples = round(duration_ms * samplingRate / 1000);
    rampSamples = round(ramp_ms * samplingRate / 1000);
    
    % Initialize envelope
    envelope = ones(totalSamples, 1);
    
    % Create fade-in (first ramp_ms)
    if rampSamples > 0 && rampSamples < totalSamples/2
        % Cosine fade-in: smooth transition from 0 to 1
        fadeInSamples = 1:rampSamples;
        envelope(fadeInSamples) = (1 - cos(pi * fadeInSamples / rampSamples)) / 2;
        
        % Create fade-out (last ramp_ms)
        fadeOutSamples = (totalSamples - rampSamples + 1):totalSamples;
        envelope(fadeOutSamples) = (1 + cos(pi * (fadeOutSamples - (totalSamples - rampSamples)) / rampSamples)) / 2;
    end
    
    % Ensure envelope values are in range [0, 1]
    envelope = max(0, min(1, envelope));
    
    % Display info
    disp(['Generated HiFi envelope: ' num2str(duration_ms) 'ms duration, ' num2str(ramp_ms) 'ms ramps, ' num2str(length(envelope)) ' samples']);
end

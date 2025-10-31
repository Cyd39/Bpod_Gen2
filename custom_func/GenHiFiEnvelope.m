function envelope = GenHiFiEnvelope(ramp_ms, samplingRate)
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

    if nargin < 2
        samplingRate = 192000; % Default HiFi sampling rate
    end
    
    % Convert to samples
    rampSamples = round(ramp_ms * samplingRate / 1000);
    
    % Initialize envelope
    % Create fade-in (first ramp_ms)
    envelope = (1 - cos(pi * (1:rampSamples) / rampSamples)) / 2;

    % Ensure envelope values are in range [0, 1]
    envelope = max(0, min(1, envelope));
    
    % Display info
    disp(['Generated HiFi envelope: ',  num2str(ramp_ms) 'ms ramps, ' num2str(length(envelope)) ' samples']);
end

function PlotPsychoFunc(SessionData)
    % PlotPsychoFunc - Plot psychometric function from SessionData
    % 
    % This function plots the psychometric function from SessionData.
    % 
    % Inputs:
    %   SessionData - Session data structure
    % 
    % Usage:
    %   PlotPsychoFunc(SessionData);
    
    %% Calculate response rates for each stimulus(including false alarm rate)
    %  Get unique stimuli from SessionData
    all_stimuli = unique(SessionData.StimTable(:,{'VibAmp','VibFreq'}),'rows'); % including catch trials (Freq = 0, Amp = 0)
    stimulus_freqs = unique(all_stimuli.VibFreq); % unique frequencies

    % Calculate response rates for each stimulus
    ResponseRates = zeros(length(stimulus_freqs), 2);


    %% Define and fit psychometric function for each frequency
    psychometric_model = @(params, x) params(1) + (1 - params(1) - params(2)) ./ ...
    (1 + exp(-params(3) * (x - params(4))));  % params = [guess_rate, lapse_rate, slope, threshold]
    %% Plot psychometric function for each frequency

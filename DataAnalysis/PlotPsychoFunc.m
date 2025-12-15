function PlotPsychoFunc()
    % PlotPsychoFunc - Plot psychometric function from SessionData
    % 
    % This function plots the psychometric function from SessionData.
    % 
    % Inputs:
    %   SessionData - Session data structure
    % 
    % Usage:
    %   PlotPsychoFunc(SessionData);
    
    %% calculate response table from multiple files
    [responseTable, fileList] = CalculateResponseTable()


    %% Define and fit psychometric function for each frequency
    psychometric_model = @(params, x) params(1) + (1 - params(1) - params(2)) ./ ...
    (1 + exp(-params(3) * (x - params(4))));  % params = [guess_rate, lapse_rate, slope, threshold]
    %% Plot psychometric function for each frequency

% PlotPsychoFunc - Plot psychometric function from SessionData
% 
% This script plots the psychometric function grouped by frequency.
% Each frequency has its own subplot, with all mice's curves plotted together.
% 
% File saved:
%   - psychometric_function_<timestamp>.mat: Fitted psychometric function parameters
%   - psychometric_function_<timestamp>.fig: Figure of psychometric functions

%% Calculate response table from multiple files
[responseTable, fileList] = CalculateResponseTable();

if isempty(responseTable)
    warning('No data to plot.');
    return;
end

tol = 1e-6;

% Separate catch trials (VibFreq == 0 & VibAmp == 0) from regular trials
catchTrialRows = abs(responseTable.VibFreq) < tol & abs(responseTable.VibAmp) < tol;
catchTrials = responseTable(catchTrialRows, :);
regularTrials = responseTable(~catchTrialRows, :);

if isempty(regularTrials)
    warning('No valid stimulus data to plot.');
    return;
end

%% Get unique frequencies and mice from regular trials
uniqueFreqs = unique(regularTrials.VibFreq);
uniqueMice = unique(regularTrials.MouseID);

% Remove NaN frequencies
uniqueFreqs = uniqueFreqs(~isnan(uniqueFreqs));

% Expand catch trials: assign catch trial data to each frequency as VibAmp = 0
% This means catch trials will be included in fits for all frequencies
if ~isempty(catchTrials) && ~isempty(uniqueFreqs)
    expandedCatchTrials = table();
    for freqIdx = 1:length(uniqueFreqs)
        freq = uniqueFreqs(freqIdx);
        % For each catch trial, create a copy with this frequency
        catchForFreq = catchTrials;
        catchForFreq.VibFreq = repmat(freq, height(catchForFreq), 1);
        catchForFreq.VibAmp = zeros(height(catchForFreq), 1);
        expandedCatchTrials = [expandedCatchTrials; catchForFreq];
    end
    % Combine regular trials with expanded catch trials
    responseTable = [regularTrials; expandedCatchTrials];
    fprintf('Catch trials assigned to all %d frequencies as VibAmp = 0\n', length(uniqueFreqs));
end

fprintf('Found %d unique frequencies and %d unique mice\n', length(uniqueFreqs), length(uniqueMice));

%% Initialize fit parameters storage
% Clear any existing table variable to avoid conflicts
if exist('table', 'var') && ~isa(table, 'function_handle')
    clear table;
end
fit_params = table();

%% Define psychometric function (Weibull with guess and lapse rates)
% P(response) = guess_rate + (1 - guess_rate - lapse_rate) * (1 - exp(-(x/threshold)^slope))
psychometric_model = @(params, x) params(1) + (1 - params(1) - params(2)) * (1 - exp(-(x/params(4)).^params(3)));
% params = [guess_rate, lapse_rate, slope, threshold]

%% Fit psychometric function for each mouse and frequency
fprintf('\n=== Fitting Psychometric Functions ===\n');
for mouseIdx = 1:length(uniqueMice)
    mouseID = uniqueMice{mouseIdx};
    mouseData = responseTable(strcmp(responseTable.MouseID, mouseID), :);
    
    for freqIdx = 1:length(uniqueFreqs)
        freq = uniqueFreqs(freqIdx);
        freqData = mouseData(abs(mouseData.VibFreq - freq) < tol, :);
        
        if height(freqData) < 3
            fprintf('  %s @ %.2f Hz: Insufficient data points (%d), skipping fit\n', mouseID, freq, height(freqData));
            continue;
        end
        
        % Calculate response rate
        responseRate = freqData.Response ./ freqData.NTrials;
        vibAmps = freqData.VibAmp;
        
        % Remove invalid data points (keep VibAmp = 0 for fitting)
        validIdx = ~isnan(responseRate) & ~isnan(vibAmps);
        if sum(validIdx) < 3
            continue;
        end
        responseRate = responseRate(validIdx);
        vibAmps = vibAmps(validIdx);
        
        % Initial parameters: [guess_rate, lapse_rate, slope, threshold]
        % Use median of non-zero amplitudes for threshold initialization
        nonZeroAmps = vibAmps(vibAmps > 0);
        if isempty(nonZeroAmps)
            continue; % Skip if no non-zero amplitudes
        end
        initialParams = [0.5, 0.01, 2, median(nonZeroAmps)];
        lowerBounds = [0, 0, 0.1, min(nonZeroAmps)];
        upperBounds = [1, 0.5, 10, max(vibAmps) * 2];
        
        try
            % Fit using fmincon
            fitResult = fmincon(@(params) sum((psychometric_model(params, vibAmps) - responseRate).^2), ...
                initialParams, [], [], [], [], lowerBounds, upperBounds, [], ...
                optimoptions('fmincon', 'Display', 'off'));
            
            % Store fit parameters
            newRow = table({mouseID}, freq, fitResult(4), fitResult(3), fitResult(1), fitResult(2), ...
                'VariableNames', {'MouseID', 'VibFreq', 'Threshold', 'Slope', 'GuessRate', 'LapseRate'});
            fit_params = [fit_params; newRow];
            
            fprintf('  %s @ %.2f Hz: Threshold=%.2f, Slope=%.2f\n', mouseID, freq, fitResult(4), fitResult(3));
        catch ME
            warning('Failed to fit %s @ %.2f Hz: %s', mouseID, freq, ME.message);
            continue;
        end
    end
end

%% Plot psychometric function for each frequency
fprintf('\n=== Plotting Psychometric Functions ===\n');

% Determine subplot layout
nFreqs = length(uniqueFreqs);
if nFreqs == 0
    warning('No frequencies to plot.');
    return;
end

% Calculate subplot dimensions
nCols = ceil(sqrt(nFreqs));
nRows = ceil(nFreqs / nCols);

% Create figure
fig = figure('Name', 'Psychometric Functions by Frequency', ...
    'Position', [100, 100, 1200, 800]);

% Color map for different mice
colors = lines(length(uniqueMice));

for freqIdx = 1:nFreqs
    freq = uniqueFreqs(freqIdx);
    subplot(nRows, nCols, freqIdx);
    hold on;
    
    % Get all data for this frequency
    freqData = responseTable(abs(responseTable.VibFreq - freq) < tol, :);
    
    % Plot data points and fitted curves for each mouse
    for mouseIdx = 1:length(uniqueMice)
        mouseID = uniqueMice{mouseIdx};
        mouseFreqData = freqData(strcmp(freqData.MouseID, mouseID), :);
        
        if isempty(mouseFreqData)
            continue;
        end
        
        % Calculate response rate
        responseRate = mouseFreqData.Response ./ mouseFreqData.NTrials;
        vibAmps = mouseFreqData.VibAmp;
        
        % Remove invalid data (keep VibAmp = 0 for plotting)
        validIdx = ~isnan(responseRate) & ~isnan(vibAmps);
        if sum(validIdx) == 0
            continue;
        end
        responseRate = responseRate(validIdx);
        vibAmps = vibAmps(validIdx);
        
        % Plot data points
        scatter(vibAmps, responseRate, 50, colors(mouseIdx, :), 'filled', ...
            'DisplayName', mouseID, 'MarkerEdgeColor', 'k', 'LineWidth', 0.5);
        
        % Plot fitted curve if available
        mouseFit = fit_params(strcmp(fit_params.MouseID, mouseID) & ...
            abs(fit_params.VibFreq - freq) < tol, :);
        
        if ~isempty(mouseFit)
            % Generate smooth curve
            % Ensure mouseFit has only one row (take first if multiple)
            if height(mouseFit) > 1
                mouseFit = mouseFit(1, :);
            end
            % Generate curve from 0 to max amplitude (include VibAmp = 0)
            ampRange = linspace(0, max(vibAmps), 100);
            params = [mouseFit.GuessRate(1), mouseFit.LapseRate(1), mouseFit.Slope(1), mouseFit.Threshold(1)];
            fittedCurve = psychometric_model(params, ampRange);
            
            plot(ampRange, fittedCurve, 'Color', colors(mouseIdx, :), ...
                'LineWidth', 2, 'LineStyle', '-', 'HandleVisibility', 'off');
        end
    end
    
    % Format subplot
    xlabel('Vibration Amplitude');
    ylabel('Response Rate');
    title(sprintf('%.2f Hz', freq));
    legend('Location', 'northwest', 'FontSize', 8);
    grid on;
    ylim([0, 1]);
    hold off;
end

% Add overall title
sgtitle('Psychometric Functions by Frequency', 'FontSize', 14, 'FontWeight', 'bold');

%% Save fit parameters, file list, and response table
timestamp = datetime('now', 'Format', 'yyyyMMdd_HHMMSS');
timestamp_str = char(timestamp);
save_dir = pwd;
save_path = fullfile(save_dir, ['psychometric_function_' timestamp_str '.mat']);
save(save_path, 'fit_params', 'fileList', 'responseTable');
fprintf('\nData saved to: %s\n', save_path);

%% Save figure
fig_path = fullfile(save_dir, ['psychometric_function_' timestamp_str '.fig']);
savefig(fig, fig_path);
fprintf('Figure saved to: %s\n', fig_path);
    
fprintf('\nPsychometric function plotted and saved successfully!\n');
fprintf('========================================\n');

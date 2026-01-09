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
    % Add Displacement Column
    responseTable.FullDisplace_um = responseTable.VibAmp*93.1;
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
psychometric_fig = figure('Name', 'Psychometric Functions by Frequency', ...
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
        
        % Sort data for plotting
        [vibAmps,ampIdx] = sort(vibAmps);
        responseRate = responseRate(ampIdx);
        
        % Plot data points (scatter)
        plot(vibAmps, responseRate, 'MarkerFaceColor', colors(mouseIdx, :),  'Marker','o','MarkerSize', 10, ...
            'DisplayName', mouseID, 'MarkerEdgeColor', 'k', 'LineWidth', 0.5, 'LineStyle', 'none');
        
        % Plot fitted curve or connecting line
        if ~isempty(fit_params) && height(fit_params) > 0
            % Check if fit parameters exist for this mouse and frequency
            mouseFit = fit_params(strcmp(fit_params.MouseID, mouseID) & ...
                abs(fit_params.VibFreq - freq) < tol, :);
            
            if ~isempty(mouseFit)
                % Plot fitted curve
                % Ensure mouseFit has only one row (take first if multiple)
                if height(mouseFit) > 1
                    mouseFit = mouseFit(1, :);
                end
                % Generate smooth curve from 0 to max amplitude
                maxAmp = max(vibAmps);
                if maxAmp > 0
                    ampRange = linspace(0, maxAmp, 100);
                    params = [mouseFit.GuessRate(1), mouseFit.LapseRate(1), mouseFit.Slope(1), mouseFit.Threshold(1)];
                    fittedCurve = psychometric_model(params, ampRange);
                    
                    plot(ampRange, fittedCurve, 'Color', colors(mouseIdx, :), ...
                        'LineWidth', 2, 'LineStyle', '-', 'HandleVisibility', 'off');
                else
                    % Only catch trials (VibAmp = 0), plot connecting line instead
                    plot(vibAmps, responseRate, 'Color', colors(mouseIdx, :), ...
                        'LineWidth', 1.5, 'LineStyle', '--', 'HandleVisibility', 'off');
                end
            else
                % No fit available, plot connecting line
                plot(vibAmps, responseRate, 'Color', colors(mouseIdx, :), ...
                    'LineWidth', 1.5, 'LineStyle', '--', 'HandleVisibility', 'off');
            end
        else
            % No fit_params available, plot connecting line
            plot(vibAmps, responseRate, 'Color', colors(mouseIdx, :), ...
                'LineWidth', 1.5, 'LineStyle', '--', 'HandleVisibility', 'off');
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

%% Plot left rate by frequency
fprintf('\n=== Plotting Left Rate by Frequency ===\n');

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
left_rate_fig = figure('Name', 'Left Rate by Frequency', ...
    'Position', [100, 100, 1200, 800]);

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
        
        % Calculate left response rate
        leftResponseRate = mouseFreqData.LeftRes ./ mouseFreqData.Response;
        vibAmps = mouseFreqData.VibAmp;
        
        % Remove invalid data (keep VibAmp = 0 for plotting)
        validIdx = ~isnan(leftResponseRate) & ~isnan(vibAmps);
        if sum(validIdx) == 0
            continue;
        end
        leftResponseRate = leftResponseRate(validIdx);
        vibAmps = vibAmps(validIdx);
        
        % Sort data for plotting
        [vibAmps,ampIdx] = sort(vibAmps);
        leftResponseRate = leftResponseRate(ampIdx);
        
        % Plot data points (scatter)
        plot(vibAmps, leftResponseRate, 'MarkerFaceColor', colors(mouseIdx, :),  'Marker','o','MarkerSize', 10, ...
            'DisplayName', mouseID, 'MarkerEdgeColor', 'k', 'LineWidth', 0.5, 'LineStyle', 'none');
        
        % Plot connecting line (no fit for left rate)
        plot(vibAmps, leftResponseRate, 'Color', colors(mouseIdx, :), ...
            'LineWidth', 1.5, 'LineStyle', '--', 'HandleVisibility', 'off');
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
sgtitle('Left Rate by Frequency', 'FontSize', 14, 'FontWeight', 'bold');
%% Save fit parameters, file list, and response table
timestamp = datetime('now', 'Format', 'yyyyMMdd_HHmmss');
timestamp_str = char(timestamp);
% directory to save the figures and data
save_dir = 'G:\Data\ProcessedData\Yudi\OperantConditioning\PooledPsychoFunc&LeftRate';

save_path = fullfile(save_dir, ['psychometric_function_' timestamp_str '.mat']);
save(save_path, 'fit_params', 'fileList', 'responseTable');
fprintf('\nData saved to: %s\n', save_path);

%% Save figures
psychometric_fig_path = fullfile(save_dir, ['psychometric_function_' timestamp_str '.fig']);
psychometric_png_path = fullfile(save_dir, ['psychometric_function_' timestamp_str '.png']);
savefig(psychometric_fig, psychometric_fig_path);
saveas(psychometric_fig, psychometric_png_path, 'png');
fprintf('Psychometric function figure saved to: %s\n', psychometric_fig_path);
fprintf('Psychometric function PNG saved to: %s\n', psychometric_png_path);

left_rate_fig_path = fullfile(save_dir, ['left_rate_function_' timestamp_str '.fig']);
left_rate_png_path = fullfile(save_dir, ['left_rate_function_' timestamp_str '.png']);
savefig(left_rate_fig, left_rate_fig_path);
saveas(left_rate_fig, left_rate_png_path, 'png');
fprintf('Left rate figure saved to: %s\n', left_rate_fig_path);
fprintf('Left rate PNG saved to: %s\n', left_rate_png_path);

fprintf('\nAll figures plotted and saved successfully!\n');
fprintf('========================================\n');

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
    ylabel('Left Rate');
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

%% Plot left rate seperately by mouse(by frequency within each subplot) 
r = responseTable;
highResRate = 0.75; % standard of "high response rate"

mice = unique(r.MouseID);
nMice = length(mice);

% keep only one line for catch trial for each mouse
% and make VibFreq to be 0 again for catch trials
r.to_keep = true(height(r), 1);
zero_rows = r.VibAmp == 0;
for id = mice'
    id_rows = find(strcmp(r.MouseID,id) & zero_rows);
    if numel(id_rows) > 1
        r.to_keep(id_rows(2:end)) = false;
    end
end
r = r(r.to_keep, :);
r.to_keep = [];  
idx_catch = r.VibAmp ==0;
r.VibFreq(idx_catch) = 0;

% add response rate and left rate column
r.ResRate = r.Response ./r.NTrials;
r.LeftRate = r.LeftRes ./r.Response;

% calculate subplot rows and columns
nCols = ceil(sqrt(nMice));
nRows = ceil(nMice / nCols);

uniqueFreqs = sort(unique(r.VibFreq));

% Create figure
figure('Position', [200, 200, 800, 600]);
freqColors = lines(length(uniqueFreqs));

for m = 1:nMice
    subplot(nCols,nRows,m)
    hold on;
    mouseMask = strcmp(r.MouseID, mice{m});
    mouseData = r(mouseMask, :);
    x_positions = zeros(height(mouseData), 1);
    group_labels = cell(height(mouseData), 1);
    
    for f = 1:length(uniqueFreqs)
        freq = uniqueFreqs(f);
        freqMask = mouseData.VibFreq == freq;
        
        if any(freqMask)
            n_points = sum(freqMask);
            x_positions(freqMask) = f + linspace(-0.2, 0.2, n_points)';
        end
    end
    
    for f = 1:length(uniqueFreqs)
        freq = uniqueFreqs(f);
        freqMask = mouseData.VibFreq == freq;
        if any(freqMask)
                scatter(x_positions(freqMask), mouseData.LeftRate(freqMask), 120,...
                    freqColors(f,:), 'filled');
        end
    end
    
    title(sprintf('Mouse: %s', mice{m}));
    ylabel('Left Rate');
    ylim([0, 1]);
    grid off;
    
    % 设置 x 轴：每个频率一个刻度
    xticks(1:length(uniqueFreqs));
    tickLabels = cell(length(uniqueFreqs), 1);
    for f = 1:length(uniqueFreqs)
        if uniqueFreqs(f) == 0
            tickLabels{f} = '';
        else
            tickLabels{f} = num2str(uniqueFreqs(f));
        end
    end
    xticklabels(tickLabels);
    xlabel('Vibration Frequency (Hz)');
    
    % show amplitude
    for i = 1:height(mouseData)
        if mouseData.VibAmp(i) ~= 0
            text(x_positions(i)-0.07, mouseData.LeftRate(i)+0.02, ...
                 sprintf('%.2f', mouseData.VibAmp(i)), ... % sprintf('%.2f μm', mouseData.VibAmp(i) * 93.1), ... % displacement
                 'FontSize', 12, 'VerticalAlignment', 'bottom',...
                 'HorizontalAlignment', 'center');
                
        else
            text(x_positions(i)-0.2, mouseData.LeftRate(i)+0.02, ...
                 'catch trial', ...
                 'FontSize', 12, 'VerticalAlignment', 'bottom');
        end
    end

end

sgtitle('Left Rate');

saveFigAsPNG("LeftRate");
%% Helper: Save Figure As PNG
function saveFigAsPNG(prefix)
% SAVE FIGURE AS PNG
% Save current MATLAB figure as PNG format with timestamp in filename
% 
% INPUTS:
%   prefix    - Optional prefix for filename (optional)
%
% OUTPUT:
%   Saves figure as PNG file with format: YYMMDD_HHMMSS.png
%   Example: 240123_143022.png

    figHandle = gcf;  % Use current figure
    savePath = "G:\Data\ProcessedData\Yudi\OperantConditioning";   % Default save path
    
    if nargin < 1
        prefix = '';
    end
    
    % Generate timestamp for filename using datetime
    % Format: YYMMDD_HHMMSS
    currentTime = datetime('now', 'Format', 'yyMMdd_HHmmss');
    timestampStr = char(currentTime);  % Convert datetime to char array
    
    % Build complete filename
    if isempty(prefix)
        filename = sprintf('%s.png', timestampStr);
    else
        filename = sprintf('%s_%s.png', prefix, timestampStr);
    end
    
    fullPath = fullfile(savePath, filename);
    
    % Ensure save directory exists
    if ~exist(savePath, 'dir')
        mkdir(savePath);
    end
    
    % Set figure export parameters
    set(figHandle, 'PaperPositionMode', 'auto');  % Maintain screen display size
    
    % Save as PNG format
    print(figHandle, fullPath, '-dpng', '-r300');  % 300 DPI resolution
    
    % Display confirmation message
    fprintf('Figure saved as: %s\n', fullPath);
end
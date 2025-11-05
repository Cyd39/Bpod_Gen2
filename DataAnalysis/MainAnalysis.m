%% load data
[SessionData, ~, ~] = LoadData();

%% ExtractTimeStamps
Session_tbl = ExtractTimeStamps(SessionData);

%%
plotraster_behavior(Session_tbl)

%% pre-process data
% align timing to stimulus onset
n_stim = height(Session_tbl);
%LickOn = cell(n_stim,1);
% LickOff = cell(n_stim,1);

% align timing to stimulus onset
for ii = 1:height(Session_tbl)
    Session_tbl.LickOnAfterStim{ii} = Session_tbl.LickOn{ii} - Session_tbl.Stimulus{ii}(1);
    Session_tbl.LickOffAfterStim{ii} = Session_tbl.LickOff{ii} - Session_tbl.Stimulus{ii}(1);
end

% calculate first lick after stimulus onset
FirstLickAfterStim = cellfun(@(x) min(x(x>0)), Session_tbl.LickOnAfterStim, 'UniformOutput', false);
Session_tbl.FirstLickAfterStim = FirstLickAfterStim;

disp("Data pre-processed.")

%% add column "Hit" to Session_tbl
Session_tbl.Hit = zeros(height(Session_tbl), 1); % Initialize Hit column

for t = 1:height(Session_tbl)
    % Get trial parameters
    ResWin = SessionData.TrialSettings(t).GUI.ResWin;
    LickOn_t = Session_tbl.FirstLickAfterStim{t};
    
    % Check if FirstLickAfterStim is within the time window and not NaN
    if ~isempty(LickOn_t) && ~all(isnan(LickOn_t))
        % Check if any valid lick is within the response window
        licksInWindow = LickOn_t >= 0 & LickOn_t <= ResWin;
        
        if any(licksInWindow)
            Session_tbl.Hit(t) = 1;
        else
            Session_tbl.Hit(t) = 0;
        end
    end
end

disp("Colon 'Hit' added.");

%% histogram
figure('Position', [200, 300, 1600, 400]);

% All licks
subplot(1, 2, 1);
% Convert cell array to numeric array for histogram
% Preallocate with maximum possible size
maxPossibleSize = sum(cellfun(@(x) length(x), Session_tbl.LickOnAfterStim));
allLickOnTimes = zeros(maxPossibleSize, 1);
currentIndex = 1;

for i = 1:height(Session_tbl)
    if ~isempty(Session_tbl.LickOnAfterStim{i}) && ~all(isnan(Session_tbl.LickOnAfterStim{i}))
        validTimes = Session_tbl.LickOnAfterStim{i}(~isnan(Session_tbl.LickOnAfterStim{i}));
        validTimes = validTimes(:);
        nValid = length(validTimes);
        allLickOnTimes(currentIndex:currentIndex+nValid-1) = validTimes;
        currentIndex = currentIndex + nValid;
    end
end
% Trim to actual size
allLickOnTimes = allLickOnTimes(1:currentIndex-1);
histogram(allLickOnTimes, -5:0.05:2);
title('All Lick On Times');

xlabel('Time (s)');
ylabel('Count');

% First LickOn
subplot(1, 2, 2);
% Convert cell array to numeric array for histogram
% Preallocate with maximum possible size
firstLickOnTimes = zeros(height(Session_tbl), 1);
currentIndex = 1;

for i = 1:height(Session_tbl)
    if ~isempty(Session_tbl.FirstLickAfterStim{i}) && ~isnan(Session_tbl.FirstLickAfterStim{i})
        firstLickTime = Session_tbl.FirstLickAfterStim{i}(:);
        firstLickOnTimes(currentIndex) = firstLickTime;
        currentIndex = currentIndex + 1;
    end
end
% Trim to actual size
firstLickOnTimes = firstLickOnTimes(1:currentIndex-1);
histogram(firstLickOnTimes, 0:0.05:2);
title('First Lick On Times');
xlabel('Time (s)');
ylabel('Count');

%% raster plot
LickOn = Session_tbl.LickOnAfterStim;
fig = figure;
ax = axes("Parent",fig);
uInt = unique(Session_tbl.AudIntensity);
nInt= length(uInt);
Colour = turbo(nInt);%[0,0,0];
[ax,YTick,YTickLab] = plotraster(ax, LickOn,Session_tbl.AudIntensity, Colour,10,1);
ax.YTick = YTick{1};
ax.YTickLabel = YTickLab;
xlim(ax,[0,2])

% Increase marker size for better visibility
set(findobj(ax, 'Type', 'line'), 'MarkerSize', 8);
set(findobj(ax, 'Type', 'line'), 'LineWidth', 1.5);

%% plot hit rate
% Calculate hit rate for each intensity level
hitRateTable = CalculateHitRate(Session_tbl);

% Create hit rate plot with -inf on x-axis
figure;

% Check if -inf is present in intensities
hasInf = any(isinf(hitRateTable.Intensity) & hitRateTable.Intensity < 0);

if hasInf
    % Separate -inf from other intensities for plotting
    infMask = isinf(hitRateTable.Intensity) & hitRateTable.Intensity < 0;
    normalMask = ~infMask;
    
    % Create x-axis values with -inf positioned to the left
    xValues = hitRateTable.Intensity;
    if any(normalMask)
        minNormalInt = min(hitRateTable.Intensity(normalMask));
        xValues(infMask) = minNormalInt - 20; % Position -inf to the left
    end
    
    % Plot normal intensities first
    if any(normalMask)
        plot(xValues(normalMask), hitRateTable.HitRate(normalMask) * 100, 'o-', 'LineWidth', 2, 'MarkerSize', 8);
        hold on;
    end
    
    % Plot -inf values
    if any(infMask)
        plot(xValues(infMask), hitRateTable.HitRate(infMask) * 100, 's', 'LineWidth', 2, 'MarkerSize', 8, 'Color', 'red');
    end
    
    % Set x-axis limits
    xlim([min(xValues)-5, max(xValues)+5]);
    
    % Create custom x-axis with break
    ax = gca;
    % Set tick positions
    tickPositions = [xValues(infMask); xValues(normalMask)];
    ax.XTick = tickPositions;
    
    % Set tick labels
    tickLabels = cell(length(tickPositions), 1);
    for i = 1:length(tickPositions)
        if isinf(tickPositions(i)) && tickPositions(i) < 0
            tickLabels{i} = '-∞';
        else
            tickLabels{i} = num2str(tickPositions(i));
        end
    end
    ax.XTickLabel = tickLabels;
    
    % Add break symbol on x-axis
    if any(normalMask)
        xBreak = minNormalInt - 10;
        yLim = ylim;
        plot([xBreak, xBreak], yLim, 'k--', 'LineWidth', 1);
        text(xBreak, yLim(2), '//', 'HorizontalAlignment', 'center', 'FontSize', 12);
    end
    
else
    % No -inf values, plot normally
    plot(hitRateTable.Intensity, hitRateTable.HitRate * 100, 'o-', 'LineWidth', 2, 'MarkerSize', 8);
end

xlabel('Intensity');
ylabel('Hit Rate (%)');
title('Hit Rate vs Intensity');
grid on;

% Add data points as text labels
for i = 1:height(hitRateTable)
    if hasInf && infMask(i)
        xPos = xValues(i);
    else
        xPos = hitRateTable.Intensity(i);
    end
    text(xPos, hitRateTable.HitRate(i) * 100 + 2, ...
        sprintf('n=%d', hitRateTable.TotalTrials(i)), ...
        'HorizontalAlignment', 'center', 'FontSize', 8);
end

% Add legend if there are -inf values
if hasInf
    legend('Stimulus', 'No Stimulus', 'Location', 'best');
end

%% plot latency
% Calculate latency for Hit = 1 trials by intensity
hitTrials = Session_tbl.Hit == 1;
latencyByIntensity = struct();

% Get unique intensities
uInt = unique(Session_tbl.AudIntensity);

for t = 1:height(Session_tbl)
    if hitTrials(t)
        % Get trial data
        intensity = Session_tbl.AudIntensity(t);
        
        % Get FirstLickAfterStim (already aligned to stimulus onset)
        firstLickTime = Session_tbl.FirstLickAfterStim{t};
        
        % Check if we have a valid first lick time
        if ~isempty(firstLickTime) && ~isnan(firstLickTime)
            % FirstLickAfterStim is already the latency (time from stimulus onset)
            latency = firstLickTime;
            
                            % Store latency by intensity
                intensityStr = num2str(intensity);
                % Create safe field name
                if isinf(intensity) && intensity < 0
                    fieldName = 'Intensity_Inf';
                else
                    fieldName = ['Intensity_' intensityStr];
                end
                if ~isfield(latencyByIntensity, fieldName)
                    latencyByIntensity.(fieldName) = [];
                end
                latencyByIntensity.(fieldName) = [latencyByIntensity.(fieldName); latency];
        end
    end
end

% Create boxplot of latency by intensity
if ~isempty(fieldnames(latencyByIntensity))
    % Count how many intensities have data
    validIntensities = 0;
    for i = 1:length(uInt)
        intensityStr = num2str(uInt(i));
        % Create safe field name
        if isinf(uInt(i)) && uInt(i) < 0
            fieldName = 'Intensity_Inf';
        else
            fieldName = ['Intensity_' intensityStr];
        end
        if isfield(latencyByIntensity, fieldName) && ~isempty(latencyByIntensity.(fieldName))
            validIntensities = validIntensities + 1;
        end
    end
    
    if validIntensities > 0
        % Create single figure for all boxplots
        figure('Position', [100, 100, 800, 500]);
        
        fprintf('\nLatency Analysis by Intensity (Hit trials only):\n');
        fprintf('================================================\n');
        
        % Prepare data for combined boxplot
        allData = [];
        groupLabels = {};
        
        for i = 1:length(uInt)
            intensityStr = num2str(uInt(i));
            % Create safe field name
            if isinf(uInt(i)) && uInt(i) < 0
                fieldName = 'Intensity_Inf';
            else
                fieldName = ['Intensity_' intensityStr];
            end
            if isfield(latencyByIntensity, fieldName) && ~isempty(latencyByIntensity.(fieldName))
                data = latencyByIntensity.(fieldName);
                allData = [allData; data];
                
                % Create group labels
                if isinf(uInt(i)) && uInt(i) < 0
                    intensityLabel = '-∞';
                else
                    intensityLabel = intensityStr;
                end
                
                % Add group labels for each data point
                groupLabels = [groupLabels; repmat({intensityLabel}, length(data), 1)];
                
                % Print statistics
                meanLatency = mean(data);
                medianLatency = median(data);
                stdLatency = std(data);
                fprintf('Intensity %s: n=%d, mean=%.3f±%.3f s, median=%.3f s\n', ...
                    intensityLabel, length(data), meanLatency, stdLatency, medianLatency);
            end
        end
        
        % Create combined boxplot
        boxplot(allData, groupLabels);
        hold on;
        
        % Add individual data points
        for i = 1:length(uInt)
            intensityStr = num2str(uInt(i));
            if isinf(uInt(i)) && uInt(i) < 0
                fieldName = 'Intensity_Inf';
            else
                fieldName = ['Intensity_' intensityStr];
            end
            if isfield(latencyByIntensity, fieldName) && ~isempty(latencyByIntensity.(fieldName))
                data = latencyByIntensity.(fieldName);
                % Add jittered points
                x_pos = i + (rand(length(data), 1) - 0.5) * 0.3;
                scatter(x_pos, data, 20, 'k', 'filled', 'MarkerFaceAlpha', 0.6);
            end
        end
        
        xlabel('Intensity');
        ylabel('Latency (s)');
        title('Latency by Intensity (Hit Trials Only)');
        grid on;
        
        % Add statistics as text on the plot
        yLim = ylim;
        textY = yLim(2) * 0.95;
        for i = 1:length(uInt)
            intensityStr = num2str(uInt(i));
            if isinf(uInt(i)) && uInt(i) < 0
                fieldName = 'Intensity_Inf';
                intensityLabel = '-∞';
            else
                fieldName = ['Intensity_' intensityStr];
                intensityLabel = intensityStr;
            end
            if isfield(latencyByIntensity, fieldName) && ~isempty(latencyByIntensity.(fieldName))
                data = latencyByIntensity.(fieldName);
                meanLatency = mean(data);
                text(i, textY, sprintf('n=%d\nμ=%.2f', length(data), meanLatency), ...
                    'HorizontalAlignment', 'center', 'FontSize', 8, 'BackgroundColor', 'white');
            end
        end
        
    else
        fprintf('\nNo Hit trials found for latency analysis.\n');
    end
else
    fprintf('\nNo Hit trials found for latency analysis.\n');
end

% plot latency median vs intensity
if ~isempty(fieldnames(latencyByIntensity))
    % Prepare data for median plot
    medianLatencies = [];
    intensityValues = [];
    intensityLabels = {};
    
    for i = 1:length(uInt)
        intensityStr = num2str(uInt(i));
        if isinf(uInt(i)) && uInt(i) < 0
            fieldName = 'Intensity_Inf';
            intensityLabel = '-∞';
        else
            fieldName = ['Intensity_' intensityStr];
            intensityLabel = intensityStr;
        end
        
        if isfield(latencyByIntensity, fieldName) && ~isempty(latencyByIntensity.(fieldName))
            data = latencyByIntensity.(fieldName);
            medianLatencies = [medianLatencies; median(data)];
            intensityValues = [intensityValues; uInt(i)];
            intensityLabels{end+1} = intensityLabel;
        end
    end
    
    if ~isempty(medianLatencies)
        figure;
        
        % Handle -inf for plotting
        plotIntensities = intensityValues;
        if any(isinf(intensityValues) & intensityValues < 0)
            % Replace -inf with a negative value for plotting
            plotIntensities(isinf(intensityValues) & intensityValues < 0) = min(intensityValues(~isinf(intensityValues))) - 10;
        end
        
        % Create the plot
        plot(plotIntensities, medianLatencies, 'o-', 'LineWidth', 2, 'MarkerSize', 8);
        
        % Set x-axis with proper labels
        ax = gca;
        ax.XTick = plotIntensities;
        ax.XTickLabel = intensityLabels;
        
        % Add break symbol if there's -inf
        if any(isinf(intensityValues) & intensityValues < 0)
            xBreak = min(intensityValues(~isinf(intensityValues))) - 5;
            yLim = ylim;
            hold on;
            plot([xBreak, xBreak], yLim, 'k--', 'LineWidth', 1);
            text(xBreak, yLim(2), '//', 'HorizontalAlignment', 'center', 'FontSize', 12);
        end
        
        xlabel('Intensity');
        ylabel('Median Latency (s)');
        title('Median Response Latency vs Intensity');
        grid on;
        
        % Add data points as text labels
        for i = 1:length(medianLatencies)
            % Create safe field name
            if isinf(intensityValues(i)) && intensityValues(i) < 0
                fieldName = 'Intensity_Inf';
            else
                fieldName = ['Intensity_' num2str(intensityValues(i))];
            end
            text(plotIntensities(i), medianLatencies(i) + 0.02, ...
                sprintf('n=%d', length(latencyByIntensity.(fieldName))), ...
                'HorizontalAlignment', 'center', 'FontSize', 8);
        end
    end
end

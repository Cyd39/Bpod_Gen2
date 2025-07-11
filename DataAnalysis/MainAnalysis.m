%% load data
[SessionData, ~, ~] = LoadData();

% ExtractTimeStamps
Session_tbl = ExtractTimeStamps(SessionData);

% align timing to stimulus onset
n_stim = height(Session_tbl);
LickOn = cell(n_stim,1);
LickOff = cell(n_stim,1);

for ii = 1:height(Session_tbl)
    LickOn{ii} = Session_tbl.LickOn{ii} - Session_tbl.Stimulus(ii,1);
    LickOff{ii} = Session_tbl.LickOff{ii} - Session_tbl.Stimulus(ii,1);
end

disp("Data loaded")

%% add column "Hit" to Session_tbl
Session_tbl.Hit = zeros(height(Session_tbl), 1); % Initialize Hit column

for t = 1:height(Session_tbl)
    % Get trial parameters
    ResWin = SessionData.TrialSettings(t).GUI.ResWin;
    stimulusStart = Session_tbl.Stimulus(t, 1);
    windowEnd = stimulusStart + ResWin;
    
    % Get LickOn times for this trial
    LickOn_t = LickOn{t};
    
    % Check if any LickOn is within the time window and not NaN
    if ~isempty(LickOn_t) && ~all(isnan(LickOn_t))
        % Find valid licks (not NaN)
        validLicks = LickOn_t(~isnan(LickOn_t));
        
        % Check if any valid lick is within the response window
        licksInWindow = validLicks >= stimulusStart & validLicks <= windowEnd;
        
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
histogram([LickOn{:}],-5:0.05:2);
title('All Lick On Times');

xlabel('Time (s)');
ylabel('Count');

% First LickOn
LickOnFirst = cellfun(@(x) x(1), LickOn, 'UniformOutput', false);
LickOnFirst = [LickOnFirst{:}];

subplot(1, 2, 2);
histogram(LickOnFirst, -5:0.05:2);
title('First Lick On Times');
xlabel('Time (s)');
ylabel('Count');


%% raster plot
fig = figure;
ax = axes("Parent",fig);
uInt = unique(Session_tbl.AudIntensity);
nInt= length(uInt);
Colour = turbo(nInt);%[0,0,0];
[ax,YTick,YTickLab] = plotraster(ax, LickOn,Session_tbl.AudIntensity, Colour,[10],1);
ax.YTick = YTick{1};
ax.YTickLabel = YTickLab;
xlim(ax,[0,1])

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
        lickOnTimes = LickOn{t}; % Already aligned to stimulus onset
        stimulusStart = Session_tbl.Stimulus(t, 1);
        resWin = SessionData.TrialSettings(t).GUI.ResWin;
        windowEnd = stimulusStart + resWin;
        intensity = Session_tbl.AudIntensity(t);
        
        % Find the first valid lick within the response window
        if ~isempty(lickOnTimes) && ~all(isnan(lickOnTimes))
            validLicks = lickOnTimes(~isnan(lickOnTimes));
            licksInWindow = validLicks >= stimulusStart & validLicks <= windowEnd;
            
            if any(licksInWindow)
                % Get the first lick in the window
                firstLickInWindow = validLicks(licksInWindow);
                firstLickInWindow = firstLickInWindow(1); % First lick
                
                % Calculate latency (time from stimulus onset to first lick)
                latency = firstLickInWindow - stimulusStart;
                
                % Store latency by intensity
                intensityStr = num2str(intensity);
                if ~isfield(latencyByIntensity, intensityStr)
                    latencyByIntensity.(intensityStr) = [];
                end
                latencyByIntensity.(intensityStr) = [latencyByIntensity.(intensityStr); latency];
            end
        end
    end
end

% Create boxplot of latency by intensity
if ~isempty(fieldnames(latencyByIntensity))
    figure;
    
    % Prepare data for boxplot
    latencyData = [];
    intensityLabels = {};
    
    for i = 1:length(uInt)
        intensityStr = num2str(uInt(i));
        if isfield(latencyByIntensity, intensityStr) && ~isempty(latencyByIntensity.(intensityStr))
            latencyData = [latencyData; latencyByIntensity.(intensityStr)];
            if isinf(uInt(i)) && uInt(i) < 0
                intensityLabels{end+1} = '-∞';
            else
                intensityLabels{end+1} = intensityStr;
            end
        end
    end
    
    % Create boxplot
    if ~isempty(latencyData)
        boxplot(latencyData, 'Labels', intensityLabels);
        xlabel('Intensity');
        ylabel('Latency (s)');
        title('Response Latency by Intensity (Hit Trials Only)');
        grid on;
        
        % Add statistics
        fprintf('\nLatency Analysis by Intensity (Hit trials only):\n');
        fprintf('================================================\n');
        for i = 1:length(uInt)
            intensityStr = num2str(uInt(i));
            if isfield(latencyByIntensity, intensityStr) && ~isempty(latencyByIntensity.(intensityStr))
                data = latencyByIntensity.(intensityStr);
                if isinf(uInt(i)) && uInt(i) < 0
                    intensityLabel = '-∞';
                else
                    intensityLabel = intensityStr;
                end
                fprintf('Intensity %s: n=%d, mean=%.3f±%.3f s\n', ...
                    intensityLabel, length(data), mean(data), std(data));
            end
        end
    else
        fprintf('\nNo Hit trials found for latency analysis.\n');
    end
else
    fprintf('\nNo Hit trials found for latency analysis.\n');
end

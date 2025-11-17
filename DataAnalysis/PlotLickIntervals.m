function PlotLickIntervals(SessionData, varargin)
    % PlotLickIntervals - Plot lick interval histogram from SessionData
    % 
    % This function extracts all lick events (BNC1High and BNC2High) from all trials,
    % converts them to absolute time, calculates intervals between consecutive licks,
    % and displays a histogram with log-scale y-axis.
    %
    % Inputs:
    %   SessionData - Session data structure
    %   Optional name-value pairs:
    %     'FigureHandle' - figure handle for the combined plot (optional, for activation in online mode)
    %     'Axes' - axes handle for the plot (optional, if not provided, creates new figure)
    %     'FigureName' - name for new figure if axes not provided (default: 'Lick Intervals Distribution')
    %
    % Usage:
    %   Online mode: PlotLickIntervals(BpodSystem.Data, 'FigureHandle', customPlotFig, 'Axes', lickIntervalAx);
    %   Offline mode: PlotLickIntervals(SessionData);
    
    % Parse optional inputs
    p = inputParser;
    addParameter(p, 'FigureHandle', [], @(x) isempty(x) || isgraphics(x, 'figure'));
    addParameter(p, 'Axes', [], @(x) isempty(x) || isgraphics(x, 'axes'));
    addParameter(p, 'FigureName', 'Lick Intervals Distribution', @ischar);
    parse(p, varargin{:});
    
    customPlotFig = p.Results.FigureHandle;
    ax = p.Results.Axes;
    figureName = p.Results.FigureName;
    
    % Activate figure if provided (for online mode)
    if ~isempty(customPlotFig) && isvalid(customPlotFig)
        figure(customPlotFig);
    end
    
    % Create axes if not provided (offline mode)
    if isempty(ax)
        figure('Name', figureName, 'Position', [100 100 1000 600]);
        ax = axes('Position', [0.1 0.15 0.85 0.75]);
        title(ax, 'Lick Intervals Distribution');
        xlabel(ax, 'Lick Interval (seconds)');
        ylabel(ax, 'Count');
        grid(ax, 'on');
        hold(ax, 'on');
    end
    
    % Check if data exists
    if ~isfield(SessionData, 'RawEvents') || ~isfield(SessionData.RawEvents, 'Trial')
        warning('SessionData.RawEvents.Trial not found');
        cla(ax);
        text(ax, 0.5, 0.5, 'No data available', ...
            'HorizontalAlignment', 'center', 'FontSize', 14);
        if ~isempty(customPlotFig)
            drawnow;
        end
        return;
    end
    
    % Get number of trials
    if ~isfield(SessionData, 'nTrials')
        % Try to get from RawEvents if nTrials not available
        nTrials = length(SessionData.RawEvents.Trial);
    else
        nTrials = SessionData.nTrials;
    end
    
    % Check if there are any trials
    if nTrials == 0
        warning('No trials found in SessionData');
        cla(ax);
        text(ax, 0.5, 0.5, 'No trials available', ...
            'HorizontalAlignment', 'center', 'FontSize', 14);
        if ~isempty(customPlotFig)
            drawnow;
        end
        return;
    end
    
    % Extract all lick times from all trials
    allLickTimesGlobal = [];
    
    % Loop through each trial
    for trialNum = 1:nTrials
        if trialNum > length(SessionData.RawEvents.Trial)
            continue;
        end
        
        % Get trial events structure
        trialData = SessionData.RawEvents.Trial{trialNum};
        
        % Get trial start time
        if ~isfield(SessionData, 'TrialStartTimestamp') || trialNum > length(SessionData.TrialStartTimestamp)
            warning(['TrialStartTimestamp not found for trial ' num2str(trialNum)]);
            continue;
        end
        trialStartTime = SessionData.TrialStartTimestamp(trialNum);
        
        % Extract lick events from this trial
        trialLickTimes = [];
        if isfield(trialData, 'Events')
            % Extract BNC1High (left lick)
            if isfield(trialData.Events, 'BNC1High')
                trialLickTimes = [trialLickTimes, trialData.Events.BNC1High];
            end
            % Extract BNC2High (right lick)
            if isfield(trialData.Events, 'BNC2High')
                trialLickTimes = [trialLickTimes, trialData.Events.BNC2High];
            end
        end
        
        % Convert to absolute time and add to global array
        if ~isempty(trialLickTimes)
            % Convert relative time (from trial start) to absolute time (from session start)
            absoluteLickTimes = trialStartTime + trialLickTimes;
            allLickTimesGlobal = [allLickTimesGlobal, absoluteLickTimes];
        end
    end
    
    % Get QuietTime range for No-Lick display
    minQuietTime = NaN;
    maxQuietTime = NaN;
    if isfield(SessionData, 'QuietTime')
        quietTimeValues = SessionData.QuietTime(~isnan(SessionData.QuietTime));
        if ~isempty(quietTimeValues)
            minQuietTime = min(quietTimeValues);
            maxQuietTime = max(quietTimeValues);
        end
    elseif isfield(SessionData, 'TrialSettings') && ~isempty(SessionData.TrialSettings)
        % Try to get from TrialSettings if available
        if isfield(SessionData.TrialSettings(1), 'GUI')
            if isfield(SessionData.TrialSettings(1).GUI, 'MinQuietTime') && ...
               isfield(SessionData.TrialSettings(1).GUI, 'MaxQuietTime')
                minQuietTime = SessionData.TrialSettings(1).GUI.MinQuietTime;
                maxQuietTime = SessionData.TrialSettings(1).GUI.MaxQuietTime;
            end
        end
    end
    
    % Calculate intervals and plot
    if length(allLickTimesGlobal) > 1
        % Sort all lick times chronologically
        allLickTimesGlobal = sort(allLickTimesGlobal);
        
        % Calculate intervals between consecutive licks (automatically includes cross-trial intervals)
        allLickIntervals = diff(allLickTimesGlobal);
        
        % Plot histogram
        axes(ax);  % Activate the correct axes
        cla(ax);   % Clear previous plot
        histogram(ax, allLickIntervals, 'BinWidth', 0.1, 'FaceColor', [0.2 0.6 0.8], 'EdgeColor', 'black');
        set(ax, 'YScale', 'log');  % Set y-axis to log scale
        
        % Set x-axis range and ticks
        xlim(ax, [0, 5]);  
        xticks(ax, 0:0.5:5);  

        % Set x-axis label and y-axis label
        xlabel(ax, 'Lick Interval (seconds)');
        ylabel(ax, 'Count');
        
        % Create title with No-Lick range if available (offline mode feature)
        % In online mode, use simpler title
        if isempty(customPlotFig) && ~isnan(minQuietTime) && ~isnan(maxQuietTime)
            % Offline mode: show QuietTime info
            if abs(minQuietTime - maxQuietTime) < 0.001
                % If min and max are the same, show single value
                title(ax, ['Lick Intervals Distribution (n=' num2str(length(allLickIntervals)) ' intervals, No-Lick: ' sprintf('%.1f', minQuietTime) ' s)']);
            else
                title(ax, ['Lick Intervals Distribution (n=' num2str(length(allLickIntervals)) ' intervals, No-Lick: ' sprintf('%.1f-%.1f', minQuietTime, maxQuietTime) ' s)']);
            end
        else
            % Online mode or QuietTime not available: simple title
            title(ax, ['Lick Intervals Distribution (n=' num2str(length(allLickIntervals)) ' intervals)']);
        end
        grid(ax, 'on');
        
        % Display summary statistics
        disp('=== Lick Interval Statistics ===');
        disp(['Total intervals: ' num2str(length(allLickIntervals))]);
        disp(['Mean interval: ' sprintf('%.3f', mean(allLickIntervals)) ' seconds']);
        disp(['Median interval: ' sprintf('%.3f', median(allLickIntervals)) ' seconds']);
        disp(['Min interval: ' sprintf('%.3f', min(allLickIntervals)) ' seconds']);
        disp(['Max interval: ' sprintf('%.3f', max(allLickIntervals)) ' seconds']);
        disp('================================');
    else
        warning('Not enough lick events to calculate intervals. Need at least 2 licks.');
        cla(ax);
        text(ax, 0.5, 0.5, 'Not enough lick events to calculate intervals', ...
            'HorizontalAlignment', 'center', 'FontSize', 14);
    end
    
    % Force update of the figure (for online mode)
    if ~isempty(customPlotFig)
        drawnow;
    end
end


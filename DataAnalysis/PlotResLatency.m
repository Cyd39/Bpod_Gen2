function PlotResLatency(SessionData, varargin)
    % PlotResLatency - Plot response latency histogram from SessionData
    % 
    % This function extracts response latency (time from stimulus start to first lick)
    % from SessionData (all completed trials) and plots the latency distribution.
    % First lick is defined as the earlier of BNC1High (left) or BNC2High (right),
    % regardless of correctness.
    %
    % Inputs:
    %   SessionData - Session data structure
    %   Optional name-value pairs:
    %     'FigureHandle' - figure handle for the combined plot (optional, for activation in online mode)
    %     'Axes' - axes handle for the plot (optional, if not provided, creates new figure)
    %     'FigureName' - name for new figure if axes not provided (default: 'Response Latency Distribution')
    %
    % Usage:
    %   Online mode: PlotResLatency(BpodSystem.Data, 'FigureHandle', customPlotFig, 'Axes', resLatencyAx);
    %   Offline mode: PlotResLatency(SessionData);
    
    % Parse optional inputs
    p = inputParser;
    addParameter(p, 'FigureHandle', [], @(x) isempty(x) || isgraphics(x, 'figure'));
    addParameter(p, 'Axes', [], @(x) isempty(x) || isgraphics(x, 'axes'));
    addParameter(p, 'FigureName', 'Response Latency Distribution', @ischar);
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
        title(ax, 'Response Latency Distribution');
        xlabel(ax, 'Response Latency (seconds)');
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
    
    % Extract all response latencies from all trials
    allResponseLatencies = [];
    
    % Loop through each trial
    for trialNum = 1:nTrials
        if trialNum > length(SessionData.RawEvents.Trial)
            continue;
        end
        
        % Get trial events structure
        trialData = SessionData.RawEvents.Trial{trialNum};
        
        % Find stimulus start time (Stimulus state start)
        stimulusStartTime = NaN;
        if isfield(trialData, 'States') && isfield(trialData.States, 'Stimulus')
            if ~isempty(trialData.States.Stimulus) && ~isnan(trialData.States.Stimulus(1))
                stimulusStartTime = trialData.States.Stimulus(1, 1);
            end
        end
        
        % Skip if no stimulus state found
        if isnan(stimulusStartTime)
            continue;
        end
        
        % Find first lick time AFTER stimulus start (BNC1High or BNC2High, whichever comes first)
        % This is the first lick after stimulus onset, regardless of correctness
        % IMPORTANT: Only consider licks that occur after stimulus start to avoid excluding trials
        % with pre-stimulus licks
        firstLickTime = NaN;
        if isfield(trialData, 'Events')
            % Check BNC1High (left lick) - only consider licks after stimulus start
            if isfield(trialData.Events, 'BNC1High') && ~isempty(trialData.Events.BNC1High)
                bnc1TimesAfterStim = trialData.Events.BNC1High(trialData.Events.BNC1High >= stimulusStartTime);
                if ~isempty(bnc1TimesAfterStim)
                    firstLickTime = bnc1TimesAfterStim(1);
                end
            end
            % Check BNC2High (right lick) - only consider licks after stimulus start
            if isfield(trialData.Events, 'BNC2High') && ~isempty(trialData.Events.BNC2High)
                bnc2TimesAfterStim = trialData.Events.BNC2High(trialData.Events.BNC2High >= stimulusStartTime);
                if ~isempty(bnc2TimesAfterStim)
                    bnc2Time = bnc2TimesAfterStim(1);
                    if isnan(firstLickTime) || bnc2Time < firstLickTime
                        firstLickTime = bnc2Time;
                    end
                end
            end
        end
        
        % Calculate response latency (firstLickTime is guaranteed to be >= stimulusStartTime)
        if ~isnan(firstLickTime)
            responseLatency = firstLickTime - stimulusStartTime;
            allResponseLatencies = [allResponseLatencies, responseLatency];
        end
    end
    
    % Plot histogram
    if ~isempty(allResponseLatencies)
        axes(ax);  % Activate the correct axes
        cla(ax);   % Clear previous plot
        histogram(ax, allResponseLatencies, 'BinWidth', 0.05, 'FaceColor', [0.8 0.4 0.2], 'EdgeColor', 'black');
        
        % Set x-axis range and ticks
        xlim(ax, [0, 5]);  
        xticks(ax, 0:0.5:5);  

        % Set x-axis label and y-axis label
        xlabel(ax, 'Response Latency (seconds)');
        ylabel(ax, 'Count');
        title(ax, ['Response Latency Distribution (n=' num2str(length(allResponseLatencies)) ' first licks / ' num2str(nTrials) ' trials)']);
        grid(ax, 'on');
        
        % Display summary statistics (only in offline mode)
        if isempty(customPlotFig)
            disp('=== Response Latency Statistics ===');
            disp(['Total first licks: ' num2str(length(allResponseLatencies)) ' in ' num2str(nTrials) ' trials']);
            disp(['Mean latency: ' sprintf('%.3f', mean(allResponseLatencies)) ' seconds']);
            disp(['Median latency: ' sprintf('%.3f', median(allResponseLatencies)) ' seconds']);
            disp(['Min latency: ' sprintf('%.3f', min(allResponseLatencies)) ' seconds']);
            disp(['Max latency: ' sprintf('%.3f', max(allResponseLatencies)) ' seconds']);
            disp('===================================');
        end
    else
        warning('No response latencies found. Need at least one lick after stimulus start.');
        cla(ax);
        text(ax, 0.5, 0.5, 'No response latencies available', ...
            'HorizontalAlignment', 'center', 'FontSize', 14);
    end
    
    % Force update of the figure (for online mode)
    if ~isempty(customPlotFig)
        drawnow;
    end
end


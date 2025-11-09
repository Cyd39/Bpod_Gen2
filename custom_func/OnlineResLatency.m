function OnlineResLatency(customPlotFig, ResLatencyAx, SessionData)
    % OnlineResLatency - Plot response latency histogram from SessionData
    % This function extracts response latency (time from stimulus start to first lick)
    % from SessionData (all completed trials) and plots the latency distribution.
    % First lick is defined as the earlier of BNC1High (left) or BNC2High (right),
    % regardless of correctness.
    % Inputs:
    %   customPlotFig - figure handle for the combined plot (optional, for activation)
    %   ResLatencyAx - axes handle for the histogram plot
    %   SessionData - session data structure (e.g., BpodSystem.Data)
    
    % Activate figure if provided
    if nargin >= 1 && ~isempty(customPlotFig) && isvalid(customPlotFig)
        figure(customPlotFig);
    end
    
    % Check if data exists
    if ~isfield(SessionData, 'RawEvents') || ~isfield(SessionData.RawEvents, 'Trial')
        warning('SessionData.RawEvents.Trial not found');
        cla(ResLatencyAx);
        text(ResLatencyAx, 0.5, 0.5, 'No data available', ...
            'HorizontalAlignment', 'center', 'FontSize', 14);
        drawnow;
        return;
    end
    
    % Get number of trials
    nTrials = SessionData.nTrials;
    
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
        
        % Find first lick time (BNC1High or BNC2High, whichever comes first)
        % This is the first lick regardless of correctness
        firstLickTime = NaN;
        if isfield(trialData, 'Events')
            % Check BNC1High (left lick)
            if isfield(trialData.Events, 'BNC1High') && ~isempty(trialData.Events.BNC1High)
                firstLickTime = trialData.Events.BNC1High(1);
            end
            % Check BNC2High (right lick) - use the earlier one if both exist
            if isfield(trialData.Events, 'BNC2High') && ~isempty(trialData.Events.BNC2High)
                bnc2Time = trialData.Events.BNC2High(1);
                if isnan(firstLickTime) || bnc2Time < firstLickTime
                    firstLickTime = bnc2Time;
                end
            end
        end
        
        % Calculate response latency (only if first lick occurred after stimulus start)
        if ~isnan(firstLickTime) && firstLickTime >= stimulusStartTime
            responseLatency = firstLickTime - stimulusStartTime;
            allResponseLatencies = [allResponseLatencies, responseLatency];
        end
    end
    
    % Plot histogram
    if ~isempty(allResponseLatencies)
        axes(ResLatencyAx);  % Activate the correct subplot
        cla(ResLatencyAx);
        histogram(ResLatencyAx, allResponseLatencies, 'BinWidth', 0.05, 'FaceColor', [0.8 0.4 0.2], 'EdgeColor', 'black');
        
        % Set x-axis range and ticks
        xlim(ResLatencyAx, [0, 5]);  
        xticks(ResLatencyAx, 0:0.5:5);  

        % Set x-axis label and y-axis label
        xlabel(ResLatencyAx, 'Response Latency (seconds)');
        ylabel(ResLatencyAx, 'Count');
        title(ResLatencyAx, ['Response Latency Distribution (n=' num2str(length(allResponseLatencies)) ' first licks / ' num2str(nTrials) ' trials)']);
        grid(ResLatencyAx, 'on');
        
        % Display summary statistics
        disp('=== Response Latency Statistics ===');
        disp(['Total first licks: ' num2str(length(allResponseLatencies)) ' in ' num2str(nTrials) ' trials']);
        disp(['Mean latency: ' sprintf('%.3f', mean(allResponseLatencies)) ' seconds']);
        disp(['Median latency: ' sprintf('%.3f', median(allResponseLatencies)) ' seconds']);
        disp(['Min latency: ' sprintf('%.3f', min(allResponseLatencies)) ' seconds']);
        disp(['Max latency: ' sprintf('%.3f', max(allResponseLatencies)) ' seconds']);
        disp('===================================');
    else
        warning('No response latencies found. Need at least one lick after stimulus start.');
        cla(ResLatencyAx);
        text(ResLatencyAx, 0.5, 0.5, 'No response latencies available', ...
            'HorizontalAlignment', 'center', 'FontSize', 14);
    end
    
    % Force update of the figure
    drawnow;
end
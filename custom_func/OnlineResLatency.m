function OnlineResLatency(customPlotFig, ResLatencyAx, SessionData)
    % OnlineResLatency - Plot response latency histogram from SessionData
    % This function extracts response latency from SessionData (all completed trials)
    % and plots the latency distribution
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
        
        % Find reward state start time (correct response time)
        % Use LeftReward or RightReward state start time, whichever comes first
        rewardStateTime = NaN;
        if isfield(trialData, 'States')
            % Check LeftReward state
            if isfield(trialData.States, 'LeftReward') && ~isempty(trialData.States.LeftReward)
                if ~isnan(trialData.States.LeftReward(1))
                    rewardStateTime = trialData.States.LeftReward(1, 1);
                end
            end
            % Check RightReward state - use the earlier one if both exist
            if isfield(trialData.States, 'RightReward') && ~isempty(trialData.States.RightReward)
                if ~isnan(trialData.States.RightReward(1))
                    rightRewardTime = trialData.States.RightReward(1, 1);
                    if isnan(rewardStateTime) || rightRewardTime < rewardStateTime
                        rewardStateTime = rightRewardTime;
                    end
                end
            end
        end
        
        % Calculate response latency (only if reward state occurred after stimulus start)
        if ~isnan(rewardStateTime) && rewardStateTime >= stimulusStartTime
            responseLatency = rewardStateTime - stimulusStartTime;
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
        title(ResLatencyAx, ['Response Latency Distribution (n=' num2str(length(allResponseLatencies)) ' responses)']);
        grid(ResLatencyAx, 'on');
        
        % Display summary statistics
        disp('=== Response Latency Statistics ===');
        disp(['Total responses: ' num2str(length(allResponseLatencies))]);
        disp(['Mean latency: ' sprintf('%.3f', mean(allResponseLatencies)) ' seconds']);
        disp(['Median latency: ' sprintf('%.3f', median(allResponseLatencies)) ' seconds']);
        disp(['Min latency: ' sprintf('%.3f', min(allResponseLatencies)) ' seconds']);
        disp(['Max latency: ' sprintf('%.3f', max(allResponseLatencies)) ' seconds']);
        disp('===================================');
    else
        warning('No response latencies found. Need at least one response after stimulus start.');
        cla(ResLatencyAx);
        text(ResLatencyAx, 0.5, 0.5, 'No response latencies available', ...
            'HorizontalAlignment', 'center', 'FontSize', 14);
    end
    
    % Force update of the figure
    drawnow;
end
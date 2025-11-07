function PlotResLatencyFromSessionData(SessionData)
    % PlotResLatencyFromSessionData - Plot response latency histogram from saved SessionData
    % 
    % Input:
    %   SessionData - Session data structure loaded from saved .mat file
    %
    % This function extracts response latency (time from stimulus start to reward state)
    % from all trials and displays a histogram.
    %
    % Usage:
    %   load('SessionData.mat', 'SessionData');
    %   PlotResLatencyFromSessionData(SessionData);
    
    % Initialize figure
    figure('Name', 'Response Latency Distribution', 'Position', [100 100 1000 600]);
    ax = axes('Position', [0.1 0.15 0.85 0.75]);
    title(ax, 'Response Latency Distribution');
    xlabel(ax, 'Response Latency (seconds)');
    ylabel(ax, 'Count');
    grid(ax, 'on');
    hold(ax, 'on');
    
    % Get number of trials
    if ~isfield(SessionData, 'nTrials')
        error('SessionData does not contain nTrials field');
    end
    nTrials = SessionData.nTrials;
    
    % Extract all response latencies from all trials
    allResponseLatencies = [];
    
    % Loop through each trial
    for trialNum = 1:nTrials
        % Check if trial data exists
        if ~isfield(SessionData, 'RawEvents') || ~isfield(SessionData.RawEvents, 'Trial')
            warning('SessionData.RawEvents.Trial not found');
            continue;
        end
        
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
    
    % Get ResWin value(s) for display
    ResWin = NaN;
    if isfield(SessionData, 'ResWin')
        % Get ResWin from SessionData.ResWin array (use mean if multiple values)
        ResWinValues = SessionData.ResWin(~isnan(SessionData.ResWin));
        if ~isempty(ResWinValues)
            ResWin = mean(ResWinValues); % Use mean if ResWin varies across trials
        end
    elseif isfield(SessionData, 'TrialSettings') && ~isempty(SessionData.TrialSettings)
        % Try to get ResWin from TrialSettings
        if isfield(SessionData.TrialSettings(1), 'GUI') && isfield(SessionData.TrialSettings(1).GUI, 'ResWin')
            ResWin = SessionData.TrialSettings(1).GUI.ResWin;
        end
    end
    
    % Plot histogram
    if ~isempty(allResponseLatencies)
        % Plot histogram
        cla(ax);
        hold(ax, 'on');
        
        % Plot histogram
        histogram(ax, allResponseLatencies, 'BinWidth', 0.05, 'FaceColor', [0.8 0.4 0.2], 'EdgeColor', 'black', 'DisplayName', 'Response Latency');
        
        % Plot ResWin line if available
        if ~isnan(ResWin)
            xline(ax, ResWin, 'r--', 'LineWidth', 2, 'DisplayName', ['ResWindow = ' sprintf('%.2f', ResWin) ' s']);
        end
        
        % Set x-axis range and ticks based on ResWin
        if ~isnan(ResWin)
            xMax = ResWin + 0.5;
            xlim(ax, [0, xMax]);
            % Set ticks with appropriate spacing
            if xMax <= 2
                xticks(ax, 0:0.2:xMax);
            elseif xMax <= 5
                xticks(ax, 0:0.5:xMax);
            else
                xticks(ax, 0:1:xMax);
            end
        else
            % Default range if ResWin not available
            xlim(ax, [0, 5]);
            xticks(ax, 0:0.5:5);
        end  

        % Set x-axis label and y-axis label
        xlabel(ax, 'Response Latency (seconds)');
        ylabel(ax, 'Count');
        
        title(ax, ['Response Latency Distribution (n=' num2str(length(allResponseLatencies)) ' rewarded responses / ' num2str(nTrials) ' trials)']);
        grid(ax, 'on');
        
        % Add legend if ResWin is available
        if ~isnan(ResWin)
            legend(ax, 'show', 'Location', 'best');
        end
        
        % Display summary statistics
        disp('=== Response Latency Statistics ===');
        disp(['Total rewarded responses: ' num2str(length(allResponseLatencies)) ' in ' num2str(nTrials) ' trials']);
        disp(['Mean latency: ' sprintf('%.3f', mean(allResponseLatencies)) ' seconds']);
        disp(['Median latency: ' sprintf('%.3f', median(allResponseLatencies)) ' seconds']);
        disp(['Min latency: ' sprintf('%.3f', min(allResponseLatencies)) ' seconds']);
        disp(['Max latency: ' sprintf('%.3f', max(allResponseLatencies)) ' seconds']);
        disp('===================================');
    else
        warning('No response latencies found. Need at least one response after stimulus start.');
        cla(ax);
        text(ax, 0.5, 0.5, 'No response latencies available', ...
            'HorizontalAlignment', 'center', 'FontSize', 14);
    end
end

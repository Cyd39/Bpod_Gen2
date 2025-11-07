function OnlineLickInterval(customPlotFig, lickIntervalAx, SessionData)
    % OnlineLickInterval - Plot lick interval histogram from SessionData
    % This function extracts lick events from SessionData (all completed trials)
    % and plots the interval distribution, using the same logic as PlotLickIntervalsFromSessionData
    % Inputs:
    %   customPlotFig - figure handle for the combined plot (optional, for activation)
    %   lickIntervalAx - axes handle for the histogram plot
    %   SessionData - session data structure (e.g., BpodSystem.Data)
    
    % Activate figure if provided
    if nargin >= 1 && ~isempty(customPlotFig) && isvalid(customPlotFig)
        figure(customPlotFig);
    end
    
    % Check if data exists
    if ~isfield(SessionData, 'RawEvents') || ~isfield(SessionData.RawEvents, 'Trial')
        warning('SessionData.RawEvents.Trial not found');
        cla(lickIntervalAx);
        text(lickIntervalAx, 0.5, 0.5, 'No data available', ...
            'HorizontalAlignment', 'center', 'FontSize', 14);
        drawnow;
        return;
    end
    
    % Get number of trials
    nTrials = SessionData.nTrials;
    
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
        if trialNum > length(SessionData.TrialStartTimestamp)
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
    
    % Calculate intervals and plot
    if length(allLickTimesGlobal) > 1
        % Sort all lick times chronologically
        allLickTimesGlobal = sort(allLickTimesGlobal);
        
        % Calculate intervals between consecutive licks (automatically includes cross-trial intervals)
        allLickIntervals = diff(allLickTimesGlobal);
        
        % Plot histogram
        axes(lickIntervalAx);  % Activate the correct subplot
        cla(lickIntervalAx);
        histogram(lickIntervalAx, allLickIntervals, 'BinWidth', 0.1, 'FaceColor', [0.2 0.6 0.8], 'EdgeColor', 'black');
        set(lickIntervalAx, 'YScale', 'log');  % Set y-axis to log scale
        
        % Set x-axis range and ticks
        xlim(lickIntervalAx, [0, 5]);  
        xticks(lickIntervalAx, 0:0.5:5);  

        % Set x-axis label and y-axis label
        xlabel(lickIntervalAx, 'Lick Interval (seconds)');
        ylabel(lickIntervalAx, 'Count');
        title(lickIntervalAx, ['Lick Intervals Distribution (n=' num2str(length(allLickIntervals)) ' intervals)']);
        grid(lickIntervalAx, 'on');
        
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
        cla(lickIntervalAx);
        text(lickIntervalAx, 0.5, 0.5, 'Not enough lick events to calculate intervals', ...
            'HorizontalAlignment', 'center', 'FontSize', 14);
    end
    
    % Force update of the figure
    drawnow;
end
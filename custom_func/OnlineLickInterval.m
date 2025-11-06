function OnlineLickInterval(lickIntervalFig, lickIntervalAx, RawEvents)
    % Update histogram with lick intervals
    % This function handles all data extraction, processing, and plotting
    % Inputs:
    %   lickIntervalFig - figure handle for the histogram plot
    %   lickIntervalAx - axes handle for the histogram plot
    %   RawEvents - raw trial events structure from Bpod
    
    % Persistent variable to store all lick times across all trials
    persistent allLickTimesGlobal
    
    % Initialize persistent variable if empty
    if isempty(allLickTimesGlobal)
        allLickTimesGlobal = [];
    end
    
    % Extract all lick events from current trial (BNC1High = left, BNC2High = right)
    % Event timestamps are relative to trial start, convert to absolute (global) time
    trialLickTimes = [];
    if isfield(RawEvents, 'Events')
        if isfield(RawEvents.Events, 'BNC1High')
            trialLickTimes = [trialLickTimes, RawEvents.Events.BNC1High];
        end
        if isfield(RawEvents.Events, 'BNC2High')
            trialLickTimes = [trialLickTimes, RawEvents.Events.BNC2High];
        end
    end
    
    % Convert trial-relative lick times to absolute (global) time
    if ~isempty(trialLickTimes) && isfield(RawEvents, 'TrialStartTimestamp')
        trialStartTime = RawEvents.TrialStartTimestamp;
        % Convert to absolute time: absolute_time = trial_start_time + relative_time
        absoluteLickTimes = trialStartTime + trialLickTimes;
        % Add to global array
        allLickTimesGlobal = [allLickTimesGlobal, absoluteLickTimes];
        
        % Sort all lick times chronologically (now they're all on the same time axis)
        if length(allLickTimesGlobal) > 1
            allLickTimesGlobal = sort(allLickTimesGlobal);
            % Calculate all lick intervals (automatically includes cross-trial intervals)
            allLickIntervals = diff(allLickTimesGlobal);
        elseif length(allLickTimesGlobal) == 1
            % Only one lick so far, no intervals to calculate
            allLickIntervals = [];
        end
    else
        % No new licks in this trial, use existing intervals
        if length(allLickTimesGlobal) > 1
            allLickIntervals = diff(sort(allLickTimesGlobal));
        else
            allLickIntervals = [];
        end
    end
    
    % Update histogram if we have intervals
    if ~isempty(allLickIntervals)
        % Activate figure to ensure it's visible and updated
        figure(lickIntervalFig);
        
        cla(lickIntervalAx);
        histogram(lickIntervalAx, allLickIntervals, 'BinWidth', 0.1, 'FaceColor', [0.2 0.6 0.8], 'EdgeColor', 'black');
        set(lickIntervalAx, 'YScale', 'log');  % Set y-axis to log scale
        
        % Set x-axis range and ticks
        xlim(lickIntervalAx, [0, 2]);
        xticks(lickIntervalAx, 0:0.2:2);
        
        xlabel(lickIntervalAx, 'Lick Interval (seconds)');
        ylabel(lickIntervalAx, 'Count');
        title(lickIntervalAx, ['Lick Intervals Distribution (n=' num2str(length(allLickIntervals)) ' intervals)']);
        grid(lickIntervalAx, 'on');
        drawnow; % Force update of the figure
    end
end
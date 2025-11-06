function OnlineLickInterval(lickIntervalFig, lickIntervalAx, ~)
    % Update histogram with lick intervals from all completed trials
    % This function extracts lick events from BpodSystem.Data (all completed trials)
    % and plots the interval distribution, similar to PlotLickIntervalsFromSessionData
    % Inputs:
    %   lickIntervalFig - figure handle for the histogram plot
    %   lickIntervalAx - axes handle for the histogram plot
    %   ~ - raw trial events structure from Bpod (not used, kept for compatibility with calling code)
    
    global BpodSystem
    
    % Extract all lick times from all completed trials in BpodSystem.Data
    allLickTimesGlobal = [];
    
    % Check if BpodSystem.Data exists and has trial data
    if ~isfield(BpodSystem, 'Data') || ~isfield(BpodSystem.Data, 'RawEvents') || ...
       ~isfield(BpodSystem.Data.RawEvents, 'Trial')
        % No data available yet
        allLickIntervals = [];
        nTrials = 0;
    else
        % Get number of completed trials
        nTrials = length(BpodSystem.Data.RawEvents.Trial);
        
        % Loop through each completed trial
        for trialNum = 1:nTrials
            % Get trial events structure
            trialData = BpodSystem.Data.RawEvents.Trial{trialNum};
            
            % Get trial start time
            if isfield(BpodSystem.Data, 'TrialStartTimestamp') && ...
               trialNum <= length(BpodSystem.Data.TrialStartTimestamp)
                trialStartTime = BpodSystem.Data.TrialStartTimestamp(trialNum);
            else
                % Skip this trial if no timestamp available
                continue;
            end
            
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
        
        % Calculate intervals from all lick times
        if length(allLickTimesGlobal) > 1
            % Sort all lick times chronologically
            allLickTimesGlobal = sort(allLickTimesGlobal);
            % Calculate intervals between consecutive licks (automatically includes cross-trial intervals)
            allLickIntervals = diff(allLickTimesGlobal);
        elseif length(allLickTimesGlobal) == 1
            % Only one lick so far, no intervals to calculate
            allLickIntervals = [];
        else
            % No licks yet
            allLickIntervals = [];
        end
    end
    
    % Always update the figure, even if we don't have intervals yet
    % Activate figure to ensure it's visible and updated
    figure(lickIntervalFig);
    
    % Clear axes
    cla(lickIntervalAx);
    
    % Update histogram if we have intervals
    if ~isempty(allLickIntervals)
        histogram(lickIntervalAx, allLickIntervals, 'BinWidth', 0.1, 'FaceColor', [0.2 0.6 0.8], 'EdgeColor', 'black');
        set(lickIntervalAx, 'YScale', 'log');  % Set y-axis to log scale
        
        % Set x-axis range and ticks
        xlim(lickIntervalAx, [0, 2]);
        xticks(lickIntervalAx, 0:0.2:2);
        
        xlabel(lickIntervalAx, 'Lick Interval (seconds)');
        ylabel(lickIntervalAx, 'Count');
        title(lickIntervalAx, ['Lick Intervals Distribution (n=' num2str(length(allLickIntervals)) ' intervals, ' num2str(nTrials) ' trials)']);
        grid(lickIntervalAx, 'on');
    else
        % No intervals yet - show empty plot with message
        xlim(lickIntervalAx, [0, 2]);
        xticks(lickIntervalAx, 0:0.2:2);
        ylim(lickIntervalAx, [0.1, 10]);
        set(lickIntervalAx, 'YScale', 'log');
        xlabel(lickIntervalAx, 'Lick Interval (seconds)');
        ylabel(lickIntervalAx, 'Count');
        if length(allLickTimesGlobal) == 1
            title(lickIntervalAx, ['Lick Intervals Distribution (waiting for more licks... ' num2str(nTrials) ' trials)']);
        elseif nTrials > 0
            title(lickIntervalAx, ['Lick Intervals Distribution (no licks yet, ' num2str(nTrials) ' trials)']);
        else
            title(lickIntervalAx, 'Lick Intervals Distribution (no data yet)');
        end
        grid(lickIntervalAx, 'on');
    end
    
    % Force update of the figure
    drawnow;
end
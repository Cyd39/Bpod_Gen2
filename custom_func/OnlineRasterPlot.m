function OnlineRasterPlot(customPlotFig, rasterAx, SessionData)
    % OnlineRasterPlot - Plot raster plot of lick events aligned to stimulus onset
    % This function extracts lick events from SessionData (all completed trials)
    % and plots them in a raster format, similar to plotraster_behavior_v2
    % Inputs:
    %   customPlotFig - figure handle for the combined plot (optional, for activation)
    %   rasterAx - axes handle for the raster plot
    %   SessionData - session data structure (e.g., BpodSystem.Data)
    
    % Activate figure if provided
    if nargin >= 1 && ~isempty(customPlotFig) && isvalid(customPlotFig)
        figure(customPlotFig);
    end
    
    % Check if data exists
    if ~isfield(SessionData, 'RawEvents') || ~isfield(SessionData.RawEvents, 'Trial')
        warning('SessionData.RawEvents.Trial not found');
        cla(rasterAx);
        text(rasterAx, 0.5, 0.5, 'No data available', ...
            'HorizontalAlignment', 'center', 'FontSize', 14, 'Units', 'normalized');
        drawnow;
        return;
    end
    
    % Extract timestamps using ExtractTimeStamps
    try
        Session_tbl = ExtractTimeStamps(SessionData);
    catch ME
        warning(['Failed to extract timestamps: ' ME.message]);
        cla(rasterAx);
        text(rasterAx, 0.5, 0.5, 'Failed to extract data', ...
            'HorizontalAlignment', 'center', 'FontSize', 14, 'Units', 'normalized');
        drawnow;
        return;
    end
    
    % Check if Session_tbl is empty
    if isempty(Session_tbl) || height(Session_tbl) == 0
        cla(rasterAx);
        text(rasterAx, 0.5, 0.5, 'No trials completed', ...
            'HorizontalAlignment', 'center', 'FontSize', 14, 'Units', 'normalized');
        drawnow;
        return;
    end
    
    % Clear axes and prepare for plotting
    cla(rasterAx);
    hold(rasterAx, 'on');
    
    n_trial = height(Session_tbl);
    t_min = 0;
    t_max = 0;
    
    % Get ResWin value for x-axis limit
    ResWin = NaN;
    if isfield(SessionData, 'ResWin')
        ResWinData = SessionData.ResWin;
        if isstruct(ResWinData)
            ResWinValues = [];
            for i = 1:length(ResWinData)
                structFields = fieldnames(ResWinData(i));
                if ~isempty(structFields)
                    for j = 1:length(structFields)
                        fieldValue = ResWinData(i).(structFields{j});
                        if isnumeric(fieldValue) && isscalar(fieldValue) && ~isnan(fieldValue)
                            ResWinValues = [ResWinValues, fieldValue];
                            break;
                        elseif isstruct(fieldValue)
                            nestedFields = fieldnames(fieldValue);
                            if ~isempty(nestedFields)
                                nestedValue = fieldValue.(nestedFields{1});
                                if isnumeric(nestedValue) && isscalar(nestedValue) && ~isnan(nestedValue)
                                    ResWinValues = [ResWinValues, nestedValue];
                                    break;
                                end
                            end
                        end
                    end
                end
            end
            if ~isempty(ResWinValues)
                ResWin = ResWinValues(end);
            end
        elseif isnumeric(ResWinData)
            ResWinValues = ResWinData(~isnan(ResWinData));
            if ~isempty(ResWinValues)
                ResWin = ResWinValues(end);
            end
        end
    elseif isfield(SessionData, 'TrialSettings') && ~isempty(SessionData.TrialSettings)
        lastTrial = length(SessionData.TrialSettings);
        if isfield(SessionData.TrialSettings(lastTrial), 'GUI') && ...
           isfield(SessionData.TrialSettings(lastTrial).GUI, 'ResWin')
            ResWin = SessionData.TrialSettings(lastTrial).GUI.ResWin;
        end
    end
    
    % Plot each trial
    for idx = 1:n_trial
        pos = idx;
        
        % Handle both cell array and numeric array cases
        if iscell(Session_tbl.LeftLickOn)
            tempLeftLicks = Session_tbl.LeftLickOn{idx};
        else
            tempLeftLicks = Session_tbl.LeftLickOn(idx);
        end
        if iscell(Session_tbl.RightLickOn)
            tempRightLicks = Session_tbl.RightLickOn{idx};
        else
            tempRightLicks = Session_tbl.RightLickOn(idx);
        end
        
        % Convert scalar NaN to empty array for consistency
        if isscalar(tempLeftLicks) && isnan(tempLeftLicks)
            tempLeftLicks = [];
        end
        if isscalar(tempRightLicks) && isnan(tempRightLicks)
            tempRightLicks = [];
        end
        
        try
            tempLeftReward = Session_tbl.LeftReward(idx,1);
        catch
            tempLeftReward = NaN;
        end
        
        try
            tempRightReward = Session_tbl.RightReward(idx,1);
        catch
            tempRightReward = NaN;
        end
        
        % Check if reward was triggered by Port1 click (Condition6)
        % Extract Port1In events from RawEvents
        % Note: Port1 can be clicked before Stimulus state, Condition6 will be checked in Stimulus state
        isLeftRewardFromPort1 = false;
        isRightRewardFromPort1 = false;
        
        try
            if isfield(SessionData, 'RawEvents') && isfield(SessionData.RawEvents, 'Trial') && ...
               idx <= length(SessionData.RawEvents.Trial) && ...
               isfield(SessionData.RawEvents.Trial{idx}, 'Events')
                
                % Get Port1In events
                if isfield(SessionData.RawEvents.Trial{idx}.Events, 'Port1In')
                    port1InTimes = SessionData.RawEvents.Trial{idx}.Events.Port1In;
                    if ~isempty(port1InTimes)
                        % Get trial start time to ensure Port1In is within this trial
                        trialStartTime = 0; % Trial start is at time 0
                        
                        % Get Stimulus state timing to check if Port1In is before or during Stimulus
                        stimulusStart = NaN;
                        if isfield(SessionData.RawEvents.Trial{idx}, 'States') && ...
                           isfield(SessionData.RawEvents.Trial{idx}.States, 'Stimulus')
                            stimulusStart = SessionData.RawEvents.Trial{idx}.States.Stimulus(1);
                        end
                        
                        % Check if Port1In occurred in this trial (before or during Stimulus state)
                        % Port1 can be clicked before Stimulus, and Condition6 will trigger reward when Stimulus state is entered
                        if ~isnan(stimulusStart)
                            % Port1In should be before or at the start of Stimulus state
                            port1InBeforeOrDuringStimulus = port1InTimes <= stimulusStart;
                        else
                            % If Stimulus state doesn't exist, check if Port1In is within reasonable time window
                            % Use a larger window (e.g., 10 seconds) to catch Port1 clicks before stimulus
                            port1InBeforeOrDuringStimulus = port1InTimes >= trialStartTime & port1InTimes <= 10;
                        end
                        
                        if any(port1InBeforeOrDuringStimulus)
                            % Port1 was clicked before or at the start of Stimulus state
                            % Check if reward occurred, and if Port1In timing is consistent with Condition6 trigger
                            % Condition6 triggers reward when Stimulus state is entered, so reward should occur shortly after Stimulus starts
                            
                            if ~isnan(tempLeftReward)
                                % Get absolute reward time (before alignment)
                                try
                                    leftRewardAbsTime = Session_tbl.LeftReward(idx,1);
                                    % Find Port1In that could have triggered the reward
                                    % Port1In should be before Stimulus start, and reward should occur after Stimulus start
                                    % Check if there's a Port1In before Stimulus start, and reward occurs within reasonable time
                                    if ~isnan(stimulusStart)
                                        % Port1In before Stimulus, and reward after Stimulus start
                                        timeFromPort1ToReward = leftRewardAbsTime - port1InTimes;
                                        % Reward should occur after Stimulus starts, so timeFromPort1ToReward should be positive
                                        % and within a reasonable window (e.g., 0 to 2 seconds)
                                        if any(timeFromPort1ToReward > 0 & timeFromPort1ToReward < 2 & port1InBeforeOrDuringStimulus)
                                            isLeftRewardFromPort1 = true;
                                        end
                                    else
                                        % Fallback: if Stimulus timing is not available, check if Port1In is close to reward
                                        timeDiff = abs(port1InTimes - leftRewardAbsTime);
                                        if any(timeDiff < 2 & port1InBeforeOrDuringStimulus)
                                            isLeftRewardFromPort1 = true;
                                        end
                                    end
                                catch
                                end
                            end
                            
                            if ~isnan(tempRightReward)
                                % Get absolute reward time (before alignment)
                                try
                                    rightRewardAbsTime = Session_tbl.RightReward(idx,1);
                                    % Find Port1In that could have triggered the reward
                                    if ~isnan(stimulusStart)
                                        % Port1In before Stimulus, and reward after Stimulus start
                                        timeFromPort1ToReward = rightRewardAbsTime - port1InTimes;
                                        % Reward should occur after Stimulus starts, so timeFromPort1ToReward should be positive
                                        % and within a reasonable window (e.g., 0 to 2 seconds)
                                        if any(timeFromPort1ToReward > 0 & timeFromPort1ToReward < 2 & port1InBeforeOrDuringStimulus)
                                            isRightRewardFromPort1 = true;
                                        end
                                    else
                                        % Fallback: if Stimulus timing is not available, check if Port1In is close to reward
                                        timeDiff = abs(port1InTimes - rightRewardAbsTime);
                                        if any(timeDiff < 2 & port1InBeforeOrDuringStimulus)
                                            isRightRewardFromPort1 = true;
                                        end
                                    end
                                catch
                                end
                            end
                        end
                    end
                end
            end
        catch
            % If extraction fails, assume reward is from animal lick
        end
        
        trial_start = 0;
        try
            trial_end = Session_tbl.WaitToFinish(idx,2);
        catch
            trial_end = NaN;
        end
        
        % Align to stimulus onset
        try
            if iscell(Session_tbl.Stimulus)
                StimOnset = Session_tbl.Stimulus{idx}(1);
            else
                StimOnset = Session_tbl.Stimulus(idx,1);
            end
        catch
            StimOnset = NaN;
        end
        
        % Skip this trial if StimOnset is invalid
        if isnan(StimOnset)
            continue;
        end
        tempLeftLicks = tempLeftLicks - StimOnset;
        tempRightLicks = tempRightLicks - StimOnset;
        if ~isnan(tempLeftReward)
            tempLeftReward = tempLeftReward - StimOnset;
        end
        if ~isnan(tempRightReward)
            tempRightReward = tempRightReward - StimOnset;
        end
        trial_start = trial_start - StimOnset;
        t_min = min(t_min, trial_start);
        if ~isnan(trial_end)
            trial_end = trial_end - StimOnset;
            t_max = max(t_max, trial_end);
            % Plot trial duration line only if trial_end is valid
            plot(rasterAx, [trial_start, trial_end], [pos, pos], '-', 'Color', [.7, .7, .7]);
        else
            % If trial_end is invalid, use a default duration or skip
            % Use a default duration of 5 seconds if trial_end is NaN
            default_trial_end = trial_start + 5;
            t_max = max(t_max, default_trial_end);
            plot(rasterAx, [trial_start, default_trial_end], [pos, pos], '-', 'Color', [.7, .7, .7]);
        end
        
        % Plot left licks
        if ~isempty(tempLeftLicks)
            plot(rasterAx, tempLeftLicks, pos.*ones(size(tempLeftLicks)), '.', 'Color', [0.2 0.2 1]);
        end
        
        % Plot right licks
        if ~isempty(tempRightLicks)
            plot(rasterAx, tempRightLicks, pos.*ones(size(tempRightLicks)), '.', 'Color', [1 0.2 0.2]);
        end
        
        % Plot reward markers - distinguish between Port1-triggered (triangle) and animal lick-triggered (square)
        % Left reward
        if ~isnan(tempLeftReward)
            if isLeftRewardFromPort1
                % Port1-triggered reward - use triangle marker
                plot(rasterAx, tempLeftReward, pos, '^', 'MarkerFaceColor', [0.2 0.2 1], 'Color', [0.2 0.2 1], 'MarkerSize', 8);
            else
                % Animal lick-triggered reward - use square marker
                plot(rasterAx, tempLeftReward, pos, 's', 'MarkerFaceColor', [0.2 0.2 1], 'Color', [0.2 0.2 1]);
            end
        end
        
        % Right reward
        if ~isnan(tempRightReward)
            if isRightRewardFromPort1
                % Port1-triggered reward - use triangle marker
                plot(rasterAx, tempRightReward, pos, '^', 'MarkerFaceColor', [1 0.2 0.2], 'Color', [1 0.2 0.2], 'MarkerSize', 8);
            else
                % Animal lick-triggered reward - use square marker
                plot(rasterAx, tempRightReward, pos, 's', 'MarkerFaceColor', [1 0.2 0.2], 'Color', [1 0.2 0.2]);
            end
        end
    end
    
    % Set axes properties
    ylabel(rasterAx, 'Trial number');
    xlabel(rasterAx, 'Time re stim. onset (s)');
    ylim(rasterAx, [0.2, n_trial + 0.8]);
    
    % Set x-axis limits based on ResWin if available
    if ~isnan(ResWin)
        xlim(rasterAx, [-.55, ResWin + 0.5]);
        % Draw ResWin lines
        xline(rasterAx, 0, '--', 'Color', [0 0.5 0], 'LineWidth', 1.5);
        xline(rasterAx, ResWin, '--', 'Color', [0 0.5 0], 'LineWidth', 1.5);
    else
        xlim(rasterAx, [t_min - 0.1, t_max]);
    end
    
    title(rasterAx, 'Licks aligned to stimulus onset');
    grid(rasterAx, 'on');
    
    drawnow;
end


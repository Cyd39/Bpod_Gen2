function plotraster_behavior_v2(SessionData)
    % plotraster_behavior_v2 - Plot raster plot of lick events aligned to stimulus onset
    % Version 2: Added ResWin (response window) display
    % Inputs:
    %   Session_tbl - Table containing trial data with lick events and states
    %   SessionData - Session data structure to extract ResWin for display
    %% ExtractTimeStamps
    Session_tbl = ExtractTimeStamps(SessionData);
    
    fig = figure('Position', [500, 300, 1000, 700]); clf(fig);
    
    % Add figure title
    sgtitle(fig, 'Licks aligned to stimulus onset', 'FontSize', 12, 'FontWeight', 'bold');
    
    n_trial = height(Session_tbl);
    
    % Get ResWin value(s) for display
    ResWin = NaN;
    if isfield(SessionData, 'ResWin')
        ResWinData = SessionData.ResWin;
        
        % Check if ResWin is a struct array
        if isstruct(ResWinData)
            % Extract numeric values from struct array
            ResWinValues = [];
            for i = 1:length(ResWinData)
                % Try to convert struct to numeric value
                % If struct has a single numeric field, use it
                structFields = fieldnames(ResWinData(i));
                if ~isempty(structFields)
                    % Check each field for numeric value
                    for j = 1:length(structFields)
                        fieldValue = ResWinData(i).(structFields{j});
                        if isnumeric(fieldValue) && isscalar(fieldValue) && ~isnan(fieldValue)
                            ResWinValues = [ResWinValues, fieldValue];
                            break;
                        elseif isstruct(fieldValue)
                            % Nested struct - try to extract from it
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
                else
                    % Empty struct, try direct conversion
                    try
                        val = double(ResWinData(i));
                        if ~isnan(val)
                            ResWinValues = [ResWinValues, val];
                        end
                    catch
                        % Cannot convert, skip
                    end
                end
            end
            % Take the last value if multiple values exist
            if ~isempty(ResWinValues)
                ResWin = ResWinValues(end);
            end
        elseif isnumeric(ResWinData)
            % ResWin is numeric array - take the last non-NaN value
            ResWinValues = ResWinData(~isnan(ResWinData));
            if ~isempty(ResWinValues)
                ResWin = ResWinValues(end);
            end
        end
    elseif isfield(SessionData, 'TrialSettings') && ~isempty(SessionData.TrialSettings)
        % Try to get ResWin from TrialSettings (take last trial)
        lastTrial = length(SessionData.TrialSettings);
        if isfield(SessionData.TrialSettings(lastTrial), 'GUI') && ...
           isfield(SessionData.TrialSettings(lastTrial).GUI, 'ResWin')
            ResWin = SessionData.TrialSettings(lastTrial).GUI.ResWin;
        end
    end

    % loop through trials
    t_min = 0;
    t_max = 0;
    
    % Handles for legend elements (shared across subplots)
    hLeftLick = [];
    hRightLick = [];
    hRewardedLick = [];
    hResWin = [];
    
    % Flags to track if we've created legend handles
    leftLickLegendCreated = false;
    rightLickLegendCreated = false;
    rewardedLickLegendCreated = false;
    
    for i_ax = 1:2
        ax = subplot(1,2,i_ax); hold(ax,'on');
        
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
    
            tempLeftReward = Session_tbl.LeftReward(idx,1);
            tempRightReward = Session_tbl.RightReward(idx,1);
    
            trial_start = 0;
            trial_end = Session_tbl.WaitToFinish(idx,2);
            
            % align to stimulus onset
            StimOnset = Session_tbl.Stimulus(idx,1);
            tempLeftLicks = tempLeftLicks - StimOnset;
            tempRightLicks = tempRightLicks - StimOnset;
            tempLeftReward = tempLeftReward - StimOnset;
            tempRightReward = tempRightReward - StimOnset;
            trial_start = trial_start - StimOnset;
            t_min = min(t_min,trial_start);
            trial_end = trial_end - StimOnset;
            t_max = max(t_max,trial_end);
            
            plot(ax, [trial_start,trial_end],[pos,pos],'-','Color',[.7,.7,.7]);    
    
            % Plot left licks - create legend handle on first occurrence (only in first subplot)
            if ~isempty(tempLeftLicks)
                if ~leftLickLegendCreated && i_ax == 1
                    hLeftLick = plot(ax, tempLeftLicks(1), pos, '.', 'Color', [0.2 0.2 1], 'DisplayName', 'Left Lick');
                    leftLickLegendCreated = true;
                    if length(tempLeftLicks) > 1
                        plot(ax, tempLeftLicks(2:end), pos.*ones(size(tempLeftLicks(2:end))), '.', 'Color', [0.2 0.2 1]);
                    end
                else
                    plot(ax, tempLeftLicks, pos.*ones(size(tempLeftLicks)), '.', 'Color', [0.2 0.2 1]);
                end
            end
            
            % Plot right licks - create legend handle on first occurrence (only in first subplot)
            if ~isempty(tempRightLicks)
                if ~rightLickLegendCreated && i_ax == 1
                    hRightLick = plot(ax, tempRightLicks(1), pos, '.', 'Color', [1 0.2 0.2], 'DisplayName', 'Right Lick');
                    rightLickLegendCreated = true;
                    if length(tempRightLicks) > 1
                        plot(ax, tempRightLicks(2:end), pos.*ones(size(tempRightLicks(2:end))), '.', 'Color', [1 0.2 0.2]);
                    end
                else
                    plot(ax, tempRightLicks, pos.*ones(size(tempRightLicks)), '.', 'Color', [1 0.2 0.2]);
                end
            end
    
            % Plot reward markers - create legend handle on first occurrence (only in first subplot)
            if ~isnan(tempLeftReward)
                if ~rewardedLickLegendCreated && i_ax == 1
                    hRewardedLick = plot(ax, tempLeftReward, pos, 's', 'MarkerFaceColor', [0.2 0.2 1], 'Color', [0.2 0.2 1], 'DisplayName', 'Rewarded lick');
                    rewardedLickLegendCreated = true;
                else
                    plot(ax, tempLeftReward, pos, 's', 'MarkerFaceColor', [0.2 0.2 1], 'Color', [0.2 0.2 1]);
                end
            end
            if ~isnan(tempRightReward)
                if ~rewardedLickLegendCreated && i_ax == 1
                    hRewardedLick = plot(ax, tempRightReward, pos, 's', 'MarkerFaceColor', [1 0.2 0.2], 'Color', [1 0.2 0.2], 'DisplayName', 'Rewarded lick');
                    rewardedLickLegendCreated = true;
                else
                    plot(ax, tempRightReward, pos, 's', 'MarkerFaceColor', [1 0.2 0.2], 'Color', [1 0.2 0.2]);
                end
            end 
        end
        
        ylabel('Trial number')
        xlabel('Time re stim. onset (s)')
        ylim([0.2,n_trial+0.8]);
        
        % Plot ResWin lines only in the right subplot (zoomed view)
        if i_ax == 2 && ~isnan(ResWin)
            % Draw two green dashed lines: one at x=0 (window start) and one at x=ResWin (window end)
            xline(ax, 0, '--', 'Color', [0 0.5 0], 'LineWidth', 1.5);
            hResWin = xline(ax, ResWin, '--', 'Color', [0 0.5 0], 'LineWidth', 1.5, 'DisplayName', ['ResWindow = ' sprintf('%.2f', ResWin) ' s']);
        end

        switch i_ax
            case 1
                xlim(ax, [t_min-0.1, t_max]);
            case 2
                if ~isnan(ResWin)
                    xlim(ax, [-.55, ResWin + 0.5]);
                else
                    xlim(ax, [-.55, 1]);
                end
        end
    end
    
    % Create invisible legend handles if no licks were found (only needed for first subplot)
    if isempty(hLeftLick)
        ax1 = subplot(1,2,1);
        hLeftLick = plot(ax1, NaN, NaN, '.', 'Color', [0.2 0.2 1], 'DisplayName', 'Left Lick');
    end
    if isempty(hRightLick)
        ax1 = subplot(1,2,1);
        hRightLick = plot(ax1, NaN, NaN, '.', 'Color', [1 0.2 0.2], 'DisplayName', 'Right Lick');
    end
    if isempty(hRewardedLick)
        ax1 = subplot(1,2,1);
        hRewardedLick = plot(ax1, NaN, NaN, 's', 'MarkerFaceColor', [0.2 0.2 1], 'Color', [0.2 0.2 1], 'DisplayName', 'Rewarded lick');
    end
    
    % Add single legend to the figure (on the right subplot)
    ax2 = subplot(1,2,2);
    legendHandles = [];
    legendLabels = {};
    
    if ~isempty(hLeftLick)
        legendHandles = [legendHandles, hLeftLick];
        legendLabels{end+1} = 'Left Lick';
    end
    
    if ~isempty(hRightLick)
        legendHandles = [legendHandles, hRightLick];
        legendLabels{end+1} = 'Right Lick';
    end
    
    if ~isempty(hRewardedLick)
        legendHandles = [legendHandles, hRewardedLick];
        legendLabels{end+1} = 'Rewarded lick';
    end
    
    if ~isempty(hResWin)
        legendHandles = [legendHandles, hResWin];
        legendLabels{end+1} = ['ResWindow = ' sprintf('%.2f', ResWin) ' s'];
    end
    
    if ~isempty(legendHandles)
        legend(ax2, legendHandles, legendLabels, 'Location', 'northeast');
    end
end


function plotraster_behavior_v2(SessionData)
    % plotraster_behavior_v2 - Plot raster plot of lick events aligned to stimulus onset
    % Version 2: Added ResWin (response window) display
    % Inputs:
    %   Session_tbl - Table containing trial data with lick events and states
    %   SessionData - Session data structure to extract ResWin for display
    %% ExtractTimeStamps
    try
        Session_tbl = ExtractTimeStamps(SessionData);
    catch ME
        error('Failed to extract timestamps: %s', ME.message);
    end
    
    % Check if Session_tbl is empty or invalid
    if isempty(Session_tbl) || height(Session_tbl) == 0
        warning('Session_tbl is empty or has no trials. Cannot create raster plot.');
        fig = figure('Position', [500, 300, 1000, 700]);
        ax1 = subplot(1,2,1);
        text(ax1, 0.5, 0.5, 'No data available', 'HorizontalAlignment', 'center', ...
            'FontSize', 14, 'Units', 'normalized');
        ax2 = subplot(1,2,2);
        text(ax2, 0.5, 0.5, 'No data available', 'HorizontalAlignment', 'center', ...
            'FontSize', 14, 'Units', 'normalized');
        return;
    end
    
    fig = figure('Position', [500, 300, 800, 700]); clf(fig);
    
    % Add figure title
    sgtitle(fig, 'Licks aligned to stimulus onset', 'FontSize', 12, 'FontWeight', 'bold');
    
    n_trial = height(Session_tbl);
    
    % Check if n_trial is valid
    if n_trial == 0
        warning('No trials found in Session_tbl. Cannot create raster plot.');
        ax1 = subplot(1,2,1);
        text(ax1, 0.5, 0.5, 'No trials found', 'HorizontalAlignment', 'center', ...
            'FontSize', 14, 'Units', 'normalized');
        ax2 = subplot(1,2,2);
        text(ax2, 0.5, 0.5, 'No trials found', 'HorizontalAlignment', 'center', ...
            'FontSize', 14, 'Units', 'normalized');
        return;
    end
    
    % Debug: Check if required fields exist
    requiredFields = {'LeftLickOn', 'RightLickOn', 'Stimulus', 'WaitToFinish'};
    missingFields = {};
    for i = 1:length(requiredFields)
        if ~ismember(requiredFields{i}, Session_tbl.Properties.VariableNames)
            missingFields{end+1} = requiredFields{i};
        end
    end
    if ~isempty(missingFields)
        warning('Missing required fields in Session_tbl: %s', strjoin(missingFields, ', '));
    end
    
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
    
    % Create 3 subplots: 2 for data, 1 for legend
    % First create all 3 subplots, then adjust their positions
    ax1 = subplot(1,3,1);
    ax2 = subplot(1,3,2);
    ax3 = subplot(1,3,3);
    
    % Adjust positions: data subplots take ~42% each, legend takes ~8%
    % IMPORTANT: Modify the values below to adjust subplot widths and spacing
    % Position format: [left, bottom, width, height] in normalized units (0-1)
    
    % First subplot - adjust these values:
    pos1 = get(ax1, 'Position');
    pos1(3) = 0.3;  % Width: 42% (change this to adjust first subplot width)
    pos1(1) = 0.08;  % Left position: 8% (change this to adjust left margin)
    set(ax1, 'Position', pos1);
    hold(ax1, 'on');
    
    % Second subplot - adjust these values:
    pos2 = get(ax2, 'Position');
    pos2(3) = 0.50;  % Width: 50% (change this to adjust second subplot width, increased from 42%)
    pos2(1) = 0.42;  % Left position: 42% (change this to adjust spacing between subplots, right-shifted)
    % Note: spacing = pos2(1) - (pos1(1) + pos1(3))
    % Current spacing: 0.42 - (0.08 + 0.3) = 0.04 (4% gap)
    set(ax2, 'Position', pos2);
    hold(ax2, 'on');
    
    % Third subplot (for legend) - adjust these values:
    pos3 = get(ax3, 'Position');
    pos3(3) = 0.05;
    % Width: 5% (change this to adjust legend subplot width, smaller = narrower)
    pos3(1) = 0.95;  % Left position
    % Note: spacing = pos3(1) - (pos2(1) + pos2(3))
    % Current spacing: 0.95 - (0.42 + 0.50) = 0.03 (3% gap)
    set(ax3, 'Position', pos3);
    
    % Force update to ensure positions are applied
    drawnow;
    
    % Now loop through data subplots
    for i_ax = 1:2
        if i_ax == 1
            ax = ax1;
        else
            ax = ax2;
        end
        
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
    
            trial_start = 0;
            try
                trial_end = Session_tbl.WaitToFinish(idx,2);
            catch
                trial_end = NaN;
            end
            
            % align to stimulus onset
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
            t_min = min(t_min,trial_start);
            if ~isnan(trial_end)
                trial_end = trial_end - StimOnset;
                t_max = max(t_max,trial_end);
                % Plot trial duration line only if trial_end is valid
                plot(ax, [trial_start,trial_end],[pos,pos],'-','Color',[.7,.7,.7]);
            else
                % If trial_end is invalid, use a default duration or skip
                % Use a default duration of 5 seconds if trial_end is NaN
                default_trial_end = trial_start + 5;
                t_max = max(t_max, default_trial_end);
                plot(ax, [trial_start,default_trial_end],[pos,pos],'-','Color',[.7,.7,.7]);
            end    
    
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
        
        % Set labels for each subplot explicitly
        ylabel(ax, 'Trial number')
        xlabel(ax, 'Time re stim. onset (s)')
        ylim(ax, [0.2,n_trial+0.8]);
        
        % Plot ResWin lines only in the right subplot (zoomed view)
        if i_ax == 2 && ~isnan(ResWin)
            % Draw two green dashed lines: one at x=0 (window start) and one at x=ResWin (window end)
            xline(ax, 0, '--', 'Color', [0 0.5 0], 'LineWidth', 1.5);
            xline(ax, ResWin, '--', 'Color', [0 0.5 0], 'LineWidth', 1.5);
            % Create a dummy line object for legend (xline objects can't be used directly in legend)
            hResWin = plot(ax, [NaN NaN], [NaN NaN], '--', 'Color', [0 0.5 0], 'LineWidth', 1.5, ...
                'DisplayName', ['ResWindow = ' sprintf('%.2f', ResWin) ' s']);
        end

        switch i_ax
            case 1
                % Ensure t_min and t_max are valid
                if isnan(t_min) || isnan(t_max) || t_min >= t_max
                    % Use default range if invalid
                    xlim(ax, [-1, 5]);
                else
                    xlim(ax, [t_min-0.1, t_max+0.1]);
                end
            case 2
                if ~isnan(ResWin)
                    xlim(ax, [-.55, ResWin + 0.5]);
                else
                    % Use default range if ResWin is not available
                    if isnan(t_min) || isnan(t_max) || t_min >= t_max
                        xlim(ax, [-.55, 1]);
                    else
                        xlim(ax, [-.55, min(t_max+0.5, 5)]);
                    end
                end
        end
    end
    
    % Re-apply positions after data plotting (in case plotting changed them)
    % Re-apply second subplot position
    pos2_after_plot = get(ax2, 'Position');
    pos2_after_plot(1) = 0.46;  % Left position: 45%
    pos2_after_plot(3) = 0.32;  % Width: 32%
    set(ax2, 'Position', pos2_after_plot);
    % Re-apply labels after position change
    ylabel(ax2, 'Trial number')
    xlabel(ax2, 'Time re stim. onset (s)')
    
    % Re-apply first subplot position (for consistency)
    pos1_after_plot = get(ax1, 'Position');
    pos1_after_plot(1) = 0.08;  % Left position: 8%
    pos1_after_plot(3) = 0.32;  % Width: 32%
    set(ax1, 'Position', pos1_after_plot);
    % Re-apply labels after position change
    ylabel(ax1, 'Trial number')
    xlabel(ax1, 'Time re stim. onset (s)')
    
    % Use the third subplot (already created) for legend display
    % Re-apply position before creating legend (in case data plotting changed it)
    pos3_before_legend = get(ax3, 'Position');
    pos3_before_legend(1) = 0.93;  % Left position: 95%
    pos3_before_legend(3) = 0.05;  % Width: 5%
    set(ax3, 'Position', pos3_before_legend);
    axis(ax3, 'off');  % Turn off axes for legend-only subplot
    
    % Create dummy objects in ax3 for legend (all handles must be from the same axes)
    hold(ax3, 'on');
    legendHandles = [];
    legendLabels = {};
    
    % Create dummy objects for each legend item in ax3
    hLeftDummy = plot(ax3, NaN, NaN, '.', 'Color', [0.2 0.2 1], 'MarkerSize', 10);
    legendHandles = [legendHandles, hLeftDummy];
    legendLabels{end+1} = 'Left Lick';
    
    hRightDummy = plot(ax3, NaN, NaN, '.', 'Color', [1 0.2 0.2], 'MarkerSize', 10);
    legendHandles = [legendHandles, hRightDummy];
    legendLabels{end+1} = 'Right Lick';
    
    hRewardedDummy = plot(ax3, NaN, NaN, 's', 'MarkerFaceColor', [0.2 0.2 1], 'Color', [0.2 0.2 1], 'MarkerSize', 8);
    legendHandles = [legendHandles, hRewardedDummy];
    legendLabels{end+1} = 'Rewarded lick';
    
    if ~isempty(hResWin) && ~isnan(ResWin)
        hResWinDummy = plot(ax3, NaN, NaN, '--', 'Color', [0 0.5 0], 'LineWidth', 1.5);
        legendHandles = [legendHandles, hResWinDummy];
        legendLabels{end+1} = ['ResWindow = ' sprintf('%.2f', ResWin) ' s'];
    end
    
    % Create legend in the third subplot, centered
    if ~isempty(legendHandles)
        legend(ax3, legendHandles, legendLabels, 'Location', 'north', 'Box', 'off');
        % Ensure the subplot position is maintained after legend creation
        % Re-apply position in case legend creation changed it
        pos3_final = get(ax3, 'Position');
        pos3_final(1) = 0.95;  % Left position: 95% (ensure it's at the right)
        pos3_final(3) = 0.05;  % Width: 5% (ensure width is correct)
        set(ax3, 'Position', pos3_final);
    end
    
    % Final position check and fix before returning (critical for saving)
    % Re-apply all positions one final time to ensure they're correct
    pos1_final = get(ax1, 'Position');
    pos1_final(1) = 0.08;
    pos1_final(3) = 0.32;
    set(ax1, 'Position', pos1_final);
    
    pos2_final = get(ax2, 'Position');
    pos2_final(1) = 0.46;
    pos2_final(3) = 0.32;
    set(ax2, 'Position', pos2_final);
    
    pos3_final = get(ax3, 'Position');
    pos3_final(1) = 0.95;
    pos3_final(3) = 0.05;
    set(ax3, 'Position', pos3_final);
    
    % Re-apply labels after final position fix
    ylabel(ax1, 'Trial number')
    xlabel(ax1, 'Time re stim. onset (s)')
    ylabel(ax2, 'Trial number')
    xlabel(ax2, 'Time re stim. onset (s)')
    
    % Force final render to ensure all positions are applied
    drawnow;
end


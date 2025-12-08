function PlotLickRaster(SessionData, varargin)
    % PlotLickRaster - Plot raster plot of lick events aligned to stimulus onset
    % 
    % This function extracts lick events from SessionData and plots them in a raster format.
    % Logic is based on plotraster_behavior_v2, with support for both online and offline modes.
    %
    % Inputs:
    %   SessionData - Session data structure
    %   Optional name-value pairs:
    %     'FigureHandle' - figure handle for the combined plot (optional, for activation in online mode)
    %     'Axes' - axes handle(s) for the plot (optional, can be single axes or cell array of 2 axes for dual subplot mode)
    %              If 2 axes provided, generates 2 subplots with legend in right subplot's northwest
    %     'FigureName' - name for new figure if axes not provided (default: 'Licks aligned to stimulus onset')
    %
    % Usage:
    %   Online mode (single): PlotLickRaster(BpodSystem.Data, 'FigureHandle', customPlotFig, 'Axes', rasterAx);
    %   Online mode (dual): PlotLickRaster(BpodSystem.Data, 'FigureHandle', customPlotFig, 'Axes', {rasterAx1, rasterAx2});
    %   Offline mode: PlotLickRaster(SessionData);
    
    % Parse optional inputs
    p = inputParser;
    addParameter(p, 'FigureHandle', [], @(x) isempty(x) || isgraphics(x, 'figure'));
    % Validate Axes: can be empty, single axes, or cell array of 2 axes
    validateAxes = @(x) isempty(x) || ...
        (~iscell(x) && isgraphics(x, 'axes')) || ...
        (iscell(x) && length(x) == 2 && all(cellfun(@(y) isgraphics(y, 'axes'), x)));
    addParameter(p, 'Axes', [], validateAxes);
    addParameter(p, 'FigureName', 'Licks aligned to stimulus onset', @ischar);
    parse(p, varargin{:});
    
    customPlotFig = p.Results.FigureHandle;
    ax = p.Results.Axes;
    figureName = p.Results.FigureName;
    
    % Activate figure if provided (for online mode)
    if ~isempty(customPlotFig) && isvalid(customPlotFig)
        figure(customPlotFig);
    end
    
    % Determine mode: online (single or dual axes) or offline (multiple subplots)
    % Check this early to handle error cases properly
    isOnlineMode = ~isempty(ax);
    isDualAxesMode = iscell(ax) && length(ax) == 2;
    
    % Check if data exists
    if ~isfield(SessionData, 'RawEvents') || ~isfield(SessionData.RawEvents, 'Trial')
        warning('SessionData.RawEvents.Trial not found');
        if ~isempty(ax)
            if isDualAxesMode
                cla(ax{1});
                cla(ax{2});
                text(ax{1}, 0.5, 0.5, 'No data available', ...
                    'HorizontalAlignment', 'center', 'FontSize', 14, 'Units', 'normalized');
                text(ax{2}, 0.5, 0.5, 'No data available', ...
                    'HorizontalAlignment', 'center', 'FontSize', 14, 'Units', 'normalized');
            else
                cla(ax);
                text(ax, 0.5, 0.5, 'No data available', ...
                    'HorizontalAlignment', 'center', 'FontSize', 14, 'Units', 'normalized');
            end
            if ~isempty(customPlotFig)
                drawnow;
            end
        end
        return;
    end
    
    % Extract timestamps using ExtractTimeStamps
    try
        Session_tbl = ExtractTimeStamps(SessionData);
    catch ME
        warning(['Failed to extract timestamps: ' ME.message]);
        if ~isempty(ax)
            if isDualAxesMode
                cla(ax{1});
                cla(ax{2});
                text(ax{1}, 0.5, 0.5, 'Failed to extract data', ...
                    'HorizontalAlignment', 'center', 'FontSize', 14, 'Units', 'normalized');
                text(ax{2}, 0.5, 0.5, 'Failed to extract data', ...
                    'HorizontalAlignment', 'center', 'FontSize', 14, 'Units', 'normalized');
            else
                cla(ax);
                text(ax, 0.5, 0.5, 'Failed to extract data', ...
                    'HorizontalAlignment', 'center', 'FontSize', 14, 'Units', 'normalized');
            end
            if ~isempty(customPlotFig)
                drawnow;
            end
        end
        return;
    end
    
    % Check if Session_tbl is empty
    if isempty(Session_tbl) || height(Session_tbl) == 0
        if ~isempty(ax)
            if isDualAxesMode
                cla(ax{1});
                cla(ax{2});
                text(ax{1}, 0.5, 0.5, 'No trials completed', ...
                    'HorizontalAlignment', 'center', 'FontSize', 14, 'Units', 'normalized');
                text(ax{2}, 0.5, 0.5, 'No trials completed', ...
                    'HorizontalAlignment', 'center', 'FontSize', 14, 'Units', 'normalized');
            else
                cla(ax);
                text(ax, 0.5, 0.5, 'No trials completed', ...
                    'HorizontalAlignment', 'center', 'FontSize', 14, 'Units', 'normalized');
            end
            if ~isempty(customPlotFig)
                drawnow;
            end
        end
        return;
    end
    
    n_trial = height(Session_tbl);
    
    if isOnlineMode
        if isDualAxesMode
            % Online mode: use provided two axes (dual subplot mode with legend)
            PlotLickRasterOnlineDual(ax{1}, ax{2}, Session_tbl, SessionData, n_trial, customPlotFig);
        else
            % Online mode: use provided single axes (simplified single plot)
            PlotLickRasterOnline(ax, Session_tbl, SessionData, n_trial, customPlotFig);
        end
    else
        % Offline mode: create full figure with multiple subplots (complete version from plotraster_behavior_v2)
        PlotLickRasterOffline(Session_tbl, SessionData, n_trial, figureName);
    end
end

function PlotLickRasterOnline(ax, Session_tbl, SessionData, n_trial, customPlotFig)
    % Online mode: simplified single axes plot
    
    % Clear axes and prepare for plotting
    cla(ax);
    hold(ax, 'on');
    
    t_min = 0;
    t_max = 0;
    
    % Get ResWin value for x-axis limit
    ResWin = GetResWin(SessionData);
    
    % Plot each trial
    for idx = 1:n_trial
        pos = idx;
        
        % Extract lick and reward data
        [tempLeftLicks, tempRightLicks, tempLeftReward, tempRightReward, ...
         isLeftRewardFromPort1, isRightRewardFromPort1, StimOnset, trial_start, trial_end] = ...
            ExtractTrialData(Session_tbl, SessionData, idx);
        
        % Skip this trial if StimOnset is invalid
        if isnan(StimOnset)
            continue;
        end
        
        % Align to stimulus onset
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
            plot(ax, [trial_start, trial_end], [pos, pos], '-', 'Color', [.7, .7, .7]);
        else
            default_trial_end = trial_start + 5;
            t_max = max(t_max, default_trial_end);
            plot(ax, [trial_start, default_trial_end], [pos, pos], '-', 'Color', [.7, .7, .7]);
        end
        
        % Plot left licks
        if ~isempty(tempLeftLicks)
            plot(ax, tempLeftLicks, pos.*ones(size(tempLeftLicks)), '.', 'Color', [0.2 0.2 1]);
        end
        
        % Plot right licks
        if ~isempty(tempRightLicks)
            plot(ax, tempRightLicks, pos.*ones(size(tempRightLicks)), '.', 'Color', [1 0.2 0.2]);
        end
        
        % Plot reward markers
        if ~isnan(tempLeftReward)
            if isLeftRewardFromPort1
                plot(ax, tempLeftReward, pos, '^', 'MarkerFaceColor', [0.2 0.2 1], 'Color', [0.2 0.2 1], 'MarkerSize', 8);
            else
                plot(ax, tempLeftReward, pos, 's', 'MarkerFaceColor', [0.2 0.2 1], 'Color', [0.2 0.2 1]);
            end
        end
        
        if ~isnan(tempRightReward)
            if isRightRewardFromPort1
                plot(ax, tempRightReward, pos, '^', 'MarkerFaceColor', [1 0.2 0.2], 'Color', [1 0.2 0.2], 'MarkerSize', 8);
            else
                plot(ax, tempRightReward, pos, 's', 'MarkerFaceColor', [1 0.2 0.2], 'Color', [1 0.2 0.2]);
            end
        end
    end
    
    % Set axes properties
    ylabel(ax, 'Trial number');
    xlabel(ax, 'Time re stim. onset (s)');
    ylim(ax, [0.2, n_trial + 0.8]);
    
    % Set x-axis limits based on ResWin if available
    if ~isnan(ResWin)
        xlim(ax, [-.55, ResWin + 0.5]);
        xline(ax, 0, '--', 'Color', [0 0.5 0], 'LineWidth', 1.5);
        xline(ax, ResWin, '--', 'Color', [0 0.5 0], 'LineWidth', 1.5);
    else
        if isnan(t_min) || isnan(t_max) || t_min >= t_max
            xlim(ax, [-.55, 5]);
        else
            xlim(ax, [t_min - 0.1, t_max + 0.1]);
        end
    end
    
    title(ax, 'Licks aligned to stimulus onset');
    grid(ax, 'on');
    
    if ~isempty(customPlotFig)
        drawnow;
    end
end

function PlotLickRasterOnlineDual(ax1, ax2, Session_tbl, SessionData, n_trial, customPlotFig)
    % Online mode: dual axes plot with legend in right subplot's northwest
    
    % Clear axes and prepare for plotting
    cla(ax1);
    cla(ax2);
    hold(ax1, 'on');
    hold(ax2, 'on');
    
    t_min = 0;
    t_max = 0;
    
    % Get ResWin value for x-axis limit
    ResWin = GetResWin(SessionData);
    
    % Flags to track if we've created legend handles
    leftLickLegendCreated = false;
    rightLickLegendCreated = false;
    rewardedLickLegendCreated = false;
    port1RewardLegendCreated = false;
    hResWin = [];
    
    % Loop through data subplots
    for i_ax = 1:2
        if i_ax == 1
            ax = ax1;
        else
            ax = ax2;
        end
        
        for idx = 1:n_trial
            pos = idx;
            
            % Extract lick and reward data
            [tempLeftLicks, tempRightLicks, tempLeftReward, tempRightReward, ...
             isLeftRewardFromPort1, isRightRewardFromPort1, StimOnset, trial_start, trial_end] = ...
                ExtractTrialData(Session_tbl, SessionData, idx);
            
            % Skip this trial if StimOnset is invalid
            if isnan(StimOnset)
                continue;
            end
            
            % Align to stimulus onset
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
                plot(ax, [trial_start, trial_end], [pos, pos], '-', 'Color', [.7, .7, .7]);
            else
                default_trial_end = trial_start + 5;
                t_max = max(t_max, default_trial_end);
                plot(ax, [trial_start, default_trial_end], [pos, pos], '-', 'Color', [.7, .7, .7]);
            end
            
            % Plot left licks - create legend handle on first occurrence (only in first subplot)
            if ~isempty(tempLeftLicks)
                if ~leftLickLegendCreated && i_ax == 1
                    plot(ax, tempLeftLicks(1), pos, '.', 'Color', [0.2 0.2 1], 'DisplayName', 'Left Lick');
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
                    plot(ax, tempRightLicks(1), pos, '.', 'Color', [1 0.2 0.2], 'DisplayName', 'Right Lick');
                    rightLickLegendCreated = true;
                    if length(tempRightLicks) > 1
                        plot(ax, tempRightLicks(2:end), pos.*ones(size(tempRightLicks(2:end))), '.', 'Color', [1 0.2 0.2]);
                    end
                else
                    plot(ax, tempRightLicks, pos.*ones(size(tempRightLicks)), '.', 'Color', [1 0.2 0.2]);
                end
            end
            
            % Plot reward markers
            if ~isnan(tempLeftReward)
                if isLeftRewardFromPort1
                    if ~port1RewardLegendCreated && i_ax == 1
                        plot(ax, tempLeftReward, pos, '^', 'MarkerFaceColor', [0.2 0.2 1], 'Color', [0.2 0.2 1], 'MarkerSize', 8, 'DisplayName', 'Manual reward');
                        port1RewardLegendCreated = true;
                    else
                        plot(ax, tempLeftReward, pos, '^', 'MarkerFaceColor', [0.2 0.2 1], 'Color', [0.2 0.2 1], 'MarkerSize', 8);
                    end
                else
                    if ~rewardedLickLegendCreated && i_ax == 1
                        plot(ax, tempLeftReward, pos, 's', 'MarkerFaceColor', [0.2 0.2 1], 'Color', [0.2 0.2 1], 'DisplayName', 'Rewarded lick');
                        rewardedLickLegendCreated = true;
                    else
                        plot(ax, tempLeftReward, pos, 's', 'MarkerFaceColor', [0.2 0.2 1], 'Color', [0.2 0.2 1]);
                    end
                end
            end
            
            if ~isnan(tempRightReward)
                if isRightRewardFromPort1
                    if ~port1RewardLegendCreated && i_ax == 1
                        plot(ax, tempRightReward, pos, '^', 'MarkerFaceColor', [1 0.2 0.2], 'Color', [1 0.2 0.2], 'MarkerSize', 8, 'DisplayName', 'Manual reward');
                        port1RewardLegendCreated = true;
                    else
                        plot(ax, tempRightReward, pos, '^', 'MarkerFaceColor', [1 0.2 0.2], 'Color', [1 0.2 0.2], 'MarkerSize', 8);
                    end
                else
                    if ~rewardedLickLegendCreated && i_ax == 1
                        plot(ax, tempRightReward, pos, 's', 'MarkerFaceColor', [1 0.2 0.2], 'Color', [1 0.2 0.2], 'DisplayName', 'Rewarded lick');
                        rewardedLickLegendCreated = true;
                    else
                        plot(ax, tempRightReward, pos, 's', 'MarkerFaceColor', [1 0.2 0.2], 'Color', [1 0.2 0.2]);
                    end
                end
            end
        end
        
        % Set labels for each subplot
        ylabel(ax, 'Trial number');
        xlabel(ax, 'Time re stim. onset (s)');
        ylim(ax, [0.2, n_trial + 0.8]);
        
        % Plot ResWin lines in both subplots
        if ~isnan(ResWin)
            xline(ax, 0, '--', 'Color', [0 0.5 0], 'LineWidth', 1.5);
            xline(ax, ResWin, '--', 'Color', [0 0.5 0], 'LineWidth', 1.5);
            if i_ax == 1
                hResWin = plot(ax, [NaN NaN], [NaN NaN], '--', 'Color', [0 0.5 0], 'LineWidth', 1.5, ...
                    'DisplayName', ['ResWindow']);
            end
        end
        
        switch i_ax
            case 1
                if isnan(t_min) || isnan(t_max) || t_min >= t_max
                    xlim(ax, [-1, 5]);
                else
                    xlim(ax, [t_min-0.1, t_max+0.1]);
                end
            case 2
                if ~isnan(ResWin)
                    xlim(ax, [-.55, ResWin + 0.5]);
                else
                    if isnan(t_min) || isnan(t_max) || t_min >= t_max
                        xlim(ax, [-.55, 1]);
                    else
                        xlim(ax, [-.55, min(t_max+0.5, 5)]);
                    end
                end
        end
    end
    
    % Create legend in right subplot's northwest
    % Clear any existing legend first
    legend(ax2, 'off');
    
    legendHandles = [];
    legendLabels = {};
    
    % Get legend handles from first subplot (where DisplayName was set)
    ax1Children = get(ax1, 'Children');
    for i = 1:length(ax1Children)
        if isprop(ax1Children(i), 'DisplayName') && ~isempty(ax1Children(i).DisplayName)
            legendHandles = [legendHandles, ax1Children(i)];
            legendLabels{end+1} = ax1Children(i).DisplayName;
        end
    end
    
    % Create legend in right subplot's northwest
    if ~isempty(legendHandles)
        legend(ax2, legendHandles, legendLabels, 'Location', 'northwest', 'Box', 'off');
    end
    
    % Set titles
    title(ax1, 'Licks aligned to stimulus onset (full range)');
    title(ax2, 'Licks aligned to stimulus onset (response window)');
    grid(ax1, 'on');
    grid(ax2, 'on');
    
    if ~isempty(customPlotFig)
        drawnow;
    end
end

function PlotLickRasterOffline(Session_tbl, SessionData, n_trial, figureName)
    % Offline mode: full figure with multiple subplots (complete version from plotraster_behavior_v2)
    
    fig = figure('Position', [500, 300, 1200, 700], 'Name', figureName);
    clf(fig);
    
    % Add figure title
    sgtitle(fig, 'Licks aligned to stimulus onset', 'FontSize', 12, 'FontWeight', 'bold');
    
    t_min = 0;
    t_max = 0;
    
    % Get ResWin value for display
    ResWin = GetResWin(SessionData);
    
    % Handles for legend elements (shared across subplots)
    hResWin = [];
    
    % Subplot position configuration
    SUBPLOT1_POS = [0.05, 0.11, 0.38, 0.815];
    SUBPLOT2_POS = [0.5, 0.11, 0.35, 0.815];
    SUBPLOT3_POS = [0.95, 0.11, 0.05, 0.815];
    
    function applySubplotPositions(ax1, ax2, ax3)
        set(ax1, 'Position', SUBPLOT1_POS);
        set(ax2, 'Position', SUBPLOT2_POS);
        set(ax3, 'Position', SUBPLOT3_POS);
    end
    
    % Create subplots
    ax1 = subplot(1,3,1);
    ax2 = subplot(1,3,2);
    ax3 = subplot(1,3,3);
    
    applySubplotPositions(ax1, ax2, ax3);
    hold(ax1, 'on');
    hold(ax2, 'on');
    
    drawnow;
    
    % Flags to track if we've created legend handles
    leftLickLegendCreated = false;
    rightLickLegendCreated = false;
    rewardedLickLegendCreated = false;
    port1RewardLegendCreated = false;
    
    % Loop through data subplots
    for i_ax = 1:2
        if i_ax == 1
            ax = ax1;
        else
            ax = ax2;
        end
        
        for idx = 1:n_trial
            pos = idx;
            
            % Extract lick and reward data
            [tempLeftLicks, tempRightLicks, tempLeftReward, tempRightReward, ...
             isLeftRewardFromPort1, isRightRewardFromPort1, StimOnset, trial_start, trial_end] = ...
                ExtractTrialData(Session_tbl, SessionData, idx);
            
            % Skip this trial if StimOnset is invalid
            if isnan(StimOnset)
                continue;
            end
            
            % Align to stimulus onset
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
                plot(ax, [trial_start, trial_end], [pos, pos], '-', 'Color', [.7, .7, .7]);
            else
                default_trial_end = trial_start + 5;
                t_max = max(t_max, default_trial_end);
                plot(ax, [trial_start, default_trial_end], [pos, pos], '-', 'Color', [.7, .7, .7]);
            end
            
            % Plot left licks - create legend handle on first occurrence (only in first subplot)
            if ~isempty(tempLeftLicks)
                if ~leftLickLegendCreated && i_ax == 1
                    plot(ax, tempLeftLicks(1), pos, '.', 'Color', [0.2 0.2 1], 'DisplayName', 'Left Lick');
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
                    plot(ax, tempRightLicks(1), pos, '.', 'Color', [1 0.2 0.2], 'DisplayName', 'Right Lick');
                    rightLickLegendCreated = true;
                    if length(tempRightLicks) > 1
                        plot(ax, tempRightLicks(2:end), pos.*ones(size(tempRightLicks(2:end))), '.', 'Color', [1 0.2 0.2]);
                    end
                else
                    plot(ax, tempRightLicks, pos.*ones(size(tempRightLicks)), '.', 'Color', [1 0.2 0.2]);
                end
            end
            
            % Plot reward markers
            if ~isnan(tempLeftReward)
                if isLeftRewardFromPort1
                    if ~port1RewardLegendCreated && i_ax == 1
                        plot(ax, tempLeftReward, pos, '^', 'MarkerFaceColor', [0.2 0.2 1], 'Color', [0.2 0.2 1], 'MarkerSize', 8, 'DisplayName', 'Manual reward');
                        port1RewardLegendCreated = true;
                    else
                        plot(ax, tempLeftReward, pos, '^', 'MarkerFaceColor', [0.2 0.2 1], 'Color', [0.2 0.2 1], 'MarkerSize', 8);
                    end
                else
                    if ~rewardedLickLegendCreated && i_ax == 1
                        plot(ax, tempLeftReward, pos, 's', 'MarkerFaceColor', [0.2 0.2 1], 'Color', [0.2 0.2 1], 'DisplayName', 'Rewarded lick');
                        rewardedLickLegendCreated = true;
                    else
                        plot(ax, tempLeftReward, pos, 's', 'MarkerFaceColor', [0.2 0.2 1], 'Color', [0.2 0.2 1]);
                    end
                end
            end
            
            if ~isnan(tempRightReward)
                if isRightRewardFromPort1
                    if ~port1RewardLegendCreated && i_ax == 1
                        plot(ax, tempRightReward, pos, '^', 'MarkerFaceColor', [1 0.2 0.2], 'Color', [1 0.2 0.2], 'MarkerSize', 8, 'DisplayName', 'Manual reward');
                        port1RewardLegendCreated = true;
                    else
                        plot(ax, tempRightReward, pos, '^', 'MarkerFaceColor', [1 0.2 0.2], 'Color', [1 0.2 0.2], 'MarkerSize', 8);
                    end
                else
                    if ~rewardedLickLegendCreated && i_ax == 1
                        plot(ax, tempRightReward, pos, 's', 'MarkerFaceColor', [1 0.2 0.2], 'Color', [1 0.2 0.2], 'DisplayName', 'Rewarded lick');
                        rewardedLickLegendCreated = true;
                    else
                        plot(ax, tempRightReward, pos, 's', 'MarkerFaceColor', [1 0.2 0.2], 'Color', [1 0.2 0.2]);
                    end
                end
            end
        end
        
        % Set labels for each subplot
        ylabel(ax, 'Trial number');
        xlabel(ax, 'Time re stim. onset (s)');
        ylim(ax, [0.2, n_trial + 0.8]);
        
        % Plot ResWin lines in both subplots
        if ~isnan(ResWin)
            xline(ax, 0, '--', 'Color', [0 0.5 0], 'LineWidth', 1.5);
            xline(ax, ResWin, '--', 'Color', [0 0.5 0], 'LineWidth', 1.5);
            if i_ax == 1
                hResWin = plot(ax, [NaN NaN], [NaN NaN], '--', 'Color', [0 0.5 0], 'LineWidth', 1.5, ...
                    'DisplayName', 'ResWindow');
            end
        end
        
        switch i_ax
            case 1
                if isnan(t_min) || isnan(t_max) || t_min >= t_max
                    xlim(ax, [-1, 5]);
                else
                    xlim(ax, [t_min-0.1, t_max+0.1]);
                end
            case 2
                if ~isnan(ResWin)
                    xlim(ax, [-.55, ResWin + 0.5]);
                else
                    if isnan(t_min) || isnan(t_max) || t_min >= t_max
                        xlim(ax, [-.55, 1]);
                    else
                        xlim(ax, [-.55, min(t_max+0.5, 5)]);
                    end
                end
        end
    end
    
    % Re-apply positions after data plotting
    applySubplotPositions(ax1, ax2, ax3);
    
    % Re-apply labels
    ylabel(ax1, 'Trial number');
    xlabel(ax1, 'Time re stim. onset (s)');
    ylabel(ax2, 'Trial number');
    xlabel(ax2, 'Time re stim. onset (s)');
    
    % Use the third subplot for legend display
    axis(ax3, 'off');
    hold(ax3, 'on');
    legendHandles = [];
    legendLabels = {};
    
    % Create dummy objects for legend
    hLeftDummy = plot(ax3, NaN, NaN, '.', 'Color', [0.2 0.2 1], 'MarkerSize', 10);
    legendHandles = [legendHandles, hLeftDummy];
    legendLabels{end+1} = 'Left Lick';
    
    hRightDummy = plot(ax3, NaN, NaN, '.', 'Color', [1 0.2 0.2], 'MarkerSize', 10);
    legendHandles = [legendHandles, hRightDummy];
    legendLabels{end+1} = 'Right Lick';
    
    hRewardedDummy = plot(ax3, NaN, NaN, 's', 'MarkerFaceColor', [0.2 0.2 1], 'Color', [0.2 0.2 1], 'MarkerSize', 8);
    legendHandles = [legendHandles, hRewardedDummy];
    legendLabels{end+1} = 'Rewarded lick';
    
    hPort1RewardDummy = plot(ax3, NaN, NaN, '^', 'MarkerFaceColor', [0.2 0.2 1], 'Color', [0.2 0.2 1], 'MarkerSize', 8);
    legendHandles = [legendHandles, hPort1RewardDummy];
    legendLabels{end+1} = 'Manual reward';
    
    if ~isempty(hResWin) && ~isnan(ResWin)
        hResWinDummy = plot(ax3, NaN, NaN, '--', 'Color', [0 0.5 0], 'LineWidth', 1.5);
        legendHandles = [legendHandles, hResWinDummy];
        legendLabels{end+1} = ['ResWindow = ' sprintf('%.2f', ResWin) ' s'];
    end
    
    % Create legend
    if ~isempty(legendHandles)
        legend(ax3, legendHandles, legendLabels, 'Location', 'north', 'Box', 'off');
    end
    
    % Final position check and fix
    applySubplotPositions(ax1, ax2, ax3);
    ylabel(ax1, 'Trial number');
    xlabel(ax1, 'Time re stim. onset (s)');
    ylabel(ax2, 'Trial number');
    xlabel(ax2, 'Time re stim. onset (s)');
    drawnow;
end

function ResWin = GetResWin(SessionData)
    % Helper function to extract ResWin value from SessionData
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
end

function [tempLeftLicks, tempRightLicks, tempLeftReward, tempRightReward, ...
          isLeftRewardFromPort1, isRightRewardFromPort1, StimOnset, trial_start, trial_end] = ...
    ExtractTrialData(Session_tbl, SessionData, idx)
    % Helper function to extract trial data
    
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
    
    % Convert scalar NaN to empty array
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
    
    % Check if reward was triggered by Port1 click
    isLeftRewardFromPort1 = false;
    isRightRewardFromPort1 = false;
    
    try
        if isfield(SessionData, 'RawEvents') && isfield(SessionData.RawEvents, 'Trial') && ...
           idx <= length(SessionData.RawEvents.Trial) && ...
           isfield(SessionData.RawEvents.Trial{idx}, 'Events')
            
            if isfield(SessionData.RawEvents.Trial{idx}.Events, 'Port1In')
                port1InTimes = SessionData.RawEvents.Trial{idx}.Events.Port1In;
                if ~isempty(port1InTimes)
                    trialStartTime = 0;
                    stimulusStart = NaN;
                    if isfield(SessionData.RawEvents.Trial{idx}, 'States') && ...
                       isfield(SessionData.RawEvents.Trial{idx}.States, 'Stimulus')
                        stimulusStart = SessionData.RawEvents.Trial{idx}.States.Stimulus(1);
                    end
                    
                    if ~isnan(stimulusStart)
                        port1InBeforeOrDuringStimulus = port1InTimes <= stimulusStart;
                    else
                        port1InBeforeOrDuringStimulus = port1InTimes >= trialStartTime & port1InTimes <= 10;
                    end
                    
                    if any(port1InBeforeOrDuringStimulus)
                        if ~isnan(tempLeftReward)
                            try
                                leftRewardAbsTime = Session_tbl.LeftReward(idx,1);
                                if ~isnan(stimulusStart)
                                    timeFromPort1ToReward = leftRewardAbsTime - port1InTimes;
                                    if any(timeFromPort1ToReward > 0 & timeFromPort1ToReward < 2 & port1InBeforeOrDuringStimulus)
                                        isLeftRewardFromPort1 = true;
                                    end
                                else
                                    timeDiff = abs(port1InTimes - leftRewardAbsTime);
                                    if any(timeDiff < 2 & port1InBeforeOrDuringStimulus)
                                        isLeftRewardFromPort1 = true;
                                    end
                                end
                            catch
                            end
                        end
                        
                        if ~isnan(tempRightReward)
                            try
                                rightRewardAbsTime = Session_tbl.RightReward(idx,1);
                                if ~isnan(stimulusStart)
                                    timeFromPort1ToReward = rightRewardAbsTime - port1InTimes;
                                    if any(timeFromPort1ToReward > 0 & timeFromPort1ToReward < 2 & port1InBeforeOrDuringStimulus)
                                        isRightRewardFromPort1 = true;
                                    end
                                else
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
    end
    
    trial_start = 0;
    try
        trial_end = Session_tbl.WaitToFinish(idx,2);
    catch
        trial_end = NaN;
    end
    
    % Get stimulus onset
    try
        if iscell(Session_tbl.Stimulus)
            StimOnset = Session_tbl.Stimulus{idx}(1);
        else
            StimOnset = Session_tbl.Stimulus(idx,1);
        end
    catch
        StimOnset = NaN;
    end
end


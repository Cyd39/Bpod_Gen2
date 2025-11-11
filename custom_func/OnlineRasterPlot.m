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
        
        tempLeftReward = Session_tbl.LeftReward(idx,1);
        tempRightReward = Session_tbl.RightReward(idx,1);
        
        trial_start = 0;
        trial_end = Session_tbl.WaitToFinish(idx,2);
        
        % Align to stimulus onset
        StimOnset = Session_tbl.Stimulus(idx,1);
        tempLeftLicks = tempLeftLicks - StimOnset;
        tempRightLicks = tempRightLicks - StimOnset;
        tempLeftReward = tempLeftReward - StimOnset;
        tempRightReward = tempRightReward - StimOnset;
        trial_start = trial_start - StimOnset;
        t_min = min(t_min, trial_start);
        trial_end = trial_end - StimOnset;
        t_max = max(t_max, trial_end);
        
        % Plot trial duration line
        plot(rasterAx, [trial_start, trial_end], [pos, pos], '-', 'Color', [.7, .7, .7]);
        
        % Plot left licks
        if ~isempty(tempLeftLicks)
            plot(rasterAx, tempLeftLicks, pos.*ones(size(tempLeftLicks)), '.', 'Color', [0.2 0.2 1]);
        end
        
        % Plot right licks
        if ~isempty(tempRightLicks)
            plot(rasterAx, tempRightLicks, pos.*ones(size(tempRightLicks)), '.', 'Color', [1 0.2 0.2]);
        end
        
        % Plot reward markers
        if ~isnan(tempLeftReward)
            plot(rasterAx, tempLeftReward, pos, 's', 'MarkerFaceColor', [0.2 0.2 1], 'Color', [0.2 0.2 1]);
        end
        if ~isnan(tempRightReward)
            plot(rasterAx, tempRightReward, pos, 's', 'MarkerFaceColor', [1 0.2 0.2], 'Color', [1 0.2 0.2]);
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


function PlotBarResponse(SessionData, varargin)
    % PlotBarResponse - Plot bar response from SessionData
    % 
    % This function plots the bar plot of response rate by condition (Left, Right, Catch).
    % Each bar shows the total response rate, with stacked segments indicating
    % the proportion of left-side responses and right-side responses.
    %
    % Inputs:
    %   SessionData - Session data structure
    %   Optional name-value pairs:
    %     'FigureHandle' - figure handle for the plot (optional, for activation in online mode)
    %     'Axes' - axes handle for the plot (optional, if not provided, creates new figure)
    %     'FigureName' - name for new figure if axes not provided (default: 'Response Rate by Condition')
    %
    % Usage:
    %   PlotBarResponse(SessionData);
    %   PlotBarResponse(SessionData, 'FigureHandle', customPlotFig);
    %   PlotBarResponse(SessionData, 'FigureHandle', customPlotFig, 'Axes', customAxes);
    
    % Parse optional inputs
    p = inputParser;
    addParameter(p, 'FigureHandle', [], @(x) isempty(x) || isgraphics(x, 'figure'));
    addParameter(p, 'Axes', [], @(x) isempty(x) || isgraphics(x, 'axes'));
    addParameter(p, 'FigureName', 'Response Rate by Condition', @ischar);
    parse(p, varargin{:});
    
    customPlotFig = p.Results.FigureHandle;
    ax = p.Results.Axes;
    figureName = p.Results.FigureName;
    
    % Activate figure if provided (for online mode)
    if ~isempty(customPlotFig) && isvalid(customPlotFig)
        figure(customPlotFig);
    end
    
    % Create axes if not provided (offline mode)
    if isempty(ax)
        figure('Name', figureName, 'Position', [100 100 1000 600]);
        ax = axes('Position', [0.1 0.15 0.85 0.75]);
    end
    
    % Check if data exists
    if ~isfield(SessionData, 'RawEvents') || ~isfield(SessionData.RawEvents, 'Trial')
        warning('SessionData.RawEvents.Trial not found');
        cla(ax);
        text(ax, 0.5, 0.5, 'No data available', ...
            'HorizontalAlignment', 'center', 'FontSize', 14);
        if ~isempty(customPlotFig)
            drawnow;
        end
        return;
    end
    
    % Get number of trials
    nTrials = length(SessionData.RawEvents.Trial);
    
    % Check if there are any trials
    if nTrials == 0
        warning('No trials found in SessionData');
        cla(ax);
        text(ax, 0.5, 0.5, 'No trials available', ...
            'HorizontalAlignment', 'center', 'FontSize', 14);
        if ~isempty(customPlotFig)
            drawnow;
        end
        return;
    end
    
    % Extract trial information
    isCatchTrial = SessionData.IsCatchTrial(:);
    correctSide = SessionData.CorrectSide(:);
    
    % Define conditions: 1=Left, 2=Right, 3=Catch
    leftTrials = find(correctSide == 1 & ~isCatchTrial);
    rightTrials = find(correctSide == 2 & ~isCatchTrial);
    catchTrials = find(isCatchTrial);
    
    % Initialize counters for each condition
    % For each condition: [total responses, left responses, right responses]
    leftCondition = [0, 0, 0];   % [total, left responses, right responses]
    rightCondition = [0, 0, 0];
    catchCondition = [0, 0, 0];
    
    % Process each trial to determine responses
    for trialNum = 1:nTrials
        if trialNum > length(SessionData.RawEvents.Trial)
            continue;
        end
        
        % Get trial data
        trialData = SessionData.RawEvents.Trial{trialNum};
        
        % Get response window duration for this trial
        if isfield(SessionData, 'ResWin') && length(SessionData.ResWin) >= trialNum
            ResWin = SessionData.ResWin(trialNum);
        else
            ResWin = 1; % Default response window if not available
        end
        
        % Get stimulus start time
        if isfield(trialData, 'States') && isfield(trialData.States, 'Stimulus') && ~isempty(trialData.States.Stimulus)
            stimulusStart = trialData.States.Stimulus(1);
            responseWindowEnd = stimulusStart + ResWin;
        else
            continue; % Skip trials without stimulus state
        end
        
        % Check for left-side lick (BNC1High) in response window
        hasLeftLick = false;
        leftLickTimes = [];
        if isfield(trialData.Events, 'BNC1High') && ~isempty(trialData.Events.BNC1High)
            leftLickTimes = trialData.Events.BNC1High(trialData.Events.BNC1High >= stimulusStart & trialData.Events.BNC1High <= responseWindowEnd);
            hasLeftLick = ~isempty(leftLickTimes);
        end
        
        % Check for right-side lick (BNC2High) in response window
        hasRightLick = false;
        rightLickTimes = [];
        if isfield(trialData.Events, 'BNC2High') && ~isempty(trialData.Events.BNC2High)
            rightLickTimes = trialData.Events.BNC2High(trialData.Events.BNC2High >= stimulusStart & trialData.Events.BNC2High <= responseWindowEnd);
            hasRightLick = ~isempty(rightLickTimes);
        end

        % Initialize first response side
        firstResponseSide = NaN;
        % Determine the first response side if both sides are licked
        if hasLeftLick && hasRightLick
            % Both sides have licks, find which came first
            firstLeftLick = min(leftLickTimes);
            firstRightLick = min(rightLickTimes);
            if firstLeftLick <= firstRightLick
                firstResponseSide = 1;
            else
                firstResponseSide = 2;
            end
        elseif hasLeftLick
            firstResponseSide = 1;
        elseif hasRightLick
            firstResponseSide = 2;
        end
        % If neither side has lick, firstResponseSide remains NaN
        
        % Determine which condition this trial belongs to
        if isCatchTrial(trialNum)
            % Catch trial
            if ~isnan(firstResponseSide)
                catchCondition(1) = catchCondition(1) + 1; % Total responses
                if firstResponseSide == 1
                    catchCondition(2) = catchCondition(2) + 1; % Left responses
                else
                    catchCondition(3) = catchCondition(3) + 1; % Right responses
                end
            end
        elseif correctSide(trialNum) == 1
            % Left condition trial
            if ~isnan(firstResponseSide)
                if firstResponseSide == 1
                    leftCondition(1) = leftCondition(1) + 1; % Total responses
                    leftCondition(2) = leftCondition(2) + 1; % Left responses
                else
                    leftCondition(1) = leftCondition(1) + 1; % Total responses
                    leftCondition(3) = leftCondition(3) + 1; % Right responses
                end
            end
        elseif correctSide(trialNum) == 2
            % Right condition trial
            if ~isnan(firstResponseSide)
                if firstResponseSide == 1
                    rightCondition(1) = rightCondition(1) + 1; % Total responses
                    rightCondition(2) = rightCondition(2) + 1; % Left responses
                else
                    rightCondition(1) = rightCondition(1) + 1; % Total responses
                    rightCondition(3) = rightCondition(3) + 1; % Right responses
                end
            end
        end
    end
    
    % Calculate response rates for each condition
    nLeftTrials = length(leftTrials);
    nRightTrials = length(rightTrials);
    nCatchTrials = length(catchTrials);
    
    % Response rates (proportion of trials with any response)
    if nLeftTrials > 0
        leftResponseRate = leftCondition(1) / nLeftTrials;
    else
        leftResponseRate = 0;
    end
    
    if nRightTrials > 0
        rightResponseRate = rightCondition(1) / nRightTrials;
    else
        rightResponseRate = 0;
    end
    
    if nCatchTrials > 0
        catchResponseRate = catchCondition(1) / nCatchTrials;
    else
        catchResponseRate = 0;
    end
    
    % Calculate proportions of left and right responses within each condition
    % (as proportion of total response rate)
    if leftCondition(1) > 0
        leftLeftProp = (leftCondition(2) / leftCondition(1)) * leftResponseRate;
        leftRightProp = (leftCondition(3) / leftCondition(1)) * leftResponseRate;
    else
        leftLeftProp = 0;
        leftRightProp = 0;
    end
    
    if rightCondition(1) > 0
        rightLeftProp = (rightCondition(2) / rightCondition(1)) * rightResponseRate;
        rightRightProp = (rightCondition(3) / rightCondition(1)) * rightResponseRate;
    else
        rightLeftProp = 0;
        rightRightProp = 0;
    end
    
    if catchCondition(1) > 0
        catchLeftProp = (catchCondition(2) / catchCondition(1)) * catchResponseRate;
        catchRightProp = (catchCondition(3) / catchCondition(1)) * catchResponseRate;
    else
        catchLeftProp = 0;
        catchRightProp = 0;
    end
    
    % Prepare data for stacked bar plot
    % Each row represents a condition, columns are: [left responses, right responses]
    barData = [leftLeftProp, leftRightProp; ...
               rightLeftProp, rightRightProp; ...
               catchLeftProp, catchRightProp];
    
    % Plot stacked bar chart
    axes(ax);
    cla(ax);
    hold(ax, 'on');
    
    % Create bar plot with stacked segments
    b = bar(ax, barData, 'stacked');
    
    % Set colors: blue for left responses, red for right responses
    b(1).FaceColor = [0.2 0.4 0.8]; % Blue for left responses
    b(2).FaceColor = [0.8 0.2 0.2]; % Red for right responses
    
    % Set x-axis labels
    ax.XTick = 1:3; % Set tick positions
    ax.XTickLabel = {'Left', 'Right', 'Catch'}; % Set tick labels
    xlabel(ax, 'Stimulus Condition', 'FontSize', 12);
    ylabel(ax, 'Response Rate', 'FontSize', 12);
    title(ax, 'Response Rate by Condition', 'FontSize', 12);
    
    % Set y-axis limits
    ylim(ax, [0 1]);
    
    % Add legend
    legend(ax, {'Left Response', 'Right Response'}, 'Location', 'northeast', 'FontSize', 10);
    
    % Add grid
    grid(ax, 'on');
    
    hold(ax, 'off');
    
    % Force update of the figure (for online mode)
    if ~isempty(customPlotFig)
        drawnow;
    end
end
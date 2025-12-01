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
    
    % Get vibration frequencies from StimTable
    vibFreqs = SessionData.StimTable.VibFreq(:);
    % Get unique vibration frequencies (excluding catch trials if needed)
    uniqueVibFreqs = unique(vibFreqs(~isCatchTrial));
    uniqueVibFreqs = uniqueVibFreqs(~isnan(uniqueVibFreqs)); % Remove NaN values
    uniqueVibFreqs = sort(uniqueVibFreqs); % Sort for consistent ordering
    
    % Initialize counters for each condition
    % For each condition: [total responses, left responses, right responses]
    % Create condition structure for each unique VibFreq
    nConditions = length(uniqueVibFreqs);
    conditions = struct();
    for i = 1:nConditions
        freq = uniqueVibFreqs(i);
        conditions.(['freq_' num2str(freq)]) = [0, 0, 0]; % [total, left responses, right responses]
    end
    % Add catch condition
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
        % Skip if no response
        if isnan(firstResponseSide)
            continue;
        end
        
        if isCatchTrial(trialNum)
            % Catch trial
            catchCondition(1) = catchCondition(1) + 1; % Total responses
            if firstResponseSide == 1
                catchCondition(2) = catchCondition(2) + 1; % Left responses
            else
                catchCondition(3) = catchCondition(3) + 1; % Right responses
            end
        else
            % Classify by VibFreq
            currentVibFreq = vibFreqs(trialNum);
            if isnan(currentVibFreq)
                continue;
            end
            
            freqKey = ['freq_' num2str(currentVibFreq)];
            if ~isfield(conditions, freqKey)
                continue;
            end
            
            conditions.(freqKey)(1) = conditions.(freqKey)(1) + 1; % Total responses
            if firstResponseSide == 1
                conditions.(freqKey)(2) = conditions.(freqKey)(2) + 1; % Left responses
            else
                conditions.(freqKey)(3) = conditions.(freqKey)(3) + 1; % Right responses
            end
        end
    end
    
    % Calculate response rates for each condition
    % Count trials for each frequency condition
    nTrialsPerFreq = zeros(1, nConditions);
    for i = 1:nConditions
        freq = uniqueVibFreqs(i);
        nTrialsPerFreq(i) = sum(vibFreqs == freq & ~isCatchTrial);
    end
    
    % Calculate response rates and proportions for each frequency
    responseRates = zeros(1, nConditions);
    leftProps = zeros(1, nConditions);
    rightProps = zeros(1, nConditions);
    
    for i = 1:nConditions
        freq = uniqueVibFreqs(i);
        freqKey = ['freq_' num2str(freq)];
        conditionData = conditions.(freqKey);
        
        if nTrialsPerFreq(i) > 0
            responseRates(i) = conditionData(1) / nTrialsPerFreq(i);
            if conditionData(1) > 0
                leftProps(i) = (conditionData(2) / conditionData(1)) * responseRates(i);
                rightProps(i) = (conditionData(3) / conditionData(1)) * responseRates(i);
            end
        end
    end
    
    % Calculate catch trial response rate
    catchTrials = find(isCatchTrial);
    nCatchTrials = length(catchTrials);
    if nCatchTrials > 0
        catchResponseRate = catchCondition(1) / nCatchTrials;
        if catchCondition(1) > 0
            catchLeftProp = (catchCondition(2) / catchCondition(1)) * catchResponseRate;
            catchRightProp = (catchCondition(3) / catchCondition(1)) * catchResponseRate;
        else
            catchLeftProp = 0;
            catchRightProp = 0;
        end
    else
        catchLeftProp = 0;
        catchRightProp = 0;
    end
        
    % Prepare data for stacked bar plot
    % Each row represents a condition, columns are: [left responses, right responses]
    barData = [leftProps', rightProps'];
    if nCatchTrials > 0
        barData = [barData; catchLeftProp, catchRightProp];
    end
    
    % Prepare labels for x-axis
    xLabels = cell(1, nConditions);
    for i = 1:nConditions
        xLabels{i} = [num2str(uniqueVibFreqs(i)) ' Hz'];
    end
    if nCatchTrials > 0
        xLabels{end+1} = 'Catch';
    end
    
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
    nBars = size(barData, 1);
    ax.XTick = 1:nBars; % Set tick positions
    ax.XTickLabel = xLabels; % Set tick labels
    xlabel(ax, 'Stimulus Condition');
    ylabel(ax, 'Response Rate');
    title(ax, 'Response Rate by Condition');
    
    % Set y-axis limits
    ylim(ax, [0 1]);
    
    % Add legend
    legend(ax, {'Left', 'Right'}, 'Location', 'northeast');
    
    % Add grid
    grid(ax, 'on');
    
    hold(ax, 'off');
    
    % Force update of the figure (for online mode)
    if ~isempty(customPlotFig)
        drawnow;
    end
end
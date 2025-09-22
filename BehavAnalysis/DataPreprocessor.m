% data preprocessor for Bpod experimental data
classdef DataPreprocessor < handle
    properties
        Config
        StimulusColumn
        ResponseWindowColumn
    end
    
    methods
        function obj = DataPreprocessor(config)
            obj.Config = config;
            obj.StimulusColumn = 'Stimulus';
            obj.ResponseWindowColumn = 'ResWin';
        end
        
        function processedData = processSessionData(obj, data)
            % Process entire session data
            SessionData = data.SessionData;
            Session_tbl = data.Session_tbl;
            
            % Align timing to stimulus onset
            processedData = obj.alignToStimulus(SessionData, Session_tbl);
            
            % Calculate first lick after stimulus
            processedData = obj.calculateFirstLick(processedData);
            
            % Calculate hit rates
            processedData = obj.calculateHitRates(processedData);
            
            % Calculate latencies
            processedData = obj.calculateLatencies(processedData);
        end
        
        function processedData = processTrialData(obj, ~)
            % Process single trial data (for real-time analysis)
            % This is a simplified version for real-time processing
            processedData = struct(); % Placeholder for real-time processing
        end
        
        function processedData = alignToStimulus(obj, SessionData, Session_tbl)
            % Align timing to stimulus onset (similar to DataAnalysis/MainAnalysis.m)
            n_stim = height(Session_tbl);
            
            % Initialize aligned timing columns
            Session_tbl.LickOnAfterStim = cell(n_stim, 1);
            Session_tbl.LickOffAfterStim = cell(n_stim, 1);
            
            % Align timing to stimulus onset
            for ii = 1:height(Session_tbl)
                try
                    % Check if Stimulus column exists in the table
                    if ismember(obj.StimulusColumn, Session_tbl.Properties.VariableNames)
                        % Access stimulus data from table
                        stimulus_data = Session_tbl.(obj.StimulusColumn)(ii);
                        
                        % Check if stimulus data is valid
                        if ~isempty(stimulus_data) && ~all(isnan(stimulus_data))
                            % Get stimulus onset time
                            if iscell(stimulus_data)
                                stimulus_time = stimulus_data{1}(1);
                            else
                                stimulus_time = stimulus_data(1);
                            end
                            
                            % Align lick times to stimulus onset
                            if ~isempty(Session_tbl.LickOn{ii}) && ~all(isnan(Session_tbl.LickOn{ii}))
                                Session_tbl.LickOnAfterStim{ii} = Session_tbl.LickOn{ii} - stimulus_time;
                            else
                                Session_tbl.LickOnAfterStim{ii} = NaN;
                            end
                            
                            if ~isempty(Session_tbl.LickOff{ii}) && ~all(isnan(Session_tbl.LickOff{ii}))
                                Session_tbl.LickOffAfterStim{ii} = Session_tbl.LickOff{ii} - stimulus_time;
                            else
                                Session_tbl.LickOffAfterStim{ii} = NaN;
                            end
                        else
                            Session_tbl.LickOnAfterStim{ii} = NaN;
                            Session_tbl.LickOffAfterStim{ii} = NaN;
                        end
                    else
                        % Try to get stimulus timing from SessionData.RawEvents.Trial
                        if ii <= length(SessionData.RawEvents.Trial)
                            trial_data = SessionData.RawEvents.Trial{ii};
                            if isfield(trial_data, 'States') && isfield(trial_data.States, 'Stimulus')
                                stimulus_time = trial_data.States.Stimulus(1);
                                
                                % Align lick times to stimulus onset
                                if ~isempty(Session_tbl.LickOn{ii}) && ~all(isnan(Session_tbl.LickOn{ii}))
                                    Session_tbl.LickOnAfterStim{ii} = Session_tbl.LickOn{ii} - stimulus_time;
                                else
                                    Session_tbl.LickOnAfterStim{ii} = NaN;
                                end
                                
                                if ~isempty(Session_tbl.LickOff{ii}) && ~all(isnan(Session_tbl.LickOff{ii}))
                                    Session_tbl.LickOffAfterStim{ii} = Session_tbl.LickOff{ii} - stimulus_time;
                                else
                                    Session_tbl.LickOffAfterStim{ii} = NaN;
                                end
                            else
                                Session_tbl.LickOnAfterStim{ii} = NaN;
                                Session_tbl.LickOffAfterStim{ii} = NaN;
                            end
                        else
                            Session_tbl.LickOnAfterStim{ii} = NaN;
                            Session_tbl.LickOffAfterStim{ii} = NaN;
                        end
                    end
                catch ME
                    % If stimulus data access fails, use NaN
                    fprintf('Warning: Failed to process trial %d: %s\n', ii, ME.message);
                    Session_tbl.LickOnAfterStim{ii} = NaN;
                    Session_tbl.LickOffAfterStim{ii} = NaN;
                end
            end
            
            % Create processed data structure
            % Convert table to struct for easier handling
            processedData = table2struct(Session_tbl, 'ToScalar', true);
            processedData.SessionData = SessionData;
        end
        
        function processedData = calculateFirstLick(obj, processedData)
            % Calculate first lick after stimulus onset
            n_trials = length(processedData.LickOnAfterStim);
            FirstLickAfterStim = cell(n_trials, 1);
            
            for i = 1:n_trials
                lick_times = processedData.LickOnAfterStim{i};
                if ~isempty(lick_times) && ~all(isnan(lick_times))
                    % Find first positive lick time (after stimulus onset)
                    valid_licks = lick_times(lick_times > 0);
                    if ~isempty(valid_licks)
                        FirstLickAfterStim{i} = min(valid_licks);
                    else
                        FirstLickAfterStim{i} = NaN;
                    end
                else
                    FirstLickAfterStim{i} = NaN;
                end
            end
            
            processedData.FirstLickAfterStim = FirstLickAfterStim;
        end
        
        function processedData = calculateHitRates(obj, processedData)
            % Calculate hit rates for each trial
            SessionData = processedData.SessionData;
            n_trials = length(processedData.FirstLickAfterStim);
            
            % Initialize Hit column
            processedData.Hit = zeros(n_trials, 1);
            
            for t = 1:n_trials
                % Get trial parameters
                if isfield(SessionData.TrialSettings(t).GUI, obj.ResponseWindowColumn)
                    ResWin = SessionData.TrialSettings(t).GUI.(obj.ResponseWindowColumn);
                else
                    ResWin = 2.0; % Default response window
                end
                
                LickOn_t = processedData.FirstLickAfterStim{t};
                
                % Check if FirstLickAfterStim is within the time window and not NaN
                if ~isempty(LickOn_t) && ~all(isnan(LickOn_t))
                    % Check if any valid lick is within the response window
                    licksInWindow = LickOn_t >= 0 & LickOn_t <= ResWin;
                    
                    if any(licksInWindow)
                        processedData.Hit(t) = 1;
                    else
                        processedData.Hit(t) = 0;
                    end
                end
            end
        end
        
        function processedData = calculateLatencies(obj, processedData)
            % Calculate response latencies for hit trials
            hitTrials = processedData.Hit == 1;
            n_trials = length(processedData.FirstLickAfterStim);
            latencies = cell(n_trials, 1);
            
            for t = 1:n_trials
                if hitTrials(t)
                    firstLickTime = processedData.FirstLickAfterStim{t};
                    if ~isempty(firstLickTime) && ~isnan(firstLickTime)
                        latencies{t} = firstLickTime;
                    else
                        latencies{t} = NaN;
                    end
                else
                    latencies{t} = NaN;
                end
            end
            
            processedData.Latency = latencies;
        end
        
        function processedData = extractStimulusParameters(obj, processedData)
            % Extract stimulus parameters for analysis
            if isfield(processedData, 'AudIntensity')
                processedData.Intensity = processedData.AudIntensity;
            elseif isfield(processedData, 'Intensity')
                % Already exists
            else
                % Try to extract from StimTable
                if isfield(processedData, 'StimTable')
                    stimTable = processedData.StimTable;
                    if isfield(stimTable, 'Intensity')
                        processedData.Intensity = stimTable.Intensity;
                    end
                end
            end
        end
        
        function validateData(obj, processedData)
            % Validate processed data
            if ~isfield(processedData, 'LickOnAfterStim')
                error('Missing LickOnAfterStim data');
            end
            
            if ~isfield(processedData, 'Hit')
                error('Missing Hit data');
            end
            
            if ~isfield(processedData, 'FirstLickAfterStim')
                error('Missing FirstLickAfterStim data');
            end
        end
    end
end

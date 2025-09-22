% configuration manager
classdef AnalysisConfig < handle
    properties
        % data related configuration
        SamplingRate
        FileFormats
        DataColumns
        StimulusColumn
        ResponseWindowColumn
        IntensityColumn
        DefaultDataPath
        LickEvents
        
        % experiment settings
        ExperimentSettings
        
        % analysis related configuration
        AnalysisSettings
        
        % visualization settings
        VisualizationSettings
        
        % output configuration
        OutputSettings
        
        % psychophysics settings
        PsychophysicsSettings
    end
    
    methods
        function obj = AnalysisConfig(configPath)
            if nargin > 0
                obj.loadFromFile(configPath);
            else
                obj.setDefaultConfig();
            end
        end
        
        function loadFromFile(obj, configPath)
            % load configuration from JSON or MAT file
            if endsWith(configPath, '.json')
                configData = jsondecode(fileread(configPath));
            else
                configData = load(configPath);
            end
            obj.updateFromStruct(configData);
        end
        
        function updateFromStruct(obj, configData)
            % Update configuration from struct data
            if isfield(configData, 'data_settings')
                dataSettings = configData.data_settings;
                obj.SamplingRate = dataSettings.sampling_rate;
                obj.FileFormats = dataSettings.file_format;
                obj.DataColumns = dataSettings.data_columns;
                obj.StimulusColumn = dataSettings.stimulus_column;
                obj.ResponseWindowColumn = dataSettings.response_window_column;
                obj.IntensityColumn = dataSettings.intensity_column;
                obj.DefaultDataPath = dataSettings.default_data_path;
                if isfield(dataSettings, 'lick_events')
                    obj.LickEvents = dataSettings.lick_events;
                end
            end
            
            if isfield(configData, 'experiment_settings')
                obj.ExperimentSettings = configData.experiment_settings;
            end
            
            if isfield(configData, 'analysis_settings')
                obj.AnalysisSettings = configData.analysis_settings;
            end
            
            if isfield(configData, 'visualization_settings')
                obj.VisualizationSettings = configData.visualization_settings;
            end
            
            if isfield(configData, 'output_settings')
                obj.OutputSettings = configData.output_settings;
            end
            
            if isfield(configData, 'psychophysics_settings')
                obj.PsychophysicsSettings = configData.psychophysics_settings;
            end
        end
        
        function setDefaultConfig(obj)
            % set default configuration
            obj.SamplingRate = 1000;
            obj.FileFormats = 'mat';
            obj.DataColumns = {'trial_num', 'response', 'rt', 'correct'};
            obj.StimulusColumn = 'Stimulus';
            obj.ResponseWindowColumn = 'ResWin';
            obj.IntensityColumn = 'AudIntensity';
            obj.DefaultDataPath = 'G:\Data\OperantConditioning\Yudi';
            
            % Default lick events
            obj.LickEvents = struct();
            obj.LickEvents.lick_on_event = 'BNC1High';
            obj.LickEvents.lick_off_event = 'BNC1Low';
            obj.LickEvents.lick_on_label = 'LickOn';
            obj.LickEvents.lick_off_label = 'LickOff';
            
            % Default analysis settings
            obj.AnalysisSettings = struct();
            obj.AnalysisSettings.realTime = struct('enabled', true, 'analysis_types', {'hit_rate', 'latency'});
            obj.AnalysisSettings.postHoc = struct('enabled', true, 'analysis_types', {'hit_rate', 'latency'});
            
            % Default output settings
            obj.OutputSettings = struct();
            obj.OutputSettings.save_format = 'mat';
            obj.OutputSettings.figure_format = 'png';
            obj.OutputSettings.auto_generate_report = true;
        end
    end
end
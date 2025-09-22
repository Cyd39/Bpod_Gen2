% configuration manager
classdef AnalysisConfig < handle
    properties
        % data related configuration
        DataPaths
        FileFormats
        SamplingRate
        TrialParameters
        
        % analysis related configuration
        AnalysisTypes
        RealTimeSettings
        PostHocSettings
        
        % output configuration
        OutputPaths
        SaveFormats
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
        
        function setDefaultConfig(obj)
            % set default configuration
            obj.SamplingRate = 1000;
            obj.AnalysisTypes = {'performance', 'reaction_time', 'psychometric'};
            % ... other default configurations
        end
    end
end
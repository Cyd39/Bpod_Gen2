% data loader
classdef DataLoader < handle
    properties
        Config
        SupportedFormats
    end
    
    methods
        function obj = DataLoader(config)
            obj.Config = config;
            obj.SupportedFormats = {'.mat', '.csv', '.json', '.tdms'};
        end
        
        function data = loadSessionData(obj, sessionPath)
            % load entire experimental session data
            dataFiles = obj.findDataFiles(sessionPath);
            data = struct();
            
            for i = 1:length(dataFiles)
                fileData = obj.loadSingleFile(dataFiles{i});
                data = obj.mergeData(data, fileData);
            end
        end
        
        function trialData = loadTrialData(obj, trialPath)
            % load single trial data (for real-time analysis)
            trialData = obj.loadSingleFile(trialPath);
        end
    end
end
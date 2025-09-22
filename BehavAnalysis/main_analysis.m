% main analysis script - equivalent to DataAnalysis/MainAnalysis.m
function main_analysis(analysisType, dataPath, configPath)
    % Main analysis script for behavior analysis
    % Usage:
    %   main_analysis() - Run complete analysis with GUI data selection (default)
    %   main_analysis('complete') - Run complete analysis with GUI data selection
    %   main_analysis('complete', dataPath) - Run complete analysis on specific data
    %   main_analysis('post_hoc', dataPath, configPath) - Run post-hoc analysis
    
    % Set default analysis type if not provided
    if nargin < 1 || isempty(analysisType)
        analysisType = 'complete';
    end
    
    % Set default data path if not provided
    if nargin < 2
        dataPath = [];
    end
    
    % Set default config path if not provided
    if nargin < 3 || isempty(configPath)
        configPath = fullfile(fileparts(mfilename('fullpath')), 'config.json');
    end
    
    % Initialize analysis manager
    analysisManager = BehaviorAnalysisManager(configPath);
    
    switch lower(analysisType)
        case 'complete'
            % Complete analysis (equivalent to DataAnalysis/MainAnalysis.m)
            if nargin < 2 || isempty(dataPath)
                % Use GUI data selection
                analysisManager.runCompleteAnalysis();
            else
                % Use specified data path
                analysisManager.runCompleteAnalysis(dataPath);
            end
            
        case 'post_hoc'
            % Post-analysis mode
            if nargin < 2 || isempty(dataPath)
                analysisManager.runPostAnalysis();
            else
                analysisManager.runPostAnalysis(dataPath);
            end
            
        case 'real_time'
            % Real-time analysis mode
            runRealTimeAnalysis(analysisManager, dataPath);
            
        case 'batch'
            % Batch analysis multiple sessions
            runBatchAnalysis(analysisManager, dataPath);
            
        otherwise
            error('Unknown analysis type: %s. Use: complete, post_hoc, real_time, or batch', analysisType);
    end
end

function runRealTimeAnalysis(analysisManager, dataPath)
    % Simulate real-time data stream
    fprintf('Starting real-time analysis...\n');
    
    % This would be implemented for real-time monitoring during experiments
    % For now, just demonstrate the interface
    if isempty(dataPath)
        fprintf('Real-time analysis requires a data path\n');
        return;
    end
    
    % Simulate trial data processing
    trialCount = 0;
    maxTrials = 10; % Simulate 10 trials
    
    while trialCount < maxTrials
        % Simulate getting new trial data
        trialData = simulateTrialData(trialCount + 1);
        
        % Run real-time analysis
        analysisManager.runRealTimeAnalysis(trialData);
        
        trialCount = trialCount + 1;
        pause(0.5); % Simulate time between trials
    end
    
    fprintf('Real-time analysis completed (%d trials processed)\n', trialCount);
end

function runBatchAnalysis(analysisManager, dataPath)
    % Batch analysis multiple sessions
    fprintf('Starting batch analysis...\n');
    
    if isempty(dataPath)
        % Use default data path
        dataPath = analysisManager.DataLoader.DefaultDataPath;
    end
    
    % Find all data files
    if exist(dataPath, 'dir')
        files = dir(fullfile(dataPath, '*.mat'));
        fileNames = {files.name};
        
        fprintf('Found %d data files for batch analysis\n', length(fileNames));
        
        % Process each file
        for i = 1:length(fileNames)
            filePath = fullfile(dataPath, fileNames{i});
            fprintf('Processing file %d/%d: %s\n', i, length(fileNames), fileNames{i});
            
            try
                analysisManager.runCompleteAnalysis(filePath);
                fprintf('Successfully processed: %s\n', fileNames{i});
            catch ME
                fprintf('Error processing %s: %s\n', fileNames{i}, ME.message);
            end
        end
        
        fprintf('Batch analysis completed\n');
    else
        fprintf('Data path not found: %s\n', dataPath);
    end
end

function trialData = simulateTrialData(trialNumber)
    % Simulate trial data for real-time analysis
    trialData = struct();
    trialData.trialNumber = trialNumber;
    trialData.timestamp = now;
    trialData.hit = rand > 0.5; % Random hit/miss
    trialData.latency = rand * 2; % Random latency 0-2s
    trialData.intensity = randi([1, 10]); % Random intensity 1-10
end

% Convenience function for easy access
function runCompleteAnalysis(dataPath)
    % Convenience function to run complete analysis
    % Usage: runCompleteAnalysis() or runCompleteAnalysis(dataPath)
    if nargin < 1
        dataPath = [];
    end
    main_analysis('complete', dataPath);
end
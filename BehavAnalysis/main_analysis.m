% main analysis script
function main_analysis(analysisType, dataPath, configPath)
    % initialize analysis manager
    analysisManager = BehaviorAnalysisManager(configPath);
    
    switch analysisType
        case 'real_time'
            % real-time analysis mode
            runRealTimeAnalysis(analysisManager, dataPath);
            
        case 'post_hoc'
            % post-analysis mode
            runPostHocAnalysis(analysisManager, dataPath);
            
        case 'batch'
            % batch analysis multiple sessions
            runBatchAnalysis(analysisManager, dataPath);
    end
end

function runRealTimeAnalysis(analysisManager, dataPath)
    % simulate real-time data stream
    while hasNewData(dataPath)
        trialData = getLatestTrialData(dataPath);
        analysisManager.runRealTimeAnalysis(trialData);
        pause(0.1); % control analysis frequency
    end
end

function runPostHocAnalysis(analysisManager, sessionPath)
    results = analysisManager.runPostAnalysis(sessionPath);
    generateReport(results);
end
% Simple test script to verify the system works
function test_simple()
    fprintf('Testing BehaviorAnalysis system...\n');
    fprintf('==================================\n\n');
    
    try
        % Initialize analysis manager
        configPath = fullfile(fileparts(mfilename('fullpath')), 'config.json');
        analysisManager = BehaviorAnalysisManager(configPath);
        
        % Load data
        fprintf('Loading data...\n');
        [SessionData, Session_tbl, filePath] = analysisManager.DataLoader.loadSessionData();
        fprintf('✓ Data loaded from: %s\n', filePath);
        
        % Process data
        fprintf('Processing data...\n');
        data = struct('SessionData', SessionData, 'Session_tbl', Session_tbl, 'filePath', filePath);
        processedData = analysisManager.Preprocessor.processSessionData(data);
        fprintf('✓ Data processed successfully\n');
        
        % Check key fields
        fprintf('\nChecking processed data:\n');
        fprintf('- LickOnAfterStim: %d trials\n', length(processedData.LickOnAfterStim));
        fprintf('- Hit: %d trials\n', length(processedData.Hit));
        fprintf('- AudIntensity: %d trials\n', length(processedData.AudIntensity));
        
        % Count valid data
        validLickTrials = 0;
        for i = 1:length(processedData.LickOnAfterStim)
            if ~isempty(processedData.LickOnAfterStim{i}) && ~all(isnan(processedData.LickOnAfterStim{i}))
                validLickTrials = validLickTrials + 1;
            end
        end
        fprintf('- Valid lick trials: %d/%d\n', validLickTrials, length(processedData.LickOnAfterStim));
        
        hitTrials = sum(processedData.Hit == 1);
        fprintf('- Hit trials: %d/%d (%.1f%%)\n', hitTrials, length(processedData.Hit), hitTrials/length(processedData.Hit)*100);
        
        % Test visualization
        fprintf('\nTesting visualization...\n');
        try
            % Create a simple histogram
            analysisManager.Visualizers.raster.createHistogramPlot(processedData, 'Title', 'Test Histogram');
            fprintf('✓ Histogram created successfully\n');
        catch ME
            fprintf('❌ Histogram failed: %s\n', ME.message);
        end
        
        try
            % Create raster plot
            analysisManager.Visualizers.raster.createRasterPlot(processedData, 'Title', 'Test Raster');
            fprintf('✓ Raster plot created successfully\n');
        catch ME
            fprintf('❌ Raster plot failed: %s\n', ME.message);
        end
        
        fprintf('\n✓ Test completed successfully!\n');
        
    catch ME
        fprintf('\n❌ Test failed with error:\n');
        fprintf('Error: %s\n', ME.message);
        fprintf('Location: %s (line %d)\n', ME.stack(1).file, ME.stack(1).line);
    end
end

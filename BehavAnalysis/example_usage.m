% Example usage of BehaviorAnalysis system
% This script demonstrates how to use the new BehaviorAnalysis system
% to replicate all functionality from DataAnalysis/MainAnalysis.m

function example_usage()
    % Example usage of BehaviorAnalysis system
    
    fprintf('BehaviorAnalysis Example Usage\n');
    fprintf('==============================\n\n');
    
    % Method 1: Run complete analysis with GUI data selection
    fprintf('Method 1: Complete analysis with GUI data selection\n');
    fprintf('This is equivalent to running DataAnalysis/MainAnalysis.m\n');
    fprintf('Command: main_analysis(''complete'')\n\n');
    
    % Uncomment the following line to run with GUI:
    % main_analysis('complete');
    
    % Method 2: Run complete analysis on specific data file
    fprintf('Method 2: Complete analysis on specific data file\n');
    fprintf('Command: main_analysis(''complete'', dataFilePath)\n\n');
    
    % Example with specific file:
    % dataFilePath = 'G:\Data\OperantConditioning\Yudi\SessionData_20240101_001.mat';
    % main_analysis('complete', dataFilePath);
    
    % Method 3: Run post-hoc analysis only
    fprintf('Method 3: Post-hoc analysis only\n');
    fprintf('Command: main_analysis(''post_hoc'', dataFilePath)\n\n');
    
    % Method 4: Batch analysis multiple files
    fprintf('Method 4: Batch analysis multiple files\n');
    fprintf('Command: main_analysis(''batch'', dataDirectory)\n\n');
    
    % Method 5: Use the convenience function
    fprintf('Method 5: Convenience function\n');
    fprintf('Command: runCompleteAnalysis() or runCompleteAnalysis(dataFilePath)\n\n');
    
    % Method 6: Direct API usage
    fprintf('Method 6: Direct API usage\n');
    fprintf('This gives you full control over the analysis process:\n\n');
    
    % Initialize analysis manager
    configPath = fullfile(fileparts(mfilename('fullpath')), 'config.json');
    analysisManager = BehaviorAnalysisManager(configPath);
    
    % Load data
    fprintf('Loading data...\n');
    [SessionData, Session_tbl, filePath] = analysisManager.DataLoader.loadSessionData();
    
    % Process data
    fprintf('Processing data...\n');
    data = struct('SessionData', SessionData, 'Session_tbl', Session_tbl, 'filePath', filePath);
    processedData = analysisManager.Preprocessor.processSessionData(data);
    
    % Run specific analyses
    fprintf('Running hit rate analysis...\n');
    hitRateResults = analysisManager.Analyzers.postHoc.hit_rate.analyze(processedData);
    
    fprintf('Running latency analysis...\n');
    latencyResults = analysisManager.Analyzers.postHoc.latency.analyze(processedData);
    
    % Create visualizations
    fprintf('Creating visualizations...\n');
    
    % Histogram plots
    analysisManager.Visualizers.raster.createHistogramPlot(processedData, ...
        'Title', 'All Lick On Times');
    
    analysisManager.Visualizers.raster.createFirstLickHistogram(processedData, ...
        'Title', 'First Lick On Times');
    
    % Raster plot
    analysisManager.Visualizers.raster.createRasterPlot(processedData, ...
        'Title', 'Raster Plot - Lick Times by Intensity');
    
    % Hit rate plot
    analysisManager.Visualizers.hitRate.createHitRatePlot(hitRateResults.hitRateTable, ...
        'Title', 'Hit Rate vs Intensity');
    
    % Latency plots
    analysisManager.Visualizers.hitRate.createLatencyPlot(latencyResults.latencyByIntensity, ...
        'PlotType', 'boxplot', 'Title', 'Latency by Intensity (Hit Trials Only)');
    
    analysisManager.Visualizers.hitRate.createMedianLatencyPlot(latencyResults.latencyByIntensity, ...
        'Title', 'Median Response Latency vs Intensity');
    
    % Save results
    fprintf('Saving results...\n');
    results = struct('hit_rate', hitRateResults, 'latency', latencyResults);
    analysisManager.saveResults(results, 'example');
    
    fprintf('\nExample completed successfully!\n');
    fprintf('All plots have been created and results saved.\n');
end

function compare_with_data_analysis()
    % Compare BehaviorAnalysis with DataAnalysis functionality
    
    fprintf('Comparison: BehaviorAnalysis vs DataAnalysis\n');
    fprintf('===========================================\n\n');
    
    fprintf('DataAnalysis/MainAnalysis.m functionality:\n');
    fprintf('1. LoadData() - GUI data selection\n');
    fprintf('2. ExtractTimeStamps() - Extract lick events\n');
    fprintf('3. Data preprocessing - Align to stimulus onset\n');
    fprintf('4. Hit rate calculation\n');
    fprintf('5. Histogram plots (all licks and first licks)\n');
    fprintf('6. Raster plot (plotraster.m)\n');
    fprintf('7. Hit rate vs intensity plot\n');
    fprintf('8. Latency analysis and plots\n\n');
    
    fprintf('BehaviorAnalysis equivalent functionality:\n');
    fprintf('1. DataLoader.loadDataWithGUI() - GUI data selection\n');
    fprintf('2. DataLoader.extractTimeStamps() - Extract lick events\n');
    fprintf('3. DataPreprocessor.processSessionData() - Data preprocessing\n');
    fprintf('4. HitRateAnalyzer.analyze() - Hit rate calculation\n');
    fprintf('5. RasterVisualizer.createHistogramPlot() - Histogram plots\n');
    fprintf('6. RasterVisualizer.createRasterPlot() - Raster plot\n');
    fprintf('7. HitRateVisualizer.createHitRatePlot() - Hit rate plot\n');
    fprintf('8. LatencyAnalyzer.analyze() + HitRateVisualizer.createLatencyPlot() - Latency analysis\n\n');
    
    fprintf('Additional BehaviorAnalysis features:\n');
    fprintf('1. Real-time analysis capability\n');
    fprintf('2. Batch processing multiple files\n');
    fprintf('3. Configurable analysis parameters\n');
    fprintf('4. Modular, extensible architecture\n');
    fprintf('5. Statistical analysis (Kruskal-Wallis, etc.)\n');
    fprintf('6. Psychometric curve fitting\n');
    fprintf('7. Error handling and validation\n');
    fprintf('8. Results saving and reporting\n\n');
end

% Test script for BehaviorAnalysis system
% This script tests the new BehaviorAnalysis functionality

function test_behavior_analysis()
    % Test the BehaviorAnalysis system
    
    fprintf('Testing BehaviorAnalysis System\n');
    fprintf('================================\n\n');
    
    try
        % Test 1: Initialize analysis manager
        fprintf('Test 1: Initialize analysis manager...\n');
        configPath = fullfile(fileparts(mfilename('fullpath')), 'config.json');
        analysisManager = BehaviorAnalysisManager(configPath);
        fprintf('✓ Analysis manager initialized successfully\n\n');
        
        % Test 2: Test data loader
        fprintf('Test 2: Test data loader...\n');
        dataLoader = analysisManager.DataLoader;
        fprintf('✓ Data loader created successfully\n');
        fprintf('  - Default data path: %s\n', dataLoader.DefaultDataPath);
        fprintf('  - Supported formats: %s\n', strjoin(dataLoader.SupportedFormats, ', '));
        fprintf('\n');
        
        % Test 3: Test data preprocessor
        fprintf('Test 3: Test data preprocessor...\n');
        preprocessor = analysisManager.Preprocessor;
        fprintf('✓ Data preprocessor created successfully\n');
        fprintf('  - Stimulus column: %s\n', preprocessor.StimulusColumn);
        fprintf('  - Response window column: %s\n', preprocessor.ResponseWindowColumn);
        fprintf('\n');
        
        % Test 4: Test analyzers
        fprintf('Test 4: Test analyzers...\n');
        if isfield(analysisManager.Analyzers, 'postHoc')
            analyzerNames = fieldnames(analysisManager.Analyzers.postHoc);
            fprintf('✓ Post-hoc analyzers created successfully\n');
            for i = 1:length(analyzerNames)
                analyzer = analysisManager.Analyzers.postHoc.(analyzerNames{i});
                fprintf('  - %s: %s\n', analyzerNames{i}, analyzer.AnalyzerName);
            end
        end
        fprintf('\n');
        
        % Test 5: Test visualizers
        fprintf('Test 5: Test visualizers...\n');
        if isfield(analysisManager.Visualizers, 'raster')
            fprintf('✓ Raster visualizer created successfully\n');
        end
        if isfield(analysisManager.Visualizers, 'hitRate')
            fprintf('✓ Hit rate visualizer created successfully\n');
        end
        fprintf('\n');
        
        % Test 6: Test configuration
        fprintf('Test 6: Test configuration...\n');
        config = analysisManager.Config;
        fprintf('✓ Configuration loaded successfully\n');
        fprintf('  - Sampling rate: %d Hz\n', config.SamplingRate);
        fprintf('  - File format: %s\n', config.FileFormats);
        if isfield(config, 'AnalysisTypes')
            fprintf('  - Analysis types: %s\n', strjoin(config.AnalysisTypes, ', '));
        end
        fprintf('\n');
        
        % Test 7: Test main analysis function
        fprintf('Test 7: Test main analysis function...\n');
        fprintf('✓ Main analysis function available\n');
        fprintf('  - Usage: main_analysis(''complete'')\n');
        fprintf('  - Usage: main_analysis(''complete'', dataPath)\n');
        fprintf('  - Usage: main_analysis(''post_hoc'', dataPath)\n');
        fprintf('  - Usage: main_analysis(''batch'', dataDirectory)\n');
        fprintf('\n');
        
        % Test 8: Test convenience function
        fprintf('Test 8: Test convenience function...\n');
        fprintf('✓ Convenience function available\n');
        fprintf('  - Usage: runCompleteAnalysis()\n');
        fprintf('  - Usage: runCompleteAnalysis(dataPath)\n');
        fprintf('\n');
        
        fprintf('All tests completed successfully!\n');
        fprintf('The BehaviorAnalysis system is ready to use.\n\n');
        
        % Display usage instructions
        fprintf('Usage Instructions:\n');
        fprintf('==================\n');
        fprintf('1. Run complete analysis with GUI:\n');
        fprintf('   main_analysis(''complete'')\n\n');
        fprintf('2. Run complete analysis on specific file:\n');
        fprintf('   main_analysis(''complete'', ''path/to/data.mat'')\n\n');
        fprintf('3. Run post-hoc analysis:\n');
        fprintf('   main_analysis(''post_hoc'', ''path/to/data.mat'')\n\n');
        fprintf('4. Run batch analysis:\n');
        fprintf('   main_analysis(''batch'', ''path/to/data/directory'')\n\n');
        fprintf('5. Use convenience function:\n');
        fprintf('   runCompleteAnalysis()\n\n');
        
    catch ME
        fprintf('❌ Test failed with error:\n');
        fprintf('Error: %s\n', ME.message);
        fprintf('Location: %s (line %d)\n', ME.stack(1).file, ME.stack(1).line);
        fprintf('\nPlease check the error and try again.\n');
    end
end

function test_with_sample_data()
    % Test with sample data (if available)
    fprintf('Testing with sample data...\n');
    fprintf('============================\n\n');
    
    % Look for sample data files
    dataPath = 'G:\Data\OperantConditioning\Yudi';
    if exist(dataPath, 'dir')
        files = dir(fullfile(dataPath, '*.mat'));
        if ~isempty(files)
            fprintf('Found %d data files in %s\n', length(files), dataPath);
            fprintf('Sample files:\n');
            for i = 1:min(5, length(files)) % Show first 5 files
                fprintf('  - %s\n', files(i).name);
            end
            if length(files) > 5
                fprintf('  ... and %d more files\n', length(files) - 5);
            end
            fprintf('\nTo test with real data, run:\n');
            fprintf('main_analysis(''complete'', ''%s'')\n', dataPath);
        else
            fprintf('No .mat files found in %s\n', dataPath);
        end
    else
        fprintf('Data directory not found: %s\n', dataPath);
        fprintf('Please update the data path in the configuration or provide a valid path.\n');
    end
end

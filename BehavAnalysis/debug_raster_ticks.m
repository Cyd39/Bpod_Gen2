% Debug script to check raster plot Y-axis ticks
function debug_raster_ticks()
    fprintf('Debugging raster plot Y-axis ticks...\n');
    fprintf('=====================================\n\n');
    
    try
        % Initialize analysis manager
        configPath = fullfile(fileparts(mfilename('fullpath')), 'config.json');
        analysisManager = BehaviorAnalysisManager(configPath);
        
        % Load data
        [SessionData, Session_tbl, filePath] = analysisManager.DataLoader.loadSessionData();
        fprintf('✓ Data loaded from: %s\n', filePath);
        
        % Process data
        data = struct('SessionData', SessionData, 'Session_tbl', Session_tbl, 'filePath', filePath);
        processedData = analysisManager.Preprocessor.processSessionData(data);
        fprintf('✓ Data processed successfully\n');
        
        % Check intensity data
        fprintf('\nIntensity data analysis:\n');
        if isfield(processedData, 'AudIntensity')
            intensities = processedData.AudIntensity;
            uniqueIntensities = unique(intensities);
            fprintf('- All intensities: %s\n', mat2str(intensities));
            fprintf('- Unique intensities: %s\n', mat2str(uniqueIntensities));
            fprintf('- Sorted unique intensities: %s\n', mat2str(sort(uniqueIntensities)));
        else
            fprintf('❌ No AudIntensity data found\n');
            return;
        end
        
        % Check lick data
        fprintf('\nLick data analysis:\n');
        validTrials = 0;
        for i = 1:length(processedData.LickOnAfterStim)
            if ~isempty(processedData.LickOnAfterStim{i}) && ~all(isnan(processedData.LickOnAfterStim{i}))
                validTrials = validTrials + 1;
            end
        end
        fprintf('- Valid lick trials: %d/%d\n', validTrials, length(processedData.LickOnAfterStim));
        
        % Test raster plot creation manually
        fprintf('\nTesting raster plot creation:\n');
        
        % Prepare data for raster plot
        EventT = processedData.LickOnAfterStim;
        Var = processedData.AudIntensity;
        
        % Get unique intensities and create color map
        uInt = unique(Var);
        nInt = length(uInt);
        Colour = turbo(nInt);
        
        fprintf('- EventT length: %d\n', length(EventT));
        fprintf('- Var length: %d\n', length(Var));
        fprintf('- Unique intensities: %s\n', mat2str(uInt));
        fprintf('- Number of colors: %d\n', nInt);
        
        % Create a test figure
        fig = figure('Visible', 'off');
        ax = axes('Parent', fig);
        
        % Call plotRaster method
        [ax, YTick, YTickLab] = analysisManager.Visualizers.raster.plotRaster(ax, EventT, Var, Colour, 10, 1);
        
        fprintf('\nYTick analysis:\n');
        for i = 1:length(YTick)
            if ~isempty(YTick{i})
                fprintf('- YTick{%d}: %s\n', i, mat2str(YTick{i}));
            else
                fprintf('- YTick{%d}: empty\n', i);
            end
        end
        
        fprintf('\nYTickLab analysis:\n');
        if ~isempty(YTickLab)
            fprintf('- YTickLab: %s\n', mat2str(YTickLab));
        else
            fprintf('- YTickLab: empty\n');
        end
        
        % Check if YTick{1} and YTickLab have matching lengths
        if ~isempty(YTick{1}) && ~isempty(YTickLab)
            fprintf('\nLength comparison:\n');
            fprintf('- YTick{1} length: %d\n', length(YTick{1}));
            fprintf('- YTickLab length: %d\n', length(YTickLab));
            fprintf('- Lengths match: %s\n', string(length(YTick{1}) == length(YTickLab)));
        end
        
        % Close test figure
        close(fig);
        
        fprintf('\n✓ Raster tick debugging completed!\n');
        
    catch ME
        fprintf('\n❌ Debug failed with error:\n');
        fprintf('Error: %s\n', ME.message);
        if ~isempty(ME.stack)
            fprintf('Location: %s (line %d)\n', ME.stack(1).file, ME.stack(1).line);
        end
    end
end

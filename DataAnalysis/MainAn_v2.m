%% 1. load behavioural data from multiple files
clearvars

% use current directory
defaultDataPath = pwd;
% Alternative: Set default path for file selection dialog
%defaultDataPath = '';  % Change this to default path

% Check if default path exists, if not use current directory
if ~exist(defaultDataPath, 'dir')
    warning(['Default path does not exist: ' defaultDataPath '. Using current directory instead.']);
    defaultDataPath = pwd;
end

% Select files and get absolute paths (supports both single and multiple file selection)
[filenames, filepath] = uigetfile('*.mat', 'Select file(s) to load', defaultDataPath, 'MultiSelect', 'on');

if isequal(filenames, 0)
    disp('User canceled file selection');
    return;  % Exit if user canceled
end

% Handle both single file (string) and multiple files (cell array) cases
if ischar(filenames)
    % Single file selected - convert to cell array for uniform processing
    filenames = {filenames};
end

% Get number of files
numFiles = length(filenames);
disp(['Selected ' num2str(numFiles) ' file(s) to process']);

% Loop through each file
for fileIdx = 1:numFiles
    filename = filenames{fileIdx};
    
    % Get absolute path
    absolute_path = fullfile(filepath, filename);
    
    % Get filename without extension
    [~, name_only, ~] = fileparts(filename);
    
    % Display file information
    disp('========================================');
    disp(['Processing file ' num2str(fileIdx) ' of ' num2str(numFiles) ': ' filename]);
    disp(['File path: ' absolute_path]);
    
    % Load file based on file type
    [~, ~, extension] = fileparts(filename);
    
    switch lower(extension)
        case {'.mat'}
            % Load MAT file
            load(absolute_path);
            disp('MAT file loaded successfully');
        otherwise
            % For other file types
            warning(['Unsupported file type: ' extension '. Skipping this file.']);
            continue;  % Skip to next file
    end
    
    % Display file information
    file_info = dir(absolute_path);
    disp(['File size: ' num2str(file_info.bytes) ' bytes']);
    disp('Behavior Data loaded');

    %% Plot and save figure
% Plot functions create their own figures, so we get the figure handles after plotting
PlotLickIntervals(SessionData);
figLickIntervals = gcf;  % Get the current figure handle after plotting

PlotResLatency(SessionData);
figResLatency = gcf;  % Get the current figure handle after plotting

PlotLickRaster(SessionData);
figRaster = gcf;  % Get the current figure handle after plotting

PlotSessionSummary(SessionData);
figSessionSummary = gcf;  % Get the current figure handle after plotting

PlotCDFHitRate(SessionData);
figCDFHitRate = gcf;  % Get the current figure handle after plotting

PlotBarResponse(SessionData);
figBarResponse = gcf;  % Get the current figure handle after plotting

PlotHitResponseRate(SessionData);
figHitResponseRate = gcf;  % Get the current figure handle after plotting

    % Save figures to the same directory as the loaded file
    savePath = filepath;  % Use the directory where the data file was loaded from

    % Save figures with proper settings to prevent position shifts
    try
        % Use exportgraphics if available (better layout preservation)
        exportgraphics(figLickIntervals, fullfile(savePath, [name_only,'_LickIntervals', '.png']), ...
            'Resolution', 300, 'ContentType', 'image');
        exportgraphics(figResLatency, fullfile(savePath, [name_only,'_ResLatency', '.png']), ...
            'Resolution', 300, 'ContentType', 'image');
        exportgraphics(figRaster, fullfile(savePath, [name_only,'_Raster', '.png']), ...
            'Resolution', 300, 'ContentType', 'image');
        exportgraphics(figSessionSummary, fullfile(savePath, [name_only,'_SessionSummary', '.png']), ...
            'Resolution', 300, 'ContentType', 'image');
        exportgraphics(figCDFHitRate, fullfile(savePath, [name_only,'_CDFHitRate', '.png']), ...
            'Resolution', 300, 'ContentType', 'image');
        exportgraphics(figBarResponse, fullfile(savePath, [name_only,'_BarResponse', '.png']), ...
            'Resolution', 300, 'ContentType', 'image');
        exportgraphics(figHitResponseRate, fullfile(savePath, [name_only,'_HitResponseRate', '.png']), ...
            'Resolution', 300, 'ContentType', 'image');
    catch
        % Force figure to render before capturing
        drawnow;
        
        % Save Lick Intervals figure
        frame = getframe(figLickIntervals);
        imwrite(frame.cdata, fullfile(savePath, [name_only,'_LickIntervals',  '.png']), 'PNG');
        
        % Save Response Latency figure
        frame = getframe(figResLatency);
        imwrite(frame.cdata, fullfile(savePath, [name_only,'_ResLatency',  '.png']), 'PNG');
        
        % Save Raster plot figure
        frame = getframe(figRaster);
        imwrite(frame.cdata, fullfile(savePath, [name_only,'_Raster',  '.png']), 'PNG');
        
        % Save Session Summary figure
        frame = getframe(figSessionSummary);
        imwrite(frame.cdata, fullfile(savePath, [name_only,'_SessionSummary',  '.png']), 'PNG');
        
        % Save CDF Hit Rate figure
        frame = getframe(figCDFHitRate);
        imwrite(frame.cdata, fullfile(savePath, [name_only,'_CDFHitRate',  '.png']), 'PNG');
        
        % Save Bar Response figure
        frame = getframe(figBarResponse);
        imwrite(frame.cdata, fullfile(savePath, [name_only,'_BarResponse',  '.png']), 'PNG');
        
        % Save Hit Response Rate figure
        frame = getframe(figHitResponseRate);
        imwrite(frame.cdata, fullfile(savePath, [name_only,'_HitResponseRate',  '.png']), 'PNG');
    end

    disp(['Figures saved to: ' savePath]);

    %% Create combined figure with all plots
    % Create a large figure with multiple subplots containing all plots
    figCombined = figure('Name', ['Combined Analysis Plot: ' name_only], 'Position', [100, 100, 1500, 800]);

    % Layout: 3 rows x 3 columns
    % Row 1: PlotLickIntervals, PlotResLatency, PlotLickRaster (2 subplots)
    % Row 2: PlotSessionSummary, PlotCDFHitRate, PlotBarResponse
    % Row 3: PlotHitResponseRate (centered), empty, empty

    % Create subplots and plot each graph
    % Subplot 1: Session Summary (1,1)
    ax1 = subplot(3, 3, [1,4]);
    PlotSessionSummary(SessionData, 'FigureHandle', figCombined, 'Axes', ax1);

    % Subplot 2: Lick Intervals (1,2)
    ax2 = subplot(3, 3, 5);
    PlotLickIntervals(SessionData, 'FigureHandle', figCombined, 'Axes', ax2);

    % Subplot 3: Response Latency (1,3)
    ax3 = subplot(3, 3, 6);
    PlotResLatency(SessionData, 'FigureHandle', figCombined, 'Axes', ax3);

    % Subplot 4: Lick Raster (2,1) - split into 2 subplots
    ax4a = subplot(3, 3, 2);
    ax4b = subplot(3, 3, 3);
    PlotLickRaster(SessionData, 'FigureHandle', figCombined, 'Axes', {ax4a, ax4b});

    % Subplot 5: CDF Hit Rate (2,2)
    ax5 = subplot(3, 3, 8);
    PlotCDFHitRate(SessionData, 'FigureHandle', figCombined, 'Axes', ax5);

    % Subplot 6: Bar Response (2,3)
    ax6 = subplot(3, 3, 7);
    PlotBarResponse(SessionData, 'FigureHandle', figCombined, 'Axes', ax6);

    % Subplot 7: Hit Response Rate (3,2)
    ax7 = subplot(3, 3, 9);
    PlotHitResponseRate(SessionData, 'FigureHandle', figCombined, 'Axes', ax7);

    % Add overall title
    sgtitle(figCombined, name_only, 'FontSize', 14, 'FontWeight', 'bold', 'Interpreter', 'none');

    % Adjust subplot spacing for better layout
    set(figCombined, 'Units', 'normalized');

    drawnow;

    % Save combined figure
    try
        exportgraphics(figCombined, fullfile(savePath, [name_only,'_Combined', '.png']), ...
            'Resolution', 300, 'ContentType', 'image');
        disp(['Combined figure saved to: ' fullfile(savePath, [name_only,'_Combined', '.png'])]);
    catch
        % Force figure to render before capturing
        drawnow;
        frame = getframe(figCombined);
        imwrite(frame.cdata, fullfile(savePath, [name_only,'_Combined', '.png']), 'PNG');
        disp(['Combined figure saved to: ' fullfile(savePath, [name_only,'_Combined', '.png'])]);
    end

    % Close figures for current file (optional - comment out if you want to keep them open)
    figHandles = findall(0, 'Type', 'figure');
    close(figHandles);
    
    disp(['Completed processing file ' num2str(fileIdx) ' of ' num2str(numFiles)]);
    disp('========================================');
end

% Final message
disp('All files processed successfully!');


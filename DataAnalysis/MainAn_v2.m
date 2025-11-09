%% 1. load behavioural data
clearvars

% use current directory
defaultDataPath = pwd;
% Alternative: Set default path for file selection dialog
% defaultDataPath = '';  % Change this to default path

% Check if default path exists, if not use current directory
if ~exist(defaultDataPath, 'dir')
    warning(['Default path does not exist: ' defaultDataPath '. Using current directory instead.']);
    defaultDataPath = pwd;
end

% Select file and get absolute path
[filename, filepath] = uigetfile('*.mat', 'Select a file to load', defaultDataPath);

if isequal(filename, 0)
    disp('User canceled file selection');
else
    % Get absolute path
    absolute_path = fullfile(filepath, filename);

    % Get filename without extension
    [~, name_only, ~] = fileparts(filename);
    
    % Display absolute path
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
            disp(['Unsupported file type: ' extension]);
            data = absolute_path;
    end
    
    % Display file information
    file_info = dir(absolute_path);
    disp('=== File Information ===');
    disp(['File name: ' filename]);
    disp(['File size: ' num2str(file_info.bytes) ' bytes']);
end

disp('Behavior Data loaded');

%% Plot and save figure
% Plot functions create their own figures, so we get the figure handles after plotting
PlotLickIntervalsFromSessionData(SessionData);
figLickIntervals = gcf;  % Get the current figure handle after plotting

PlotResLatencyFromSessionData(SessionData);
figResLatency = gcf;  % Get the current figure handle after plotting

plotraster_behavior_v2(SessionData);
figRaster = gcf;  % Get the current figure handle after plotting

% Save figures to the same directory as the loaded file
savePath = filepath;  % Use the directory where the data file was loaded from

% Save figures with proper settings to prevent position shifts
% Method 1: Try exportgraphics (MATLAB R2020a+), which preserves layout better
% Method 2: Fall back to getframe + imwrite if exportgraphics is not available

try
    % Use exportgraphics if available (better layout preservation)
    exportgraphics(figLickIntervals, fullfile(savePath, ['LickIntervals_', name_only, '.png']), ...
        'Resolution', 300, 'ContentType', 'image');
    exportgraphics(figResLatency, fullfile(savePath, ['ResLatency_', name_only, '.png']), ...
        'Resolution', 300, 'ContentType', 'image');
    exportgraphics(figRaster, fullfile(savePath, ['Raster_', name_only, '.png']), ...
        'Resolution', 300, 'ContentType', 'image');
catch
    % Fallback: Use getframe + imwrite (preserves exact screen appearance)
    % Force figure to render before capturing
    drawnow;
    
    % Save Lick Intervals figure
    frame = getframe(figLickIntervals);
    imwrite(frame.cdata, fullfile(savePath, ['LickIntervals_', name_only, '.png']), 'PNG');
    
    % Save Response Latency figure
    frame = getframe(figResLatency);
    imwrite(frame.cdata, fullfile(savePath, ['ResLatency_', name_only, '.png']), 'PNG');
    
    % Save Raster plot figure
    frame = getframe(figRaster);
    imwrite(frame.cdata, fullfile(savePath, ['Raster_', name_only, '.png']), 'PNG');
end

disp(['Figures saved to: ' savePath]);

% close figures
figHandles = findall(0, 'Type', 'figure');
close(figHandles);
function [protocolName, subjectName] = ProtocolNameGui()
    % Create handle structure
    h = struct();
    
    % Create figure window
    h_gui = figure('Name', 'Protocol Parameter Setting', ...
        'NumberTitle', 'off', ...
        'Position', [500 600 500 250], ...
        'MenuBar', 'none', ...
        'Resize', 'off');

    % Get list of available protocols
    protocolDir = fullfile(pwd, 'Protocols');
    protocolList = dir(protocolDir);
    protocolList = protocolList([protocolList.isdir]); % Get only directories
    protocolList = protocolList(~ismember({protocolList.name}, {'.', '..'})); % Remove . and ..
    protocolNames = {protocolList.name};

    % Get list of available subjects
    subjectFile = fullfile(protocolDir, 'subjects.txt');
    if exist(subjectFile, 'file')
        % Read subject list from file
        fid = fopen(subjectFile, 'r');
        subjectList = textscan(fid, '%s', 'Delimiter', '\n', 'Whitespace', '');
        fclose(fid);
        subjectNames = subjectList{1};
        % Remove empty lines
        subjectNames = subjectNames(~cellfun(@isempty, subjectNames));
    else
        % If file doesn't exist, create it with default subject
        fid = fopen(subjectFile, 'w');
        fprintf(fid, 'human_test\r\n');
        fclose(fid);
        subjectNames = {'human_test'};
    end

    % Protocol Name
    uicontrol('Style', 'text', ...
        'String', 'Protocol Name:', ...
        'Units', 'normalized', ...
        'Position', [0.05 0.6 0.3 0.2], ...
        'FontSize', 12, ...
        'HorizontalAlignment', 'right');
    h.ProtocolName = uicontrol('Style', 'popup', ...
        'String', protocolNames, ...
        'Units', 'normalized', ...
        'Position', [0.4 0.6 0.4 0.2], ...
        'FontSize', 12);

    % Subject Name
    uicontrol('Style', 'text', ...
        'String', 'Subject Name:', ...
        'Units', 'normalized', ...
        'Position', [0.05 0.3 0.3 0.2], ...
        'FontSize', 12, ...
        'HorizontalAlignment', 'right');
    h.SubjectName = uicontrol('Style', 'popup', ...
        'String', subjectNames, ...
        'Units', 'normalized', ...
        'Position', [0.4 0.3 0.4 0.2], ...
        'FontSize', 12);

    % Add new subject button
    uicontrol('Style', 'pushbutton', ...
        'String', 'Add New', ...
        'Units', 'normalized', ...
        'Position', [0.8 0.37 0.18 0.15], ...
        'FontSize', 10, ...
        'Callback', @addNewSubject);

    % Set button
    uicontrol('Style', 'pushbutton', ...
        'String', 'Set Parameters', ...
        'Units', 'normalized', ...
        'Position', [0.35 0.1 0.3 0.15], ...
        'FontSize', 12, ...
        'Callback', @setParams);

    % Error message display area
    h.ErrorMsg = uicontrol('Style', 'text', ...
        'String', '', ...
        'Units', 'normalized', ...
        'Position', [0.1 0.02 0.8 0.06], ...
        'FontSize', 10, ...
        'ForegroundColor', 'red', ...
        'HorizontalAlignment', 'left', ...
        'BackgroundColor', [0.95 0.95 0.95]);

    % Initialize return values
    protocolName = '';
    subjectName = '';

    function addNewSubject(~, ~)
        % Create input dialog for new subject
        newSubject = inputdlg('Enter new subject name:', 'Add New Subject', 1);
        
        if ~isempty(newSubject)
            newSubject = newSubject{1};
            % Check if subject already exists
            if ~ismember(newSubject, subjectNames)
                % Add new subject to list
                subjectNames{end+1} = newSubject;
                % Update dropdown menu
                set(h.SubjectName, 'String', subjectNames);
                % Save to file
                fid = fopen(subjectFile, 'a');
                fprintf(fid, '%s\r\n', newSubject);
                fclose(fid);
            else
                set(h.ErrorMsg, 'String', 'Subject already exists');
            end
        end
    end

    function setParams(~, ~)
        % Clear previous error message
        set(h.ErrorMsg, 'String', '');
        
        try
            % Get values from GUI
            protocolIndex = get(h.ProtocolName, 'Value');
            protocolName = protocolNames{protocolIndex};
            subjectIndex = get(h.SubjectName, 'Value');
            subjectName = subjectNames{subjectIndex};
            
            % Close the GUI
            uiresume(h_gui);
        catch ME
            % Display error message
            set(h.ErrorMsg, 'String', ME.message);
        end
    end

    % Wait for user input
    uiwait(h_gui);
    close(h_gui);
end 
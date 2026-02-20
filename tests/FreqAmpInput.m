function freqamp = FreqAmpInput()
    % FreqAmpInput - Simple GUI for entering frequency-amplitude pairs
    % Output: freqamp - Structure array containing entered frequency-amplitude pairs
    % 
    % Validation rules:
    % - Frequency must be a positive integer
    % - Amplitude must be between 0 and 1 (inclusive)
    % - Multiple amplitudes allowed for same frequency
    % - Pairs are sorted by frequency, then by amplitude
    
    % Initialize output
    freqamp = [];
    
    % Create main figure
    h.fig = figure('Position', [400, 300, 450, 380], ...
                   'Name', 'Frequency-Amplitude Input', ...
                   'NumberTitle', 'off', ...
                   'MenuBar', 'none', ...
                   'Resize', 'off');
    
    % Store data
    h.pairs = struct('freq', {}, 'amp', {});
    
    % Frequency input
    uicontrol('Parent', h.fig, ...
              'Style', 'text', ...
              'String', 'Frequency (Hz, integer):', ...
              'Position', [50, 300, 130, 20], ...
              'HorizontalAlignment', 'left');
    
    h.edit_freq = uicontrol('Parent', h.fig, ...
                            'Style', 'edit', ...
                            'Position', [190, 300, 100, 25], ...
                            'String', '', ...
                            'Callback', @edit_freq_Callback);
    
    % Amplitude input
    uicontrol('Parent', h.fig, ...
              'Style', 'text', ...
              'String', 'Amplitude (0-1):', ...
              'Position', [50, 260, 130, 20], ...
              'HorizontalAlignment', 'left');
    
    h.edit_amp = uicontrol('Parent', h.fig, ...
                           'Style', 'edit', ...
                           'Position', [190, 260, 100, 25], ...
                           'String', '', ...
                           'Callback', @edit_amp_Callback);
    
    % Add button
    h.btn_add = uicontrol('Parent', h.fig, ...
                          'Style', 'pushbutton', ...
                          'String', 'Add Pair', ...
                          'Position', [310, 260, 80, 30], ...
                          'Callback', @btn_add_Callback, ...
                          'Enable', 'off');  % Initially disabled
    
    % Validation status
    h.txt_status = uicontrol('Parent', h.fig, ...
                             'Style', 'text', ...
                             'String', 'Enter frequency and amplitude', ...
                             'Position', [50, 220, 350, 20], ...
                             'HorizontalAlignment', 'left', ...
                             'ForegroundColor', [0.5, 0.5, 0.5]);
    
    % Listbox to display added pairs
    uicontrol('Parent', h.fig, ...
              'Style', 'text', ...
              'String', 'Added Pairs (sorted by Freq/Amp):', ...
              'Position', [50, 190, 180, 20], ...
              'HorizontalAlignment', 'left');
    
    h.listbox = uicontrol('Parent', h.fig, ...
                          'Style', 'listbox', ...
                          'Position', [50, 50, 280, 130], ...
                          'String', {}, ...
                          'Value', 1, ...
                          'BackgroundColor', [1, 1, 1]);
    
    % Delete button
    h.btn_delete = uicontrol('Parent', h.fig, ...
                             'Style', 'pushbutton', ...
                             'String', 'Delete Selected', ...
                             'Position', [340, 110, 100, 25], ...
                             'Callback', @btn_delete_Callback, ...
                             'Enable', 'off');  % Initially disabled
    
    % Done button
    h.btn_done = uicontrol('Parent', h.fig, ...
                           'Style', 'pushbutton', ...
                           'String', 'Done', ...
                           'Position', [170, 10, 100, 30], ...
                           'Callback', @btn_done_Callback);
    
    % Store handles
    guidata(h.fig, h);
    
    % Wait for figure to close
    uiwait(h.fig);
    
    % Return the collected pairs
    if ishandle(h.fig)
        h = guidata(h.fig);
        freqamp = h.pairs;
        delete(h.fig);
    end
    
    % Callback functions
    function edit_freq_Callback(~, ~)
        h = guidata(h.fig);
        validate_inputs();
        guidata(h.fig, h);
    end

    function edit_amp_Callback(~, ~)
        h = guidata(h.fig);
        validate_inputs();
        guidata(h.fig, h);
    end

    function validate_inputs()
        % Validate frequency and amplitude inputs
        freq_str = get(h.edit_freq, 'String');
        amp_str = get(h.edit_amp, 'String');
        
        % Default status
        status_text = '';
        status_color = [0.5, 0.5, 0.5];  % Gray
        add_enabled = false;
        
        % Check if both fields are filled
        if isempty(freq_str) || isempty(amp_str)
            status_text = 'Please enter both frequency and amplitude';
        else
            % Validate frequency
            freq = str2double(freq_str);
            if isnan(freq)
                status_text = 'Frequency must be a number';
                status_color = [1, 0, 0];  % Red
            elseif mod(freq, 1) ~= 0
                status_text = 'Frequency must be an integer';
                status_color = [1, 0, 0];  % Red
            elseif freq <= 0
                status_text = 'Frequency must be positive';
                status_color = [1, 0, 0];  % Red
            else
                % Validate amplitude
                amp = str2double(amp_str);
                if isnan(amp)
                    status_text = 'Amplitude must be a number';
                    status_color = [1, 0, 0];  % Red
                elseif amp < 0 || amp > 1
                    status_text = 'Amplitude must be between 0 and 1';
                    status_color = [1, 0, 0];  % Red
                else
                    % All validations passed
                    status_text = sprintf('Valid: %d Hz, %.4f', freq, amp);
                    status_color = [0, 0.5, 0];  % Green
                    add_enabled = true;
                end
            end
        end
        
        % Update status display and add button
        set(h.txt_status, 'String', status_text, 'ForegroundColor', status_color);
        set(h.btn_add, 'Enable', bool_to_on_off(add_enabled));
    end

    function btn_add_Callback(~, ~)
        h = guidata(h.fig);
        
        % Get validated values
        freq = round(str2double(get(h.edit_freq, 'String')));  % Ensure integer
        amp = str2double(get(h.edit_amp, 'String'));
        
        % Add new pair
        new_pair.freq = freq;
        new_pair.amp = amp;
        
        if isempty(h.pairs)
            h.pairs = new_pair;
        else
            % Append new pair
            h.pairs(end+1) = new_pair;
            
            % Sort pairs by frequency first, then by amplitude
            [~, sort_idx] = sort([h.pairs.freq]);  % Sort by frequency first
            h.pairs = h.pairs(sort_idx);
            
            % For same frequencies, sort by amplitude
            unique_freqs = unique([h.pairs.freq]);
            if length(unique_freqs) < length(h.pairs)  % If there are duplicate frequencies
                sorted_pairs = [];
                for f = unique_freqs
                    % Get all pairs with current frequency
                    freq_mask = [h.pairs.freq] == f;
                    freq_pairs = h.pairs(freq_mask);
                    
                    % Sort these by amplitude
                    [~, amp_idx] = sort([freq_pairs.amp]);
                    freq_pairs = freq_pairs(amp_idx);
                    
                    % Add to sorted list
                    sorted_pairs = [sorted_pairs, freq_pairs];
                end
                h.pairs = sorted_pairs;
            end
        end
        
        % Update status
        set(h.txt_status, 'String', sprintf('Added: %d Hz, %.4f', freq, amp), ...
            'ForegroundColor', [0, 0.5, 0]);
        
        % Clear input fields
        set(h.edit_freq, 'String', '');
        set(h.edit_amp, 'String', '');
        
        % Update listbox
        update_listbox();
        
        % Enable delete button
        set(h.btn_delete, 'Enable', 'on');
        
        % Reset validation
        validate_inputs();
        
        % Save handles
        guidata(h.fig, h);
    end

    function btn_delete_Callback(~, ~)
        h = guidata(h.fig);
        
        % Get selected index
        selected_idx = get(h.listbox, 'Value');
        
        if isempty(h.pairs) || selected_idx > length(h.pairs)
            return;
        end
        
        % Get info for confirmation message
        freq_to_delete = h.pairs(selected_idx).freq;
        amp_to_delete = h.pairs(selected_idx).amp;
        
        % Confirm deletion
        choice = questdlg(sprintf('Delete %d Hz @ %.4f ?', freq_to_delete, amp_to_delete), ...
                         'Confirm Delete', 'Yes', 'No', 'No');
        
        if strcmp(choice, 'Yes')
            % Delete selected pair
            h.pairs(selected_idx) = [];
            
            % Update listbox
            update_listbox();
            
            % Update status
            set(h.txt_status, 'String', sprintf('Deleted %d Hz @ %.4f', freq_to_delete, amp_to_delete), ...
                'ForegroundColor', [0.5, 0.5, 0.5]);
            
            % Disable delete button if no pairs left
            if isempty(h.pairs)
                set(h.btn_delete, 'Enable', 'off');
            end
        end
        
        % Save handles
        guidata(h.fig, h);
    end

    function btn_done_Callback(~, ~)
        % Close figure and return control to main function
        uiresume(h.fig);
    end

    function update_listbox()
        % Update the listbox display with current pairs
        if isempty(h.pairs)
            set(h.listbox, 'String', {'<No pairs added>'}, 'Value', 1);
        else
            % Create display strings (already sorted)
            display_str = cell(length(h.pairs), 1);
            for i = 1:length(h.pairs)
                display_str{i} = sprintf('Freq: %3d Hz, Amp: %.4f', ...
                    h.pairs(i).freq, h.pairs(i).amp);
            end
            set(h.listbox, 'String', display_str, 'Value', 1);
        end
    end

    function on_off_str = bool_to_on_off(bool_val)
        % Convert boolean to 'on'/'off' string for UI controls
        if bool_val
            on_off_str = 'on';
        else
            on_off_str = 'off';
        end
    end
end
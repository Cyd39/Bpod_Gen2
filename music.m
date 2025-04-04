% Use MATLAB to generate and play 'Ode to Joy', 'Castle in the Sky' and 'Twinkle Twinkle Little Star'.

function music_player_gui
    % main GUI
    fig = figure('Name', 'MATLAB Music Player', 'NumberTitle', 'off', ...
                 'Position', [400, 400, 300, 150], 'MenuBar', 'none', ...
                 'ToolBar', 'none', 'Resize', 'off');
    
    % title
    uicontrol('Style', 'text', 'String', 'Please choose the music to play:', ...
              'Position', [50, 110, 200, 20], 'FontSize', 10);
    
    % pulldown
    song_list = {'Ode to Joy', 'Castle in the Sky', 'Twinkle Twinkle Little Star'};
    popup = uicontrol('Style', 'popupmenu', 'String', song_list, ...
                      'Position', [50, 80, 200, 20], 'FontSize', 10);
    
    % play button
    play_btn = uicontrol('Style', 'pushbutton', 'String', 'Play', ...
                         'Position', [100, 40, 100, 30], 'FontSize', 10, ...
                         'Callback', @play_song);
    
    % sampling frequency
    fs = 44100;
    
    % play music
    function play_song(~, ~)
        % index of music
        idx = popup.Value;
        
        % choose music according to GUI
        switch idx
            case 1 % Ode to Joy
                melody = get_ode_to_joy();
                msgbox('Playing: Ode to Joy', 'Playing');
            case 2 % Castle in the Sky
                melody = get_castle_in_the_sky();
                msgbox('Playing: Castle in the Sky', 'Playing');
            case 3 % Twinkle Twinkle Little Star
                melody = get_twinkle_little_star();
                msgbox('Playing: Twinkle Twinkle Little Star', 'Playing');
        end
        
        % play music
        sound(melody, fs);
    end

    % Generate Ode to Joy
    function melody = get_ode_to_joy()
        % define notes
        notes.C = 261.63;  % middle C
        notes.D = 293.66;  % D
        notes.E = 329.63;  % E
        notes.F = 349.23;  % F
        notes.G = 392.00;  % G
        notes.A = 440.00;  % A
        notes.B = 493.88;  % B
        notes.hC = 523.25; % High C
        
        % melody
        melody_notes = [notes.E, notes.E, notes.F, notes.G, ...
                       notes.G, notes.F, notes.E, notes.D, ...
                       notes.C, notes.C, notes.D, notes.E, ...
                       notes.E, notes.D, notes.D, ...
                       notes.E, notes.E, notes.F, notes.G, ...
                       notes.G, notes.F, notes.E, notes.D, ...
                       notes.C, notes.C, notes.D, notes.E, ...
                       notes.D, notes.C, notes.C];
        
        % Duration of notes
        durations = [0.5, 0.5, 0.5, 0.5, ...
                    0.5, 0.5, 0.5, 0.5, ...
                    0.5, 0.5, 0.5, 0.5, ...
                    0.75, 0.25, 1, ...
                    0.5, 0.5, 0.5, 0.5, ...
                    0.5, 0.5, 0.5, 0.5, ...
                    0.5, 0.5, 0.5, 0.5, ...
                    0.75, 0.25, 1];
        
        melody = generate_melody(melody_notes, durations, fs);
    end

    % Generate Castle in the Sky
    function melody = get_castle_in_the_sky()
        % define notes
        notes.lowG = 196.00;   % low G
        notes.lowA = 220.00;   % low A
        notes.lowB = 246.94;   % low B
        notes.C = 261.63;      % low C
        notes.D = 293.66;      % D
        notes.E = 329.63;      % E
        notes.F = 349.23;      % F
        notes.G = 392.00;      % G
        notes.A = 440.00;      % A
        notes.B = 493.88;      % B
        notes.hC = 523.25;     % High C
        notes.hD = 587.33;     % High D
        notes.hE = 659.25;     % High E
        notes.hF = 698.46;

        % melody
        melody_notes = [notes.A, notes.B, notes.hC, notes.B, notes.hC, notes.hE, notes.B, 0, ...
                       notes.E, notes.A, notes.G, notes.A, notes.hC, notes.G,0,  ...
                       notes.E, notes.E, notes.F, notes.E, notes.F, notes.hC, notes.E,0,  ...
                       notes.hC, notes.B, notes.F, notes.F, notes.B, notes.B,0,  ...
                       notes.A, notes.B, notes.hC, notes.B, notes.hC, notes.hE, notes.B, 0, ...
                       notes.E, notes.A, notes.G, notes.A, notes.hC, notes.G, 0,  ...
                       notes.E, notes.F, notes.hC, notes.B, notes.hC,0,  notes.hD, notes.hD, notes.hE, notes.hC, 0,  ...
                       notes.hC, notes.B, notes.A, notes.A, notes.B, 420, notes.A, 0,];
        
         % Duration of notes
        durations = [0.5, 0.5, 1.5, 0.5, 1, 1, 2, 1, ...       
                     1, 1.5, 0.5, 1, 1, 2, 1, ...       
                     0.5, 0.5, 1.5, 0.5, 1, 1, 2, 1,  ...       
                     1, 1.5, 0.5, 1, 1, 2, 1,  ...       
                     0.5, 0.5, 1.5, 0.5, 1, 1, 2, 1,  ...  
                     1, 1.5, 0.5, 1, 1, 2, 1,  ...    
                     1, 1, 0.5, 1, 1 , 0.5,0.5, 1, 0.5, 1, 1, ...
                     0.5, 0.5, 0.5, 0.5, 1.5, 0.5, 3,1];          
        
        % main melody
        melody = generate_melody(melody_notes, durations, fs);
        
    end

    % Generate Twinkle Twinkle Little Star
    function melody = get_twinkle_little_star()
        % define notes
        notes.C = 261.63;  % middle C
        notes.D = 293.66;  % D
        notes.E = 329.63;  % E
        notes.F = 349.23;  % F
        notes.G = 392.00;  % G
        notes.A = 440.00;  % A
        notes.B = 493.88;  % B
        notes.hC = 523.25; % High C
        
        % melody
        melody_notes = [notes.C, notes.C, notes.G, notes.G, notes.A, notes.A, notes.G, ...
                       notes.F, notes.F, notes.E, notes.E, notes.D, notes.D, notes.C, ...
                       notes.G, notes.G, notes.F, notes.F, notes.E, notes.E, notes.D, ...
                       notes.G, notes.G, notes.F, notes.F, notes.E, notes.E, notes.D, ...
                       notes.C, notes.C, notes.G, notes.G, notes.A, notes.A, notes.G, ...
                       notes.F, notes.F, notes.E, notes.E, notes.D, notes.D, notes.C];
        
        % Duration of notes
        durations = [0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 1, ...
                    0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 1, ...
                    0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 1, ...
                    0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 1, ...
                    0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 1, ...
                    0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 1];
        
        melody = generate_melody(melody_notes, durations, fs);
    end

    % General melody generation function
    function melody = generate_melody(note_freqs, durations, fs)
        % initialize
        melody = [];
        
        % base duration
        base_duration = 0.8;
        
        % generate each note
        for i = 1:length(note_freqs)
            duration = durations(i) * base_duration;
            t = 0:1/fs:duration;
            note = sin(2*pi*note_freqs(i)*t);
            
            % fade in and out
            fade_len = round(0.05*fs);
            fade_in = linspace(0, 1, fade_len);
            fade_out = linspace(1, 0, fade_len);
            
            note(1:fade_len) = note(1:fade_len) .* fade_in;
            note(end-fade_len+1:end) = note(end-fade_len+1:end) .* fade_out;
            
            % add notes to melody
            melody = [melody, note];
        end
    end
end
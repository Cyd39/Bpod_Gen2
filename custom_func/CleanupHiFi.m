function CleanupHiFi()
% CleanupHiFi - Clean up HiFi module connection
% This function safely stops HiFi playback and releases COM port connection
% Usage: CleanupHiFi()

    try
        % Check if HiFi object exists in workspace
        if evalin('base', 'exist(''H'', ''var'')')
            H = evalin('base', 'H');
            
            % Stop HiFi playback
            H.stop();
            disp('HiFi playback stopped');
            
            % Clear HiFi object to release COM port
            evalin('base', 'clear H');
            disp('HiFi object cleared - COM port released');
        else
            disp('No HiFi object found in workspace');
        end
        
        % Additional cleanup - close any COM3 connections
        try
            com3_objects = serialportfind('Port', 'COM3');
        catch
            com3_objects = instrfind('Port', 'COM3');
        end
        if ~isempty(com3_objects)
            fclose(com3_objects);
            delete(com3_objects);
            disp('COM3 port connections closed');
        end
        
    catch ME
        disp(['Warning: Error during HiFi cleanup: ' ME.message]);
        
        % Force cleanup as last resort - only COM3
        try
            fclose('all');
            % Only close COM3 connections, preserve other serial ports
            try
                com3_objects = serialportfind('Port', 'COM3');
            catch
                com3_objects = instrfind('Port', 'COM3');
            end
            if ~isempty(com3_objects)
                fclose(com3_objects);
                delete(com3_objects);
                disp('Forced cleanup of COM3 connections only');
            end
        catch
            disp('Warning: Could not perform forced cleanup');
        end
    end
end

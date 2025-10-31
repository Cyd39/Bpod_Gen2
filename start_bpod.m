%% Bpod Startup Script
% This script properly initializes Bpod system

clear all;
close all;
clc;

% Change to Bpod directory
cd('Y:\Code\Bpod_Gen2');

% Display current directory
disp(['Current directory: ' pwd]);

% Check if Bpod.m exists
if exist('Bpod.m', 'file')
    disp('Bpod.m found - initializing Bpod system...');
    
    % Initialize Bpod
    Bpod;
    
    % Wait a moment for initialization
    pause(2);
    
    % Check BpodSystem status
    if exist('BpodSystem', 'var')
        disp('BpodSystem initialized successfully');
        disp('Bpod Status:');
        disp(BpodSystem.Status);
        
        % Check connection
        if BpodSystem.Status.BeingUsed
            disp('Bpod is connected and ready');
        else
            disp('Bpod is not connected');
        end
    else
        disp('Error: BpodSystem not initialized');
    end
else
    disp('Error: Bpod.m not found in current directory');
    disp('Please ensure you are in the correct Bpod directory');
end


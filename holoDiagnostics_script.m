% Script to run post-flight Holodec diagnostic routines 

%% Directory/file locations for current flight, edit as needed
% Hologram directories
driveA = '/Volumes/Holodec21A/CAESAR/RF03/20240302';
driveB = '/Volumes/Holodec21B/CAESAR/RF03/20240302';

% Holodec housekeeping directory (leave empty if unavailable)
housedir = '/Volumes/Holodec21A/CAESAR/RF03/Data/20240302/';

% LRT data file (leave empty if unavailable)
ncfile = '';%'/Users/bansemer/data/caesar/c130/CAESARrf02.nc';

% Optional reference data (earliest diagnostic .mat file available)
fn_reference = 'TF01_2024-02-09-16-41-29_diagnostics.mat';

%% Compare A and B drives
if exist(driveA, 'dir') && exist(driveB, 'dir')
    if driveA(end) ~= filesep; driveA = [driveA filesep]; end
    if driveB(end) ~= filesep; driveB = [driveB filesep]; end
    driveAholograms = dir([driveA '**/*.tiff']);
    driveBholograms = dir([driveB '**/*.tiff']);
    disp(['Number of DriveA holograms: '+string(length(driveAholograms))]);
    disp(['Number of DriveB holograms: '+string(length(driveBholograms))]);
end

%% Run diagnostics
fn = holoDiagnostics(driveA, 'housedir', housedir, 'ncfile', ncfile);

%% Plot diagnostics
if exist(fn_reference, 'file')
    holoDiagnosticsPlot(fn, fn_reference);
else
    holoDiagnosticsPlot(fn);
end

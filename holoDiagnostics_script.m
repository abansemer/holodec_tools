%% Script to run post-flight Holodec diagnostic routines 

%% Directory/file locations for current flight
% Hologram directories
driveA = '/Volumes/Holodec05A/CAESER/RF02';
driveB = '/Volumes/Holodec05B/CAESER/RF02';

% Holodec housekeeping directory (leave empty if unavailable)
housedir = '/Volumes/Holodec05A/CAESER/20240229_data';

% LRT data file (leave empty if unavailable)
ncfile = '/Users/bansemer/data/caesar/c130/CAESARrf02.nc';

%% Compare A and B drives
if driveA(end) ~= filesep; driveA = [driveA filesep]; end
if driveB(end) ~= filesep; driveB = [driveB filesep]; end
driveAholograms = dir([driveA '**/*.tiff']);
driveBholograms = dir([driveB '**/*.tiff']);
disp(['Number of DriveA holograms: '+string(length(driveAholograms))]);
disp(['Number of DriveB holograms: '+string(length(driveBholograms))]);

%% Run diagnostics
fn = holoDiagnostics(driveA, 'housedir', housedir, 'ncfile', ncfile);

%% Plot diagnostics
% Optional reference data (earliest diagnostic .mat file available)
fn_reference = 'RF02_2024-02-29-09-32-00_diagnostics.mat';
holoDiagnosticsPlot(fn, fn_reference);


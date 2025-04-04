function data = load_holodec_archive(ncfile, start, count, options)
% Load the vector variables of a HOLODEC particle-by-particle file 
% into memory.  Currently expects CAESAR format as of 4/2025, subject to
% change.
%
% Input arguments:
%    ncfile: The netCDF filename containing Holodec data
%    start: Particle start index to begin reading (optional)
%    count: Number of particles to read in (optional)
%    'starttime': Time (seconds) to begin file read, overrides start/count
%    'stoptime':  Time (seconds) to stop file read, overrides count
%
% Output structure:
%    Vector data as indicated in code below.  Other variables may be
%    available but not read by this routine.
%
% Example:
%    rf06 = load_holodec_archive('RF06_20240312_HOLODEC.nc');
%    holodec_psd_contour(rf06);
%    holodec_scatter3d(rf06, 37037.3);

arguments
    ncfile string
    start double = 1
    count double = Inf
    options.loadimage single = 1
    options.starttime = []
    options.stoptime = []
end

% File check
if ~exist(ncfile, 'file')
    disp('File not available');
    data = 0;
    return
end

% Get variables in the file
finfo = ncinfo(ncfile);
varnames = {finfo.Variables.Name};

% Get new start and count values if starttime/stoptime are specified
if ~isempty(options.starttime)
    time = ncread(ncfile, 'particletime');
    dummy = find(time >= options.starttime);
    start = dummy(1);
    stop = dummy(end);
    count = stop-start+1;
end
if ~isempty(options.stoptime)
    dummy = find(time <= options.stoptime);
    stop = dummy(end);
    count = stop-start+1;
end

% Get basic data in netCDF file
% More variables are available.  See documentation or variable listing in the files.
data.flightdate = ncreadatt(ncfile, '/', 'FlightDate');
data.flightname = ncreadatt(ncfile, '/', 'FlightNumber');
data.project = ncreadatt(ncfile, '/', 'ProjectName');
data.probetype = ncreadatt(ncfile, '/', 'ProbeName');
data.filename = ncfile;

% Read 1Hz arrays, reads everything regardless of start/stop arguments
data.psdtime = ncread(ncfile,'time');
data.psd = ncread(ncfile,'concentration');
data.nt = ncread(ncfile,'nt');
data.endbins = ncread(ncfile,'bin_edges');
data.midbins = ncread(ncfile,'bin_centers');

% Environmental 1Hz variables, check first if they are available
if sum(strcmp(varnames, 't')); data.t = ncread(ncfile, 't'); end
if sum(strcmp(varnames, 'lat')); data.lat = ncread(ncfile, 'lat'); end
if sum(strcmp(varnames, 'lon')); data.lon = ncread(ncfile, 'lon'); end
if sum(strcmp(varnames, 'alt')); data.alt = ncread(ncfile, 'alt'); end

% Read particle-by-particle data
% Some variable names have been added or changed so check availability first
data.particletime = ncread(ncfile, 'particletime', start, count);
data.hid = ncread(ncfile, 'hid', start, count);
data.x = ncread(ncfile, 'x', start, count);
data.y = ncread(ncfile, 'y', start, count);
data.z = ncread(ncfile, 'z', start, count);

if sum(strcmp(varnames, 'dmajor'))
    data.dmajor = ncread(ncfile, 'dmajor', start, count);
end
if sum(strcmp(varnames, 'd'))
    data.dmajor = ncread(ncfile, 'd', start, count);
end
if sum(strcmp(varnames, 'dminor'))
    data.dminor = ncread(ncfile, 'dminor', start, count);
end
if sum(strcmp(varnames, 'arearatio'))
    data.arearatio = ncread(ncfile, 'arearatio', start, count);
end
if sum(strcmp(varnames, 'ar'))
    data.arearatio = ncread(ncfile, 'ar', start, count);
end
if sum(strcmp(varnames, 'aspectratio'))
    data.aspectratio = ncread(ncfile, 'aspectratio', start, count);
end
if sum(strcmp(varnames, 'aspr'))
    data.aspectratio = ncread(ncfile, 'aspr', start, count);
end


end
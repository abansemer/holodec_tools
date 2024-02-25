function data=read_convair(ncfile)
    % Read basic data from Convair netCDF files for the 2022 ESCAPE field
    % campaign.  Put all relevant data into a structure.
    %
    % See also holoDianostics_escape.m and holoprep.m

    %Set large time range and return if no aircraft data   
    if ~isfile(ncfile)
        data.timerange = [datetime(2000,1,1), datetime(2100,1,1)];
        return
    end

    %% Get supporting data in netCDF file (NRC Convair format):
    %Add basic flight info to data structure
    data.flightnumber = upper(ncreadatt(ncfile, '/', 'FlightNumber'));
    data.flightdate = ncreadatt(ncfile, '/', 'FlightDate');
    data.project = ncreadatt(ncfile, '/', 'Project');
    data.aircraftname = ncreadatt(ncfile, '/', 'Aircraft');
    data.ncfile = ncfile;

    %Read in key variables
    nctime = ncread(ncfile,'Time')';   %Sec since 1970, transposed for some reason
    tas = ncread(ncfile,'TAS_rt');
    t = ncread(ncfile,'Ts_rt');
    pres = ncread(ncfile,'Psc_rt');
    lat = ncread(ncfile, 'lat_rt');
    lon = ncread(ncfile, 'lon_rt');
    alt = ncread(ncfile, 'alt_rt');
    w = ncread(ncfile,'vwind_rt');
    cdplwc = ncread(ncfile,'lwc_cdp_sp_rt');
    nevlwc = ncread(ncfile,'lwc_nevz_sp_rt');
    nevtwc = ncread(ncfile,'twc_nevz_sp_rt');
    rice = ncread(ncfile,'mso_rt');

    %Filter where airspeed > 50m/s to avoid long periods on ground
    inflight = find(tas > 50);
    fulltime = datetime(nctime, 'ConvertFrom', 'posixtime');
    data.timerange = [min(fulltime(inflight)), max(fulltime(inflight))];

    %Add aircraft data to the structure
    data.ncrange = [min(inflight):max(inflight)];
    aircraft.time = fulltime(data.ncrange);
    aircraft.sfm = mod(nctime(data.ncrange), 86400);
    aircraft.lat = lat(data.ncrange);
    aircraft.lon = lon(data.ncrange);
    aircraft.alt = alt(data.ncrange);
    aircraft.tas = tas(data.ncrange);
    aircraft.t = t(data.ncrange);
    aircraft.w = w(data.ncrange);
    aircraft.cdplwc = cdplwc(data.ncrange);
    aircraft.nevlwc = nevlwc(data.ncrange);
    aircraft.nevtwc = nevtwc(data.ncrange);
    aircraft.rice = rice(data.ncrange);
    data.aircraft = aircraft;
end

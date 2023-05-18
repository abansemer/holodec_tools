function data=read_ncar_aircraft(ncfile, refvar)
    % Read basic data from Convair netCDF files for the 2021 SPICULE field
    % campaign or other NCAR GV/C130 campaigns.  Put all relevant data into 
    % a structure.
    %
    % See also holoDianostics_spicule.m and holoprep.m

    arguments
        ncfile string
        refvar string = "none"
    end
    
    %Set large time range and return if no aircraft data
    if ~isfile(ncfile)
       data.timerange = [datetime(2000,1,1), datetime(2100,1,1)];
       return
    end

    %% Get supporting data in netCDF file
    data.flightnumber = upper(ncreadatt(ncfile, '/', 'FlightNumber'));
    data.flightdate = ncreadatt(ncfile, '/', 'FlightDate');
    data.ncfile = ncfile;
    nctime = ncread(ncfile,'Time');
    tas = ncread(ncfile,'TASX');
    t = ncread(ncfile,'ATX');
    w = ncread(ncfile,'WIC');
    lat = ncread(ncfile, 'GGLAT');
    lon = ncread(ncfile, 'GGLON');
    alt = ncread(ncfile, 'GGALT');
   
    %Find CDP LWC (PLWCD_XXXX)
    finfo = ncinfo(ncfile);
    cdplwc = [];
    for i = 1:length(finfo.Variables)
        if (length(finfo.Variables(i).Name) >= 6)...
                && (finfo.Variables(i).Name(1:6) == "PLWCD_")
            cdplwc = ncread(ncfile, finfo.Variables(i).Name);
        end
    end
    
    %Filter where airspeed > 50m/s to avoid long periods on ground
    inflight = find(tas > 50);
    fulltime = datenum(data.flightdate,'mm/dd/yyyy') + double(nctime)./86400;
    data.timerange = [min(fulltime(inflight)), max(fulltime(inflight))];
    
    %Add aircraft data to the structure
    data.ncrange = [min(inflight):max(inflight)];
    aircraft.time = fulltime(data.ncrange);
    aircraft.sfm = nctime(data.ncrange);
    aircraft.tas = tas(data.ncrange);
    aircraft.t = t(data.ncrange);
    aircraft.w = w(data.ncrange);
    aircraft.lat = lat(data.ncrange);
    aircraft.lon = lon(data.ncrange);
    aircraft.alt = alt(data.ncrange);
    
    %Get CDP data
    if length(cdplwc) == length(nctime)   %Have data
        aircraft.cdplwc = cdplwc(data.ncrange);
    else   %No CDPLWC available
        aircraft.cdplwc = cdplwc;
    end
    
    %Get reference data for holoprep (usually CDP)
    gotrefdata = false;
    for i = 1:length(finfo.Variables)
        if finfo.Variables(i).Name == refvar
            refdata = ncread(ncfile, finfo.Variables(i).Name);
            aircraft.refdata = refdata(data.ncrange);
            gotrefdata = true;
        end
    end
    
    data.aircraft = aircraft;
end

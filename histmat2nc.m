function fnout = histmat2nc(options)
    % Read a hist.mat file(s) from HoloSuite, apply particle rejection and
    % sorting, and save the results in a netCDF file for testing/archival.
    %
    % indir: Directory tree containing hist.mat or scalar.mat files
    % ruleset: Rejection ruleset to apply for particle rejection
    % roundruleset: Rejection ruleset to apply for round particle rejection
    % ncfile:  Aircraft data file in netCDF format (NCAR compatible)
    % outdir:  Output directory
    % [xyz]min:  Minumum range for cropping hologram volume (meters)
    % [xyz]max:  Maximum range for cropping hologram volume (meters)
    % writeimages:  Write images to PNG files (1=accepted, 2=accepted+rejected)
    % writeimages_minsize:  Minimum size for image export (meters)
    % bullseyecorrect:  Remove particles near the 'bullseye' feature in SPICULE/ESCAPE
    %     (1=delicate, 2=aggressive).  See boundaries in holodec_ruleset.m.
    %
    % Example:
    %    fn = histmat2nc('indir', 'RF01', 'ruleset', 8, 'ncfile', fn.nc)
    %
    % See also minicarft.m, holodec_ruleset.m

    arguments
        options.indir char = '.'
        options.ruleset {mustBeInteger} = 0
        options.roundruleset {mustBeInteger} = 0  %A value of zero will suppress round variables
        options.ncfile char = ''  %This is for the aircraft data
        options.outdir char = ''
        options.housekeepingfile char = ''  %Housekeeping data (not yet implemented)
        options.xmin = []   %Custom crop ranges to be passed into holodec_ruleset.m
        options.xmax = []   %If set to empty then defaults in holodec_ruleset will apply.
        options.ymin = []
        options.ymax = []
        options.zmin = []
        options.zmax = []
        options.writeimages {mustBeInteger} = 0
        options.writeimages_minsize {mustBeNumeric} = 0
        options.bullseyecorrect {mustBeInteger} = 0
        options.timeoffset {mustBeFloat} = 0
    end

    if (options.ruleset == 0)
        disp('Need to specify ruleset option')
        return
    end

    % If fn is a directory get all of the hist.mat or scalar.mat files in the tree
    if exist(options.indir, 'dir') == 7
        %Add trailing slash if necessary
        if (numel(options.indir) > 0) && (options.indir(end) ~= filesep)
            options.indir = [options.indir filesep];
        end

        matfiles = dir([options.indir '**/*_hist.mat']);

        % Check for 'scalar.mat' files if no 'hist.mat' files found
        if length(matfiles) == 0
            matfiles = dir([options.indir '**/*_scalar.mat']);
        end
    end

    % Return if no files available
    if length(matfiles) == 0
        disp(['No hist.mat or scalar.mat files found in: ' options.indir]);
        fnout='null';
        return
    end

    % Make sure files are sorted by name/time
    matfilenames = string(struct2cell(matfiles));    % Makes sorting by filename possible
    [~, isort] = sort(matfilenames(1,:));
    matfiles = matfiles(isort);
    [firstimagetime, prefix] = holoNameParse(matfiles(1).name, options.timeoffset);
    lastimagetime = holoNameParse(matfiles(end).name, options.timeoffset);
    [y,m,d] = ymd(firstimagetime);
    startdate = datetime(y, m, d);

    %Time range from images, will be overwritten if aircraft data exists
    timerange = [firstimagetime, lastimagetime];

    %% Get supporting aircraft data if available
    gotaircraft = false;
    if exist(options.ncfile, 'file')
        flightdate = ncreadatt(options.ncfile, '/', 'FlightDate');  %This works for all projects so far, may need to change later
        if (flightdate(1:4) == "2022")
            %ESCAPE 2022 NRC Convair
            ac = read_convair(options.ncfile);
            gotaircraft = true;
        else
            %SPICULE 2021 or other GV/C130 project
            ac = read_ncar_aircraft(options.ncfile);
            gotaircraft = true;
        end

        if ac.aircraft.sfm(2)-ac.aircraft.sfm(1) ~= 1
            disp('Aircraft data must be 1Hz');
            return
        end

        %Use this time range instead of Holodec image start/stop
        timerange = ac.timerange;
    end

    %% Get supporting housekeeping/diagnostic data if available
    %  Will come from .mat file created by holoDiagnostics_escape or
    %  holoDiagnostics_spicule,  in a structure named 'data'.
    %  ...not yet implemented, reconsidering if needed since will need
    %  another time variable for individual hologram brightness, and
    %  the internal temperatures and background diagnostics are not really
    %  necessary in this file.
    gothousekeeping = false;
    if exist(options.housekeepingfile, 'file')
        %gothousekeeping = true;
        load(options.housekeepingfile);
        %Available variables will vary by project
    end

    %% Set up count/concentration variables
    starttime_sfm = floor(seconds(timerange(1)-startdate));
    stoptime_sfm = floor(seconds(timerange(2)-startdate));
    conctime = starttime_sfm:1:stoptime_sfm;
    endbins = [10:2:48, 50:5:95, 100:10:190, 200:50:450, 500:100:2000];
    binwidth = endbins(2:end) - endbins(1:end-1);
    midbins = (endbins(2:end) + endbins(1:end-1))./2;
    counts = zeros(length(conctime), length(midbins));
    countsround = zeros(length(conctime), length(midbins));
    concnorm = zeros(length(conctime), length(midbins));
    concroundnorm = zeros(length(conctime), length(midbins));
    lwc = zeros(1, length(conctime));
    mvd = zeros(1, length(conctime));
    nholograms = zeros(1, length(conctime));   %Number per time period (~3)

    %% Set up the netCDF file

    % Make output directory
    if ~exist(options.outdir)
        status = mkdir(options.outdir);
    end

    % Add trailing slash to outdir if necessary
    if (numel(options.outdir) > 1) && (options.outdir(end) ~= filesep)
        options.outdir = [options.outdir filesep];
    end
    fnout = [options.outdir char(prefix) '_' char(startdate, 'yyyyMMdd') '_HOLODEC.nc'];
    cmode = netcdf.getConstant('NETCDF4');

    if exist(fnout, 'file')  %Clobber not supported, use system
       delete(fnout)
    end
    ncid = netcdf.create(fnout, cmode);

    % Dimensions
    particle_dimid = netcdf.defDim(ncid, 'particle', netcdf.getConstant('NC_UNLIMITED'));
    conctime_dimid = netcdf.defDim(ncid, 'time', length(conctime));
    midbins_dimid = netcdf.defDim(ncid, 'bin_centers', length(midbins));
    endbins_dimid = netcdf.defDim(ncid, 'bin_edges', length(endbins));

    % Variables and attributes
    ncdfprops = {'time', 'UTC time for concentration arrays and bulk variables', 'Seconds from midnight of start date', conctime_dimid;
        'bin_edges', 'Upper/lower edges of concentration size bins', 'microns', endbins_dimid;
        'bin_centers', 'Center value of concentration size bins', 'microns', midbins_dimid;
        'concentration', 'Particle number concentration, normalized by bin width', '#/m4', [conctime_dimid, midbins_dimid];
        'nt', 'Total number concentration', '#/m3', conctime_dimid;
        'particletime', 'UTC time of individual cloud particles', 'Seconds from midnight of start date', particle_dimid;
        'hid', 'Hologram identification number', 'unitless', particle_dimid;
        'd', 'Particle diameter', 'microns', particle_dimid;
        'x', 'Particle x-position (origin at center of hologram)', 'microns', particle_dimid;
        'y', 'Particle y-position (origin at center of hologram)', 'microns', particle_dimid;
        'z', 'Particle z-position (origin at object plane)', 'microns', particle_dimid;
        'aspr', 'Particle aspect ratio', 'unitless', particle_dimid;
        'ar', 'Particle area ratio', 'unitless', particle_dimid};
    if options.roundruleset ~= 0
        % Add round variables if a ruleset is available
        ncdfprops(end+1:end+4,:) = ...
        {'concentration_round', 'Particle number concentration of round particles, normalized by bin width', '#/m4', [conctime_dimid, midbins_dimid];
        'lwc_round', 'Derived liquid water content using round particles', 'g/m3', conctime_dimid;
        'mvd_round', 'Median volume diameter using round particles', 'microns', conctime_dimid;
        'dmean_round', 'Mean diameter using round particles', 'microns', conctime_dimid};
    end
    if gotaircraft
        % Append aircraft variables if available
        ncdfprops(end+1:end+4,:) = {'lat', 'Latitude', 'degrees North', conctime_dimid;
        'lon', 'Longitude', 'degrees East', conctime_dimid;
        'alt', 'GPS Altitude', 'meters', conctime_dimid;
        't', 'Ambient Temperature', 'C', conctime_dimid};
    end

    for i = 1:length(ncdfprops)
        varid = netcdf.defVar(ncid, ncdfprops{i,1}, 'NC_DOUBLE', ncdfprops{i,4});
        netcdf.putAtt(ncid, varid, 'longname', ncdfprops{i,2});
        netcdf.putAtt(ncid, varid, 'units', ncdfprops{i,3});
        netcdf.defVarDeflate(ncid, varid, true, true, 5);   %Turn on compression
    end

    % Write global attributes
    varid = netcdf.getConstant('NC_GLOBAL');  %Need to set for global atts
    netcdf.putAtt(ncid, varid, 'ProbeName', 'HOLODEC');
    netcdf.putAtt(ncid, varid, 'Source', 'HoloSuite (reconstructions and particle metrics); NCAR tools (particle analysis)');
    %netcdf.putAtt(ncid, varid, 'DataContact', 'Aaron Bansemer (bansemer@ucar.edu)');
    netcdf.putAtt(ncid, varid, 'FlightDate', string(startdate, 'yyyy/MM/dd'));
    timeintervalstring = [char(timerange(1), 'hh:mm:ss') '-' char(timerange(2), 'hh:mm:ss')];
    netcdf.putAtt(ncid, varid, 'TimeInterval', string(timeintervalstring));
    if gotaircraft
        netcdf.putAtt(ncid, varid, 'ProjectName', ac.project);
        netcdf.putAtt(ncid, varid, 'Platform', ac.aircraftname);
        netcdf.putAtt(ncid, varid, 'FlightNumber', ac.flightnumber);
    end
    netcdf.putAtt(ncid, varid, 'Ruleset', options.ruleset);
    if options.roundruleset >0
        netcdf.putAtt(ncid, varid, 'RoundRuleset', options.roundruleset);
    end
    netcdf.putAtt(ncid, varid, 'TimeOffsetSeconds', single(options.timeoffset));
    netcdf.putAtt(ncid, varid, 'date_created', string(datetime('today'), 'yyyy/MM/dd'));
    netcdf.endDef(ncid);  %Enter data mode

    % Write time and bin sizes
    netcdf.putVar(ncid, netcdf.inqVarID(ncid, 'time'), conctime)
    netcdf.putVar(ncid, netcdf.inqVarID(ncid, 'bin_centers'), midbins)
    netcdf.putVar(ncid, netcdf.inqVarID(ncid, 'bin_edges'), endbins)

    % Save variable ids for use when writing
    xvarid = netcdf.inqVarID(ncid, 'x');
    yvarid = netcdf.inqVarID(ncid, 'y');
    zvarid = netcdf.inqVarID(ncid, 'z');
    dvarid = netcdf.inqVarID(ncid, 'd');
    particletimevarid = netcdf.inqVarID(ncid, 'particletime');
    hidvarid = netcdf.inqVarID(ncid, 'hid');
    arvarid = netcdf.inqVarID(ncid, 'ar');
    asprvarid = netcdf.inqVarID(ncid, 'aspr');

    %% Read each hist.mat/scalar.mat file and write individual particles to netCDF
    disp('');
    offset = 0;
    for i = 1:length(matfiles)
        % Use minicarft to apply rules
        pStats = minicarft([matfiles(i).folder filesep matfiles(i).name],...
            options.ruleset, 'roundruleset', options.roundruleset, 'noplot', 1,...
            'xmin', options.xmin, 'xmax', options.xmax,...
            'ymin', options.ymin, 'ymax', options.ymax,...
            'zmin', options.zmin, 'zmax', options.zmax,...
            'sizmin', min(endbins/1e6), 'sizmax', max(endbins/1e6),...
            'bullseyecorrect', options.bullseyecorrect);
        if pStats.error == 0
            imagetime = holoNameParse(matfiles(i).name, options.timeoffset);
            imagesfm = floor(seconds(imagetime - startdate));
            imagesfm_full = round(seconds(imagetime - startdate), 3); %Round to 3 digits

            NParticles = length(pStats.good);
            if NParticles > 0
                netcdf.putVar(ncid, xvarid, offset, NParticles, [pStats.xpos(pStats.good)]*1e6)
                netcdf.putVar(ncid, yvarid, offset, NParticles, [pStats.ypos(pStats.good)]*1e6)
                netcdf.putVar(ncid, zvarid, offset, NParticles, [pStats.zpos(pStats.good)]*1e6)
                netcdf.putVar(ncid, dvarid, offset, NParticles, [pStats.majsiz(pStats.good)]*1e6)
                netcdf.putVar(ncid, arvarid, offset, NParticles, [pStats.arearatio(pStats.good)])
                netcdf.putVar(ncid, asprvarid, offset, NParticles, [pStats.asprat(pStats.good)])
                netcdf.putVar(ncid, hidvarid, offset, NParticles, zeros(1, NParticles)+i)
                netcdf.putVar(ncid, particletimevarid, offset, NParticles, zeros(1, NParticles)+imagesfm_full)
            end
            % Update offset for next netCDF write
            offset = offset + NParticles;

            % Add particles to the concentration array
            icount = find(conctime==imagesfm);
            counts(icount,:) = counts(icount,:) + histcounts(pStats.majsiz(pStats.good)*1e6, endbins);
            if options.roundruleset ~= 0
                countsround(icount,:) = countsround(icount,:) + histcounts(pStats.majsiz(pStats.goodround)*1e6, endbins);
            end
            nholograms(icount) = nholograms(icount)+1;

            % Write accepted images to png
            if options.writeimages
                %Use minsize threshold to avoid writing small images
                w = find(pStats.majsiz(pStats.good) > options.writeimages_minsize);
                wbad = find(pStats.majsiz(pStats.bad) > options.writeimages_minsize);

                %Get the image panel and write good images to png
                if ~isempty(w)
                    imagepanel = display_histmat_particles(pStats, pStats.good(w), ...
                        'noplot', 1, 'collagewidth', 1200);
                    imagename = [options.outdir char(prefix) '_' char(imagetime, 'yyyyMMdd_HH-mm-ss-SSSSSS') '_accepted.png'];
                    imwrite(imagepanel', imagename);
                end

                %Get the image panel and write bad images to png
                if ~isempty(wbad) && (options.writeimages == 2)
                    imagepanel = display_histmat_particles(pStats, pStats.bad(wbad), ...
                        'noplot', 1, 'collagewidth', 1200);
                    imagename = [options.outdir char(prefix) '_' char(imagetime, 'yyyyMMdd_HH-mm-ss-SSSSSS') '_rejected.png'];
                    imwrite(imagepanel', imagename);
                end

            end

            %Show progress
            if mod(i,100) == 0
                %fprintf(repmat('\b',1,20));    %Backup
                fprintf('%d / %d \n',[i,length(matfiles)]);
            end
        end
    end

    %% Compute concentration array and bulk parameters
    sv = nholograms * pStats.samplevolume.total;
    for i = 1:length(conctime)
        if nholograms(i) > 0
            concnorm(i,:) = counts(i,:)./(binwidth/1e6)/sv(i);  % #/m4
            concroundnorm(i,:) = countsround(i,:)./(binwidth/1e6)/sv(i);  % #/m4
       end
    end
    bulk = compute_bulk_simple(concnorm, endbins);


    %% Write concentration and bulk to netCDF
    netcdf.putVar(ncid, netcdf.inqVarID(ncid, 'nt'), bulk.nt)
    netcdf.putVar(ncid, netcdf.inqVarID(ncid, 'concentration'), concnorm)
    if options.roundruleset ~= 0
        bulkround = compute_bulk_simple(concroundnorm, endbins);
        netcdf.putVar(ncid, netcdf.inqVarID(ncid, 'lwc_round'), bulkround.lwc)
        netcdf.putVar(ncid, netcdf.inqVarID(ncid, 'mvd_round'), bulkround.mvd)
        netcdf.putVar(ncid, netcdf.inqVarID(ncid, 'dmean_round'), bulkround.dmean)
        netcdf.putVar(ncid, netcdf.inqVarID(ncid, 'concentration_round'), concroundnorm)
    end
    if gotaircraft
        netcdf.putVar(ncid, netcdf.inqVarID(ncid, 'lat'), ac.aircraft.lat)
        netcdf.putVar(ncid, netcdf.inqVarID(ncid, 'lon'), ac.aircraft.lon)
        netcdf.putVar(ncid, netcdf.inqVarID(ncid, 'alt'), ac.aircraft.alt)
        netcdf.putVar(ncid, netcdf.inqVarID(ncid, 't'), ac.aircraft.t)
    end
    if gothousekeeping
        %Not yet implemented
    end

    %Add final global attributes now that we have pStats data
    globaloptions = struct('xmin_meters', single(pStats.samplevolume.xmin), ...
        'xmax_meters', single(pStats.samplevolume.xmax), ...
        'ymin_meters', single(pStats.samplevolume.ymin), ...
        'ymax_meters', single(pStats.samplevolume.ymax), ...
        'zmin_meters', single(pStats.samplevolume.zmin), ...
        'zmax_meters', single(pStats.samplevolume.zmax), ...
        'rejectedvolume_m3', single(pStats.samplevolume.rejected), ...
        'samplevolume_m3', single(pStats.samplevolume.total));
    tags = fieldnames(globaloptions);

    varid = netcdf.getConstant('NC_GLOBAL');  %Need to set for global atts
    for i = 1:length(tags)
       attdata = getfield(globaloptions, tags{i});
       if islogical(attdata)  %netCDF req
           attdata = uint8(attdata);
       end
       if length(attdata) >= 1
           netcdf.putAtt(ncid, varid, tags{i}, attdata);
       end
    end

    netcdf.close(ncid);
end

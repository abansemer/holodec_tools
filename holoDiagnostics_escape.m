function fnout=holoDiagnostics_escape(imagedir, options)
    % holoDiagnostics_escape  Given a directory of holograms, save a file 
    %   with diagnostic information about image times, brightness, and 
    %   background.  Use holoDiagnosticsPlot(fnout) to create figures from 
    %   this file.
    %
    %   Examples:   
    %   fnout = holoDiagnostics_escape(imagepath)
    %       Generate a .mat file based on all tiff files found in the 
    %       imagepath and its subdirectories.
    %
    %   fnout = holoDiagnostics_escape(imagepath, 'ncfile', ncfile)
    %       Add select variables from the aircraft netCDF file to
    %       the output, including temperature, CDP concentration, etc.
    %
    %   fnout = holoDiagnostics_escape(imagepath, 'housedir', housedir)
    %       Add housekeeping data collected by Holodec to the output
    %       file.  These files should be in a directory and will have name
    %       HolodecData_*.txt
    %
    %   fnout = holoDiagnostics_escape('housedir', housedir)
    %       Generate a .mat file with only housekeeping data (no images).
    %
    %   See also holoDiagnosticsPlot.m.

    %This version is for Holodec data in 2022 which records .tiff files 
    %instead of .seq files.

    % Arrange arguments
    arguments
       imagedir char = ''
       options.ncfile char = ''
       options.housedir char = ''
    end

 
    %% Get supporting data in netCDF file (NCAR format):
    % Still awaiting Convair data for testing
    if isfile(options.ncfile)
        %Add basic flight info to data structure
        data.flightnumber = upper(ncreadatt(ncfile, '/', 'FlightNumber'));
        data.flightdate = ncreadatt(ncfile, '/', 'FlightDate');
        data.ncfile = ncfile;
        
        %Read in key variables
        nctime = ncread(ncfile,'Time');
        tas = ncread(ncfile,'TASX');
        t = ncread(ncfile,'ATX');
        w = ncread(ncfile,'WIC');
        cdplwc = ncread(ncfile,'PLWCD_LWOO');
        
        %Filter where airspeed > 50m/s to avoid long periods on ground
        inflight = find(tas > 50);
        fulltime = datenum(data.flightdate,'mm/dd/yyyy') + double(nctime)./86400;
        timerange = [min(fulltime(inflight)), max(fulltime(inflight))];
        
        %Add aircraft data to the data structure
        data.ncrange = [min(inflight):max(inflight)];
        data.nctime = nctime(data.ncrange);
        data.tas = tas(data.ncrange);
        data.t = t(data.ncrange);
        data.w = w(data.ncrange);
        data.cdplwc = cdplwc(data.ncrange);
    else
        timerange = [0,999999];
    end
    
    %% Get supporting data from Holodec housekeeping files (txt format):
    % Provided by Robert Stillwell 6/2022
    if isfolder(options.housedir)
        % Loading data
        s = dir(fullfile(options.housedir,'HolodecData_*.txt'));
        house = [];
        for m=1:1:size(s,1)
           Temp = readmatrix(fullfile(options.housedir,s(m,1).name));
           A = ~isnan(Temp(:,20:end));
           if size(A,2) ~= 0
               B = sum(A,2);
               B(B>=1) = 1;
               Temp(B==1,:) = [];
               Temp(:,20:end) = [];
           end
           house = [house;Temp;nan.*zeros(1,19)];
        end

        % Removing bad data
        house(house == -99) = nan;
        house(house == -999) = nan;
        house(house == -1000) = nan;
        house(abs(house) > 3000) = nan;

        % Checking for laser errors
        LaserError = house(:,3);
        house(:,3)  = mod(house(:,3),8);
        LaserError = double(not((LaserError - house(:,3))==0 | isnan(LaserError - house(:,3))));
        LaserError(LaserError==0) = nan;

        % Checking the interlock status
        house(isnan(house(:,2)),2) = 0;
        % Extracting interlocks from binary "Relay"
        Interlocks = cell2mat(arrayfun(@(x) dec2bin(x,6)-'0',house(:,2),'uni',false));
        Interlocks(isnan(house(:,2)),:) = nan;
        Interlocks(Interlocks==0) = nan;
        Interlocks = Interlocks .* [0,1,2,3,4,5];
        
        %Arrange into a structure and add to 'data'
        hk.time = house(:,1)*3600.0;  %seconds
        hk.LaserStatus = house(:,3);
        hk.PowerOutput = house(:,4);
        hk.Interlocks = Interlocks;
        hk.LaserError = LaserError;
        hk.tsetpoints = house(:,10:14)./10;  %degC
        hk.tobserved = house(:,15:19)./10;
        hk.tlabels = {'Camera','Laser Head','Cam. Tip', 'Laser Tip', 'L. Controller'};
        data.hk = hk;
        
        %Save data now if no images are available
        if ~isfolder(imagedir)
            datepat = digitsPattern(8);
            data.date = extract(s(1).name, datepat);
            fnout = data.date + "_housekeeping.mat";
            disp("Saving: " + fnout);
            save(fnout, 'data');
        end
    end
 
    %% Get image filenames
    if ~isfolder(imagedir); disp("Image directory not found: "+imagedir); return; end
    %Add trailing slash if necessary
    if imagedir(end) ~= filesep; imagedir = [imagedir filesep]; end
    imagefiles=dir([imagedir '*.tiff']);     %If all images are in main flight directory
    if length(imagefiles)==0       %If all are in subdirectories by hour and minute
        imagefiles=dir([imagedir '**/*.tiff']);
    end
    nholograms=length(imagefiles);
    fullsizeinterval = min([100, nholograms]);   %Read a full size hologram at this interval
    nfullholograms=floor(nholograms/fullsizeinterval);

    %% Initialize Holodec variables
    data.imagetime = [];
    data.fullimagetime = [];
    data.brightness = [];
    data.fullsizebrightness = [];
    data.framenum = [];
    data.imagehist = [];
    data.histogram_edges = 0:1:255;
    
    %% Read first image to get basic info
    fullImage = imread([imagefiles(1).folder filesep imagefiles(1).name]);
    meanbackground = zeros(size(fullImage));
    [imagetime, prefix] = holoNameParse(imagefiles(1).name);
    data.date = datestr(imagetime, 'yyyy-mm-dd-HH-MM-SS');
    data.prefix = prefix{1};

    %% Get data for each tiff file and add to struct
    ngood = 0;  %Keep track of number of good (bright) full holograms
    c = 1;      %Keep track of number of all tiff files in time range
    cfull = 1;  %Index of full-size images read in
    for i = 1:length(imagefiles)
        [imagetime, prefix] = holoNameParse(imagefiles(i).name);
        if (imagetime > timerange(1)) && (imagetime < timerange(2))
       
            %Read in the entire hologram every fullsizeinterval (~100) images
            if mod(c, fullsizeinterval) == 0
                fullImage = imread([imagefiles(i).folder filesep imagefiles(i).name]);
                data.fullimagetime(cfull) = imagetime;
                data.fullsizebrightness(cfull) = mean(fullImage, 'all');
                fullHistogram = histcounts(fullImage, data.histogram_edges);
                data.imagehist = [data.imagehist; fullHistogram];
                cfull = cfull+1;
                %Record mean background if have valid image
                if median(fullImage, 'all') > 30
                    meanbackground = meanbackground + double(fullImage);
                    ngood = ngood+1;
                end
            end

            %Read in a small portion of every hologram
            fid = fopen([imagefiles(i).folder filesep imagefiles(i).name], 'r');
            fseek(fid,5000000,'bof');
            patchImage = fread(fid,3000,'uint8=>uint8');
            fclose(fid);

            %2x slower: patchImage = imread([imagefiles(i).folder filesep imagefiles(i).name],'PixelRegion',{[2000,2000],[2000,3000]});       
            data.imagetime = [data.imagetime imagetime];
            data.brightness = [data.brightness mean(patchImage, 'all')];
            c = c + 1;
        end
        
        %Show progress
        if mod(i,50) == 0
            fprintf(repmat('\b',1,20));    %Backup
            fprintf('%d / %d ',[i,length(imagefiles)]);
        end
    end

    %% Normalize the background
    data.meanbackground = meanbackground ./ ngood;

    %% Save data
    if c > 0
        fnout = data.date + "_diagnostics.mat";
        disp("Saving: " + fnout);
        save(fnout, 'data');
    else
        disp('No data found in timerange of netCDF file');
    end
end

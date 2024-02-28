function fnout=holoDiagnostics(imagedir, options)
    % holoDiagnostics_escape  Given a directory of holograms, save a file 
    %   with diagnostic information about image times, brightness, and 
    %   background.  Use holoDiagnosticsPlot(fnout) to create figures from 
    %   this file.
    %
    %   Examples:   
    %   fnout = holoDiagnostics(imagepath)
    %       Generate a .mat file based on all tiff files found in the 
    %       imagepath and its subdirectories.
    %
    %   fnout = holoDiagnostics(imagepath, 'ncfile', ncfile)
    %       Add select variables from the aircraft netCDF file to
    %       the output, including temperature, CDP concentration, etc.
    %
    %   fnout = holoDiagnostics(imagepath, 'housedir', housedir)
    %       Add housekeeping data collected by Holodec to the output
    %       file.  These files should be in a directory and will have name
    %       HolodecData_*.txt
    %
    %   fnout = holoDiagnostics('housedir', housedir)
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
       options.flightid char = ''
       options.fingerprint {mustBeNumeric} = 0
       options.platform char = 'C130'  %or 'Convair' for ESCAPE
    end

 
    %% Get supporting data in netCDF file (NCAR or NRC Convair format):
    if isfile(options.ncfile)
        if strcmp(options.platform, 'Convair')
            data = read_convair(options.ncfile);
        else 
            data = read_ncar_aircraft(options.ncfile);
        end
    end
    
    %% Get image filenames
    if ~isfolder(imagedir); disp("Image directory not found: "+imagedir); return; end
    %Add trailing slash if necessary
    if imagedir(end) ~= filesep; imagedir = [imagedir filesep]; end
    
    %Find all matching images in main directory
    imagefiles=dir([imagedir options.flightid '*.tiff']);
    
    %If no images, search in subdirectories by hour and minute
    if length(imagefiles)==0
        imagefiles=dir([imagedir '**/' options.flightid '*.tiff']);
    end
    nholograms=length(imagefiles);
    if nholograms == 0
        disp(['No holograms found with id: ' options.flightid]);
        return
    end
    fullsizeinterval = min([100, nholograms]);   %Read a full size hologram at this interval
    nfullholograms=floor(nholograms/fullsizeinterval);

    %% If the timerange isn't already available from other source, get from holograms
    if ~exist('data', 'var')
        [imagetime, prefix] = holoNameParse(imagefiles(1).name);
        data.timerange = [imagetime, imagetime];  %Initialize with first hologram
        for i = 1:length(imagefiles)
            [imagetime, prefix] = holoNameParse(imagefiles(i).name);
            if imagetime < data.timerange(1)
                data.timerange(1) = imagetime;
            end
            if imagetime > data.timerange(2)
                data.timerange(2) = imagetime;
            end
        end
    end
    data.timerange

    %% Get supporting data from Holodec housekeeping files (txt format):
    % Provided by Robert Stillwell 6/2022
    if isfolder(options.housedir)
        % Loading data
        s = dir(fullfile(options.housedir,'HolodecData_*.txt'));
        datepat = digitsPattern(8);
        
        house = [];
        housetime = datetime([],[],[]);
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
            datestring = char(extract(s(m,1).name, datepat));
            househour = floor(Temp(:,1));
            timesec = Temp(:,1)*3600.0;   %Seconds
            housemin = floor(mod(timesec, 3600)/60);
            housesec = floor(mod(timesec, 60));
            housemsec = mod(timesec, 1);
            thishousetime = datetime(str2num(datestring(1:4)), ...
                str2num(datestring(5:6)), str2num(datestring(7:8)),...
                househour, housemin, housesec, housemsec);
            housetime = [housetime thishousetime'];
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
        hkrange = find((housetime >= data.timerange(1)) & (housetime <= data.timerange(2)));
        hk.sfm = (house(hkrange,1)*3600.0)';  %seconds
        hk.time = housetime(hkrange);
        hk.LaserStatus = house(hkrange,3)';
        hk.PowerOutput = house(hkrange,4)';
        hk.Interlocks = Interlocks(hkrange,:)';
        hk.LaserError = LaserError(hkrange,:)';
        hk.tsetpoints = (house(hkrange,10:14)./10)';  %degC
        hk.tobserved = (house(hkrange,15:19)./10)';
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
 

    %% Initialize Holodec variables
    data.imagetime = datetime([],[],[]);
    data.fullimagetime = datetime([],[],[]);
    data.brightness = [];
    data.fullsizebrightness = [];
    data.framenum = [];
    data.imagehist = [];
    data.fingerprintdiff = [];
    data.histogram_edges = 0:1:255;
    data.filename =[];
    fpref = zeros(10, 15);  %Reference fingerprint, will be updated at first valid background
    
    %% Read first image to get basic info
    fullImage = imread([imagefiles(1).folder filesep imagefiles(1).name]);
    meanbackground = zeros(size(fullImage));
    [imagetime, prefix] = holoNameParse(imagefiles(1).name);
    data.date = string(imagetime, 'yyyy-MM-dd-HH-mm-ss');
    data.prefix = prefix{1};

    %% Get data for each tiff file and add to struct
    ngood = 0;  %Keep track of number of good (bright) full holograms
    c = 1;      %Keep track of number of all tiff files in time range
    cfull = 1;  %Index of full-size images read in
    for i = 1:length(imagefiles)
        [imagetime, prefix] = holoNameParse(imagefiles(i).name);
        if (imagetime > data.timerange(1)) && (imagetime < data.timerange(2))
       
            %Read in the entire hologram every fullsizeinterval (~100) images
            if mod(c, fullsizeinterval) == 1
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
                if options.fingerprint
                    fpref = hologram_fingerprint(uint8(meanbackground ./ ngood));
                end
            end

            %Read in a small portion of every hologram
            fid = fopen([imagefiles(i).folder filesep imagefiles(i).name], 'r');
            fseek(fid,5000000,'bof');
            patchImage = fread(fid,3000,'uint8=>uint8');
            fclose(fid);
            %2x slower: patchImage = imread([imagefiles(i).folder filesep imagefiles(i).name],'PixelRegion',{[2000,2000],[2000,3000]});       
            
            %Make a fingerprint if flagged.  Will need full image for this.
            if options.fingerprint               
                fullImage = imread([imagefiles(i).folder filesep imagefiles(i).name]);
                fp = hologram_fingerprint(fullImage);
                fpdiff = sum(fp ~= fpref, 'all');  %Reference is based on background to date
                data.fingerprintdiff = [data.fingerprintdiff fpdiff];
            end
            
            data.imagetime = [data.imagetime imagetime];
            data.brightness = [data.brightness mean(patchImage, 'all')];
            data.filename = [data.filename string([imagefiles(i).folder filesep imagefiles(i).name])];
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
        fnout = string(data.prefix) + "_" + data.date + "_diagnostics.mat";
        disp("Saving: " + fnout);
        save(fnout, 'data');
    else
        disp('No data found in timerange of netCDF file');
    end
end

function fnout=holoDiagnostics_escape(imagedir, ncfile)
    %Given a directory of holograms, save a file with diagnostic
    %information about image times, brightness, etc.  Use
    %holoDiagnosticsPlot.m to create figures from this file.
    
    %This version is for Holodec data in 2022 which records .tiff files 
    %instead of .seq files.

    %Add trailing slash to directory and get filenames 
    if imagedir(end) ~= filesep; imagedir = [imagedir filesep]; end
    imagefiles=dir([imagedir '*.tiff']);     %If all images are in main flight directory
    if length(imagefiles)==0       %If all are in subdirectories by hour and minute
        imagefiles=dir([imagedir '**/*.tiff']);
    end
    nholograms=length(imagefiles);
    fullsizeinterval = min([100, nholograms]);   %Read a full size hologram at this interval
    nfullholograms=floor(nholograms/fullsizeinterval);

    %Get supporting data in netCDF file (NCAR format):
    if exist('ncfile')
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
    
    %Initialize Holodec variables
    data.imagetime = [];
    data.fullimagetime = [];
    data.brightness = [];
    data.fullsizebrightness = [];
    data.framenum = [];
    data.imagehist = [];
    data.histogram_edges = 0:1:255;
    
    %Read first image to get basic info
    fullImage = imread([imagefiles(1).folder filesep imagefiles(1).name]);
    meanbackground = zeros(size(fullImage));
    [imagetime, prefix] = holoNameParse(imagefiles(1).name);
    data.date = datestr(imagetime, 'yyyy-mm-dd-HH-MM-SS');
    data.prefix = prefix{1};

    %Get data for each tiff file and add to struct
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

    %Normalize the background
    data.meanbackground = meanbackground ./ ngood;

    %Save data
    if c > 0
        fnout = data.date + "_diagnostics.mat";
        disp("Saving: " + fnout);
        save(fnout, 'data');
    else
        disp('No data found in timerange of netCDF file');
    end
end

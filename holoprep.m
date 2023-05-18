function data = holoprep(options)
    % Find and save PNG files from a directory full of seq/tiff files that meet 
    % the criteria for processing.  Will use a GV/C130 netCDF file with CDP
    % (or other) data to find where cloud exists, with some padding
    % before/after cloud.
    %
    % rawdir: directory containing Holodec *.seq or *.tiff files
    % outdir: directory to save the output, defaults to /glade/scratch/user/holoprep_[flightid]
    % ncfile: netCDF file containing CDP or other variable to detect cloud
    % refvar: netCDF tag for the variable to use as reference
    % thresh: lower threshold to apply on refvar (maybe change to a range?)
    % starttime/stoptime: time range limits in seconds (defaults to full flight)
    % flightid: flight name string, will use to search for image files
    %
    % Example:
    % x=holoprep('rawdir', '/glade/campaign/eol/archive/2021/spicule/aircraft/gv_n677f/holodec/RF04',...
    %   'outdir', '.', ...
    %   'ncfile', 'gv/SPICULErf04.nc', ...
    %   'refvar', 'PLWCD_LWOO', ...
    %   'thresh', 0.001, ...
    %   'flightid', 'RF04');
    %
    % See also convert_all_seqfiles.m for converting without netCDF data.

    arguments
       options.rawdir char = ''
       options.ncfile char = ''
       options.refvar char = ''
       options.thresh (1,1) double = 0.001
       options.starttime (1,1) double = 0.0       %In seconds from midnight
       options.stoptime (1,1) double = 999999.0   %In seconds from midnight
       options.flightid char = ''
       options.outdir char = 'dummyfolder'
    end

    %% File management
    %Add file separator if necessary and get file listing
    if options.rawdir(end) ~= filesep; options.rawdir=[options.rawdir filesep]; end;
    
    %Check for seq files (2022)
    imagefiles = dir([options.rawdir '*.seq']);
    format = "seq";
    
    %Check for tiff files (2023+)
    if length(imagefiles) == 0
        imagefiles = dir([options.rawdir options.flightid '*.tiff']);

        %If no images, search in subdirectories by hour and minute
        if length(imagefiles) == 0
            imagefiles = dir([options.rawdir '**/' options.flightid '*.tiff']);
        end
        format = "tiff";
    end
    
    %Check for errors
    if length(imagefiles) == 0
        disp(['No holograms found with id: ' options.flightid]);
        return
    end

    % Make default output directory name
    if ~isdir(options.outdir)
        options.outdir = ['/glade/scratch/' getenv('USER') '/holoprep_' options.flightid];
        %disp('Output directory not found.'); 
        %return
    end

    % Make output directory
    if ~exist(options.outdir)
        status = mkdir(options.outdir);
    end

    %% Get supporting data from netCDF file 
    gotref = false;
    flightdate = ncreadatt(options.ncfile, '/', 'FlightDate');  %This works for all projects so far, may need to change later
    if (flightdate(1:4) == "2022")
        %ESCAPE 2022 NRC Convair
        data = read_convair(options.ncfile);
        refdata = data.aircraft.cdplwc;
        gotref = true;
    else
        %SPICULE 2021 or other GV/C130 project
        data = read_ncar_aircraft(options.ncfile, options.refvar);
        refdata = data.aircraft.refdata
        gotref = true;
    end

    if data.aircraft.sfm(2)-data.aircraft.sfm(1) ~= 1
        disp('Aircraft data must be 1Hz');
        return
    end

    %% Construct array of times to accept holograms for (1Hz)
    goodtime = ones(numel(data.aircraft.time),1);
    
    % Flag bad times based on user start/stop input
    goodtime(find(data.aircraft.sfm < options.starttime)) = 0;
    goodtime(find(data.aircraft.sfm > options.stoptime)) = 0;

    % Flag bad times based on reference data
    if gotref == true
       %Use a threshold to determine where good data exists
       %In SPICULE, CDP PLWC > 0.001 seems to work
      
       % Check for bad data 
       nandata = find(isnan(refdata) == 1);
       refdata(nandata) = 0;

       % Create  +/- 2 second padded reference data
       refdata_floored = refdata;    %First need to zero out data below thresh
       belowthresh = find(refdata_floored < options.thresh);
       refdata_floored(belowthresh) = 0;
       %Add up data +/- 2 sec
       paddata = refdata_floored + ...
          [refdata_floored(2:end) 0] + ...
          [refdata_floored(3:end) 0 0] + ...
          [0 refdata_floored(1:end-1)] + ...
          [0 0 refdata_floored(1:end-2)];
       belowthresh = find(paddata < options.thresh);
       goodtime(belowthresh) = 0;
    end
    

    %% Sequence files (CSET, SPICULE)
    if format == "seq"
        imagetime=[];
        brightness=[];
        seqfilenum=[];
        framenum=[];

        max2process = 500000;  %Set to small value (10?) for testing
        if length(imagefiles) > max2process; disp('***ONLY CHECKING A PORTION OF SEQ FILES TO SAVE TIME****'); end;

        for i = 1:min(length(imagefiles), max2process)
           disp([i length(imagefiles)]);
           seqInfo = indexSequenceFile([options.rawdir imagefiles(i).name]);
           imagetime = [imagetime seqInfo.time'];
           brightness = [brightness seqInfo.brightness'];
           seqfilenum = [seqfilenum zeros(1,numel(seqInfo.time))+i];
           framenum = [framenum 1:1:numel(seqInfo.time)];
        end

        %Find the good holograms and convert them to png
        %Use median brightness to find overly bright/dark holograms and ignore
        igoodbrightness = find((brightness > 50) & (brightness < 200));  %Only count reasonable brightness levels in the median
        medianbrightness = median(brightness(igoodbrightness));
        timeindex = floor(mod(imagetime,1)*86400) - double(min(time)) + 1;
        ioutofrange = find((timeindex < 1) | (timeindex > length(time)));   %Find times before/after takeoff to ignore them
        timeindex(ioutofrange) = 1;   %Set all bad times to the first index
        goodtime(1) = 0;  %Make sure the first index is set to 'bad'
        good = find((abs(brightness(:)-medianbrightness) < 40) & (goodtime(timeindex) == 1));
        prefix = [flightnumber '_'];
        pngname = cell(1,numel(good));
        parfor i = 1:numel(good)
           pngname{i} = extractSequenceFile([options.rawdir imagefiles(seqfilenum(good(i))).name], framenum(good(i)), prefix, options.outdir);
        end

        out = brightness;
        if length(good) > 0
            disp('Change .cfg file to reflect png range.');
            disp([pngname{1} ':1:' pngname{end}]);
        else
            disp('No good holograms found');
        end

    end  %seq image processing
    
    %% TIFF images (ESCAPE, CAESAR)
    if format == "tiff"
        %Search through tiff files to get hologram time and brightness
        %imagetime=[];
        data.imagetime = datetime([],[],[]);
        data.brightness=[];
        data.filename=[];
        
        ngood = 0;  %Keep track of number of good (bright) full holograms
        for i = 1:length(imagefiles)
            [imagetime, prefix] = holoNameParse(imagefiles(i).name);
            timeindex = max(find(imagetime >= data.aircraft.time));
            if (imagetime > data.timerange(1)) && (imagetime < data.timerange(2)) && (goodtime(timeindex) == 1)

                imageName = [imagefiles(i).folder filesep imagefiles(i).name];
                fullImage = imread(imageName);
                brightness = mean(fullImage, 'all');

                % Check if within brightness range 50-200 and write out as png
                if (brightness > 50) && (brightness < 200)
                    [tiffPath, baseName] = fileparts(imageName);
                    %status = copyfile(imageName, options.outdir);
                    imwrite(fullImage, [options.outdir filesep baseName '.png']);

                    %Concatenate to array for accepted images
                    data.imagetime = [data.imagetime imagetime];
                    data.brightness = [data.brightness brightness];
                    data.filename = [data.filename imageName];
                end
            end

            %Show progress
            if mod(i,50) == 0
                fprintf(repmat('\b',1,20));    %Backup
                fprintf('%d / %d ',[i,length(imagefiles)]);
            end
        end        
    end   %tiff image processing
    
    
    
    %% Write setup and sequences for config file

    % %% Properties %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % path = /glade/work/bansemer/escape/rf06_cloudpass
    % current_holo =  RF06_2022-06-09-21-23-52-081985.png
    % localTmp = /glade/scratch/bansemer/tmp
    % workers = 1
    % hologram_filter = \.png

    %  %% Sequences %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %  RF04_2021-06-05-14-55-00-152486.png:1:RF04_2021-06-05-14-55-02-842303.png,whole
    %  RF04_2021-06-05-14-55-00-152486.png:1:RF04_2021-06-05-14-55-02-842303.png,seq02
 
    % Get filenames that were written to options.outdir
    imagefiles = dir([options.outdir '/*.png']);

    %Deprecated tiff output, now always png since HoloSuite has some hard-coded png extensions
    %if length(imagefiles) == 0
    %    imagefiles = dir([options.outdir '/*.tiff']);
    %end

    % Make sure they are sorted by name
    imagefiles = string(struct2cell(imagefiles));    % Makes sorting by filename possible
    fn = sort(imagefiles(1,:));    

    % File setup
    fnout = ['holoprep_sequences_' options.flightid '.txt'];
    fileID = fopen(fnout, 'w');

    % Write properties
    fprintf(fileID, 'path = %s\n', options.outdir);
    fprintf(fileID, 'current_holo = %s\n', fn(1));
    localTmp = sprintf('/glade/scratch/%s/reconstructions_%s', getenv('USER'), options.flightid);
    if ~exist(localTmp); status = mkdir(localTmp); end;    %Make directory if it doesn't exist
    fprintf(fileID, 'localTmp = %s\n', localTmp);
    fprintf(fileID, 'workers = 1\n');
    fprintf(fileID, 'hologram_filter = \\.png\n');

    % Write the 'whole' sequence
    fprintf(fileID, '\n');
    fprintf(fileID, '%s:1:%s,%s\n', fn(1), fn(end), 'whole');
    %fprintf(fileID, [fn(1) + ':1:' + fn(end) + ',whole\n']);
 
    % Individual sequences of 1000 holograms each, about 7 minutes of flight time
    seqlength = 1000;
    for i = 1:floor(numel(fn)/seqlength)
        firstfile = fn(seqlength*(i-1) + 1);
        lastfile = fn(seqlength*i);
        seqname = sprintf("seq%02i",i+1);
        fprintf(fileID, '%s:1:%s,%s\n', firstfile, lastfile, seqname);
    end
    % Write final partial sequence
    if numel(i) == 0; i=0; end;    % i will be empty if fewer than seqlength holograms
    firstfile = fn(seqlength*(i) + 1);
    lastfile = fn(end);
    seqname = sprintf("seq%02i",i+2);
    fprintf(fileID, '%s:1:%s,%s\n', firstfile, lastfile, seqname);
    
    %% Write job sumbit commands
    fprintf(fileID, '\n');
    fprintf(fileID, 'qsub -J 1-%i submit_script_rfXX\n', seqlength/10 + 1);
    fprintf(fileID, 'For seglen=10 in submit_script\n');
    fclose(fileID);

    data.goodtime = goodtime;   %For output to command line
end

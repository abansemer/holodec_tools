function out=holoDiagnostics(seqdir, ncfile)
    %Given a directory of seq files, save a file with some diagnostic
    %information about image times, brightness, etc.

    if seqdir(end) ~= filesep
        %Add trailing slash
        seqdir = [seqdir filesep];
    end
    seqfiles=dir([seqdir '*.seq']);

    %Get supporting data in netCDF file
    data.flightnumber = upper(ncreadatt(ncfile, '/', 'FlightNumber'));
    data.flightdate = ncreadatt(ncfile, '/', 'FlightDate');
    data.ncfile = ncfile;
    nctime = ncread(ncfile,'Time');
    tas = ncread(ncfile,'TASX');
    t = ncread(ncfile,'ATX');
    w = ncread(ncfile,'WIC');
    cdplwc = ncread(ncfile,'PLWCD_LWOO');
    inflight = find(tas > 50);
    fulltime = datenum(data.flightdate,'mm/dd/yyyy') + double(nctime)./86400;
    timerange = [min(fulltime(inflight)), max(fulltime(inflight))];
    data.ncrange = [min(inflight):max(inflight)];
    data.nctime = nctime(data.ncrange);
    data.tas = tas(data.ncrange);
    data.t = t(data.ncrange);
    data.w = w(data.ncrange);
    data.cdplwc = cdplwc(data.ncrange);

    %Initialize structure
    data.imagetime = [];
    data.firstimagetime = [];
    data.brightness = [];
    data.fullsizebrightness = [];
    data.seqfilenum = [];
    data.framenum = [];
    data.imagehist = [];
    meanbackground = [];

    %Get data for each seq file and add to struct
    ngood = 0;  %Keep track of number of good (bright) first holograms
    c = 0;      %Keep track of number of all seq files in time range
    for i = 1:length(seqfiles)
        if mod(i,10) == 0; disp([i,length(seqfiles)]); end;
        [imageInfo, firstImage] = indexSequenceFile([seqdir seqfiles(i).name]);
        if (imageInfo.time(1) > timerange(1)) && (imageInfo.time(1) < timerange(2))
            data.imagetime = [data.imagetime imageInfo.time'];
            data.firstimagetime = [data.firstimagetime imageInfo.time(1)];
            data.brightness = [data.brightness imageInfo.brightness'];
            data.fullsizebrightness = [data.fullsizebrightness imageInfo.fullsizebrightness'];
            data.seqfilenum = [data.seqfilenum zeros(1,numel(imageInfo.time))+i];
            data.framenum = [data.framenum 1:1:numel(imageInfo.time)];
            data.imagehist = [data.imagehist; imageInfo.histogram];
            if c == 0  %Set a few more fields with the first valid file
                data.date = datestr(imageInfo.time(1), 'yyyy-mm-dd-HH-MM-SS');
                meanbackground = zeros(imageInfo.imageSizeNy, imageInfo.imageSizeNx);
            end
            if median(firstImage, 'all') > 30
                meanbackground = meanbackground + double(firstImage);
                ngood = ngood+1;
            end
            c = c + 1;
        end
    end

    %Normalize the background
    data.meanbackground = meanbackground ./ ngood;
    data.histogram_edges = imageInfo.histogram_edges;

    %Save data
    if c > 0
        fn = data.date + "_diagnostics.mat";
        disp("Saving: " + fn);
        save(fn, 'data');
    else
        disp('No data found in timerange of netCDF file');
    end
end

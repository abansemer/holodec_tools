function out=convert_seqfiles(options)
    % Extract PNG files from a directory containing one or more seq files.
    % For HOLODEC data collected in years 2010-2021.
    %
    % seqdir: directory containing Holodec *.seq files
    % seqfile: use to specify a single .seq file instead of a directory
    % outdir: directory to save the Holodec png output
    % prefix: optional prefix for extracted .png files
    %
    % Example 1, default options extract all files in current directory:
    % x=convert_seqfiles();
    %
    % Example 2, specify in/out directories and prefix:
    % x=convert_seqfiles('seqdir', './holodec/RF04',...
    %   'outdir', '.', 'prefix', 'RF04')
    %
    %
    % See also holoprep.m for converting selected files based on supporting
    % data.

    arguments
       options.seqdir char = '.'
       options.seqfile char = ''
       options.outdir char = '.'
       options.prefix char = 'hologram'
    end

    %Add file separator if necessary
    if options.seqdir(end) ~= filesep; options.seqdir=[options.seqdir filesep]; end;
    if options.prefix(end) ~= '_'; options.prefix=[options.prefix '_']; end;
    
    %Get seq files
    rawfiles=dir([options.seqdir '*.seq']);
    if options.seqfile ~= ''; rawfiles=dir(options.seqfile); end;
        
    %Check for errors
    nholograms=length(rawfiles);
    if nholograms == 0
        disp(['No holograms found:' options.seqdir]);
        return
    end

    if ~isdir(options.outdir)
        disp('Output directory not found.'); 
        return
    end

    %Index files first to get number of frames, etc.
    imagetime=[];
    brightness=[];
    seqfilenum=[];
    framenum=[];
    parfor i=1:length(rawfiles)
        seqInfo = indexSequenceFile([options.seqdir rawfiles(i).name]);
        imagetime=[imagetime seqInfo.time'];
        brightness=[brightness seqInfo.brightness'];
        seqfilenum=[seqfilenum zeros(1,numel(seqInfo.time))+i];
        framenum=[framenum 1:1:numel(seqInfo.time)];
    end

    %Extract each image individually
    parfor i=1:numel(imagetime)
       pngname{i}=extractSequenceFile([options.seqdir rawfiles(seqfilenum(i)).name], ...
           framenum(i), options.prefix, options.outdir);
    end

    %Save data in output structure
    out.brightness=brightness;
    out.framenum=framenum;
    out.seqfilenum=seqfilenum;
    out.imagetime=imagetime;
    cout.rawfiles=rawfiles;
end
    


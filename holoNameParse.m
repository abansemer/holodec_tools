function [time, prefix]=holoNameParse(fn, timeoffset)
    %Function to return the time and prefix of a Holodec image
    %Format must follow:  PREFIX_YYYY-MM-DD-HH-MM-SS-ssssss.png
    %PREFIX is optional.
    %The value in timeoffset will be added to the time derived from the
    %filename.
    
    arguments
        fn {mustBeText}
        timeoffset {mustBeFloat} = 0
    end

    prefixpat = lettersPattern(2)+digitsPattern(2);
    prefix = extract(fn, prefixpat);
    
    timepat = digitsPattern(4) + '-' + digitsPattern(2) + ...
        '-' +digitsPattern(2) + '-' +digitsPattern(2) + ...
        '-' +digitsPattern(2) + '-' +digitsPattern(2) + ...
        '-' +digitsPattern(4,6);
    
    base = extract(fn, timepat);
    hms = split(base, '-');
    sec = str2num(hms{6}) + str2num(hms{7})/1e6 + timeoffset;
    time = datetime(str2num(hms{1}), str2num(hms{2}), str2num(hms{3}),...
        str2num(hms{4}), str2num(hms{5}), sec);
    %datenum(base,'yyyy-mm-dd-HH-MM-SS-FFF') also works but with mS
    %accuracy only
end
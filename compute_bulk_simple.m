function data = compute_bulk_simple(conc, endbins, options)
    % compute_bulk_simple Compute LWC, MVD, etc. from a particle or drop size
    % distribution.
    %
    % Input arguments:
    %   conc: a [ntimes, nbins] array in m^-4, or in m^-3 if flagged.
    %   endbins: an [nbins+1] array of bin edges in microns.
    %   options.minsize: minimum size to consider (microns).
    %   options.maxsize: maximum size to consider (microns).
    %   options.normalized: default=1, set to 0 if conc data are in m^-3.
    %
    % Output structure units:
    %   LWC, IWC: g/m3
    %   MVD, MND: microns
    %   Nt: #/m3
    
    arguments
        conc {mustBeNumeric}
        endbins {mustBeNumeric}
        options.minsize single = 0
        options.maxsize single = 1e12
        options.normalized single = 1
    end

    %Make sure endbins uses right dimensions, otherwise matrix
    %multiplication ensues
    if size(endbins,1) == 1
        endbins = endbins';
    end

    %Bin setup
    binstart = min(find(endbins >= options.minsize));
    binstop = max(find(endbins <= options.maxsize)) - 1; %-1 for use on midbins
    croppedendbins = endbins(binstart:binstop+1);

    binwidth = (endbins(2:end) - endbins(1:end-1))';
    midbins = ((endbins(2:end) + endbins(1:end-1))./2)';
    liquidmass = pi/6*(midbins/1e4).^3;
    
    for i=1:size(conc, 1)
        if options.normalized == 1
            concraw = conc(i,binstart:binstop).*(binwidth(binstart:binstop)/1e6);
        else
            concraw = conc(i,binstart:binstop);
        end
        data.lwc(i) = sum(liquidmass(binstart:binstop).*concraw, 'all', 'omitnan');  % g/m3
        data.nt(i) = sum(concraw, 'all', 'omitnan');
        data.dmassw(i) = sum(liquidmass(binstart:binstop).*concraw.*midbins(binstart:binstop), 'all', 'omitnan')/data.lwc(i);
        data.dmean(i) = sum(concraw.*midbins(binstart:binstop), 'all', 'omitnan')/data.nt(i);

        %MVD, this is a little complicated since Matlab interp1 can't
        %solve for abcissa value.  Verified by compute_bulk_simple.pro
        cs = cumsum(liquidmass(binstart:binstop).*concraw, 'omitnan');
        bin1 = max(find(cs<=(data.lwc(i)/2)));
        
        %Special case for all-zero PSD
        if (numel(bin1)==0) || (bin1 == numel(midbins(binstart:binstop)))
            bin1=1; 
        end

        %Manual interpolation factor
        frac = (data.lwc(i)/2-cs(bin1))/(cs(bin1+1)-cs(bin1));

        %Adding 1 to bin1 since assuming cumulative sum is achieved
        %once upper bin edge threshold is crossed.  See mvdiam.pro.
        data.mvd(i) = croppedendbins(bin1+1) + ...
            frac*(croppedendbins(bin1+2)-croppedendbins(bin1+1));

        %Switch NaN to 0 for diameter variables
        if isnan(data.mvd(i)); data.mvd(i)=0; end
        if isnan(data.dmean(i)); data.dmean(i)=0; end
        if isnan(data.dmassw(i)); data.dmassw(i)=0; end
    end
end
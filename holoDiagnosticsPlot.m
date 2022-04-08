function holoDiagnosticsPlot(fn, fn_reference)
    %Plot data saved using the holoDiagnostics.m program

    close all  %Close previous figures

    %Load reference file containing original background, if given
    if nargin == 2
        load(fn_reference);
        ref = data;
        load(fn);
    else
        %Just copy the main file to 'ref' if no reference
        load(fn);
        ref = data;
    end

    %Clean up time variables
    time1 = (mod(data.imagetime(1),1) + (data.imagetime-data.imagetime(1)))* 86400;  %Time at each image within seq files
    time2 = (mod(data.firstimagetime(1),1) + (data.firstimagetime-data.firstimagetime(1)))* 86400;   %Time of each seq file

    %Find missed frames
    dtime = time1(2:end) - time1(1:end-1);
    outages = find(dtime > 0.33);   %Find gaps larger than the usual 3Hz
    nmissed = sum(dtime(outages))/0.3;
    outagestart = time1(outages);
    outagestop = time1(outages+1);
    disp("Number of outages: " + length(outages));
    disp("Missed frames: " + nmissed);

    %Display number bright/dark frames
    nbright = length(find(data.brightness > mean(data.brightness*1.3)));
    ndark = length(find(data.brightness < mean(data.brightness/1.3)));
    ntotal = length(data.brightness);
    disp("Bright frames: " + nbright + "/" + ntotal);
    disp("Dark frames: " + ndark + "/" + ntotal);

    %Plot background differences (if available)
    if nargin == 2
        diff = data.meanbackground - ref.meanbackground;
        figure('Name','Background Difference')
        colormap gray
        imagesc(diff);
        title(data.date+" / "+ref.date+"  Difference");
        saveas(gcf, data.date+"_backgrounddiff.png");
    end
    figure('Name','Mean Background')
    colormap gray
    imagesc(data.meanbackground);
    title([data.flightnumber ' ' data.date ' Background']);
    saveas(gcf, data.date+"_background.png");

    %Plot overall brightness histogram
    figure('Name','Brightness Histogram')
    colormap default
    good = find(data.fullsizebrightness > 50);
    plot(data.histogram_edges(1:end-1), mean(data.imagehist(good,:),1), 'DisplayName', 'Flight');
    title([data.flightnumber ' ' data.date]);
    xlabel('Brightness')
    ylabel('Histogram (mean counts)')
    xlim([5 250])
    if nargin == 2
        %Overplot reference
        hold on
        good =  find(ref.fullsizebrightness > 50);
        plot(ref.histogram_edges(1:end-1), mean(ref.imagehist(good,:),1), 'r--', 'DisplayName', 'Reference');
        hold off
    end
    legend
    saveas(gcf, data.date+"_histogram.png");

    %Image histogram contours
    figure('Name','Brightness Histogram Time Series')
    levels = linspace(0, max(data.imagehist(:,100)), 15);
    contourf(time2, data.histogram_edges(5:end-5), data.imagehist(:,5:end-4)', levels, 'LineStyle', 'none');
    %xlim(timerange)
    xlabel('Time (s)')
    ylabel('Brightness');
    c=colorbar;
    c.Label.String = 'Counts';
    hold on
    plot(time2, data.fullsizebrightness, 'r', 'Linewidth', 2);
    for i=1:length(outages)
        ff=fill([outagestart(i) outagestart(i) outagestop(i) outagestop(i)], [5 250 250 5], 'k', 'LineStyle','none');
        hold off
        alpha(ff, 0.5);
        hold on
    end

    hold off
    title([data.flightnumber ' ' data.date]);
    saveas(gcf, data.date+"_histogramcontour.png");

    %Brightness plot (center patch and full image), with aircraft data
    figure('Name','Brightness Time Series')
    if isfield(data,'cdplwc')
        tiledlayout(5,1)  % Newer files have CDP
    else
        tiledlayout(4,1)
    end

    ax1 = nexttile([2 1]);
    plot(time1, data.brightness, '.')
    ylim([0 250])
    hold on
    plot(time2, data.fullsizebrightness, 'r+', 'Linewidth', 2);
    for i=1:length(outages)
        ff=fill([outagestart(i) outagestart(i) outagestop(i) outagestop(i)], [0 255 255 0], 'k', 'LineStyle','none');
        hold off
        alpha(ff, 0.3);
        hold on
    end
    hold off
    title([data.flightnumber ' ' data.date]);
    xlabel('Time (s)')
    ylabel('Brightness')


    ax2 = nexttile;
    plot(data.nctime, data.w)
    ylim([-10 10])
    xlabel('Time (s)')
    ylabel('W (m/s)')

    ax3 = nexttile;
    plot(data.nctime, data.t)
    xlabel('Time (s)')
    ylabel('T (degC)')

    if isfield(data,'cdplwc')
        ax4 = nexttile;
        plot(data.nctime, data.cdplwc)
        xlabel('Time (s)')
        ylabel('CDP LWC (g/m3)')
        linkaxes([ax1, ax2, ax3, ax4],'x');
    else
        linkaxes([ax1, ax2, ax3],'x');
    end
    saveas(gcf, data.date+"_brightness.png");

    %Simple flight data plot, change as needed
    figure('Name','Flight Data')
    tiledlayout(2,1)

    ax1 = nexttile;
    plot(data.nctime, data.w)
    title([data.flightnumber ' ' data.date]);
    xlabel('Time (s)')
    ylabel('W (m/s)')

    ax2 = nexttile;
    plot(data.nctime, data.t)
    xlabel('Time (s)')
    ylabel('T (degC)')

    linkaxes([ax1,ax2],'x');

end

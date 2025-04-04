function holodec_psd_contour(data)
% Make a contour plot of the PSD from a Holodec archive file
%
% Input arguments:
%    data: Structure containing Holodec data from load_holodec_archive.m
%
% Example:
%    rf06 = load_holodec_archive('RF06_20240312_HOLODEC.nc');
%    holodec_psd_contour(rf06);

%Compute LWC from 10-50 um
bholo = compute_bulk_simple(data.psd, data.endbins, 'minsize', 10, 'maxsize', 50);

%Concentration contour figure
figure('Name', data.flightname, 'Position', [10 10 1000 800])
tiledlayout(3,1);
ax1 = nexttile; 

levels = 10.^(linspace(10,14,20));  %Log10 levels
contourf(data.psdtime, data.midbins, data.psd', levels, 'LineStyle', 'none');
set(gca,'ColorScale','log');
clim([min(levels), max(levels)]);
grid on

xlabel('Time (s)')
ylabel('Diameter (microns)');
c=colorbar;
set(gca,'ColorScale','log');
c.Label.String = 'Concentration (#/m4)';
ylim([0, 50])
title('Particle Size Distribution');

%Mean Diameter
ax2 = nexttile;
plot(data.psdtime, bholo.dmean, 'DisplayName', 'Holodec')
ylim([0 50])
xlabel('Time (s)')
ylabel('Dbar (microns)')
grid on
title('Mean Diameter for 10-50 micron particles');

%LWC
ax3 = nexttile;
plot(data.psdtime, bholo.lwc, 'DisplayName', 'Holodec')
xlabel('Time (s)')
ylabel('LWC (g/m3)')
grid on
title('LWC for 10-50 micron particles');

linkaxes([ax1, ax2, ax3],'x');

end
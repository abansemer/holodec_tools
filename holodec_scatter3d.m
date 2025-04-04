function b = holodec_scatter3d(data, time, options)
% Make a scatter plot of particles in a hologram, colored by diameter.
%
% Input arguments:
%    data: Structure containing Holodec data from load_holodec_archive.m
%    time: Time stamp of requested hologram.  Will use nearest hologram available
%    'hid': Hologram ID to plot, when time is not available
%    'range': Size range for colorizing particles
%    'viewangle':  Azimuth and elevation (deg) for 3D plot
%    'mag':  Particle size magnification for visibility
%    'rotation':  Rotation angle about optical axis, for making animations
%
% Example:
%    rf06 = load_holodec_archive('RF06_20240312_HOLODEC.nc');
%    holodec_scatter3d(rf06, 37037.3, 'mag', 20);

arguments
    data               % Structure from load_holodec_archive.m 
    time = []          % Nearest time to hologram of interest
    options.hid = []   % Hologram ID to plot (if no time specified)
    options.range = [10, 30]         % Colorbar size range
    options.viewangle = [-37.5, 30]  % Azimuth and elevation (deg)
    options.mag = 30                 % Particle size magnification factor
    options.rotation = 0             % Rotation about z axis (deg)
end

%Extract relevant particles from data structure
if exist('data', 'var')
    i = [];
    if ~isempty(time)
        timediff = abs(time-data.particletime);
        [~,itime] = min(timediff);
        options.hid = data.hid(itime);
    end
    if ~isempty(options.hid)
        i = find(data.hid == options.hid);
    else
        disp('Specify either time or Hologram ID (hid)')
        b = 0;
        return
    end
    if isempty(i)
        disp('No holograms found');
        b = 0;
        return
    end
    x = data.x(i);
    y = data.y(i);
    z = data.z(i);
    d = data.dmajor(i);
    hologramtime = data.particletime(i(1));
end


f = figure;
f.Position = [100,100,896,504];      % Make 16:9 figure window
colormap jet                         % jet hsv turbo parula
cmap = colormap;

% Colors need an RGB triplet array.  Color by particle size.
c = zeros(numel(d), 3);
for i = 1:numel(d)
    ind = floor((d(i) - options.range(1)) / (options.range(2)-options.range(1)) * length(cmap));
    ind = max(ind, 1);
    ind = min(ind, length(cmap));
    c(i,:) = cmap(ind,:);
end

% Rotate x/y if flagged
if options.rotation ~= 0
    [theta, rho] = cart2pol(x,y);
    theta = theta + options.rotation * pi/180;
    [x,y] = pol2cart(theta,rho);
end

% Make plot
b = bubbleplot3(z/1e3, x/1e3, y/1e3, d*options.mag/1e3, c, 0.5);
axis equal
xlim([20 150])
ylim([-7 7])  % Keep these fixed to allow clean rotations
zlim([-7 7])
ylabel('mm')
zlabel('mm')
title([data.flightname, data.flightdate, string(hologramtime)])
view(options.viewangle)
camlight right
lighting gouraud

% Make colorbar for particle size
ax = axes('Position', [0.4, 0.1, 0.5, 0.15]);  % Requires an axis first
ax.CLim = options.range;                       % Set range and position
cb = colorbar(ax, 'South');
cb.Label.String = 'Particle Size (microns)';
ax.Visible = 'off';                            % Hide axis
end
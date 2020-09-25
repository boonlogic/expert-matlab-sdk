% BoonLogic BoonNanoSDK Example Usage

% Constructor
bn = BoonNanoSDK('default');

% Nano Info
[success, version_response] = bn.getVersion();
if success
    fprintf('Boon Nano API Version: %s \n',version_response.api_version);
end



%% Create instance
[success, instance_response] = bn.openNano('imagerun');
if ~success
    fprintf('Failed To Create New Instance \n');
end




%% List instances
[success, list] = bn.nanoList();

if success
    fprintf('Found %d Active Nano Instance(s) \n', length(list));
end




%% Load Image And Scale

im_raw = imread('TestImage.bmp');

%convert to grayscale
if size(im_raw,3) > 1
    im_gray = rgb2gray(im_raw);
else
    im_gray = im_raw;
end

%downsample (for faster processing)
im_small = imresize(im_gray, 0.25);



%% Create Histograms From Image

[image_y_dim, image_x_dim, num_color_channels] = size(im_small);
neighborhood_diameter = 20; %variable
num_bins = 22;

% stride size
neighborhood_buffer = neighborhood_diameter-1;
stride = neighborhood_diameter/2;

%index limits
y_lims = 1:stride:(image_y_dim-neighborhood_buffer);
x_lims = 1:stride:(image_x_dim-neighborhood_buffer);
y_regions = length(y_lims);
x_regions = length(x_lims);

%histogram limits
step = 255.0/(num_bins);
edges = uint8( 0:step:255 );

Dataset = zeros(y_regions*x_regions, num_bins);
idx = 1;
for yy = y_lims
    for xx = x_lims
        roi = im_small(yy:yy+neighborhood_buffer, xx:xx+neighborhood_buffer, :);
        [counts,~] = histcounts(roi,edges);
        Dataset(idx,:) = counts.';
        idx = idx + 1;
    end
end



%% Generate config and configure instance

%parameters
minval = 0;
maxval = max(Dataset(:));
percent_variation = 0.04;
accuracy = 0.99;
feature_length = num_bins; %%Histogram bins

%Generate struct
[~, config] = bn.generateConfig(feature_length, 'uint16', 'batch', percent_variation, accuracy, 1, minval, maxval);

%Send to api
[success, config_response] = bn.configureNano(config);
if success
    fprintf('Nano Pod Configured \n');
else
    fprintf('Configuration Failed \n');
end


%% Load data to cloud 

[success, load_response] = bn.loadData(Dataset);

if success
    [~, status_response] = bn.getBufferStatus();
    fprintf('Total Bytes in Buffer = %d \n', status_response.totalBytesInBuffer);
else
     fprintf('Load Data Failed \n');
end




%% Run Nano and compare results
[success, run_response] = bn.runNano('ID,RI');

if(success)
    ai = mean(run_response.RI);
    fprintf('Avg Anomaly Index = %f \n', ai);
else
    fprintf('Nano Run Failed \n');
end



%% Create color image for anomaly index

%ai image
im_anomaly = zeros(image_y_dim,image_x_dim);
idx = 1;
for yy = 1:y_regions
    for xx = 1:x_regions
        %get anomaly index
        ai_val = run_response.RI((yy-1)*x_regions + xx);
        % place in image
        y_image = y_lims(yy); x_image = x_lims(xx);
        im_anomaly(y_image:y_image+neighborhood_buffer, x_image:x_image+neighborhood_buffer) = ai_val;
    end
end

%map to rgb
Map = jet(255);
im_anomaly_rgb = ind2rgb(im_anomaly, Map);

figure(1)
imshow(im_anomaly_rgb);
title('Anomaly Image')
figure(2)
imshow(im_small);
title('Raw Image')



%% close and delete this instance
[success, ~] = bn.closeNano('imagerun');

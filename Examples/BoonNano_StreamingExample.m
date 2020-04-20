% BoonLogic BoonNanoSDK Streaming Example

% Constructor
bn = BoonNanoSDK('default');

% Nano Info
[success, version_response] = bn.getVersion();
if success
    fprintf('Boon Nano API Version: %s \n',version_response.api_version);
end

%% Create instance
[success, instance_response] = bn.openNano('stream_test');
if ~success
    fprintf('Failed To Create New Instance \n');
end


%% List instances
[success, list] = bn.nanoList();

if success
    fprintf('Found %d Active Nano Instance(s) \n', length(list));
end


%% Generate config and configure instance

%parameters
minval = -4.0;
maxval = 4.0;
percent_variation = 0.05;
accuracy = 0.99;
feature_length = 1; %one sensor
streaming_window = 100; %moving window of 100 samples

%Generate struct
[~, config] = bn.generateConfig(feature_length, 'float32', percent_variation, accuracy, minval, maxval, streaming_window);

%Send to api
[success, config_response] = bn.configureNano(config);
if success
    fprintf('Nano Pod Configured \n');
else
    fprintf('Configuration Failed \n');
end




%% Generate random dataset

fprintf('Generating Random Signal \n');
dt = 0.01;
tmax=100;
t = 0:dt:tmax;

A1 = maxval;
hz1 = 0.5;
A2 = 1.0;
hz2 = 2.0;
Dataset = A1*sin(2*pi*hz1*t) + A2*sin(2*pi*hz2*t);

%add noise
noise = 0.1;
num_samples = numel(Dataset);
delta = randn(1,num_samples).*noise;
Dataset = Dataset + delta;

%insert anomaly
anomaly_pos = round(0.73*num_samples):round(0.75*num_samples);
Dataset(anomaly_pos) = delta(anomaly_pos);


%% run nano streaming 

chunksize = 1000;
numchunks = (num_samples/chunksize)-1;
anomaly_index = [];

for i = 0:numchunks
    lims = [(i*chunksize):((i+1)*chunksize)] + 1;
    [success, stream_response] = bn.runStreamingNano(Dataset(lims), 'SI');
    if(success)
        anomaly_index = [anomaly_index; stream_response.SI];
    end
    if(any(stream_response.SI))
        fprintf("Streaming \n");
    else
        fprintf("Autotuning \n");
    end
 
    %pause to wait for autotuning
    pause(5);
end



%% Plot Anomaly Detection Results

figure(1)
clf
suptitle('Streaming Anomaly Test');
s1 = subplot(2,1,1);
plot(Dataset, 'Color', 'b', 'LineWidth', 2);
axis(s1, [0,num_samples,minval,maxval])
ylabel(s1, 'Signal');

s2 = subplot(2,1,2);
plot(anomaly_index, 'Color', 'r', 'LineWidth', 2);
axis(s2, [0,num_samples,0,1000])
xlabel(s2, 'Time');
ylabel(s2, 'AI');



%% Check that we found an anomaly

sub_results = anomaly_index(anomaly_pos);
true_anomaly = [sub_results > 700];
if(any(true_anomaly))
    fprintf("Found Anomaly \n");
else
    fprintf("Missed Anomaly \n");
end


%% close and delete this instance
[success, close_response] = bn.closeNano('stream_test');

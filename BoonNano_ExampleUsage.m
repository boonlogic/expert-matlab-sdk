% BoonLogic BoonNanoSDK Example Usage

% Constructor
bn = BoonNanoSDK('default');

% Nano Info
[success, version_response] = bn.getVersion();
if success
    fprintf('Boon Nano API Version: %s \n',version_response.api_version);
end

%% Create instance
[success, instance_response] = bn.openNano('inst1');
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
minval = 0;
maxval = 500.0;
percent_variation = 0.05;
accuracy = 0.99;
feature_length = 100;

%Generate struct
[~, config] = bn.generateConfig(feature_length, 'uint16', percent_variation, accuracy, minval, maxval, 1);

%Send to api
[success, config_response] = bn.configureNano(config);
if success
    fprintf('Nano Pod Configured \n');
else
    fprintf('Configuration Failed \n');
end




%% Generate random dataset

num_templates = 5;
num_variants = 100; %100 samples per template
num_samples = num_templates*num_variants;
fprintf('Generating %d Random Samples \n', num_samples);

% Templates (Each row is a feature vector)
Templates = randi([minval, maxval],num_templates,feature_length);
noise = (maxval-minval)*percent_variation/2;

Dataset = [];
ClusterID_GT = [];
idx = 1;
for t = 1:num_templates
   for v = 1:num_variants
       delta = round( normrnd(0,noise,[1,feature_length]) );
       Dataset(idx,:) = Templates(t,:) + delta;
       ClusterID_GT(idx,1) = t;
       idx = idx + 1;
   end
end




%% load data to cloud
[success, load_response] = bn.loadData(Dataset);

if success
    [~, status_response] = bn.getBufferStatus();
    fprintf('Total Bytes in Buffer = %d \n', status_response.totalBytesInBuffer);
else
     fprintf('Load Data Failed \n');
end




%% Optionally Autotune Data
[success, autotune_response] = bn.autotuneConfig();

if success
    fprintf('Autotune completed. PV = %.3f \n', autotune_response.percentVariation);
else
     fprintf('Autotune Failed \n');
end



%% Run Nano and compare results
[success, run_response] = bn.runNano('ID'); 

if(success)
    error_count=sum(run_response.ID~=ClusterID_GT);
    fprintf('Error Count = %d \n', error_count);
else
    fprintf('Nano Run Failed \n');
end


%% Plot Clustering Results

colorspec = ['b' 'm' 'c' 'r' 'g' 'y' 'k'];

figure(1)
clf
for k = 1 : size(Dataset,1)
  hold on
  id = mod(run_response.ID(k)-1, length(colorspec)) + 1;
  plot(Dataset(k,:), 'Color', colorspec(id),'LineWidth',2)
end
hold off
grid
xlabel('Feature')
ylabel('Value')
title('BoonNano Clustering Results')
 


%% Retrieve Additional Results From Latest Run

[success, results_response] = bn.getNanoResults('FI');
if(success)
    meanfi = mean(results_response.FI);
    fprintf('Mean Frequency Index = %d \n', meanfi);
else
    fprintf('Get Results Failed \n');
end




%% Get Inference Time, etc

 [success, status_response] = bn.getNanoStatus('totalInferences,averageInferenceTime,numClusters');
if(success)
    fprintf('Total Inferences = %d \n', status_response.totalInferences);
    fprintf('Avg Inference Time = %.3f (us) \n', status_response.averageInferenceTime);
    fprintf('Cluster Count = %d \n', status_response.numClusters);
else
    fprintf('Get Status Failed \n');
end



%% Save the nano
success = bn.saveNano('tester.tar');
if ~success
   fprintf('Failed to save nano \n'); 
end




%% Reload the nano and check config
success = bn.restoreNano('tester.tar');
if ~success
   fprintf('Failed to restore nano \n'); 
else
    [~, newconfig] = bn.getConfig();
end



%% close and delete this instance
success = bn.closeNano();



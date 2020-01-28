# Tutorial: The General Pipeline

## Package Installation

### Package Installation

- Download the expert-matlab-sdk repository to your computer

- Add the @BoonNanoSDK and @MatrixProvider folders to your Matlab path

- **NOTE:** Requires Matlab version 2018a or newer

### License Configuration

Note: A license must be obtained from Boon Logic to use the BoonNano Matlab SDK

The license should be saved in ~/.BoonLogic on unix machines or C:/Users/\<user\>/.BoonLogic on windows machines. This file will contain the following format:

```json
{
  "default": {
    "api-key": "API-KEY",
    "server": "WEB ADDRESS",
    "api-tenant": "API-TENANT"
  }
}
```

The *API-KEY*, *WEB ADDRESS*, and *API-TENANT* will be unique to your obtained license.

The .BoonLogic file will be consulted by the BoonNano Matlab SDK to successfully find and authenticate with your designated server.



**NOTE:** See the *examples* directory for the code used in this tutorial


### General WorkFlow

Most BoonNano sessions will consist of the following steps.

#### Create BoonNano class handle

```matlab
bn = BoonNanoSDK('default');
```

#### Open Connection to Instance

```matlab
[success, instance_response] = bn.openNano('inst1');
if success
	fprintf('Created New Instance \n');
else
    fprintf('Failed To Create New Instance \n');
end
```


#### Configure the Nano Instance
```matlab
feature_length = 100;
numeric_format='float32';
percent_variation = 0.05;
accuracy = 0.99;
minval = 0;
maxval = 500.0;
streaming_window = 1;

[~, config] = bn.generateConfig(feature_length, numeric_format, percent_variation, accuracy, minval, maxval, streaming_window);

[success, config_response] = bn.configureNano(config);
if success
    fprintf('Nano Pod Configured \n');
else
    fprintf('Configuration Failed \n');
end
```

#### Load Data to Nano Instance

```matlab
dataFile = 'Example_Data.csv'; % Insert your file here
dataMat = csvread(dataFile);
[success, load_response] = bn.loadData(dataMat);
if success
    fprintf('Data Loaded \n');
else
    fprintf('Load Data Failed \n');
end
```

#### Run Clustering

```matlab
[success, results] = bn.runNano('All');
if success
    fprintf('Clustering Finished. See results struct. \n');
else
    fprintf('Clustering Failed \n');
end
```

#### Close NanoHanlde

```matlab
[success, response] = nano.closeNano()
if success
    fprintf('Nano Instance Closed. \n');
else
    fprintf('Instance Not Closed! \n');
end
```

### Connectivity Test

The following Matlab script provides a basic proof-of-connectivity:

**Examples/connect-example.m**

```matlab
% create new nano handle
nano = BoonNanoSDK('default');

% open/attach to nano
[success, response] = nano.openNano('my-instance');
if success
    fprintf('Created New Instance! \n');
else
    fprintf('Failed To Create New Instance \n');
end

% fetch the version information for this nano instance
[success, response] = nano.getVersion();
if success
    fprintf('Boon Nano API Version: %s \n', response.api_version);
else
    fprintf('getVersion() Failed \n');
end

% close/detach the nano instance
[success, reponse] = nano.closeNano();
if success
    fprintf('Closed Instance... \n');
else
    fprintf('closeNano() Failed \n');
end

```

Running the connect-example.m script should yield something like:

```sh
	Created New Instance!
	Boon Nano API Version: /expert/v3
	Closed Instance...
```

[Return to documentation homepage](../README.md)
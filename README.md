# Matlab SDK Documentation

This Matlab class allows easy access to the functions provided in the BoonLogic Nano API.

**NOTE:** In order to use this package, it is necessary to acquire a BoonNano license from Boon Logic, Inc.  A startup email will be sent providing the details for using this package.

- __Website__: [https://boonlogic.com](https://github.com/boonlogic/expert-matlab-sdk)
- __Documentation__: [https://github.com/boonlogic/expert-matlab-sdk](https://github.com/boonlogic/expert-matlab-sdk)


------------
### Installation of BoonNano

- Download the expert-matlab-sdk repository to your computer

- Add the @BoonNanoSDK and @MatrixProvider folders to your Matlab path

- **NOTE:** Requires Matlab version 2018a or newer


------------
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


------------

### Connectivity Test

The following Matlab script provides a basic proof-of-connectivity:

**Examples/BoonNano_ExampleUsage.m**

```matlab
% Create Nano Instance
bn = BoonNanoSDK('default');

%% Open/Attached to Nano Instane
[success, instance_response] = bn.openNano('inst1');
if success
	fprintf('Created New Instance! \n');
else
    fprintf('Failed To Create New Instance \n');
end

%Fetch the version information for this nano instance
[success, version_response] = bn.getVersion();
if success
    fprintf('Boon Nano API Version: %s \n',version_response.api_version);
end

%% Close/detatch this instance
success = bn.closeNano();
if success
	fprintf('Deleted Nano Instance"
end

```

Running the **BoonNano_ExampleUsage.m** script should yield something like:

```sh
    Created New Instance!
    Boon Nano API Version: expert/v3
    Deleted Nano Instance
```
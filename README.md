# Matlab SDK Documentation

This Matlab class allows easy access to the functions provided in the BoonLogic Nano API.

**NOTE:** In order to use this package, it is necessary to acquire a BoonNano license from Boon Logic, Inc.  A startup email will be sent providing the details for using this package.

- __Website__: [https://github.com/boonlogic/expert-matlab-sdk](https://github.com/boonlogic/expert-matlab-sdk)
- __API Documentation__: [docs.boonlogic.com](http://docs.boonlogic.com/)
- __Matlab Documentation__: ```doc BoonNanoSDk``` in Matlab Command Window


------------
### Installation of BoonNano

- Download the expert-matlab-sdk repository to your computer

- Add the expert-matlab-sdk folder to your Matlab path

- **NOTE:** Requires Matlab version 2018a or newer


------------
### License Configuration

Note: A license must be obtained from Boon Logic to use the BoonNano Matlab SDK

The license should be saved in ```~/.BoonLogic.license``` on unix machines or ```C:\Users\<user>\.BoonLogic.license``` on windows machines. This file will contain the following format:

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

The .BoonLogic.license file will be consulted by the BoonNano Matlab SDK to successfully find and authenticate with your designated server.


------------

### Connectivity Test

The following Matlab script provides a basic proof-of-connectivity:

**Examples/connect_example.m**

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

Running the **BoonNano_ExampleUsage.m** script should yield the following output:

```sh
    Created New Instance!
    Boon Nano API Version: expert/v3
    Closed Instance...
```

------------

### Tutorials
- __Introduction To Clustering__: [Introduction To Clustering](http://docs.boonlogic.com/docs/Intro_to_Clustering.html)
- __The General Pipeline__: [The General Pipeline](./Tutorials/GeneralPipeline.md)

------------

### Example Scripts

- __Example Clustering__: [BoonNano_ExampleUsage.m](./Examples/BoonNano_ExampleUsage.m)
-  __Image Analysis__: [BoonNano_ImageExample.m](./Examples/BoonNano_ImageExample.m)
- __Streaming Data__: [BoonNano_StreamingExample.m](./Examples/BoonNano_StreamingExample.m)
-  __Connection Test__: [connect_example.m](./Examples/connect_example.m)

%
% BoonNanoSDK: Handle class containing functions for interacting with the
% BoonNano Rest API.
%
% This is the primary handle to manage a Nano Pod instance.
% This SDK requires a valid license from Boon Logic Inc.
% Contact Boon Logic Inc. to receive a license.
%
%
%   BoonNanoSDK methods:
%     BoonNanoSDK       - Constructor
%     openNano          - Open Nano Pod API Instance
%     closeNano         - Destructor method - closes Nano Pod
%     nanoList          - Return list of active Nano Pod instances
%     saveNano          - Serialize the Nano Pod instance and save it to local file
%     restoreNano       - Restore a Nano Pod instance from local file
%     configureNano     - Configure the Nano Pod parameters
%     generateConfig    - Generate formatted struct containing configuration
%     getConfig         - Get current Nano Pod configuration parameters
%     autotuneConfig	- Autotune the Nano Pod configuration parameters
%     loadData          - Send data to the Nano Pod for clustering
%     runNano	        - Run the current Nano Pod instance with the loaded data
%     getNanoResults	- Get results from latest Nano run
%     getNanoStatus     - Results in relation to each cluster/overall stats
%     getBufferStatus	- Results related to the bytes processed/in the buffer
%     getVersion        - Get the current Nano Pod version information
%
%
%
%   BoonNanoSDK properties:
%     license_id        - License id block from .BoonLogic.license file
%     api_key           - API license key
%     api_tenant        - API license tenant
%     server            - Address of API server
%     url               - Full URL of API server
%     http              - HTTPOptions for interacting with server
%     http_header       - HTTP Header for interacting with server
%     instance          - Active Instance ID
%     instance_config   - Dictionary of open instances
%
%
% Naming conventions:
%   under_score: variables, camelCase: functions, TitleCase: classes
%
% Copyright 2020, Boon Logic Inc.
%

classdef BoonNanoSDK < handle
    properties (SetAccess = private)
        license_id
        api_key
        api_tenant
        server
        url
        http
        http_header
        instance
        instance_config
    end
    methods
        function obj = BoonNanoSDK(license_id, license_file, timeout)
        % BoonNanoSDK Constructor method for BoonNanoSDK class
        %
        % Optional Args:
        %   license_id (char): license id ('default')
        %   license_file (char): path to the license file
        %                       Unix Default: ~/.BoonLogic.license
        %                       Windows Default:
        %                       C:/Users/<user>/.BoonLogic.license
        %   timeout (float): HTTP Request Timeout (120.0)
        %
        % Returns:
        %   BoonNanoSDK (class): class handle
        %

            %version check
            verstr = version('-release');
            year = str2double(verstr(1:4));
            if(year < 2018)
               warning('This version of Matlab is old, certain methods may not work properly.');
               warning('Consider upgrading to version 2018a or newer.');
            end

            %authentication file
            default_license_file = '~/.BoonLogic.license';
            if ispc
                home_drive = getenv('HOMEDRIVE');
                home_path = getenv('HOMEPATH');
                default_license_file = [home_drive home_path '\.BoonLogic.license'];
            end

            %defaults
            obj.license_id = '';
            obj.api_key = '';
            obj.api_tenant = '';
            obj.server = '';
            obj.url = '';
            obj.instance = '';
            obj.instance_config = struct; %store configs across instances

            %args
            if( nargin < 3)
                timeout = 120.0;
            end
            if(nargin < 2)
                license_file = default_license_file;
            end
            if(nargin < 1)
                license_id = 'default';
            end
            
            license_block = struct;
            
            if ( exist(license_file, 'file') == 2 )
                % Load license file
                json_file = fileread(license_file);
                file_data = jsondecode(json_file); % returns struct

                % load the license block, environment gets precedence
                license_env = getenv('BOON_LICENSE_ID');
                if(~isempty(license_env))
                    if( isfield(file_data, license_env) )
                        obj.license_id = license_env;
                    else
                        error('MATLAB:arg:missingValue','BOON_LICENSE_ID value of %s not found in .BoonLogic.license file %s', license_env, license_file);
                    end
                else
                    if( isfield(file_data, license_id) )
                        obj.license_id = license_id;
                    else
                        error('MATLAB:arg:missingValue','BOON_LICENSE_ID value of %s not found in .BoonLogic.license file %s', license_id, license_file);
                    end
                end

                %Extract json data for this license ID
                license_block = getfield(file_data, obj.license_id);
            end

            %look for api_key
            obj.api_key = getenv('BOON_API_KEY');
            if(isempty(obj.api_key))
                if(~isfield(license_block, 'api_key') )
                    error('MATLAB:arg:missingValue','api-key is missing from configuration, set via BOON_API_KEY or in .BoonLogic.license file');
                end
                obj.api_key = license_block.api_key;
            end

            %look for server
            obj.server = getenv('BOON_SERVER');
            if(isempty(obj.server))
                if(~isfield(license_block, 'server') )
                    error('MATLAB:arg:missingValue','server is missing from configuration, set via BOON_SERVER or in .BoonLogic.license file');
                end
                obj.server = license_block.server;
            end

            %look for api_tenent
            obj.api_tenant = getenv('BOON_TENANT');
            if(isempty(obj.api_tenant))
                if(~isfield(license_block, 'api_tenant') )
                    error('MATLAB:arg:missingValue','api-tenant is missing from configuration, set via BOON_TENANT or in .BoonLogic.license file');
                end
                obj.api_tenant = license_block.api_tenant;
            end
            
            obj.url = [obj.server '/expert/v3/'];
            if ( ~contains(obj.server, 'http') )
                obj.url = ['http://' obj.url];
            end
            
            %HTTP Options
            obj.http = matlab.net.http.HTTPOptions('ConnectTimeout',timeout,'DecodeResponse',true,'KeepAliveTimeout',Inf);
            
            %Optional proxy server
            env_proxy = getenv('PROXY_SERVER');
            if(~isempty(env_proxy))
                obj.http.UseProxy = true;
                obj.http.ProxyURI = env_proxy;
            elseif(isfield(license_block, 'proxy_server') && ~isempty(license_block.proxy_server) )
                obj.http.UseProxy = true;
                obj.http.ProxyURI = license_block.proxy_server;
            else
                obj.http.UseProxy = false;
            end
            
            %Default Headers
            obj.http_header = matlab.net.http.HeaderField('x-token', obj.api_key,'Content-Type','application/json');
        end


        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%% Creation and Management of NanoPod Instances
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

        function [success, instance_response] = openNano(obj, instance_id)
        % openNano  Open Nano Pod API Instance
        %
        % Args:
        %   instance_id (char): instance identifier to assign to new pod instance
        %
        % Returns:
        %   success status (bool): true if api call succesful
        %   instance_response (struct): server response if success=true
        %

            success = false;
            instance_response = struct;

            % check types
            if ~ischar(instance_id)
                error('MATLAB:arg:invalidType','instance_id must be a char');
            end

            %build command
            instance_cmd = [obj.url 'nanoInstance/' instance_id '?api-tenant=' obj.api_tenant];

            %request instance
            body = matlab.net.http.MessageBody('0');
            req = matlab.net.http.RequestMessage(matlab.net.http.RequestMethod.POST, obj.http_header, body);
            [response,completedrequest,~] = req.send(instance_cmd, obj.http);

            % check for errors
            if (~completedrequest.Completed || response.StatusCode ~= 200)
                [error_type, error_msg] = obj.formatError(response);
                error(error_type, error_msg);
                obj.instance = '';
                return;
            end
            
            %store instance
            obj.instance = response.Body.Data.instanceID;

            %Key data
            instance_response = response.Body.Data;
            success = true;
            return
        end

        function [success, close_response] = closeNano(obj, instance_id)
        % closeNano Destructor method - closes Nano Pod.
        %
        % Args: (empty)
        %
        % Returns:
        %   success (bool): true if api call succesful
        %   close_response (struct): server response if success=true
        %

            success = false;
            close_response = struct;

            if(nargin < 2)
                if( isempty(obj.instance) )
                    error('MATLAB:class:invalidUsage','No Active Instances To Close. Call openNano() first.');
                else
                    instance_name = obj.instance;
                end
            else
                if isempty(instance_id) || ~ischar(instance_id)
                    error('MATLAB:arg:invalidType','instance_id must not be a non-empty char.');
                else
                    instance_name = instance_id;
                end
            end

            %command
            close_cmd = [obj.url 'nanoInstance/' instance_name '?api-tenant=' obj.api_tenant];

            %Close instance
            req = matlab.net.http.RequestMessage(matlab.net.http.RequestMethod.DELETE, obj.http_header, []);
            [response,completedrequest,~] = req.send(close_cmd, obj.http);

            % check for errors
            if (~completedrequest.Completed || response.StatusCode ~= 200)
                %Throw relevant error
                [error_type, error_msg] = obj.formatError(response);
                error(error_type, error_msg);
                obj.instance = '';
                return;
            end

            if isfield(obj.instance_config,instance_name)
                obj.instance_config = rmfield(obj.instance_config,instance_name);
            end
            
            if ~isempty(obj.instance) && strcmp(obj.instance, instance_name)
                obj.instance = '';
            end
            
            close_response = response.Body.Data;
            success = true;
            return
        end

        function [success, list_response] = nanoList(obj)
            % nanoList Return list of active Nano Pod instances
            %
            % Args: (empty)
            %
            % Returns:
            %   success (bool): true if api call successful
            %   list_response (struct): List of active nanos
            %

            % check for error
            success = false;
            
            % build command
            instance_cmd = [obj.url 'nanoInstances' '?api-tenant=' obj.api_tenant];
             
            % list of running instances
            req = matlab.net.http.RequestMessage(matlab.net.http.RequestMethod.GET, obj.http_header);
            [response,completedrequest,~] = req.send(instance_cmd, obj.http);
            
            %Check for errors
            if (~completedrequest.Completed || response.StatusCode ~= 200)
                [error_type, error_msg] = obj.formatError(response);
                error(error_type, error_msg);
                return;
            end
            
            list_response = response.Body.Data;
            success = true;
            return
        end

        function [success] = saveNano(obj, filename)
        % saveNano Serialize the Nano Pod instance and save it to local file
        %
        % Args:
        %   filename (char): Full path to file for saving
        %                       File must be of type .tar
        %
        % Returns:
        %   success (bool): true if api call succesful
        %

            success = false;
            if( isempty(obj.instance) )
                error('MATLAB:class:invalidUsage','No Active Instances To Save. Call openNano() first.');
            end

            %check filetype
            if( ~contains(filename, '.tar'))
                error('MATLAB:arg:invalidType','Dataset Must Be In .tar Format');
            end

            % build command
            snapshot_cmd = [obj.url 'snapshot/' obj.instance '?api-tenant=' obj.api_tenant];

            % serialize nano
            header = matlab.net.http.HeaderField('x-token', obj.api_key,'Content-Type','application/octet-stream');
            req = matlab.net.http.RequestMessage(matlab.net.http.RequestMethod.GET, header);
            [response,completedrequest,~] = req.send(snapshot_cmd, obj.http);
            
            %Check for errors
            if (~completedrequest.Completed || response.StatusCode ~= 200)
                [error_type, error_msg] = obj.formatError(response);
                error(error_type, error_msg);
                return;
            end
            
            %Body of response
            snapshot_response = response.Body.Data;

            % at this point, the call succeeded so save to a tar file
            fileID = fopen(filename,'w');
            if(fileID < 0)
               error('MATLAB:filewrite:cannotOpenFile','Unable to open file %s for writing',filename);
            end
            fwrite(fileID,snapshot_response);
            fclose(fileID);
            success = true;

            return;
        end

        function [success] = restoreNano(obj, filename)
        % restoreNano Restore a Nano Pod instance from local file
        %
        % Args:
        %   filename (char): Full path to file for loading
        %
        % Returns:
        %   success (bool): true if api call succesful
        %

            success = false;
            if( isempty(obj.instance) )
                error('MATLAB:class:invalidUsage','No Active Instances To Restore. Call openNano() first.');
            end

            %check filetype
            if( ~contains(filename, '.tar'))
                error('MATLAB:arg:invalidType','Dataset Must Be In .tar Format');
            end

            % build command
            snapshot_cmd = [obj.url 'snapshot/' obj.instance '?api-tenant=' obj.api_tenant ];

            % post serialized nano
            provider = matlab.net.http.io.FileProvider(filename); % get array of providers
            multipart = matlab.net.http.io.MultipartFormProvider('snapshot',provider);
            header = matlab.net.http.HeaderField('x-token', obj.api_key,'Content-Type','multipart/form-data');
            req = matlab.net.http.RequestMessage(matlab.net.http.RequestMethod.POST,header,multipart);
            [response,completedrequest,~] = req.send(snapshot_cmd, obj.http);

            % check for error
            if (~completedrequest.Completed || response.StatusCode ~= 200)
                [error_type, error_msg] = obj.formatError(response);
                error(error_type, error_msg);
                return;
            end

            %Parse
            if ~isfield(obj.instance_config,obj.instance)
                obj.instance_config.(obj.instance) = struct;
            end
            obj.instance_config.(obj.instance).numeric_format = response.Body.Data.numericFormat;
            obj.instance_config.(obj.instance).feature_count = length(response.Body.Data.features);
            success = true;
            return
        end



        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%% Configuration
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

        function [success, config_response] = configureNano(obj, config)
        % configureNano Configure the Nano Pod parameters
        %
        % Args:
        %   config (struct): Configuration returned from generateConfig()
        %
        % Returns:
        %   success (bool): success = true if Nano if configured
        %   config_response (struct): will match config when success = true
        %

            success = false;
            config_response = struct;
            if( isempty(obj.instance) )
                error('MATLAB:class:invalidUsage','No Active Instances To Configure. Call openNano() first.');
            end

            if (nargin < 2 || isempty(config) || ~isfield(config,'accuracy') || ~isfield(config,'percentVariation') || ~isfield(config,'features') || ~isfield(config,'numericFormat'))
              error('MATLAB:arg:invalidType','Must pass valid config as arg, call generateConfig() first');
            end
           
            % build command
            config_cmd = [obj.url 'clusterConfig/' obj.instance '?api-tenant=' obj.api_tenant];

            %request instance
            body = matlab.net.http.MessageBody(config);
            header = matlab.net.http.HeaderField('x-token', obj.api_key,'Content-Type','application/json'); %, 'Media-Type','application/json');
            req = matlab.net.http.RequestMessage(matlab.net.http.RequestMethod.POST, header, body);
            [response,completedrequest,~] = req.send(config_cmd, obj.http);

            % check for errors
            if (~completedrequest.Completed || response.StatusCode ~= 200)
                [error_type, error_msg] = obj.formatError(response);
                error(error_type, error_msg);
                return;
            end
            
            %Body of response
            config_response = response.Body.Data;
            
            %Check that configuration took
            if(config_response.accuracy ~= config_response.accuracy)
                warning('Configuration Response From Server Does Not Match Request');
                return;
            end
               

            %instance configurations
            if ~isfield(obj.instance_config,obj.instance)
                obj.instance_config.(obj.instance) = struct;
            end
            obj.instance_config.(obj.instance).numeric_format = config.numericFormat;
            obj.instance_config.(obj.instance).feature_count = length(config.features);

            success = true;

            return;
        end

        function [success, config] = generateConfig(obj, feature_count, numeric_format, percent_variation, accuracy, min, max, streaming_window, weight, labels)
        % generateConfig Generate formatted struct containing configuration
        %
        % Args:
        %   feature_count (int): number of features per sample
        %   numeric_format (char): 'uint16', 'int16', or 'float32'
        %
        % Optional Args:
        %   percent_variation (float): Variation between clusters (0.05)
        %   accuracy (float): Intra cluster accuracy (0.99)
        %   min (vector): min value per feature (0)
        %   max (vector): max value per feature (10)
        %   streaming_window (int): sliding window for streaming data (1)
        %   weight (vector): relative weightings [1]
        %   labels (char): feature labels ('')
        %
        % Returns:
        %   success (bool): success = true if all parameters are valid
        %   config (struct): Populated configuration to send to server
        %

            success = false;
            config = struct;

            %args
            if(nargin < 3)
                error('MATLAB:arg:invalidType','Must specify feature_count and numeric_format');
            end
            if(nargin < 4)
                percent_variation = 0.05;
            end
            if(nargin < 5)
                accuracy = 0.99;
            end
            if(nargin < 6)
                min = 1;
            end
            if(nargin < 7)
                max = 10;
            end
            if(nargin < 8)
                streaming_window = 1;
            end
            if(nargin < 9)
                weight = 1;
            end
            if(nargin < 10)
                labels = '';
            end

            %align numeric format
            cmp = strcmp(numeric_format,{'float', 'double', 'single'});
            if any(cmp(:))
                disp('Inferring numeric_format = float32');
                numeric_format = 'float32';
            end
            cmp = strcmp(numeric_format,{'int16_t', 'int'});
            if any(cmp(:))
                disp('Inferring numeric_format = int16');
                numeric_format = 'int16';
            end
            cmp = strcmp(numeric_format,{'uint16_t', 'uint', 'native'});
            if any(cmp(:))
                disp('Inferring numeric_format = uint16');
                numeric_format = 'uint16';
            end

            %check for valid numeric format
            cmp = strcmp(numeric_format,{'float32', 'int16', 'uint16'});
            if ~any(cmp(:))
            	error('MATLAB:arg:invalidType','numeric_format must be float32, int16, or uint16');
            end

            %check dimensions of args
            if(length(max) ~= 1 && length(max) ~= feature_count)
                error('MATLAB:arg:invalidType','length(max) must match feature_count');
            end
            if(length(min) ~= 1 && length(min) ~= feature_count)
                error('MATLAB:arg:invalidType','length(min) must match feature_count');
            end
            if(length(weight) ~= 1 && length(weight) ~= feature_count)
                error('MATLAB:arg:invalidType','length(weight) must match feature_count');
            end

            %initialize configuration structure
            temparray = {};
            for x = 1:feature_count
                temp_feature = struct;
                % max
                if (length(max) == 1)
                    temp_feature.maxVal = max;
                else  %the max vals are given as a list
                    temp_feature.maxVal = max(x);
                end
                % min
                if (length(min) == 1)
                    temp_feature.minVal = min;
                else % the min vals are given as a list
                    temp_feature.minVal = min(x);
                end
                % weights
                if (length(weight) == 1)
                    temp_feature.weight = uint16(weight);
                else % the weight vals are given as a list
                    temp_feature.weight = uint16(weight(x));
                end
                % labels
                if (~isempty(labels) && ~isempty(labels(x)))
                    temp_feature.label = labels(x);
                end
                temp_array{x} = temp_feature;
            end

            %build json struct
            config.accuracy = accuracy;
            config.features = temp_array;
            config.numericFormat = numeric_format;
            config.percentVariation = percent_variation;
            config.streamingWindowSize = streaming_window;
            success = true;
        end

        function [success, autotune_response] = autotuneConfig(obj, autotune_pv, autotune_range, by_feature, exclusions)
        % autotuneConfig Autotune the Nano Pod configuration parameters
        %
        % Args: (empty)
        %
        % Optional Args:
        %   autotune_pv (bool): Autotune percent variation (true)
        %   autotune_range (bool): Autotune min and max (true)
        %   by_feature (bool): Autotune each feature seperately (false)
        %   exclusions (char): Feature columns to ignore (empty)
        %
        % Returns:
        %   success (bool): true if api call succesful
        %   autotune_response (struct): The autotuned configuration
        %

            success = false;
            autotune_response = struct;

            %check for active instance
            if( isempty(obj.instance) )
                error('MATLAB:class:invalidUsage','No Active Instances To Autotune. Call openNano() first.');
            end

            %Parse Args
            if (nargin < 2)
                autotune_pv=true;
            end
            if (nargin < 3)
                autotune_range=true;
            end
            if (nargin < 4)
                by_feature=false;
            end
            if (nargin < 5)
                exclusions='';
            end


            % build command
            config_cmd = [obj.url 'autoTuneConfig/' obj.instance '?api-tenant=' obj.api_tenant '&byFeature=' obj.bool2char(by_feature) '&autoTunePV=' obj.bool2char(autotune_pv) '&autoTuneRange=' obj.bool2char(autotune_range)];
            if ~isempty(exclusions)
                config_cmd = [config_cmd '&exclusions=' exclusions];
            end
            
            %request autotune
            body = matlab.net.http.MessageBody('0');
            req = matlab.net.http.RequestMessage(matlab.net.http.RequestMethod.POST, obj.http_header, body);
            [response,completedrequest,~] = req.send(config_cmd, obj.http);

            % check for errors
            if (~completedrequest.Completed || response.StatusCode ~= 200)
                [error_type, error_msg] = obj.formatError(response);
                error(error_type, error_msg);
                return;
            end
            
            %Body of response
            autotune_response = response.Body.Data;

            %instance configurations
            if ~isfield(obj.instance_config,obj.instance)
                obj.instance_config.(obj.instance) = struct;
            end
            obj.instance_config.(obj.instance).numeric_format = autotune_response.numericFormat;
            obj.instance_config.(obj.instance).feature_count = length(autotune_response.features);

            success = true;

            return;
        end

        function [success, config_response] = getConfig(obj)
        % getConfig Get current Nano Pod configuration parameters
        %
        % Args: (empty)
        %
        % Returns:
        %   success (bool): true if api call succesful
        %   config_response (struct): Configuration struct from server
        %

            success = false;
            config_response = struct;
            if( isempty(obj.instance) )
                error('MATLAB:class:invalidUsage','No Active Instances. Call openNano() first.');
            end

            % build command
            config_cmd = [obj.url 'clusterConfig/' obj.instance '?api-tenant=' obj.api_tenant];

            % Read nano configuration
            req = matlab.net.http.RequestMessage(matlab.net.http.RequestMethod.GET, obj.http_header);
            [response,completedrequest,~] = req.send(config_cmd, obj.http);

            % check for errors
            if (~completedrequest.Completed || response.StatusCode ~= 200)
                [error_type, error_msg] = obj.formatError(response);
                error(error_type, error_msg);
                return;
            end
            
            %Body of response
            config_response = response.Body.Data;
            success = true;

            return;
        end


        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%% Loading Data and Clustering
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

        function [success, load_response] = loadData(obj, data, append_data)
        % loadData Send data to the Nano Pod for clustering
        %
        % Args:
        %   data (matrix): Data to load
        %                  Assumes row-major order
        %                  # columns = config.feature_count
        %
        % Optional Args:
        %   append_data (bool): Append this data to existing server data
        %
        % Returns:
        %   success (bool): true if api call successful
        %   load_response (struct): Response information if success = true
        %

            success = false;
            load_response = struct;

            % Optional arguments
            if(nargin<2 || isempty(data) || ~isnumeric(data))
                error('MATLAB:arg:invalidType','Must pass data matrix as argument');
            end
            if(nargin<3)
                append_data=false;
            end

            %check for instances
            if( isempty(obj.instance) )
                error('MATLAB:class:invalidUsage','No Active Instances. Call openNano() first.');
            end
            
            if isfield(obj.instance_config, obj.instance)
                %instance configurations
                inst_config = obj.instance_config.(obj.instance);

                %check data dimensions
                [nsamples, nfeatures] = size(data);
                if(nfeatures ~= inst_config.feature_count)
                   warning('BoonNanoSDK is Row Major, Loading %d Samples, %d Features', nsamples, nfeatures);
                end
            
                %set numeric format for upload
                numeric_format = inst_config.numeric_format;
            else
                %infer feature count and type
                [~, feature_count] = size(data);
                data_format = class(data);
                
                %create temp configuration
                [~, config] = obj.generateConfig(feature_count, data_format);
                numeric_format = config.numericFormat;
                
                %flash warning
                warning('Nano Pod is Not Configured. Inferring Feature Count = %d, Numeric Format = %s', feature_count, numeric_format);
                [~, ~] = obj.configureNano(config);
                
            end

            % build command
            load_cmd = [obj.url 'data/' obj.instance '?api-tenant=' obj.api_tenant '&fileType=raw' '&appendData=' obj.bool2char(append_data)];

            %format multi part message
            mat_provider = MatrixProvider(data, numeric_format);
            multipart = matlab.net.http.io.MultipartFormProvider('data',mat_provider);
            header = matlab.net.http.HeaderField('x-token', obj.api_key,'Content-Type','multipart/form-data');
            req = matlab.net.http.RequestMessage(matlab.net.http.RequestMethod.POST,header,multipart);
            [load_response,completedrequest,~] = req.send(load_cmd, obj.http);

            % check for error
            if (~completedrequest.Completed || load_response.StatusCode ~= 200)
                display(load_response);
                return;
            end
            success = true;

            return;
        end

        function [success, run_response] = runNano(obj, results)
        % runNano Run the current Nano Pod instance with the loaded data
        %
        % Args:
        %   results (char): Comma seperated result identifiers
        %         ID = cluster ID
        %         SI = smoothed anomaly index
        %         RI = raw anomaly index
        %         FI = frequency index
        %         DI = distance index
        %
        % Returns:
        %   success (bool)
        %   run_response (struct): Run response when success = true
        %                          Error message when success = false
        %

            success = false;
            run_response = struct;
            if strcmp(results, 'All')
                results_str = 'ID,SI,RI,FI,DI';
            elseif(isempty(results))
                results_str = results;
            else
                results_split = split(results,',');
                valid = {'ID','SI','RI','FI','DI'};
                for i = 1:length(results_split)
                   isin = contains(results_split(i),valid);
                   if(~any(isin(:)) )
                       error('MATLAB:arg:invalidType','unknown result %s found in results parameter', string(results_split(i)));
                   end
                end
                results_str = results;
            end

            %check for instances
            if( isempty(obj.instance) )
                error('MATLAB:class:invalidUsage','No Active Instances. Call openNano() first.');
            end

            %Command
            nano_cmd = [obj.url 'nanoRun/' obj.instance '?api-tenant=' obj.api_tenant];
            if ~isempty(results)
                nano_cmd = [nano_cmd '&results=' results_str];
            end

            % run nano
            body = matlab.net.http.MessageBody('0');
            req = matlab.net.http.RequestMessage(matlab.net.http.RequestMethod.POST, obj.http_header, body);
            [response,completedrequest,~] = req.send(nano_cmd, obj.http);

            % check for errors
            if (~completedrequest.Completed || response.StatusCode ~= 200)
                [error_type, error_msg] = obj.formatError(response);
                error(error_type, error_msg);
                return;
            end
            
            %Body of response
            run_response = response.Body.Data;
            success = true;

            return;
        end

        function [success, results_response] = getNanoResults(obj, results)
        % getNanoResults Get results from latest Nano run
        %
        % Args:
        %   results (char): Comma seperated result identifiers
        %         ID = cluster ID
        %         SI = smoothed anomaly index
        %         RI = raw anomaly index
        %         FI = frequency index
        %         DI = distance index
        %
        % Returns:
        %   success (bool):  true if successful
        %   results_response [struct]: Results when success = true
        %                               Error message when success = false
        %

            success = false;
            results_response = struct;
            if(nargin < 2)
                results = 'All'; %default
            end

            if strcmp(results, 'All')
                results_str = 'ID,SI,RI,FI,DI';
            elseif(isempty(results))
                error('MATLAB:arg:invalidType','results string must contain atleast one valid identifier');
            else
                results_split = split(results,',');
                valid = {'ID','SI','RI','FI','DI'};
                for i = 1:length(results_split)
                   isin = contains(results_split(i),valid);
                   if(~any(isin(:)) )
                       error('MATLAB:arg:invalidType','unknown result %s found in results parameter', string(results_split(i)));
                   end
                end
                results_str = results;
            end

            %check for instances
            if( isempty(obj.instance) )
                error('MATLAB:class:invalidUsage','No Active Instances. Call openNano() first.');
            end

            %Command
            results_cmd = [obj.url 'nanoResults/' obj.instance '?api-tenant=' obj.api_tenant '&results=' results_str];

            % results
            req = matlab.net.http.RequestMessage(matlab.net.http.RequestMethod.GET, obj.http_header);
            [response,completedrequest,~] = req.send(results_cmd, obj.http);

            % check for errors
            if (~completedrequest.Completed || response.StatusCode ~= 200)
                [error_type, error_msg] = obj.formatError(response);
                error(error_type, error_msg);
                return;
            end
            
            %Body of response
            results_response = response.Body.Data;
            success = true;

            return;
        end

        function [success, status_response] = getNanoStatus(obj, results)
        % getNanoStatus Results in relation to each cluster/overall stats
        %
        % Args:
        %   results (char): Comma seperated result identifiers
        %     PCA = principal components (includes 0 cluster)
        %     clusterGrowth = indexes of each increase in cluster (includes 0 cluster)
        %     clusterSizes = number of patterns in each cluster (includes 0 cluster)
        %     anomalyIndexes = anomaly index (includes 0 cluster)
        %     frequencyIndexes = frequency index (includes 0 cluster)
        %     distanceIndexes = distance index (includes 0 cluster)
        %     patternMemory = base64 pattern memory (overall)
        %     totalInferences = total number of patterns clustered (overall)
        %     averageInferenceTime = time in milliseconds to cluster per
        %         pattern (not available if uploading from serialized Nano) (overall)
        %     numClusters = total number of clusters (includes 0 cluster) (overall)
        %
        % Returns:
        %   success (bool):  true if successful
        %   status_response [struct]: Results when success = true
        %                               Error message when success = false
        %

            if(nargin < 2)
                results = 'All'; %default
            end

            %parse args
            success = false;
            status_response = struct;
            if strcmp(results, 'All')
                results_str = 'PCA,clusterGrowth,clusterSizes,anomalyIndexes,frequencyIndexes,distanceIndexes,totalInferences,numClusters';
            elseif(isempty(results))
                error('MATLAB:arg:invalidType','results string must contain atleast one valid identifier');
            else
                resultsplit = split(results,',');
                valid = {'PCA','clusterGrowth','clusterSizes','anomalyIndexes','frequencyIndexes','distanceIndexes','totalInferences','numClusters','averageInferenceTime'};
                for i = 1:length(resultsplit)
                   isin = contains(resultsplit(i),valid);
                   if(~any(isin(:)) )
                       error('MATLAB:arg:invalidType','unknown result %s found in results parameter', string(resultsplit(i)));
                   end
                end
                results_str = results;
            end

            %check for instances
            if( isempty(obj.instance) )
                error('MATLAB:class:invalidUsage','No Active Instances. Call openNano() first.');
            end

            % Command
            status_cmd = [obj.url 'nanoStatus/' obj.instance '?api-tenant=' obj.api_tenant '&results=' results_str];

            % results
            req = matlab.net.http.RequestMessage(matlab.net.http.RequestMethod.GET, obj.http_header);
            [response,completedrequest,~] = req.send(status_cmd, obj.http);

            % check for errors
            if (~completedrequest.Completed || response.StatusCode ~= 200)
                [error_type, error_msg] = obj.formatError(response);
                error(error_type, error_msg);
                return;
            end
            
            % Body of response
            status_response = response.Body.Data;
            success = true;

            return;
        end


        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%% NanoPod General Information
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

        function [success, version_response] = getVersion(obj)
        % getVersion Get the current Nano Pod version information
        %
        % Args: (empty)
        %
        % Returns:
        %    success (boolean): true if successful
        %    version_response (struct): Version information when success = true
        %                               Error message when success = false
        %

            success = false;
            version_response = struct;
            
            % build command (minus the v3 portion)
            version_cmd = [obj.url(1:end-3) 'version' '?api-tenant=' obj.api_tenant];

            % get response
            req = matlab.net.http.RequestMessage(matlab.net.http.RequestMethod.GET, obj.http_header);
            [response,completedrequest,~] = req.send(version_cmd, obj.http);

            % check for errors
            if (~completedrequest.Completed || response.StatusCode ~= 200)
                [error_type, error_msg] = obj.formatError(response);
                error(error_type, error_msg);
                return;
            end
            
            % Body of response
            version_response = response.Body.Data;
            success = true;

            return;
        end

        function [success, status_response] = getBufferStatus(obj)
        % getBufferStatus Results related to the bytes processed/in the buffer
        %
        % Args: (empty)
        %
        % Returns:
        %    success (boolean): true if successful
        %    status_response (struct): Buffer size when success = true
        %                               Error message when success = false
        %

            success = false;
            status_response = struct;
            
            % build command
            status_cmd = [obj.url 'bufferStatus/' obj.instance '?api-tenant=' obj.api_tenant];

            % get response
            req = matlab.net.http.RequestMessage(matlab.net.http.RequestMethod.GET, obj.http_header);
            [response,completedrequest,~] = req.send(status_cmd, obj.http);

            % check for errors
            if (~completedrequest.Completed || response.StatusCode ~= 200)
                [error_type, error_msg] = obj.formatError(response);
                error(error_type, error_msg);
                return;
            end
            
            % Body of response
            status_response = response.Body.Data;
            success = true;
            
            return;
        end

    end
    
    methods (Access = private)
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%% Utility Methods
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        function [error_type, error_msg] = formatError(~, response)
        % formatError: Format error codes from HTTP Response
        %
        % Args: response (matlab.net.http.ResponseMessage): Response from
        %                                                   request
        %
        % Returns:
        %    error_type (char): Relevant Code
        %    error_msg (char): Relevant Reason
        %
            error_type = ['MATLAB:webservices:HTTP' int2str(response.StatusCode) 'StatusCodeError'];
            error_msg = ['Error: ' int2str(response.StatusCode) ' ' char(response.StatusLine.ReasonPhrase)];
        end
        
        function boolstring = bool2char(~, boolean)
        % bool2char: Converts bool to 'true' or 'false' char arrays
        %
        % Args: boolean (bool or int): bool value ie 0 or 1
        %
        % Returns:
        %    boolstring (char): 'true' or 'false'
        %
            if(boolean >= 1)
                boolstring = 'true';
            else
                boolstring = 'false';
            end
        end
    end
end

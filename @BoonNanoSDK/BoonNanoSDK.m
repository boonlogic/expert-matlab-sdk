% Copyright 2020, Boon Logic Inc.

classdef BoonNanoSDK < handle
    % BoonNanoSDK: class containing functions for interacting with the
    % BoonNano cloud api.
    % This is the primary handle to manage a nano pod instance.
    % Naming conventions: 
    % under_score: variables, camelCase: functions, TitleCase: classes
    properties (SetAccess = private)
        license_id
        api_key
        api_tenant
        server
        url
        http
        instance
        instance_config
    end
    methods
        function obj = BoonNanoSDK(license_id, license_file, timeout)
        % BoonNanoSDK(): Constructor Method For BoonNanoSDK
        % Optional Args:
        %   license_id (str): license id ('default')
        %   license_file (str): path to the license file ('~/.BoonLogic')
        %   timeout (float): HTTP Request Timeout (120.0)
        %
        % Returns:
        %   nano dictionary handle 
        
            %version check
            verstr = version('-release');
            year = str2double(verstr(1:4));
            if(year < 2018)
               warning('This version of Matlab is old, certain methods may not work properly.');
               warning('Consider upgrading to version 2018a or newer.'); 
            end
            
            %authentication file
            default_license_file = '~/.BoonLogic';
            if ispc
                default_license_file = 'C:/temp/.BoonLogic';
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

            % Load license file
            json_file = fileread(license_file);
            file_data = jsondecode(json_file); % returns struct
            
            % load the license block, environment gets precedence
            license_env = getenv('BOON_LICENSE_ID');
            if(~isempty(license_env))
                if( isfield(file_data, license_env) )
                    obj.license_id = license_env;
                else
                    error('BOON_LICENSE_ID value of %s not found in .BoonLogic file %s', license_env);
                end
            else
                if( isfield(file_data, license_id) )
                    obj.license_id = license_id;
                else
                    error('BOON_LICENSE_ID value of %s not found in .BoonLogic file %s', license_id);
                end
            end

            %Extract json data for this license ID
            license_block = getfield(file_data, obj.license_id);

            %look for api_key
            obj.api_key = getenv('BOON_API_KEY');
            if(isempty(obj.api_key))
                if(~isfield(license_block, 'api_key') )
                    error('api-key is missing from configuration, set via BOON_API_KEY or in .BoonLogic file');
                end
                obj.api_key = license_block.api_key;
            end

            %look for server
            obj.server = getenv('BOON_SERVER');
            if(isempty(obj.server))
                if(~isfield(license_block, 'server') )
                    error('server is missing from configuration, set via BOON_SERVER or in .BoonLogic file');
                end
                obj.server = license_block.server;
            end

            %look for api_tenent
            obj.api_tenant = getenv('BOON_TENANT');
            if(isempty(obj.api_tenant))
                if(~isfield(license_block, 'api_tenant') )
                    error('api-tenant is missing from configuration, set via BOON_TENANT or in .BoonLogic file');
                end
                obj.api_tenant = license_block.api_tenant;
            end

            obj.url = [obj.server '/expert/v3/'];
            if ( ~contains(obj.server, 'http') )
                obj.url = ['http://' obj.url];
            end

            %Base weboptions
            obj.http = weboptions('RequestMethod','get','Timeout',timeout,'ContentType','json','KeyName','x-token','KeyValue',obj.api_key);
        end
        

        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%% Creation and Management of NanoPod Instances
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        function [success, instance_response] = openNano(obj, instance_id)
        % openNano:  Open Nano API Instance
        % Args:
        %   instance_id (char): instance identifier to assign to new pod instance
        % Returns:
        %   success status (bool): true if api call succesful
        %   instance_response (struct): server response if success=true
            
            success = false;
            instance_response = struct;
            
            % check types
            if ~ischar(instance_id)
                error('instance_id must be a char');
            end
            
            %build command
            instance_cmd = [obj.url 'nanoInstance/' instance_id '?api-tenant=' obj.api_tenant];
            options = obj.http; %default options
            options.RequestMethod = 'post';
            options.ContentType = 'auto';
            
            %initialize instance
            instance_response = webread(instance_cmd, options);

            % check for error
            if (~isfield(instance_response, 'instanceID') || ~strcmp(instance_response.instanceID, instance_id))
                display(instance_response);
                obj.instance = '';
                return;
            end

            obj.instance = instance_id;
            if ~isfield(obj.instance_config,obj.instance)
                obj.instance_config.(obj.instance) = struct;
            end
            
            success = true;
            return
        end
        
        function success = closeNano(obj)
        % closeNano Destructor Method.
        % Args:
        %
        % Returns:
        %   success (bool): true if api call succesful
        
            success = false;
            if( isempty(obj.instance) )
                error('No Active Instances To Close. Call openNano() first.');
            end
            
            %command
            close_cmd = [obj.url 'nanoInstance/' obj.instance '?api-tenant=' obj.api_tenant];
            options = obj.http; %default options
            options.RequestMethod = 'delete';
            options.ContentType = 'auto';
            
            % delete instance
            close_response = webread(close_cmd, options );
            if (close_response.code ~= 200)
                display(close_response)
                return
            end

            if isfield(obj.instance_config,obj.instance)
                obj.instance_config = rmfield(obj.instance_config,obj.instance);
            end
            obj.instance = '';
            success = true;
            return
        end

        function [success, list_response] = nanoList(obj)
            % nanoList: Return list of active nano instances
            % Args:
            %
            % Returns:
            %   success (bool): true if api call succesful
            %   list_response (struct): List of active nanos

            % build command
            instance_cmd = [obj.url 'nanoInstances' '?api-tenant=' obj.api_tenant];
            options = obj.http; %default options
            options.RequestMethod = 'get';
            options.ContentType = 'json';
            
            success = true;
            
            % list of running instances
            list_response = webread(instance_cmd, options);

            return
        end
        
        function [success] = saveNano(obj, filename)
        % saveNano: Serialize the Nano pod and saves it as a tar file
        % Args:
        %   filename (char): Full path to file for saving
        % Returns:
        %   success (bool): true if api call succesful

            success = false;
            if( isempty(obj.instance) )
                error('No Active Instances To Save. Call openNano() first.');
            end
            
            %check filetype
            if( ~contains(filename, '.tar'))
                error('Dataset Must Be In .tar Format');
            end

            % build command
            snapshot_cmd = [obj.url 'snapshot/' obj.instance '?api-tenant=' obj.api_tenant];
            options = obj.http; %default options
            options.RequestMethod = 'get';
            options.ContentType = 'binary';
            
            % serialize nano
            snapshot_response = webread(snapshot_cmd, options);

            % at this point, the call succeeded so save to a tar file
            fileID = fopen(filename,'w');
            if(fileID < 0)
               error('Unable to open file %s for writing',filename); 
            end
            fwrite(fileID,snapshot_response);
            fclose(fileID);
            success = true;

            return;
        end
        
        function [success] = restoreNano(obj, filename)
        % restoreNano: Restore a nano pod instance from local file
        % Args:
        %   filename (char): Full path to file for loading
        % Returns:
        %   success (bool): true if api call succesful
        
            success = false;
            if( isempty(obj.instance) )
                error('No Active Instances To Restore. Call openNano() first.');
            end
            
            %check filetype
            if( ~contains(filename, '.tar'))
                error('Dataset Must Be In .tar Format');
            end

            % build command
            snapshot_cmd = [obj.url 'snapshot/' obj.instance '?api-tenant=' obj.api_tenant ];
            
            % post serialized nano
            provider = matlab.net.http.io.FileProvider(filename); % get array of providers
            multipart = matlab.net.http.io.MultipartFormProvider('snapshot',provider);
            header = matlab.net.http.HeaderField('x-token', obj.api_key,'Content-Type','multipart/form-data');
            req = matlab.net.http.RequestMessage(matlab.net.http.RequestMethod.POST,header,multipart);
            [response,completedrequest,~] = req.send(snapshot_cmd);

            % check for error
            if (response.StatusCode ~= 200)
                display(response);
                return;
            end
            
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
        % configureNano: Configure the Nano pod parameters
        % Args:
        %   config (struct): configuration returned from generateConfig()
        % Returns:
        %   success (bool)
        %   config_response (struct): will match config when success = true
        
            success = false;
            config_response = struct;
            if( isempty(obj.instance) )
                error('No Active Instances To Configure. Call openNano() first.');
            end
            
            if (nargin < 2 || isempty(config))
              error('Must pass valid config, call generateConfig() first');
            end

            % build command
            config_cmd = [obj.url 'clusterConfig/' obj.instance '?api-tenant=' obj.api_tenant];
            options = obj.http; %default options
            options.RequestMethod = 'post';
            options.ContentType = 'json';
            options.MediaType = 'application/json';
            
            % config nano
            config_response = webwrite(config_cmd, config, options);

            %check for error
            if (~isfield(config_response, 'accuracy') || config_response.accuracy ~= config.accuracy)
                display(config_response);
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
        % generateConfig: Configure the Nano pod parameters
        % Args:
        %   feature_count (int): number of features per sample
        %   numeric_format (char): 'uint16', 'int16', or 'float32'
        % Optional Args:
        %   percent_variation (float): Variation between clusters (0.05)
        %   accuracy (float): Intra cluster accuracy (0.99)
        %   min (vector): min value per feature (0)
        %   max (vector): max value per feature (10)
        %   streaming_window (int): sliding window for streaming data (1)
        %   weight (vector): relative weightings [1]
        %   labels (char): feature labels ('')
        % Returns:
        %   success (bool)
        %   config (struct)
            
            success = false;
            config = struct;
            
            %args
            if(nargin < 3)
                error('Must specify feature_count and numeric_format');
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
            	error('numeric_format must be float32, int16, or uint16');
            end
            
            %check dimensions of args
            if(length(max) ~= 1 && length(max) ~= feature_count)
                error('length(max) must match feature_count');
            end
            if(length(min) ~= 1 && length(min) ~= feature_count)
                error('length(min) must match feature_count');
            end
            if(length(weight) ~= 1 && length(weight) ~= feature_count)
                error('length(weight) must match feature_count');
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
                    temp_feature.weight = weight;
                else % the weight vals are given as a list
                    temp_feature.weight = weight(x);
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
        % autotuneConfig: Autotune the Nano pod configuration parameters
        % Args:
        %
        % Optional Args:
        %   autotune_pv (bool): Autotune percent variation (true)
        %   autotune_range (bool): Autotune min and max (true)
        %   by_feature (bool): Autotune each feature seperately (false)
        %   exclusions (cell): Feature columns to ignore (empty)
        % Returns:
        %   success (bool): true if api call succesful
        %   autotune_response (struct): The autotuned configuration

            success = false;
            autotune_response = struct;
            
            %check for active instance
            if( isempty(obj.instance) )
                error('No Active Instances To Autotune. Call openNano() first.');
                return;
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
            tfs = {'false', 'true'};
            config_cmd = [obj.url 'autoTuneConfig/' obj.instance '?api-tenant=' obj.api_tenant '?byFeature=' tfs{by_feature+1} '&autoTunePV=' tfs{autotune_pv+1} '&autoTuneRange=' tfs{autotune_range+1}];
            if ~isempty(exclusions)
                config_cmd = [config_cmd '&exclusions=' exclusions];
            end
            
            %options
            options = obj.http;
            options.RequestMethod = 'post';
            options.ContentType = 'json';
            
            % autotune nano
            autotune_response = webwrite(config_cmd, options);

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
        % getConfig: Get current Nano pod configuration parameters
        % Args:
        % 
        % Returns:
        %   success (bool): true if api call succesful
        %   config_response (struct): Configuration struct from server

            success = false;
            config_response = struct;
            if( isempty(obj.instance) )
                error('No Active Instances. Call openNano() first.');
            end
            
            % build command
            config_cmd = [obj.url 'clusterConfig/' obj.instance '?api-tenant=' obj.api_tenant];
            options = obj.http; %default options
            options.RequestMethod = 'get';
            options.ContentType = 'json';
            
            % Read nano configuration
            config_response = webread(config_cmd, options);
            success = true;

            return;
        end
        
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%% Loading Data and Clustering
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        function [success, load_response] = loadData(obj, data, metadata, append_data)
        % loadData: Post the data and cluster it if runNano is True
        % Args:
        %   data (mat): Data to load #columns==config.feature_count
        % Optional Args:
        %   metadata (char): additional args (empty)
        %   append_data (bool): append this data to existing server data
        % Returns:
        %   success (bool): true if api call succesful
        %   load_response (struct): response information if success = true

            success = false;
            load_response = struct;

            % Optional arguments
            if(nargin<2 || isempty(data))
                error('Must pass data matrix as argument'); 
            end
            if(nargin<3)
                metadata='';
            end
            if(nargin<4)
                append_data=false;
            end
            
            %check for instances
            if( isempty(obj.instance) )
                error('No Active Instances. Call openNano() first.');
            end
            if ~isfield(obj.instance_config, obj.instance) 
                error('Active Instance %s Is Not Configured. Call configNano() first.'); 
            end
            
            %format metadata
            if ~isempty(metadata)
                metadata = strrep(metadata,',','|');
                metadata = strrep(metadata,'{','');
                metadata = strrep(metadata,'}','');
                metadata = strrep(metadata,' ',''); 
            end
            
            %instance configurations
            if ~isfield(obj.instance_config,obj.instance)
                obj.instance_config.(obj.instance) = struct;
            end
            inst_config = obj.instance_config.(obj.instance);
            
            %check data dimensions
            [nsamples, nfeatures] = size(data);
            if(nfeatures ~= inst_config.feature_count)
               warning('BoonNanoSDK is Row Major, Loading %d Samples, %d Features', nsamples, nfeatures);
            end
            
            % build command
            tfs = {'false', 'true'};
            load_cmd = [obj.url 'data/' obj.instance '?api-tenant=' obj.api_tenant '&fileType=raw' '&appendData=' tfs{append_data+1}];
            
            %format multi part message
            mat_provider = MatrixProvider(data, inst_config.numeric_format);
            if ~isempty(metadata)
                str_provider = matlab.net.http.io.StringProvider(metadata);
                multipart = matlab.net.http.io.MultipartFormProvider('data',mat_provider,'metadata',str_provider);
            else
                multipart = matlab.net.http.io.MultipartFormProvider('data',mat_provider);
            end
            header = matlab.net.http.HeaderField('x-token', obj.api_key,'Content-Type','multipart/form-data');
            req = matlab.net.http.RequestMessage(matlab.net.http.RequestMethod.POST,header,multipart);
            [load_response,completedrequest,~] = req.send(load_cmd);
            
            % check for error
            if (~completedrequest.Completed || load_response.StatusCode ~= 200)
                display(load_response);
                return;
            end
            success = true;
            
            return;
        end
        
        function [success, run_response] = runNano(obj, results)
        % runNano: Run the current nano instance with the loaded data
        % Args:
        %   results (char): per pattern results
        %         ID = cluster ID
        %         SI = smoothed anomaly index
        %         RI = raw anomaly index
        %         FI = frequency index
        %         DI = distance index
        %         MD = metadata
        % Returns:
        %   success (bool)
        %   run_response (struct): response from server if success=true
        
            success = false;
            run_response = struct;
            if strcmp(results, 'All')
                results_str = 'ID,SI,RI,FI,DI';
            else
                results_split = split(results,',');
                valid = {'ID','SI','RI','FI','DI','MD'};
                for i = 1:length(results_split) 
                   isin = contains(results_split(i),valid);
                   if(~any(isin(:)) )
                       success = false;
                       error('unknown result %s found in results parameter', results_split(i));
                   end
                end
                results_str = results;
            end
            
            %check for instances
            if( isempty(obj.instance) )
                error('No Active Instances. Call openNano() first.');
            end
            
            %Command
            nano_cmd = [obj.url 'nanoRun/' obj.instance '?api-tenant=' obj.api_tenant];
            if ~isempty(results)
                nano_cmd = [nano_cmd '&results=' results_str];
            end
            
            options = obj.http; %default options
            options.RequestMethod = 'post';
            options.ContentType = 'json';
            
            % run nano
            run_response = webwrite(nano_cmd, options);
            success = true;

            return;
        end
        
        function [success, results_response] = getNanoResults(obj, results)
        % getNanoResults: Get latest results from server
        % Args:
        %   results (char): per pattern results
        %         ID = cluster ID
        %         SI = smoothed anomaly index
        %         RI = raw anomaly index
        %         FI = frequency index
        %         DI = distance index
        %         MD = metadata
        % Returns:
        %   success (bool):  true if successful 
        %   results_response [struct]: results when success is true, error message when success = false
        
            success = false;
            results_response = struct;
            if(nargin < 2)
                results = 'All'; %default
            end
        
            if strcmp(results, 'All')
                results_str = 'ID,SI,RI,FI,DI';
            else
                results_split = split(results,',');
                valid = {'ID','SI','RI','FI','DI','MD'};
                for i = 1:length(results_split) 
                   isin = contains(results_split(i),valid);
                   if(~any(isin(:)) )
                       success = false;
                       error('unknown result %s found in results parameter', results_split(i));
                   end
                end
                results_str = results;
            end
            
            %check for instances
            if( isempty(obj.instance) )
                error('No Active Instances. Call openNano() first.');
            end
            
            %Command
            results_cmd = [obj.url 'nanoResults/' obj.instance '?api-tenant=' obj.api_tenant '&results=' results_str];
            
            options = obj.http; %default options
            options.RequestMethod = 'get';
            options.ContentType = 'json';
            
            % results 
            results_response = webread(results_cmd, options);
            success = true;
            
            return;
        end
        
        function [success, status_response] = getNanoStatus(obj, results)
        % getNanoStatus: Results in relation to each cluster/overall stats
        % Args:
        %   results (char): per pattern results
        %     PCA = principal components (includes 0 cluster)
        %     clusterGrowth = indexes of each increase in cluster (includes 0 cluster)
        %     clusterSizes = number of patterns in each cluster (includes 0 cluster)
        %     anomalyIndexes = anomaly index (includes 0 cluster)
        %     frequencyIndexes = frequency index (includes 0 cluster)
        %     distanceIndexes = distance index (includes 0 cluster)
        %     patternMemory = base64 pattern memory (overall)
        %     totalInferences = total number of patterns clustered (overall)
        %     averageInferenceTime = time in milliseconds to cluster per
        %         pattern (not available if uploading from serialized nano) (overall)
        %     numClusters = total number of clusters (includes 0 cluster) (overall)
        % Returns:
        %   success (bool):  true if successful 
        %   status_response [struct]: results when success is true, error message when success = false
        
            if(nargin < 2)
                results = 'All'; %default
            end
        
            %parse args
            success = false;
            status_response = struct;
            if strcmp(results, 'All')
                results_str = 'PCA,clusterGrowth,clusterSizes,anomalyIndexes,frequencyIndexes,distanceIndexes,totalInferences,numClusters';
            else
                resultsplit = split(results,',');
                valid = {'PCA','clusterGrowth','clusterSizes','anomalyIndexes','frequencyIndexes','distanceIndexes','totalInferences','numClusters','averageInferenceTime'};
                for i = 1:length(resultsplit) 
                   isin = contains(resultsplit(i),valid);
                   if(~any(isin(:)) )
                       error('unknown result %s found in results parameter', resultsplit(i));
                   end
                end
                results_str = results;
            end
            
            %check for instances
            if( isempty(obj.instance) )
                error('No Active Instances. Call openNano() first.');
            end
            
            %Command
            status_cmd = [obj.url 'nanoStatus/' obj.instance '?api-tenant=' obj.api_tenant '&results=' results_str];
            
            options = obj.http; %default options
            options.RequestMethod = 'get';
            options.ContentType = 'json';
            
            % results 
            status_response = webread(status_cmd, options);
            success = true;
            
            return;
        end
        
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%% NanoPod General Information
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        function [success, version_response] = getVersion(obj)
        % getVersion: Results related to the bytes processed/in the buffer
        % Returns:
        %    success (boolean): true if successful (version information was retrieved)
        %    version_response (struct): results when success is true, error message when success = false

            % build command (minus the v3 portion)
            success = true;
            version_cmd = [obj.url(1:end-3) 'version' '?api-tenant=' obj.api_tenant];
            
            options = obj.http; %default options
            options.RequestMethod = 'get';
            options.ContentType = 'json';
            
            % get response
            version_response = webread(version_cmd, options);

            return;
        end
        
        function [success, status_response] = getBufferStatus(obj)
        % getBufferStatus: Results related to the bytes processed/in the buffer
        % Returns:
        %    success (boolean): true if successful 
        %    status_response (struct): results when success is true, error message when success = false

            % build command
            success = true;
            status_cmd = [obj.url 'bufferStatus/' obj.instance '?api-tenant=' obj.api_tenant];
            
            options = obj.http; %default options
            options.RequestMethod = 'get';
            options.ContentType = 'json';
            
            % get response
            status_response = webread(status_cmd, options);
            return;
        end
   
  
    end
end
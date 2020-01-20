% Copyright 2020, Boon Logic Inc.

classdef MatrixProvider < matlab.net.http.io.ContentProvider & matlab.mixin.Copyable
% MatrixProvider ContentProvider that sends matrices to Rest API
%
%   This ContentProvider is a convenient way to send a matrix to a server.
%   To send one matrix in a PUT message:
%
%      import matlab.net.http.*, import matlab.net.http.field.*, import matlab.net.http.io.*
%      provider = MatrixProvider(data,'uint16');
%      req = RequestMessage(PUT,[],provider);
%      resp = req.send(url);
%
%
%   MatrixProvider properties:
%     data_matrix  - matrix of data to send to nano
%     data_type    - Nano data type 'uint16', 'int16', or 'float32'
%
%   MatrixProvider methods:
%     MatrixProvider - constructor

    properties (Access=private)
        NumElements double
        ElementCount double
        DataSet
        ByteWidth double
    end
    
    methods
        function obj = MatrixProvider(data_matrix, data_type)
        % MatrixProvider MatrixProvider constructor
        %  PROVIDERS = MatrixProvider(data_matrix,data_type) constructs a MatrixProvider
        %    which sends one (2D) matrix to the server. Used by
        %    BoonNanoSDK.
        % Args:
        %   data_matrix (matrix): Data matrix to send to server
        %   data_type (char): Nano data type 'uint16', 'int16', or 'float32'
        % 
            if nargin ~= 2
                return;
            end
            if ~isnumeric(data_matrix)
                error('data_matrix must be numeric');
            end
            if ~ischar(data_type)
                error('data_type must be char');
            end
            
            % Determine bytewidth, cast data, and reshape to 1D array
            obj.ByteWidth = 0;
            obj.DataSet = [];
            if strcmp(data_type, 'uint8')
                obj.ByteWidth = 1; %if data was already byte converted
                obj.DataSet = reshape(uint8(data_matrix).',1,[]);
            elseif strcmp(data_type, 'uint16')
                obj.ByteWidth = 2; 
                obj.DataSet = reshape(uint16(data_matrix).',1,[]);
            elseif strcmp(data_type, 'int16')
                obj.ByteWidth = 2; 
                obj.DataSet = reshape(int16(data_matrix).',1,[]);
            elseif strcmp(data_type, 'float32')
                obj.ByteWidth = 4; 
                obj.DataSet = reshape(single(data_matrix).',1,[]);
            end
            
            if obj.ByteWidth == 0
                error('data_type is unrecognized by server');
            end
            
            % Count Variables
            obj.NumElements = numel(obj.DataSet);
            obj.ElementCount = 1;
            
        end
        
        function [data, stop] = getData(obj, length)
        % getData - return next buffer of data
        %   [DATA, STOP] = getData(PROVIDER, LENGTH, FIRST) is an overridden method of
        %   ContentProvider that returns the next buffer of data from the dataset. It sets
        %   STOP to true if all bytes have been read.
        %
        % See also matlab.net.http.io.ContentProvider.getData
            if obj.NumElements == 0
                data = [];
                stop = true;
                return;
            end
            
            samplelength = 0;
            if(obj.ElementCount < obj.NumElements)
                samplelength = length/obj.ByteWidth; %eg 2 bytes == 1 uint16
                samplelength = min([samplelength, obj.NumElements - obj.ElementCount + 1]);
            end
            
            data = [];
            if samplelength > 0
                chunk = obj.DataSet(obj.ElementCount:(obj.ElementCount+samplelength-1));
                data = typecast(chunk, 'uint8'); %get bytes
            end
            obj.ElementCount = obj.ElementCount + samplelength;
            
            if isempty(data) || obj.ElementCount >= obj.NumElements
                % empty must mean done
                stop = true;
            else
                stop = false;
            end
        end
        
        function delete(obj)
            obj.ElementCount = 1;
        end
        
    end
    
    methods (Access=protected)
       function complete(obj, varargin)
        % complete Complete the header of the message
        %   complete(PROVIDER, URI) is an overridden method of ContentProvider that
        %   completes the header of the message, or (in the case of a multipart message)
        %   the part for which this provider is being used. If there is no Content-Type
        %   field, it adds one specifying "application/json". If there is already a
        %   Content-Type field that does not contain a charset parameter, and this
        %   object's Charset is different from the default for that Content-Type, then a
        %   charset parameter is added to the header field.
        %   Code duplicated from FileProvider class
        % 
            
            obj.complete@matlab.net.http.io.ContentProvider();
            if isempty(obj.DataSet)
                return
            end
            
            % Add a ContentTypeField to header 
            ctf = obj.Header.getValidField('Content-Type');
            cdf = obj.Header.getValidField('Content-Disposition');
            if ~isempty(ctf)
                mt = ctf.convert();
            else
                mt = matlab.net.http.MediaType.empty;
            end
            if isempty(cdf) || isempty(cdf.getParameter('filename')) || isempty(mt)
                % Add filename parameter to Content-Disposition field, if there isn't one
                if isempty(cdf) 
                    newcdf = matlab.net.http.field.ContentDispositionField;
                elseif ~isempty(cdf.Value) && isempty(cdf.getParameter('filename')) 
                    newcdf = cdf;
                else
                    newcdf = [];
                end
                
                % rest api requires filename
                dummyfilename = 'binary_file.bin';
                [~,fname,fext] = fileparts(dummyfilename);

                if isempty(mt)
                    % There was no Content-Type field, or it was empty, so get the type
                    % from the extension
                    [~, ~, map] = matlab.net.http.internal.getTypeMaps;
                    if strlength(fext) ~= 0
                        try
                            typeSubtype = map(char(extractAfter(fext,1)));
                            mt = strjoin(typeSubtype, '/');
                        catch e
                            % the only error expected is NoKey to indicate that the filename extension is
                            % not in our map. In this case assume binary.
                            if ~contains(e.identifier, 'NoKey')
                                rethrow(e)
                            else
                            end
                        end
                    else
                    end
                    if isempty(mt)
                        mt = matlab.net.http.MediaType('application/octet-stream');
                    else
                    end
                    if isempty(ctf) || ~isempty(ctf.Value)
                        newctf = matlab.net.http.field.ContentTypeField(mt);
                        if isempty(ctf)
                            obj.Header = obj.Header.addFields(newctf);
                        else
                            obj.Header = obj.Header.changeFields(newctf);
                        end
                    else
                    end
                end
                if ~isempty(newcdf)
                    newcdf = newcdf.setParameter('filename', string(fname) + string(fext));
                    obj.Header = obj.Header.replaceFields(newcdf);
                else
                end
            end  
        end
        
        function start(obj)
        % START Start a new transfer
        %   START(PROVIDER) is an overridden method of ContentProvider that MATLAB calls
        %   to prepare this provider for new transfer.
        % 
        % See also matlab.net.http.io.ContentProvider.start
            obj.start@matlab.net.http.io.ContentProvider();
            if isempty(obj.DataSet)
                return
            end
            obj.ElementCount = 1; %reset count
           
        end
        
        function length = expectedContentLength(obj, varargin)
        % expectedContentLength Return length of data
        %   LEN = expectedContentLength(PROVIDER, FORCE) is an overridden method of
        %   ContentProvider that returns the length of the data or [] if the length is
        %   unknown. 
        % 
        % See also matlab.net.http.io.ContentProvider.expectedContentLength
            force = ~isempty(varargin) && varargin{1};
            if force
                length = 0;
            else
                length = obj.NumElements*obj.ByteWidth;
            end
            
        end
        
        function tf = restartable(~)
        % RESTARTABLE Indicate provider is restartable
        %   TF = RESTARTABLE(PROVIDER) is an overridden method of ContentProvider that
        %   indicates whether this provider is restartable. Always returns true.
        %
        % See also matlab.net.http.io.ContentProvider.restartable, reusable
            tf = true;
        end
        
        function tf = reusable(~)
        % REUSABLE Indicate provider is reusable
        %   TF = REUSABLE(PROVIDER) is an overridden method of ContentProvider that
        %   indicates whether this provider is reusable. Always returns true.
        %
        % See also matlab.net.http.io.ContentProvider.reusable, restartable
            tf = true;
        end
    end
    
end


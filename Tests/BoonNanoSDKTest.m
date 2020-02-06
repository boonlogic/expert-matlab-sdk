classdef BoonNanoSDKTest < matlab.unittest.TestCase
    % BoonNanoSDKTest tests the Boon Nano SDK Methods + Rest API
    % Additional tests to be added along with new methods
    % Usage:
    %   testCase = BoonNanoSDKTest;
    %   result = run(testCase)
    
    methods (Test)
        %Test Methods Will Be Run In Random Order...
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%% Positive Cases %%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        function testConstructor(testCase)
            %Test class constructor
            bn = BoonNanoSDK('default');
            testCase.verifyClass(bn, ?BoonNanoSDK);
        end
        function testGetVersion(testCase)
            %Test getVersion() method
            import matlab.unittest.constraints.HasField
          
            bn = BoonNanoSDK('default');
            [success, response] = bn.getVersion();
            
            testCase.verifyTrue(success);
            testCase.verifyThat(response, HasField('api_version'));
        end
        function testOpenNano(testCase)
            %Test openNano() method
            import matlab.unittest.constraints.HasField
          
            bn = BoonNanoSDK('default');
            instance_name = 'instance1';
            [success, response] = bn.openNano(instance_name);
            
            testCase.verifyTrue(success);
            testCase.verifyThat(response, HasField('instanceID'));
            testCase.verifyEqual(response.instanceID, instance_name);
            
            [~,~] = bn.closeNano();
        end
        function testCloseNano(testCase)
            %Test closeNano() method
            import matlab.unittest.constraints.HasField
          
            bn = BoonNanoSDK('default');
            instance_name = 'instance1';
            [~, ~] = bn.openNano(instance_name);
            
            [success, response] = bn.closeNano();
            
            testCase.verifyTrue(success);
            testCase.verifyThat(response, HasField('code'));
            testCase.verifyEqual(response.code, 200);
        end
        function testNanoList(testCase)
            %Test nanoList() method
           import matlab.unittest.constraints.IsGreaterThanOrEqualTo
          
            bn = BoonNanoSDK('default');
            
            instance1 = 'instance1';
            instance2 = 'instance2';
            instance3 = 'instance3';
            [~, ~] = bn.openNano(instance1);
            [~, ~] = bn.openNano(instance2);
            [~, ~] = bn.openNano(instance3);
            
            [success1, response1] = bn.nanoList();
            
            %close all nanos
            for ii = 1:length(response1)
                [~, ~] = bn.closeNano(response1(ii).instanceID);
            end
            
            [success2, response2] = bn.nanoList();
            
            testCase.verifyTrue(success1);
            testCase.verifyTrue(success2);
            testCase.verifyThat(length(response1), IsGreaterThanOrEqualTo(3));
            testCase.verifyEqual(length(response2), 0);
        end
        function testConfigureNano(testCase)
            %Test configureNano() method
            import matlab.unittest.constraints.HasField
          
            bn = BoonNanoSDK('default');
            instance_name = 'instance1';
            [~, ~] = bn.openNano(instance_name);
            
            percentVariation = 0.05;
            accuracy = 0.99;
            numericFormat = 'uint16';

            [~, config] = bn.generateConfig(100, numericFormat, percentVariation, accuracy, 0, 1000, 1);
            [success, response] = bn.configureNano(config);

            testCase.verifyTrue(success);
            testCase.verifyThat(response, HasField('percentVariation'));
            testCase.verifyThat(response, HasField('accuracy'));
            testCase.verifyThat(response, HasField('numericFormat'));
            testCase.verifyEqual(response.percentVariation, percentVariation);
            testCase.verifyEqual(response.accuracy, accuracy);
            testCase.verifyEqual(response.numericFormat, numericFormat);
            
            [~,~] = bn.closeNano();
        end
        function testloadData(testCase)
            %Test loadData() method
          
            bn = BoonNanoSDK('default');
            instance_name = 'instance1';
            [~, ~] = bn.openNano(instance_name);
            
            featurelength = 100;

            [~, config] = bn.generateConfig(featurelength, 'int16', 0.05, 0.99, -100, 100, 1);
            [~, ~] = bn.configureNano(config);
            
            numSamples = 30;
            Dataset = randi([-100, 100],numSamples,featurelength);
            
            [success, response] = bn.loadData(Dataset);

            testCase.verifyTrue(success);
            testCase.verifyEqual(response.StatusCode, matlab.net.http.StatusCode.OK);
            
            [~,~] = bn.closeNano();
        end
        function testRunNano(testCase)
            %Test runNano() method
            import matlab.unittest.constraints.HasField
          
            bn = BoonNanoSDK('default');
            instance_name = 'instance1';
            [~, ~] = bn.openNano(instance_name);
            
            percentVariation = 0.05;
            accuracy = 0.99;
            numericFormat = 'float32';
            featurelength = 100;
            minVal = -300.0;
            maxVal = 600.0;

            [~, config] = bn.generateConfig(featurelength, numericFormat, percentVariation, accuracy, minVal, maxVal, 1);
            [~, ~] = bn.configureNano(config);
            
            numTemplates = 3;
            numMoons = 10; 
            [Dataset, Label] = BoonNanoSDKTest.GenerateData(numTemplates, numMoons, featurelength, minVal, maxVal, percentVariation);
            
            [~, ~] = bn.loadData(Dataset);
            
            [success, response] = bn.runNano('ID');

            testCase.verifyTrue(success);
            testCase.verifyThat(response, HasField('ID'));
            testCase.verifyEqual(sum(response.ID~=Label), 0);
            
            [~,~] = bn.closeNano();
        end
        function autotuneConfig(testCase)
            %Test autotuneConfig() method
            import matlab.unittest.constraints.HasField
            import matlab.unittest.constraints.IsLessThan
          
            bn = BoonNanoSDK('default');
            instance_name = 'instance1';
            [~, ~] = bn.openNano(instance_name);
            
            percentVariation = 0.05;
            accuracy = 0.99;
            numericFormat = 'uint16';
            featurelength = 100;
            minVal = 0;
            maxVal = 500;

            [~, config] = bn.generateConfig(featurelength, numericFormat, percentVariation, accuracy, minVal, maxVal, 1);
            [~, ~] = bn.configureNano(config);
            
            numTemplates = 3;
            numMoons = 50; 
            [Dataset, ~] = BoonNanoSDKTest.GenerateData(numTemplates, numMoons, featurelength, minVal, maxVal, percentVariation);
            
            [~, ~] = bn.loadData( uint16(Dataset) );
            
            [success, response] = bn.autotuneConfig();

            testCase.verifyTrue(success);
            testCase.verifyThat(response, HasField('percentVariation'));
            testCase.verifyThat(response, HasField('accuracy'));
            %check for reasonable percent variation
            testCase.verifyThat(abs(percentVariation-response.percentVariation), IsLessThan(0.3))
            
            [~,~] = bn.closeNano();
        end
        function testGetNanoStatus(testCase)
            %Test getNanoStatus() method
            import matlab.unittest.constraints.HasField
          
            bn = BoonNanoSDK('default');
            instance_name = 'instance1';
            [~, ~] = bn.openNano(instance_name);
            
            percentVariation = 0.05;
            accuracy = 0.99;
            numericFormat = 'float32';
            featurelength = 100;
            minVal = -300.0;
            maxVal = 600.0;

            [~, config] = bn.generateConfig(featurelength, numericFormat, percentVariation, accuracy, minVal, maxVal, 1);
            [~, ~] = bn.configureNano(config);
            
            numTemplates = 3;
            numMoons = 10; 
            [Dataset, ~] = BoonNanoSDKTest.GenerateData(numTemplates, numMoons, featurelength, minVal, maxVal, percentVariation);
            
            [~, ~] = bn.loadData(Dataset);
            [~, ~] = bn.runNano('');
            
            [success, response] = bn.getNanoStatus('totalInferences,averageInferenceTime,numClusters');

            testCase.verifyTrue(success);
            testCase.verifyThat(response, HasField('totalInferences'));
            testCase.verifyThat(response, HasField('averageInferenceTime'));
            testCase.verifyThat(response, HasField('numClusters'));
            testCase.verifyEqual(response.totalInferences, numTemplates*numMoons);
            testCase.verifyEqual(response.numClusters, numTemplates + 1);
            
            [~,~] = bn.closeNano();
        end
        function testGetNanoResults(testCase)
            %Test getNanoResults() method
            import matlab.unittest.constraints.HasField
          
            bn = BoonNanoSDK('default');
            instance_name = 'instance1';
            [~, ~] = bn.openNano(instance_name);
            
            percentVariation = 0.05;
            accuracy = 0.99;
            numericFormat = 'int16';
            featurelength = 100;
            minVal = -200.0;
            maxVal = 800.0;

            [~, config] = bn.generateConfig(featurelength, numericFormat, percentVariation, accuracy, minVal, maxVal, 1);
            [~, ~] = bn.configureNano(config);
            
            numTemplates = 5;
            numMoons = 50; 
            [Dataset, Label] = BoonNanoSDKTest.GenerateData(numTemplates, numMoons, featurelength, minVal, maxVal, percentVariation);
            
            [~, ~] = bn.loadData(Dataset);
            [~, ~] = bn.runNano('');
            
            [success, response] = bn.getNanoResults('ID');

            testCase.verifyTrue(success);
            testCase.verifyThat(response, HasField('ID'));
            testCase.verifyEqual(sum(response.ID~=Label), 0);
            
            [~,~] = bn.closeNano();
        end
        function testSaveNano(testCase)
            %Test saveNano(), restoreNano(), & getConfig() methods
            import matlab.unittest.constraints.HasField
          
            bn = BoonNanoSDK('default');
            instance_name = 'instance1';
            [~, ~] = bn.openNano(instance_name);
            
            percentVariation = 0.079;
            accuracy = 0.93;

            [~, config] = bn.generateConfig(100, 'uint16', percentVariation, accuracy, 0, 100, 1);
            [~, ~] = bn.configureNano(config);
            
            %save this config
            success1 = bn.saveNano('tester.tar');
            
            %change config
            [~, config] = bn.generateConfig(50, 'int16', 0.034, 0.98, -100, 300, 1);
            [~, ~] = bn.configureNano(config);
            
            %restore from save
            success2 = bn.restoreNano('tester.tar');
            [success3, response] = bn.getConfig();

            testCase.verifyTrue(success1);
            testCase.verifyTrue(success2);
            testCase.verifyTrue(success3);
            testCase.verifyThat(response, HasField('percentVariation'));
            testCase.verifyThat(response, HasField('accuracy'));
            testCase.verifyEqual(response.percentVariation, percentVariation);
            testCase.verifyEqual(response.accuracy, accuracy);
            
            [~,~] = bn.closeNano();
        end
        
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%% Failure Cases  %%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        function testConstructorError(testCase)
            %Test class constructor with invalid args
            import matlab.unittest.constraints.Throws
            
            %remove key var
            api_key = getenv('BOON_API_KEY');
            setenv('BOON_API_KEY','');
            
            %Specify non-existent license_file
            testCase.verifyThat(@() BoonNanoSDK('default','BOONLICENSE'), Throws('MATLAB:arg:missingValue'))
            
            %revert
            setenv('BOON_API_KEY',api_key);
        end
        function testOpenNanoError1(testCase)
            %Test openNano() method with invalid args
            import matlab.unittest.constraints.Throws
          
            bn = BoonNanoSDK('default');
            
            %pass non-char instance_id
            testCase.verifyThat(@() bn.openNano(530), Throws('MATLAB:arg:invalidType'))
        end
        function testOpenNanoError2(testCase)
            %Test openNano() method with too many instances
            import matlab.unittest.constraints.Throws
          
            bn = BoonNanoSDK('default');
            
            %close all nanos
            [~, response1] = bn.nanoList();
            for ii = 1:length(response1)
                [~, ~] = bn.closeNano(response1(ii).instanceID);
            end
            
            %open 4 instances
            [~, ~] = bn.openNano('instance1');
            [~, ~] = bn.openNano('instance2');
            [~, ~] = bn.openNano('instance3');
            [~, ~] = bn.openNano('instance4');
            
            %attempt to open a fifth instance
            testCase.verifyThat(@() bn.openNano('instance5'), Throws('MATLAB:webservices:HTTP400StatusCodeError'))
            
            %close all nanos again
            [~, response2] = bn.nanoList();
            for ii = 1:length(response2)
                [~, ~] = bn.closeNano(response2(ii).instanceID);
            end
            
        end
        function testCloseNanoError(testCase)
            %Test closeNano() method with invalid args
            import matlab.unittest.constraints.Throws
          
            bn = BoonNanoSDK('default');

            %close all nanos
            [~, response] = bn.nanoList();
            for ii = 1:length(response)
                [~, ~] = bn.closeNano(response(ii).instanceID);
            end

            instance_name = 'instanceNew';
            
            %close non-existent nano
            testCase.verifyThat(@() bn.closeNano(instance_name), Throws('MATLAB:webservices:HTTP404StatusCodeError'))
        end
        function testConfigureNanoError1(testCase)
            %Test configureNano() method with invalid procedure
            import matlab.unittest.constraints.Throws
          
            bn = BoonNanoSDK('default');
            
            %generate config
            [~, config] = bn.generateConfig(100, 'uint16', 0.05, 0.99, 0, 1000, 1);

            %configure non-existent nano instance
            testCase.verifyThat(@() bn.configureNano(config), Throws('MATLAB:class:invalidUsage'))
        end
        function testConfigureNanoError2(testCase)
            %Test configureNano() method with invalid args
            import matlab.unittest.constraints.Throws
          
            bn = BoonNanoSDK('default');
            [~, ~] = bn.openNano('instance1');
            
            %generate bogus configuration struct
            config.accuracy = 0.99;
            config.percentVariation = 0.05;

            %configure nano with invalid struct
            testCase.verifyThat(@() bn.configureNano(config), Throws('MATLAB:arg:invalidType'))
            
            [~, ~] = bn.closeNano();
        end
        function autotuneConfigError(testCase)
            %Test autotuneConfig() method with invalid procedure
            import matlab.unittest.constraints.Throws
          
            bn = BoonNanoSDK('default');
            
            %close all nanos
            [~, response] = bn.nanoList();
            for ii = 1:length(response)
                [~, ~] = bn.closeNano(response(ii).instanceID);
            end
            
            %open instance
            [~, ~] = bn.openNano('instanceAutotune');
            
            %request an autotune without any loaded data
            testCase.verifyThat(@() bn.autotuneConfig(), Throws('MATLAB:webservices:HTTP400StatusCodeError'))
            
            [~, ~] = bn.closeNano();
        end
        function testLoadDataError(testCase)
            %Test loadData() method with invalid procedure
            import matlab.unittest.constraints.Throws
          
            bn = BoonNanoSDK('default');
            
            %close all nanos
            [~, response] = bn.nanoList();
            for ii = 1:length(response)
                [~, ~] = bn.closeNano(response(ii).instanceID);
            end
            
            [~, ~] = bn.openNano('instanceLoad');
            
            %create data
            featurelength = 100;
            numSamples = 30;
            Dataset = randi([-100, 100],numSamples,featurelength);
            
            %load dataset without an active configuration
            testCase.verifyThat(@() bn.loadData(Dataset), Throws('MATLAB:class:invalidUsage'))

            [~, ~] = bn.closeNano();
        end
        function testRunNanoError(testCase)
            %Test runNano() method with invalid procedure
            import matlab.unittest.constraints.Throws
          
            bn = BoonNanoSDK('default');
            
            %close all nanos
            [~, response] = bn.nanoList();
            for ii = 1:length(response)
                [~, ~] = bn.closeNano(response(ii).instanceID);
            end
            
            [~, ~] = bn.openNano('instanceRun');
            [~, ~] = bn.generateConfig(100, 'uint16', 0.05, 0.99, 0, 1000, 1);
           
            
            %run Nano without data loaded
            testCase.verifyThat(@() bn.runNano('ID'), Throws('MATLAB:webservices:HTTP400StatusCodeError'))

            [~, ~] = bn.closeNano();
        end
        function testGetNanoResultsError(testCase)
            %Test getNanoResults() method with invalid procedure
            import matlab.unittest.constraints.Throws
          
            bn = BoonNanoSDK('default');
            
            %close all nanos
            [~, response] = bn.nanoList();
            for ii = 1:length(response)
                [~, ~] = bn.closeNano(response(ii).instanceID);
            end
            
            [~, ~] = bn.openNano('instanceResults');
            [~, ~] = bn.generateConfig(100, 'uint16', 0.05, 0.99, 0, 1000, 1);
           
            
            %run Nano without data loaded
            testCase.verifyThat(@() bn.getNanoResults('ID,RI'), Throws('MATLAB:webservices:HTTP400StatusCodeError'))

            [~, ~] = bn.closeNano();
        end
        function testGetNanoStatusError(testCase)
            %Test getNanoStatus() method with invalid args
            import matlab.unittest.constraints.Throws
          
            bn = BoonNanoSDK('default');
           
            %run Nano without data loaded
            testCase.verifyThat(@() bn.getNanoStatus('PCA,Dataz'), Throws('MATLAB:arg:invalidType'))
        end
    end
    
    methods(Static)
        function [Dataset, Label] = GenerateData(numTemplates, numMoons, featurelength, minVal, maxVal, percentVariation)
            % GenerateData(): generate random dataset according to min/max vals. 
            % Uses double precision 
            rangeVal = maxVal - minVal;
            Templates = rand(numTemplates, featurelength)*rangeVal + minVal;
            noise = rangeVal*percentVariation/3;

            Dataset = [];
            Label = [];
            idx = 1;
            for t = 1:numTemplates
                for v = 1:numMoons
                   delta = randn(1,featurelength).*noise;
                   Dataset(idx,:) = Templates(t,:) + delta;
                   Label(idx,1) = t;
                   idx = idx + 1;
                end
            end
        end
    end
end 

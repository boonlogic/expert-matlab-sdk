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

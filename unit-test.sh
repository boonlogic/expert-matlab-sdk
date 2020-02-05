#!/bin/bash

# add matlab symlink location to path 
# sudo ln -s /path/to/bin/matlab /usr/local/bin/matlab

#update matlab path
matlab -nodisplay -nosplash -nodesktop -batch 'addpath(pwd);savepath'

# Go to Tests/ and run unit test. 
cd Tests
matlab -nodisplay -nosplash -nodesktop -batch 'run(BoonNanoSDKTest)' | tee test.log

# Grep matlab log for results eg: '23 Passed, x Failed, 0 Incomplete.'
errorcount=$(cat test.log | grep -o -P '(?<=Passed, ).*(?= Failed,)')
rm test.log

#exit code
if [ $errorcount -eq 0 ]
then
  exit 0
else
  exit 1
fi

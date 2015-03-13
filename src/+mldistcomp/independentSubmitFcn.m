function independentSubmitFcn(cluster, job, props, ...
    clusterHost, remoteJobStorageLocation)
%INDEPENDENTSUBMITFCN Submit a MATLAB job to a PBS cluster
%
% Set your cluster's IndependentSubmitFcn to this function using the following
% command:
%     set(cluster, 'IndependentSubmitFcn', {@independentSubmitFcn, clusterHost, remoteJobStorageLocation});
%
% See also parallel.cluster.generic.independentDecodeFcn.
%

% Copyright 2010-2011 The MathWorks, Inc.

decodeFunction = 'parallel.cluster.generic.independentDecodeFcn';
% Store the current filename for the dctSchedulerMessages
currFilename = mfilename;
if cluster.HasSharedFilesystem
    error('parallelexamples:GenericPBS:SubmitFcnError', ...
        'The submit function %s is for use with nonshared filesystems.', currFilename)
end
if ~strcmpi(cluster.OperatingSystem, 'unix')
    error('parallelexamples:GenericPBS:SubmitFcnError', ...
        'The submit function %s only supports clusters with unix OS.', currFilename)
end
if ~ischar(clusterHost)
    error('parallelexamples:GenericPBS:IncorrectArguments', ...
        'Hostname must be a string');
end
if ~ischar(remoteJobStorageLocation)
    error('parallelexamples:GenericPBS:IncorrectArguments', ...
        'Remote job storage location must be a string');
end

remoteConnection = getRemoteConnection(cluster, clusterHost, remoteJobStorageLocation);

% The job specific environment variables
% Remove leading and trailing whitespace from the MATLAB arguments
matlabArguments = strtrim(props.MatlabArguments);
variables = {'MDCE_DECODE_FUNCTION', decodeFunction; ...
    'MDCE_STORAGE_CONSTRUCTOR', props.StorageConstructor; ...
    'MDCE_JOB_LOCATION', props.JobLocation; ...
    'MDCE_MATLAB_EXE', props.MatlabExecutable; ... 
    'MDCE_MATLAB_ARGS', matlabArguments; ...
    'MDCE_DEBUG', 'true'; ...
    'MDCE_STORAGE_LOCATION', remoteJobStorageLocation};



% Get the correct quote and file separator for the Cluster OS.  
% This check is unnecessary in this file because we explicitly 
% checked that the ClusterOsType is unix.  This code is an example 
% of how your integration code should deal with clusters that 
% can be unix or pc.
if strcmpi(cluster.OperatingSystem, 'unix')
    quote = '''';
    fileSeparator = '/';
else 
    quote = '"';
    fileSeparator = '\';
end

% The local job directory
localJobDirectory = cluster.getJobFolder(job);
% How we refer to the job directory on the cluster
remoteJobDirectory = remoteConnection.getRemoteJobLocation(job.ID, cluster.OperatingSystem);

% The script name is independentJobWrapper.sh
scriptName = 'independentJobWrapper.sh';
% The wrapper script is in the same directory as this file
dirpart = fileparts(mfilename('fullpath'));
localScript = fullfile(dirpart, scriptName);
% Copy the local wrapper script to the job directory
copyfile(localScript, localJobDirectory);

% The command that will be executed on the remote host to run the job.
remoteScriptName = sprintf('%s%s%s', remoteJobDirectory, fileSeparator, scriptName);
quotedScriptName = sprintf('%s%s%s', quote, remoteScriptName, quote);

% Get the tasks for use in the loop
tasks = job.Tasks;
numberOfTasks = props.NumberOfTasks;
jobIDs = cell(numberOfTasks, 1);
commandsToRun = cell(numberOfTasks, 1);
% Loop over every task we have been asked to submit
for ii = 1:numberOfTasks
    taskLocation = props.TaskLocations{ii};
    % Add the task location to the environment variables
    environmentVariables = [variables; ...
        {'MDCE_TASK_LOCATION', taskLocation}];
    
    % Choose a file for the output. Please note that currently, JobStorageLocation refers
    % to a directory on disk, but this may change in the future.
    logFile = sprintf('%s%s%s', remoteJobDirectory, fileSeparator, sprintf('Task%d.log', tasks(ii).ID));
    quotedLogFile = sprintf('%s%s%s', quote, logFile, quote);
    
    % Submit one task at a time
    jobName = sprintf('Job%d.%d', job.ID, tasks(ii).ID);
    % PBS jobs names must not exceed 15 characters
    maxJobNameLength = 15;
    if length(jobName) > maxJobNameLength
        jobName = jobName(1:maxJobNameLength);
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %% CUSTOMIZATION MAY BE REQUIRED %%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % You may also with to supply additional submission arguments to 
    % the qsub command here.

    % I'm going to mimic the way I do things in communicatingSubmitFcn.m,
    % but am explicitly assuming each task gets a single core
    additionalSubmitArgs = '-l nodes=1:ppn=1';

    % What walltime to request in the batch script
    global CHPC_WALLTIME
    my_walltime = '4:00:00';
    if (numel(CHPC_WALLTIME)>1) 
      my_walltime = CHPC_WALLTIME;
    end
    additionalSubmitArgs = strcat(additionalSubmitArgs,',walltime=',my_walltime);

    % Use this if we're over-riding the default memory request
    global CHPC_VMEM
    if (CHPC_VMEM>1000) 
      my_vmem=num2str(CHPC_VMEM);
      additionalSubmitArgs = strcat(additionalSubmitArgs,',vmem=',my_vmem,'mb');
    end

    % Route jobs to either the SMP or iDataPlex (the default) nodes
    global CHPC_NODE_TYPE
    if (strcmpi(CHPC_NODE_TYPE,'SMP')) 
      queue = 'matlab_smp'; 
    else
      queue = 'matlab';
    end
    additionalSubmitArgs = strcat(additionalSubmitArgs,' -q ', queue);

    % Finally, add the option for requesting the licenses
    additionalSubmitArgs = strcat(additionalSubmitArgs,' -W x=GRES:MATLAB_Distrib_Comp_Engine+1');

    % Create a script to submit a PBS job - this will be created in the job directory
    dctSchedulerMessage(5, '%s: Generating script for task %i', currFilename, ii);
    localScriptName = tempname(localJobDirectory);
    [~, scriptName] = fileparts(localScriptName);
    remoteScriptLocation = sprintf('%s%s%s', remoteJobDirectory, fileSeparator, scriptName);
    createSubmitScript(localScriptName, jobName, quotedLogFile, quotedScriptName, ...
        environmentVariables, additionalSubmitArgs);
    % Create the command to run on the remote host.
    commandsToRun{ii} = sprintf('sh %s', remoteScriptLocation);
end
dctSchedulerMessage(4, '%s: Starting mirror for job %d.', currFilename, job.ID);
% Start the mirror to copy all the job files over to the cluster
remoteConnection.startMirrorForJob(job);
for ii = 1:numberOfTasks
    commandToRun = commandsToRun{ii};
    
    % Now ask the cluster to run the submission command
    dctSchedulerMessage(4, '%s: Submitting job using command:\n\t%s', currFilename, commandToRun);
    % Execute the command on the remote host.
    [cmdFailed, cmdOut] = remoteConnection.runCommand(commandToRun);
    if cmdFailed
        % Stop the mirroring if we failed to submit the job - this will also
        % remove the job files from the remote location
        % Only stop mirroring if we are actually mirroring
        if remoteConnection.isJobUsingConnection(job.ID)
            dctSchedulerMessage(5, '%s: Stopping the mirror for job %d.', currFilename, job.ID);
            try
                remoteConnection.stopMirrorForJob(job);
            catch err
                warning('parallelexamples:GenericPBS:FailedToStopMirrorForJob', ...
                    'Failed to stop the file mirroring for job %d.\nReason: %s', ...
                    job.ID, err.getReport);
            end
        end
        error('parallelexamples:GenericPBS:FailedToSubmitJob', ...
            'Failed to submit job to PBS using command:\n\t%s.\nReason: %s', ...
            commandToRun, cmdOut);
    end
    jobIDs{ii} = extractJobId(cmdOut);
    
    if isempty(jobIDs{ii})
        warning('parallelexamples:GenericPBS:FailedToParseSubmissionOutput', ...
            'Failed to parse the job identifier from the submission output: "%s"', ...
            cmdOut);
    end
end

% set the cluster host, remote job storage location and job ID on the job cluster data
jobData = struct('ClusterJobIDs', {jobIDs}, ...
    'RemoteHost', clusterHost, ...
    'RemoteJobStorageLocation', remoteJobStorageLocation, ...
    'HasDoneLastMirror', false);
cluster.setJobClusterData(job, jobData);


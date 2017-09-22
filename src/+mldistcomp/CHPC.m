classdef CHPC 
	%% CHPC
    %  @return creates this.chpcSessionData from this.sessionData, adjusting filesystem trunks for use at CHPC.  

	%  $Revision$
 	%  was created 01-Mar-2017 14:58:49 by jjlee,
 	%  last modified $LastChangedDate$ and placed into repository /Users/jjlee/Local/src/mlcvl/mldistcomp/src/+mldistcomp.
 	%% It was developed on Matlab 9.1.0.441655 (R2016b) for MACI64.  Copyright 2017 John Joowon Lee.
 	
    
	properties (Constant)
        LOGIN_HOSTNAME = 'dtn01.chpc.wustl.edu'
        SCRATCH_LOCATION = '/scratch/jjlee'
        SUBJECTS_DIR_MOD_SCRATCH = '/raichle/PPGdata/jjlee2'
    end
    
    properties
 		cluster
        job
    end
    
    properties (Dependent)
        chpcSessionData
        sessionData
        theDeployedDirector
    end
    
    methods 
    end

    methods (Static)
        function [s,r] = rsync(varargin)
            %  @param src is the filename on the local machine or cells of the same.
            %  @param dest is the f.q. path on the cluster at CHPC or cells of the same.
            %  @param named chpcIsSource is logical with default false.
            %  chpcIsSource == true sets src to be at CHPC.  Ignored whenever LOGIN_HOSTNAME is in src or dest.
            %  @param options are passed to rsync, default '-rav -e ssh'.
            %
            %  See also file:///Users/jjlee/Local/bin/rsync_mlcvl.sh
            %          #!/bin/bash                                                                                                             
            %          /usr/bin/rsync -rav -e ssh --exclude '*.git' --exclude '*.svn' \
            %          ~/Local/src/mlcvl/ \
            %          william.neuroimage.wustl.edu:~/Local/src/mlcvl/

            import mldistcomp.*;
            ip = inputParser;
            addRequired( ip, 'src',  @(x) ischar(x) || all(cell2mat(cellfun(@(y) ischar(y), x))));
            addRequired( ip, 'dest', @(x) ischar(x) || all(cell2mat(cellfun(@(y) ischar(y), x))));
            addParameter(ip, 'chpcIsSource', false, @islogical);
            addParameter(ip, 'options', '-rav --no-l --safe-links -e ssh',  @ischar);
            parse(ip, varargin{:});
            
            % recursion for cells
            if (iscell(ip.Results.src))
                assert(iscell(ip.Results.dest));
                assert(length(ip.Results.src) == length(ip.Results.dest));
                s = {}; r = {};
                for c = 1:length(ip.Results.src)
                    [s1,r1] = CHPC.rsync( ...
                        ip.Results.src{c}, ...
                        ip.Results.dest{c}, ...
                        'chpcIsSource', ip.Results.chpcIsSource, ...
                        'options',      ip.Results.options);
                    s = [s s1]; %#ok<*AGROW>
                    r = [r r1];
                end
                return
            end
            
            % base case            
            [src,dest] = CHPC.whereIsChpc(ip.Results.src, ip.Results.dest, 'chpcIsSource', ip.Results.chpcIsSource);
            [s,r] = mlbash(sprintf('rsync %s %s %s', ip.Results.options, src, dest));
        end
        function [s,r] = scp(varargin)
            %  See also pre/post-conditions of mldistcomp.CHPC.whereIsChpc.
            
            [src,dest] = mldistcomp.CHPC.whereIsChpc(varargin{:});
            [s,r] = mlbash(sprintf('scp -qr %s %s', src, dest));  
        end
        function [s,r] = ssh(arg)
            %  @param arg is the argument for ssh on CHPC.
            
            assert(ischar(arg));
            [s,r] = mlbash(sprintf('ssh %s ''%s''', mldistcomp.CHPC.LOGIN_HOSTNAME, arg));
        end
        function [s,r] = sshMkdir(aDir)
            %  @param aDir is the directory to make at CHPC.
            
            assert(ischar(aDir));
            [s,r] = mlbash(sprintf('ssh %s ''mkdir -p %s''', mldistcomp.CHPC.LOGIN_HOSTNAME, aDir));
        end 
        
        function subjD = chpcSubjectsDir(obj)
            if (isa(obj, 'mlpipeline.SessionData'))
                obj = obj.subjectsDir;
            end
            import mldistcomp.*;
            idx   = strfind(obj,              CHPC.SUBJECTS_DIR_MOD_SCRATCH);
            subjD = strrep(obj, obj(1:idx-1), CHPC.SCRATCH_LOCATION);
        end
    end
    
	methods
        
        %% GET/SET
        
        function g = get.chpcSessionData(this)
            g = this.chpcSessionData_;
        end
        function g = get.sessionData(this)
            g = this.sessionData_;
        end
        function g = get.theDeployedDirector(this)
            g = this.theDeployedDirector_;
        end
        
        function this = set.chpcSessionData(this, s)
            assert(isa(s, 'mlpipeline.SessionData'));
            this.chpcSessionData_ = s;
            this.chpcSessionData_.allowDirNotYetExisting = true;
            this.chpcSessionData_.subjectsDir = this.chpcSubjectsDir(this.chpcSessionData_);            
        end
        
        %%
        
        function this  = runSerialProgram(this, varargin)
            ip = inputParser;
            addRequired(ip, 'factoryMethod', @(x) isa(x, 'function_handle'));
            addOptional(ip, 'factoryArgs', {}, @iscell);
            addOptional(ip, 'nArgout', 0, @isnumeric);
            parse(ip, varargin{:});
            
            try
                j = this.cluster.batch(ip.Results.factoryMethod, ip.Results.nArgout, ip.Results.factoryArgs);
                this.job = j;
                %this.fetchedOutputs_ = j.fetchOutputs{:};
            catch ME
                handwarning(ME, struct2str(ME.stack));
            end
        end     
        
 		function this = CHPC(varargin)
 			%% CHPC
            %  @param theDeployedDirector is some director.
            %  @param distcompHost is a valid argument for parcluster; cf.
            %  file:///Users/jjlee/Documents/MATLAB/GettingStartedWithSerialAndParallelMATLABonCHPC.pdf
            %  @param sessionData is an mlpipeline.SessionData.
            %  @param subjectsDirModScratch := subjectsDir - (subjectsDir && this.SCRATCH_LOCATION)
            
            ip = inputParser;
            addRequired( ip, 'theDeployedDirector', @(x) ~isempty(x));
            addParameter(ip, 'distcompHost', 'chpc_remote_r2016a', @ischar);
            addParameter(ip, 'memUsage', '32000', @ischar);
            addParameter(ip, 'wallTime', '12:00:00', @ischar);
            addParameter(ip, 'sessionData', @(x) isa(x, 'mlpipeline.SessionData'));
            addParameter(ip, 'subjectsDirModScratch', this.SUBJECTS_DIR_MOD_SCRATCH, @ischar);
            parse(ip, varargin{:});
 			
            this.theDeployedDirector_   = ip.Results.theDeployedDirector;
            this.distcompHost_          = ip.Results.distcompHost;
            this.sessionData_           = ip.Results.sessionData;
            this.subjectsDirModScratch_ = ip.Results.subjectsDirModScratch;
            this.chpcSessionData        = this.sessionData;
            
            this.cluster = parcluster(this.distcompHost_);
            ClusterInfo.setEmailAddress('jjlee.wustl.edu@gmail.com');
            ClusterInfo.setMemUsage(ip.Results.memUsage);
            ClusterInfo.setWallTime(ip.Results.wallTime);
            ClusterInfo.setPrivateKeyFile('/home/usr/jjlee/.ssh/id_rsa');
        end
    end 
    
    %% PROTECTED
    
    properties (Access = protected)
        chpcSessionData_
        distcompHost_
        fetchedOutputs_
        sessionData_
        subjectsDirModScratch_
        theDeployedDirector_
    end
    
    methods (Static, Access = protected)        
        function [s,d] = whereIsChpc(varargin)
            %% WHEREISCHPC
            %  @param src is the filename on the local machine.
            %  @param dest is the f.q. path on the cluster at CHPC.
            %  @param named chpcIsSource is logical with default false.
            %  chpcIsSource == true sets src to be at CHPC.  Ignored whenever LOGIN_HOSTNAME is in src or dest.
            %  @return s (src)  prefixed with LOGIN_HOSTNAME as preconditioned.
            %  @return d (dest) prefixed with LOGIN_HOSTNAME as preconditioned.
            
            import mldistcomp.*;
            ip = inputParser;
            ip.KeepUnmatched = true;
            addRequired(ip, 'src',  @ischar);
            addRequired(ip, 'dest', @ischar);
            addParameter(ip, 'chpcIsSource', false, @islogical);
            parse(ip, varargin{:});
            
            if (lstrfind(ip.Results.src,  CHPC.LOGIN_HOSTNAME) && ...
                lstrfind(ip.Results.dest, CHPC.LOGIN_HOSTNAME))
                error('mldistcomp:probableHostnameSpecificationErr', ...
                      'CHPC.whereIsChpc has %s in both src and dest', CHPC.LOGIN_HOSTNAME);
            end
            if (lstrfind(ip.Results.src,  CHPC.LOGIN_HOSTNAME) || ...
                lstrfind(ip.Results.dest, CHPC.LOGIN_HOSTNAME))
                s = ip.Results.src;
                d = ip.Results.dest;
                return
            end
            if (ip.Results.chpcIsSource)
                s = [CHPC.LOGIN_HOSTNAME ':' ip.Results.src];
                d = ip.Results.dest;
                return
            end
                s = ip.Results.src;
                d = [CHPC.LOGIN_HOSTNAME ':' ip.Results.dest];
        end
    end
    
    methods (Access = protected)       
    end

	%  Created with Newcl by John J. Lee after newfcn by Frank Gonzalez-Morphy
 end


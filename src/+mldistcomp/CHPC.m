classdef CHPC 
	%% CHPC  

	%  $Revision$
 	%  was created 01-Mar-2017 14:58:49 by jjlee,
 	%  last modified $LastChangedDate$ and placed into repository /Users/jjlee/Local/src/mlcvl/mldistcomp/src/+mldistcomp.
 	%% It was developed on Matlab 9.1.0.441655 (R2016b) for MACI64.  Copyright 2017 John Joowon Lee.
 	
    
	properties (Constant)
        CHPC_HOSTNAME = 'dtn01.chpc.wustl.edu'
        PPG = '/scratch/jjlee/raichle/PPGdata'
    end
    
    properties
 		sessionData
    end
    
    properties (Dependent)
        chpcSubjectsDir
    end
    
    methods %% GET
        function g = get.chpcSubjectsDir(this)
            g = fullfile(this.PPG, this.sessionData.subjectsFolder);
        end
    end

    methods (Static)
        function [s,r] = ssh(arg)
            assert(ischar(arg));
            [s,r] = mlbash(sprintf('ssh %s ''%s''', mldistcomp.CHPC.CHPC_HOSTNAME, arg));
        end
        function [s,r] = sshMkdir(adir)
            assert(ischar(adir));
            [s,r] = mlbash(sprintf('ssh %s ''mkdir -p %s''', mldistcomp.CHPC.CHPC_HOSTNAME, adir));
        end
    end
    
	methods		  
 		function this = CHPC(varargin)
 			%% CHPC
 			%  Usage:  this = CHPC(sessionData)
            %  @param sessionData is an mlpipeline.SessionData.
            
            ip = inputParser;
            addRequired(ip, 'sessionData', @(x) isa(x, 'mlpipeline.SessionData'));
            parse(ip, varargin{:});
 			
            this.sessionData = ip.Results.sessionData;
        end
        
        function loc = freesurferLocation(this)
            loc = fullfile(this.PPG, 'freesurfer', '');
        end
        function [s,r] = scpToChpc(this, varargin)
            %% SCPTOCHPC 
            %  @param src is the filename on the local machine.
            %  @param named dest is the f.q. path on the cluster (optional).
            
            ip = inputParser;
            addRequired(ip, 'src', @ischar);
            addOptional(ip, 'dest',  '', @ischar);
            parse(ip, varargin{:});
            if (~isempty(ip.Results.dest))
                if (~lstrfind(ip.Results.dest, this.CHPC_HOSTNAME))
                    dest = sprintf('%s:%s', this.CHPC_HOSTNAME, ip.Results.dest);
                else
                    dest = ip.Results.dest;
                end
            else
                dest = fullfile(sprintf('%s:%s', this.CHPC_HOSTNAME, this.chpcSubjectsDir), ...
                                this.sessionData.sessionFolder, ...
                                basename(this.sessionData.vLocation));
            end
            
            [s,r] = mlbash(sprintf('scp -qr %s %s', ip.Results.src, dest));
        end
        function [s,r] = scpFromChpc(this, varargin)
            %% SCPFROMCHPC 
            %  @param src is the f.q. filename on the cluster.
            %  @param named dest is the path on the local machine (optional).
            
            ip = inputParser;
            addRequired(ip, 'src', @ischar);
            addOptional(ip, 'dest',  '.', @ischar);
            parse(ip, varargin{:});
            if (~lstrfind(ip.Results.src, this.CHPC_HOSTNAME))
                src = sprintf('%s:%s', this.CHPC_HOSTNAME, ip.Results.src);
            else
                src = ip.Results.src;
            end
            
            [s,r] = mlbash(sprintf('scp -qr %s %s', src, ip.Results.dest));
        end
 	end 

	%  Created with Newcl by John J. Lee after newfcn by Frank Gonzalez-Morphy
 end


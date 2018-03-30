classdef CHPCJob 
	%% CHPCJOB  

	%  $Revision$
 	%  was created 27-Mar-2018 20:15:27 by jjlee,
 	%  last modified $LastChangedDate$ and placed into repository /Users/jjlee/MATLAB-Drive/mldistcomp/src/+mldistcomp.
 	%% It was developed on Matlab 9.1.0.441655 (R2016b) for MACI64.  Copyright 2018 John Joowon Lee.
 	
	properties
 		chpc
 	end

	methods 
		  
 		function this = CHPCJob(chpc)
 			%% CHPCJOB
 			%  @param chpc mldistcomp.CHPC object.

 			this.chpc = chpc;
        end
        
        function j = job(this)
            j = this.chpc.job;
        end
        function fo = fetchOutputs(this)
            j = this.job;
            fo = j.fetchOutputs{:};
        end
 	end 

	%  Created with Newcl by John J. Lee after newfcn by Frank Gonzalez-Morphy
 end


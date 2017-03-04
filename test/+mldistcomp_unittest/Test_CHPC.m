classdef Test_CHPC < matlab.unittest.TestCase
	%% TEST_CHPC 

	%  Usage:  >> results = run(mldistcomp_unittest.Test_CHPC)
 	%          >> result  = run(mldistcomp_unittest.Test_CHPC, 'test_dt')
 	%  See also:  file:///Applications/Developer/MATLAB_R2014b.app/help/matlab/matlab-unit-test-framework.html

	%  $Revision$
 	%  was created 01-Mar-2017 14:58:51 by jjlee,
 	%  last modified $LastChangedDate$ and placed into repository /Users/jjlee/Local/src/mlcvl/mldistcomp/test/+mldistcomp_unittest.
 	%% It was developed on Matlab 9.1.0.441655 (R2016b) for MACI64.  Copyright 2017 John Joowon Lee.
 	
	properties
 		registry
 		testObj
 	end

	methods (Test)
		function test_pushData(this)
 			import mldistcomp.*;
            pwd0 = pushd(this.testObj.vLocation);
            this.testObj.pushData( ...
                'FDG_V2-AC/fdgv2r1_on_resolved_sumt.4dfp.*', ...
                'FDG_V2-AC');
            out = this.testObj.ssh('ls /scratch/jjlee/raichle/PPGdata/jjlee/HYGLY28/V2/FDG_V2-AC');
            this.verifyTrue(lstrfind(out, 'fdgv2r1_on_resolved_sumt.4dfp.img'));
            popd(pwd0);
 		end
		function test_pullData(this)
 			import mldistcomp.*;
            pwd0 = pushd(this.testObj.vLocation);
            this.testObj.pullData( ...
                'FDG_V2-AC/fdgv2r1_on_resolved_sumt.4dfp.*', ...
                'FDG_V2-AC');
            out = ls(fullfile(getenv('PPG'), 'jjlee/HYGLY28/V2/FDG_V2-AC'));
            this.verifyTrue(lstrfind(out, 'fdgv2r1_on_resolved_sumt.4dfp.img'));
            popd(pwd0);
 		end
	end

 	methods (TestClassSetup)
		function setupCHPC(this)
 			import mldistcomp.*;
            studyd = mlraichle.StudyData;
            sessp = fullfile(getenv('PPG'), 'jjlee', 'HYGLY28', '');
            sessd = mlraichle.SessionData('studyData', studyd, 'sessionPath', sessp, 'vnumber', 2);
 			this.testObj_ = CHPC(sessd);
 		end
	end

 	methods (TestMethodSetup)
		function setupCHPCTest(this)
 			this.testObj = this.testObj_;
 			this.addTeardown(@this.cleanFiles);
 		end
	end

	properties (Access = private)
 		testObj_
 	end

	methods (Access = private)
		function cleanFiles(this)
 		end
	end

	%  Created with Newcl by John J. Lee after newfcn by Frank Gonzalez-Morphy
 end


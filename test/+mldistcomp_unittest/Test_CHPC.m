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
        testChpcLoc = '/scratch/jjlee/raichle/PPGdata/jjlee2/HYGLY28/V1'
        testFile
 	end

	methods (Test)
        function test_rsync(this)
            this.testObj.rsync(this.testFile, this.testChpcLoc);
            delete(this.testFile);
            this.testObj.rsync(fullfile(this.testChpcLoc, this.testFile), pwd, 'chpcIsSource', true);
            this.verifyTrue(lexist(this.testFile));   
            
            this.testObj_.ssh(['rm ' fullfile(this.testChpcLoc, this.testFile)]);
        end
        function test_ssh(this)
            [~,r] = this.testObj.ssh(['ls -d ' this.testChpcLoc]);
            this.verifyEqual(this.testChpcLoc, strtrim(r));
        end
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
            sessp = fullfile(mlraichle.RaichleRegistry.instance.subjectsDir, 'HYGLY28', '');
            sessd = mlraichle.SessionData('studyData', studyd, 'sessionPath', sessp);
 			this.testObj_ = CHPC('sessionData', sessd);
            
            this.pwd0_ = pushd(this.testObj_.sessionData.vLocation);
            this.testFile = ['testFile_' datestr(now, 30) '.touch'];
            mlbash(['touch ' this.testFile])
 			this.addTeardown(@this.cleanFiles);
 		end
	end

 	methods (TestMethodSetup)
		function setupCHPCTest(this)
 			this.testObj = this.testObj_;
 		end
	end

	properties (Access = private)
 		testObj_
        pwd0_
 	end

	methods (Access = private)
		function cleanFiles(this)
            try
                deleteExisting(this.testFile);
            catch ME
                handexcept(ME);
            end
            popd(this.pwd0_);
 		end
	end

	%  Created with Newcl by John J. Lee after newfcn by Frank Gonzalez-Morphy
 end


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
        sessd
 		testObj
        testChpcLoc = '/scratch/jjlee/raichle/PPGdata/jjlee2/HYGLY28/V2'
        testFile
        test4dfp
        test4dfpDated
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
            pwd0 = pushd(this.testObj.sessionData.sessionPath);
            this.testObj.pushData( ...
                ['FDG_V2-AC/' this.test4dfpDated], ...
                 'FDG_V2-AC');
            [~,r] = this.testObj.ssh('ls /scratch/jjlee/raichle/PPGdata/jjlee2/HYGLY28/V2/FDG_V2-AC');
            this.verifyTrue(lstrfind(strtrim(r), this.test4dfpDated));
            popd(pwd0);
 		end
		function test_pullData(this)
 			import mldistcomp.*;
            pwd0 = pushd(this.testObj.sessionData.sessionPath);
            this.testObj.pullData( ...
                ['FDG_V2-AC/' this.test4dfp], ...
                 'FDG_V2-AC');
            out = ls(fullfile(getenv('PPG'), 'jjlee2/HYGLY28/V2/FDG_V2-AC'));
            this.verifyTrue(lstrfind(out, this.test4dfp));
            popd(pwd0);
 		end
	end

 	methods (TestClassSetup)
		function setupCHPC(this)
 			import mldistcomp.*;
            studyd = mlraichle.StudyData;
            sessp = fullfile(mlraichle.RaichleRegistry.instance.subjectsDir, 'HYGLY28', '');
            this.sessd = mlraichle.SessionData('studyData', studyd, 'sessionPath', sessp, 'ac', true);
 			this.testObj_ = CHPC('sessionData', this.sessd);
            
            this.pwd0_ = pushd(this.testObj_.sessionData.sessionPath);
            this.testFile = ['testFile_' datestr(now, 30) '.touch'];
            mlbash(['touch ' this.testFile])
 			this.addTeardown(@this.cleanFiles);
 		end
	end

 	methods (TestMethodSetup)
		function setupCHPCTest(this)
            this.test4dfp      =         'fdgv2r2_op_fdgv2e1to4r1_frame4_sumt.4dfp.hdr';
            this.test4dfpDated = sprintf('fdgv2r2_op_fdgv2e1to4r1_frame4_sumt_%s.4dfp.hdr', datestr(now,30));
            copyfile( ...
                fullfile(this.sessd.tracerLocation, this.test4dfp), ...
                fullfile(this.sessd.tracerLocation, this.test4dfpDated));
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


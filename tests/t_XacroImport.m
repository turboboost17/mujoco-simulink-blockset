classdef t_XacroImport < matlab.unittest.TestCase
    % New-feature tests: xacro/urdf import (CRX/ros_kortex example).
    % Uses repo-local ros_kortex-noetic-devel as the test fixture.

    methods (TestClassSetup)
        function addFixture(testCase)
            testCase.applyFixture(MujocoEnvFixture());
        end
    end

    methods (Test, TestTags = {'NewFeature','Xacro'})

        function xacroToolsPresent(testCase)
            testCase.verifyEqual(exist('generate_mujoco_from_xacro_workspace','file'), 2);
            testCase.verifyEqual(exist('importrobot_xacro_workspace','file'), 2);
        end

        function kortexFixtureAvailable(testCase)
            thisDir = fileparts(mfilename('fullpath'));
            repoRoot = fileparts(thisDir);
            fixtureDir = fullfile(repoRoot, 'ros_kortex-noetic-devel');
            testCase.assumeEqual(exist(fixtureDir,'dir'), 7, ...
                'ros_kortex-noetic-devel fixture folder missing');
            % Look for any .xacro file to confirm content
            xacros = dir(fullfile(fixtureDir, '**', '*.xacro'));
            testCase.verifyGreaterThan(numel(xacros), 0, ...
                'No .xacro files found under ros_kortex-noetic-devel');
        end
    end
end

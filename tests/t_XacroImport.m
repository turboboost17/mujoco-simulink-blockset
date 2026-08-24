classdef t_XacroImport < matlab.unittest.TestCase
    % New-feature tests: xacro/urdf import (Gen3/Robotiq example).
    % Uses the tracked minimal fixture under tests/fixtures.

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
            fixtureDir = fullfile(thisDir, 'fixtures', 'gen3_robotiq_ros2');
            testCase.verifyEqual(exist(fixtureDir,'dir'), 7, ...
                'Tracked Gen3/Robotiq fixture folder missing');
            % Look for any .xacro file to confirm content
            xacros = dir(fullfile(fixtureDir, '**', '*.xacro'));
            testCase.verifyGreaterThan(numel(xacros), 0, ...
                'No .xacro files found in tracked Gen3/Robotiq fixture');
        end
    end
end

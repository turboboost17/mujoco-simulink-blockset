classdef t_BrickSdfPlugin < matlab.unittest.TestCase
    % Regression smoke for the public brick SDF plugin workflow.

    methods (TestClassSetup)
        function addFixture(testCase)
            testCase.applyFixture(MujocoEnvFixture());
        end
    end

    methods (Test, TestTags = {'Core','BrickSdf','NewFeature'})

        function smokeBuildsLoadsAndRuns(testCase)
            testCase.assumeEqual(exist('build_brick_sdf_plugin', 'file'), 2, ...
                'build_brick_sdf_plugin not on path');
            testCase.assumeEqual(exist('smoke_brick_sdf_plugin', 'file'), 2, ...
                'smoke_brick_sdf_plugin not on path');
            testCase.assumeEqual(exist('mj_sampletime', 'file'), 3, ...
                'mj_sampletime MEX not found');
            testCase.assumeEqual(exist('mj_labelmap_mex', 'file'), 3, ...
                'mj_labelmap_mex MEX not found');

            if ispc
                compiler = mex.getCompilerConfigurations('C++', 'Selected');
                testCase.assumeNotEmpty(compiler, ...
                    'Run mex -setup C++ before the brick SDF smoke test.');
            end

            [status, ~] = system('cmake --version');
            testCase.assumeEqual(status, 0, ...
                'cmake must be on PATH for the brick SDF smoke test.');

            result = smoke_brick_sdf_plugin;

            testCase.verifyTrue(isfile(result.artifact), ...
                'Plugin artifact missing after smoke build');
            testCase.verifyEqual(result.sampleTime, 0.001, 'AbsTol', 1e-12);
            testCase.verifyGreaterThanOrEqual(result.ngeom, 2);
            testCase.verifyGreaterThanOrEqual(result.nbody, 2);
            testCase.verifyGreaterThanOrEqual(result.nscenegeom, 2);
            testCase.verifyEqual(result.native.status, 0);
        end
    end
end
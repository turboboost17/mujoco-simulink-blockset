classdef t_PerCameraResolution < matlab.unittest.TestCase
    % New-feature tests (from seg repo): per-camera resolution control.
    % Skipped until Phase 2/4 lands; tagged NewFeature so baseline filters
    % can exclude.

    methods (TestClassSetup)
        function addFixture(testCase)
            testCase.applyFixture(MujocoEnvFixture());
        end
    end

    methods (Test, TestTags = {'NewFeature','PerCameraResolution'})

        function initbusAcceptsResolutionArgs(testCase)
            % mj_initbus should accept (xml, widths, heights) in new form.
            f = which('mj_initbus');
            testCase.assertNotEmpty(f);
            src = fileread(f);
            testCase.verifyTrue(contains(src, 'camWidths') && contains(src, 'camHeights'), ...
                'mj_initbus.m does not yet accept camWidths/camHeights');
        end

        function maskExposesCustomResolution(testCase)
            % mj_maskinit should reference cameraResolutionMode + customWidth.
            f = which('mj_maskinit');
            testCase.assertNotEmpty(f);
            src = fileread(f);
            testCase.verifyTrue(contains(src, 'cameraResolutionMode'), ...
                'mj_maskinit.m does not reference cameraResolutionMode');
            testCase.verifyTrue(contains(src, 'customWidth'), ...
                'mj_maskinit.m does not reference customWidth');
        end

        function customResolutionRuns(testCase)
            % End-to-end: request custom 320x240 and run briefly.
            modelPath = which('mj_gettingStarted.slx');
            testCase.assumeNotEmpty(modelPath);
            try
                [simOut, ~] = tRunSim(modelPath, StopTime='0.04', ...
                    RgbOut='on', CustomWidth=320, CustomHeight=240);
                testCase.verifyClass(simOut, 'Simulink.SimulationOutput');
            catch me
                testCase.verifyFail(sprintf('Custom-resolution sim failed: %s', me.message));
            end
        end
    end
end

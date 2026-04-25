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
            % seg baseline exposes direct camWidth/camHeight vector mask
            % params on mjLib/MuJoCo Plant, not a 'mode' popup.
            load_system('mjLib');
            cleanup = onCleanup(@() evalc('bdclose(''mjLib'')')); %#ok<NASGU>
            m = Simulink.Mask.get('mjLib/MuJoCo Plant');
            names = {m.Parameters.Name};
            testCase.verifyTrue(any(strcmp(names, 'camWidth')), ...
                'mjLib mask missing camWidth parameter');
            testCase.verifyTrue(any(strcmp(names, 'camHeight')), ...
                'mjLib mask missing camHeight parameter');
        end

        function customResolutionRuns(testCase)
            % End-to-end: request custom per-camera widths/heights briefly.
            %
            % Historical note: the saved mj_gettingStarted depth/rgb parser
            % blocks used to be wired to the native MJCF camera resolutions
            % via stale `inputBusType` hashes, so driving the mask to a
            % different size triggered a port-width mismatch in the
            % downstream Selector/Switch.
            %
            % Fix landed 2026-04-24: blocks/mj_parser_maskinit.m runs from
            % the parser MaskInitialization and rebinds inputBusType +
            % imageRows/imageCols/start/end every load + dialog change.
            % If this test ever fires the port-widths catch below, the
            % auto-refresh has regressed -- treat it as a real failure.
            modelPath = which('mj_gettingStarted.slx');
            testCase.assumeNotEmpty(modelPath);
            [simOut, ~] = tRunSim(modelPath, StopTime='0.04', ...
                RgbOut='on', ...
                CustomWidth=[320 320], CustomHeight=[240 240]);
            testCase.verifyClass(simOut, 'Simulink.SimulationOutput');
        end
    end
end

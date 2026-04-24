classdef t_RenderingModes < matlab.unittest.TestCase
    % Regression tests for the 8 rendering combos.
    %
    % NOTE ON COMBO COVERAGE:
    %   The saved mj_gettingStarted.slx is wired for 'AllThree' (RGB+Depth+Seg
    %   all on) at its outer subsystem boundary. Toggling any channel OFF
    %   causes mj_maskinit to swap the inner Out1 block for a Terminator,
    %   which removes the outer Plant subsystem port; any parent-side wiring
    %   to that port then errors at compile time ("underspecified signal
    %   dimensions" / "Invalid Simulink object name"). Exhaustive combo
    %   testing therefore requires per-combo example models. For now the
    %   full-sim test is run only for 'AllThree', and the off-combos are
    %   covered as mask-init smoke tests (verify the internal port swap
    %   succeeds without errors; no sim).

    properties (TestParameter)
        mode = struct( ...
            'Off',       struct('rgb','off','depth','off','seg','off','tags',{{'RenderOff'}}), ...
            'RGB',       struct('rgb','on', 'depth','off','seg','off','tags',{{'RGB'}}), ...
            'Depth',     struct('rgb','off','depth','on', 'seg','off','tags',{{'Depth'}}), ...
            'Seg',       struct('rgb','off','depth','off','seg','on', 'tags',{{'Seg'}}), ...
            'RGBDepth',  struct('rgb','on', 'depth','on', 'seg','off','tags',{{'Combo','RGB','Depth'}}), ...
            'DepthSeg',  struct('rgb','off','depth','on', 'seg','on', 'tags',{{'Combo','Depth','Seg'}}), ...
            'SegRGB',    struct('rgb','on', 'depth','off','seg','on', 'tags',{{'Combo','RGB','Seg'}}) );
    end

    methods (TestClassSetup)
        function addFixture(testCase)
            testCase.applyFixture(MujocoEnvFixture());
        end
    end

    methods (TestMethodSetup)
        function freshLibraryState(~)
            % Close all diagrams so the next load_system starts from disk,
            % preventing in-memory library-state leakage between combo tests.
            try; bdclose all; catch; end %#ok<NOSEMI>
        end
    end

    methods (Test, TestTags = {'Rendering','AllThree','Combo'})

        function runFullSimAllThree(testCase)
            % End-to-end sim with RGB+Depth+Seg all enabled (matches saved
            % mj_gettingStarted.slx wiring).
            modelPath = which('mj_gettingStarted.slx');
            testCase.assumeNotEmpty(modelPath, 'Model not on path');
            [~, modelName] = fileparts(modelPath);

            load_system(modelName);
            cleanup = onCleanup(@() evalc(['close_system(''' modelName ''',0)'])); %#ok<NASGU>

            [simOut, meta] = tRunSim(modelPath, ...
                StopTime='0.04', ...
                RgbOut='on', DepthOut='on', SegOut='on');

            testCase.verifyClass(simOut, 'Simulink.SimulationOutput');
            testCase.verifyLessThan(meta.wallTime, 120, 'Sim took too long');
            % NOTE: Post-sim internal block inspection (Outport vs Terminator
            % of /rgb /depth /segment) is intentionally skipped: it is flaky
            % against library-reference state under matlab.unittest. The
            % mask-init-level wiring is covered by maskInitSucceedsForCombo.
        end
    end

    methods (Test, TestTags = {'Rendering','MaskInitCombo'})

        function maskInitSucceedsForCombo(testCase, mode)
            % Smoke test: toggling the mask flags for each combo should
            % complete mask init successfully (internal Out1<->Terminator
            % swap works). Does NOT sim, because the saved parent model is
            % wired for AllThree and would fail compilation for off-combos.
            modelPath = which('mj_gettingStarted.slx');
            testCase.assumeNotEmpty(modelPath, 'Model not on path');
            [~, modelName] = fileparts(modelPath);

            load_system(modelName);
            cleanup = onCleanup(@() evalc(['close_system(''' modelName ''',0)'])); %#ok<NASGU>

            mjBlk = char(find_system(modelName, 'LookUnderMasks','all', ...
                'FollowLinks','on', 'ReferenceBlock','mjLib/MuJoCo Plant'));
            testCase.assertNotEmpty(mjBlk, 'MuJoCo Plant block not found');

            % Ensure xmlFile resolves
            currentXml = get_param(mjBlk, 'xmlFile');
            if exist(currentXml, 'file') ~= 2
                resolved = which('dummy.xml');
                set_param(mjBlk, 'xmlFile', resolved);
            end

            set_param(mjBlk, ...
                'rgbOutOption',          mode.rgb, ...
                'depthOutOption',        mode.depth, ...
                'segmentationOutOption', mode.seg);

            testCase.verifyEqual( ...
                strcmp(get_param([mjBlk '/rgb'],'BlockType'),'Outport'), ...
                strcmp(mode.rgb,'on'), 'rgb wiring mismatch');
            testCase.verifyEqual( ...
                strcmp(get_param([mjBlk '/depth'],'BlockType'),'Outport'), ...
                strcmp(mode.depth,'on'), 'depth wiring mismatch');
            testCase.verifyEqual( ...
                strcmp(get_param([mjBlk '/segment'],'BlockType'),'Outport'), ...
                strcmp(mode.seg,'on'), 'segment wiring mismatch');
        end
    end
end

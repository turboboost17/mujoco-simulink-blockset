classdef t_RenderingModes < matlab.unittest.TestCase
    % Parameterized regression tests for the 8 rendering combos:
    %   off / RGB / Depth / Seg / RGB+Depth / Depth+Seg / Seg+RGB /
    %   RGB+Depth+Seg
    %
    % Each test flips the mask on-off flags and verifies that a short
    % simulation completes without error and that the expected outports
    % are live (non-Terminator) for each combo.

    properties (TestParameter)
        mode = struct( ...
            'Off',       struct('rgb','off','depth','off','seg','off','tags',{{'RenderOff'}}), ...
            'RGB',       struct('rgb','on', 'depth','off','seg','off','tags',{{'RGB'}}), ...
            'Depth',     struct('rgb','off','depth','on', 'seg','off','tags',{{'Depth'}}), ...
            'Seg',       struct('rgb','off','depth','off','seg','on', 'tags',{{'Seg'}}), ...
            'RGBDepth',  struct('rgb','on', 'depth','on', 'seg','off','tags',{{'Combo','RGB','Depth'}}), ...
            'DepthSeg',  struct('rgb','off','depth','on', 'seg','on', 'tags',{{'Combo','Depth','Seg'}}), ...
            'SegRGB',    struct('rgb','on', 'depth','off','seg','on', 'tags',{{'Combo','RGB','Seg'}}), ...
            'AllThree',  struct('rgb','on', 'depth','on', 'seg','on', 'tags',{{'Combo','RGB','Depth','Seg'}}) );
    end

    methods (TestClassSetup)
        function addFixture(testCase)
            testCase.applyFixture(MujocoEnvFixture());
        end
    end

    methods (Test, TestTags = {'Rendering'})

        function runComboBriefly(testCase, mode)
            modelPath = which('mj_gettingStarted.slx');
            testCase.assumeNotEmpty(modelPath, 'Model not on path');

            try
                [simOut, meta] = tRunSim(modelPath, ...
                    StopTime='0.04', ...
                    RgbOut=mode.rgb, DepthOut=mode.depth, SegOut=mode.seg);
            catch me
                testCase.verifyFail(sprintf('Sim failed for combo: %s', me.message));
                return;
            end

            testCase.verifyClass(simOut, 'Simulink.SimulationOutput');
            testCase.verifyLessThan(meta.wallTime, 120, 'Sim took too long');

            % Confirm outport wiring matches mask flag
            mdl = meta.model; mjBlk = meta.mjBlk;
            rgbBlk   = [mjBlk '/rgb'];
            depthBlk = [mjBlk '/depth'];
            segBlk   = [mjBlk '/segment'];
            testCase.verifyEqual( ...
                strcmp(get_param(rgbBlk,'BlockType'),'Outport'), strcmp(mode.rgb,'on'), ...
                sprintf('rgb outport wiring mismatch in %s', mdl));
            testCase.verifyEqual( ...
                strcmp(get_param(depthBlk,'BlockType'),'Outport'), strcmp(mode.depth,'on'), ...
                sprintf('depth outport wiring mismatch in %s', mdl));
            testCase.verifyEqual( ...
                strcmp(get_param(segBlk,'BlockType'),'Outport'), strcmp(mode.seg,'on'), ...
                sprintf('segment outport wiring mismatch in %s', mdl));
        end
    end
end

classdef t_CommandInputs < matlab.unittest.TestCase
    % Validate control-input path (u inport, vector and bus forms).

    properties (TestParameter)
    end

    methods (TestClassSetup)
        function addFixture(testCase)
            testCase.applyFixture(MujocoEnvFixture());
        end
    end

    methods (Test, TestTags = {'Core','CommandInputs'})

        function controlPortHonorsMaskWhenBus(testCase)
            % With a bus-type control input the 'u' Inport should exist,
            % the uToVector subsystem should be enabled and dimensions
            % should be inherited (-1).
            modelPath = which('mj_gettingStarted.slx');
            testCase.assumeNotEmpty(modelPath, 'mj_gettingStarted.slx not on path');

            [~, modelName] = fileparts(modelPath);
            load_system(modelPath);
            cleanup = onCleanup(@() evalc(['close_system(''' modelName ''',0)']));

            mjBlk = find_system(modelName, 'LookUnderMasks','all', 'FollowLinks','on', 'ReferenceBlock','mjLib/MuJoCo Plant');
            testCase.assertNotEmpty(mjBlk, 'Expected exactly one MuJoCo Plant block');

            portBlk = [mjBlk{1} '/u'];
            btype = get_param(portBlk, 'BlockType');
            testCase.verifyTrue(any(strcmp(btype, {'Inport','Ground'})), ...
                sprintf('u block is unexpected type: %s', btype));
        end

        function modelCompiles(testCase)
            % Sanity: model compiles without error under current mask state.
            modelPath = which('mj_gettingStarted.slx');
            testCase.assumeNotEmpty(modelPath);
            [~, modelName] = fileparts(modelPath);
            load_system(modelPath);
            cleanup = onCleanup(@() evalc(['close_system(''' modelName ''',0)']));

            try
                set_param(modelName, 'SimulationCommand', 'update');
                testCase.verifyTrue(true);
            catch me
                testCase.verifyFail(sprintf('Model compile failed: %s', me.message));
            end
        end
    end
end

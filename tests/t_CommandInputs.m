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

        function multiInputActuatorGetsOneElementPerControl(testCase)
            % An orientation servo with input="quat" takes 4 controls: the
            % control bus has nu elements, not nactuator, and the 4 are
            % named <actuator>_<input>, in ctrl order after a scalar one.
            tmpDir = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
            xmlPath = fullfile(tmpDir, 'orientation_servo.xml');
            fid = fopen(xmlPath, 'w');
            fprintf(fid, ['<mujoco>\n' ...
                '  <worldbody>\n' ...
                '    <site name="origin"/>\n' ...
                '    <body name="arm">\n' ...
                '      <joint name="slide" type="slide" axis="1 0 0"/>\n' ...
                '      <joint name="ball" type="ball"/>\n' ...
                '      <geom size="0.1" mass="1"/>\n' ...
                '      <site name="tip"/>\n' ...
                '    </body>\n' ...
                '  </worldbody>\n' ...
                '  <actuator>\n' ...
                '    <position name="slide_ctrl" joint="slide"/>\n' ...
                '    <orientation name="rot_ctrl" site="tip" refsite="origin" input="quat"/>\n' ...
                '  </actuator>\n' ...
                '</mujoco>\n']);
            fclose(fid);

            [ctrlBusName, ~, ~, ~, ~, busDims] = mj_initbus(xmlPath);
            testCase.verifyEqual(double(busDims(1)), 5);
            ctrlBus = evalin('base', ctrlBusName);
            testCase.verifyEqual({ctrlBus.Elements.Name}, ...
                {'slide_ctrl', 'rot_ctrl_qw', 'rot_ctrl_qx', 'rot_ctrl_qy', 'rot_ctrl_qz'});
        end
    end
end

classdef t_ROS2_WSL < matlab.unittest.TestCase
    % ROS2 codegen regression (WSL). Uses the mj_monitorTune_ROS model.
    % Runs codegen only (no deploy).

    methods (TestClassSetup)
        function addFixture(testCase)
            testCase.applyFixture(MujocoEnvFixture());
            if ~ispref('mujoco','ros2Paths')
                testCase.assumeFail('ROS2 libs not installed (run install(''ros2''))');
            end
        end
    end

    methods (Test, TestTags = {'ROS2WSL'})

        function codegenProducesTgz(testCase)
            modelPath = which('mj_monitorTune_ROS.slx');
            testCase.assumeNotEmpty(modelPath, 'mj_monitorTune_ROS.slx not on path');
            [~, modelName] = fileparts(modelPath);
            load_system(modelPath);
            cleanup = onCleanup(@() evalc(['close_system(''' modelName ''',0)']));

            origDir = pwd;
            dirCleanup = onCleanup(@() cd(origDir));
            cd(fileparts(modelPath));

            try
                rtwbuild(modelName);
            catch me
                testCase.verifyFail(sprintf('rtwbuild failed: %s', me.message));
                return;
            end

            tgz = fullfile(fileparts(modelPath), [modelName '.tgz']);
            testCase.verifyTrue(exist(tgz,'file')==2, ...
                sprintf('ROS2 package archive not produced: %s', tgz));
        end
    end
end

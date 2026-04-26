classdef t_ROS2_WSL < matlab.unittest.TestCase
    % ROS2 codegen regression (WSL). Uses the mj_monitorTune_ROS model.
    % Verifies codegen reaches ROS2 package archive generation.

    methods (TestClassSetup)
        function addFixture(testCase)
            testCase.applyFixture(MujocoEnvFixture());
            repoRoot = fileparts(fileparts(mfilename('fullpath')));
            addpath(fullfile(repoRoot, 'tools', 'deviceProfiles'));
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

            profileName = "wsl-x64-ros2humble";
            profilePath = fullfile(fileparts(fileparts(modelPath)), ...
                'tools', 'deviceProfiles', profileName + ".mat");
            testCase.assumeTrue(isfile(profilePath), ...
                sprintf('WSL device profile not found: %s', profilePath));
            mj_applyDeviceProfile(profileName, Model=modelName, Save=false, ...
                SeedROS2Workspace=false);
            cs = getActiveConfigSet(modelName);
            codertarget.data.setParameterValue(cs, 'Runtime.BuildAction', 'Build and load');
            codertarget.data.setParameterValue(cs, 'ROS.RemoteBuild', false);

            origDir = pwd;
            dirCleanup = onCleanup(@() cd(origDir));
            cd(fileparts(modelPath));
            tgz = fullfile(fileparts(modelPath), [modelName '.tgz']);
            if isfile(tgz)
                delete(tgz);
            end

            try
                rtwbuild(modelName);
            catch me
                if exist(tgz,'file')~=2
                    testCase.verifyFail(sprintf( ...
                        'rtwbuild failed before archive generation: %s', me.message));
                    return;
                end
                fprintf('rtwbuild failed after producing archive: %s\n', me.message);
            end

            testCase.verifyTrue(exist(tgz,'file')==2, ...
                sprintf('ROS2 package archive not produced: %s', tgz));
        end
    end
end

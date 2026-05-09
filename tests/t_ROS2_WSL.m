classdef t_ROS2_WSL < matlab.unittest.TestCase
    % ROS2 codegen regression for the WSL Humble profile.
    %
    % Purpose: prove the model can be configured for the WSL ROS2 toolchain
    % and generate the deployable package archive.
    %
    % Execution: local code generation only. The test accepts failures that
    % happen after the .tgz archive is produced because local Windows colcon
    % builds are outside this profile's contract.

    methods (TestClassSetup)
        function addFixture(testCase)
            % Shared setup: add profile helpers and skip when ROS2 support is
            % not installed for this MATLAB environment.
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
            % Model/profile configuration: target WSL and keep the build local.
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

            % Archive generation contract: the .tgz is the pass/fail artifact
            % for WSL even if a later local build step reports an error.
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

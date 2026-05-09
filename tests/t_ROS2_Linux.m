classdef t_ROS2_Linux < matlab.unittest.TestCase
    % ROS2 deploy regression against a native Ubuntu 22.04 Humble target.
    %
    % Purpose: validate the native x86_64 Linux profile performs a remote
    % ROS2 build/deploy using the lab Ubuntu Humble machine.
    %
    % Execution: hardware-gated. The target must be reachable and have the
    % expected ROS2 workspace and build dependencies installed.

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

    methods (Test, TestTags = {'ROS2Linux'})
        function linuxReachable(testCase)
            % Reachability gate: keep the full suite green when the lab Linux
            % target is intentionally offline.
            host = t_ROS2_Linux.linuxHost();
            testCase.assumeNotEmpty(host, ...
                'Linux ROS2 target host not configured (set MJ_ROS2_LINUX_HOST or create the device profile)');
            [status, ~] = system(t_ROS2_Linux.pingCommand(host));
            testCase.assumeEqual(status, 0, sprintf('Linux ROS2 target %s not reachable', host));
        end

        function deployBuildsOnLinux(testCase)
            % Remote deploy contract: apply the native profile, build on the
            % target, and load the generated ROS2 package into its workspace.
            host = t_ROS2_Linux.linuxHost();
            testCase.assumeNotEmpty(host, ...
                'Linux ROS2 target host not configured (set MJ_ROS2_LINUX_HOST or create the device profile)');
            [status, ~] = system(t_ROS2_Linux.pingCommand(host));
            testCase.assumeEqual(status, 0, sprintf('Linux ROS2 target %s not reachable', host));

            modelPath = which('mj_monitorTune_ROS.slx');
            testCase.assumeNotEmpty(modelPath, 'mj_monitorTune_ROS.slx not on path');
            [~, modelName] = fileparts(modelPath);
            load_system(modelPath);
            cleanup = onCleanup(@() evalc(['close_system(''' modelName ''',0)']));

            profileName = t_ROS2_Linux.profileName();
            profilePath = t_ROS2_Linux.profilePath();
            testCase.assumeTrue(isfile(profilePath), ...
                sprintf('Linux device profile not found: %s', profilePath));
            mj_applyDeviceProfile(profileName, Model=modelName, Save=false);

            set_param(modelName, 'SimulationMode', 'normal');
            set_param(modelName, 'ExtMode', 'off');
            cs = getActiveConfigSet(modelName);
            codertarget.data.setParameterValue(cs, 'Runtime.BuildAction', 'Build and load');
            codertarget.data.setParameterValue(cs, 'ROS.RemoteBuild', true);

            % Build/deploy assertion: any rtwbuild failure is a regression for
            % this hardware profile.
            try
                rtwbuild(modelName);
                testCase.verifyTrue(true);
            catch buildError
                testCase.verifyFail(sprintf( ...
                    'rtwbuild failed targeting native Linux ROS2 target: %s', ...
                    buildError.message));
            end
        end
    end

    methods (Static, Access = private)
        function name = profileName()
            name = "ubuntu-2204-x64-ros2humble";
        end

        function host = linuxHost()
            host = getenv('MJ_ROS2_LINUX_HOST');
            if isempty(host)
                profilePath = t_ROS2_Linux.profilePath();
                if isfile(profilePath)
                    profileData = load(profilePath, 'profile');
                    if isfield(profileData.profile, 'ROS2DevicePrefs') && ...
                            isfield(profileData.profile.ROS2DevicePrefs, 'Hostname')
                        host = profileData.profile.ROS2DevicePrefs.Hostname;
                    end
                end
            end
        end

        function profilePath = profilePath()
            repoRoot = fileparts(fileparts(mfilename('fullpath')));
            profilePath = fullfile(repoRoot, 'tools', 'deviceProfiles', ...
                t_ROS2_Linux.profileName() + ".mat");
        end

        function command = pingCommand(host)
            if ispc
                command = sprintf('ping -n 1 -w 1000 %s', host);
            else
                command = sprintf('ping -c 1 -W 1 %s', host);
            end
        end
    end
end

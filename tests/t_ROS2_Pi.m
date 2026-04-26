classdef t_ROS2_Pi < matlab.unittest.TestCase
    % ROS2 deploy regression against Raspberry Pi target. Requires reachable
    % Pi configured via the MATLAB ROS Toolbox. Tests will auto-skip if the
    % Pi is unreachable so the rest of the suite keeps running.

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

    methods (Test, TestTags = {'ROS2Pi'})

        function piReachable(testCase)
            host = t_ROS2_Pi.piHost();
            [s, ~] = system(sprintf('ping -n 1 -w 1000 %s', host));
            testCase.assumeEqual(s, 0, sprintf('Pi %s not reachable', host));
        end

        function deployBuildsOnPi(testCase)
            % Attempt end-to-end build + (optional) deploy.
            host = t_ROS2_Pi.piHost();
            [s, ~] = system(sprintf('ping -n 1 -w 1000 %s', host));
            testCase.assumeEqual(s, 0, sprintf('Pi %s not reachable', host));

            modelPath = which('mj_monitorTune_ROS.slx');
            testCase.assumeNotEmpty(modelPath);
            [~, modelName] = fileparts(modelPath);
            load_system(modelPath);
            cleanup = onCleanup(@() evalc(['close_system(''' modelName ''',0)']));
            profilePath = t_ROS2_Pi.piProfilePath();
            testCase.assumeTrue(isfile(profilePath), ...
                sprintf('Pi device profile not found: %s', profilePath));
            mj_applyDeviceProfile("raspi-arm64-ros2jazzy", Model=modelName, ...
                Save=false, SeedROS2Workspace=false);
            set_param(modelName, 'SimulationMode', 'normal');
            set_param(modelName, 'ExtMode', 'off');

            try
                rtwbuild(modelName);
                testCase.verifyTrue(true);
            catch me
                testCase.verifyFail(sprintf('rtwbuild failed targeting Pi: %s', me.message));
            end
        end
    end

    methods (Static, Access = private)
        function host = piHost()
            host = getenv('MJ_ROS2_PI_HOST');
            if isempty(host)
                profilePath = t_ROS2_Pi.piProfilePath();
                if isfile(profilePath)
                    S = load(profilePath, 'profile');
                    if isfield(S.profile, 'ROS2DevicePrefs') && ...
                            isfield(S.profile.ROS2DevicePrefs, 'Hostname')
                        host = S.profile.ROS2DevicePrefs.Hostname;
                    end
                end
            end
            if isempty(host)
                host = 'raspberrypi.local';
            end
        end

        function profilePath = piProfilePath()
            repoRoot = fileparts(fileparts(mfilename('fullpath')));
            profilePath = fullfile(repoRoot, 'tools', 'deviceProfiles', ...
                'raspi-arm64-ros2jazzy.mat');
        end
    end
end

classdef t_ROS2_Pi < matlab.unittest.TestCase
    % ROS2 deploy regression against Raspberry Pi target. Requires reachable
    % Pi configured via the MATLAB ROS Toolbox. Tests will auto-skip if the
    % Pi is unreachable so the rest of the suite keeps running.

    methods (TestClassSetup)
        function addFixture(testCase)
            testCase.applyFixture(MujocoEnvFixture());
            if ~ispref('mujoco','ros2Paths')
                testCase.assumeFail('ROS2 libs not installed (run install(''ros2''))');
            end
        end
    end

    methods (Test, TestTags = {'ROS2Pi'})

        function piReachable(testCase)
            host = getenv('MJ_ROS2_PI_HOST');
            if isempty(host); host = 'raspberrypi.local'; end
            [s, ~] = system(sprintf('ping -n 1 -w 1000 %s', host));
            testCase.assumeEqual(s, 0, sprintf('Pi %s not reachable', host));
        end

        function deployBuildsOnPi(testCase)
            % Attempt end-to-end build + (optional) deploy.
            host = getenv('MJ_ROS2_PI_HOST');
            if isempty(host); host = 'raspberrypi.local'; end
            [s, ~] = system(sprintf('ping -n 1 -w 1000 %s', host));
            testCase.assumeEqual(s, 0, sprintf('Pi %s not reachable', host));

            modelPath = which('mj_monitorTune_ROS.slx');
            testCase.assumeNotEmpty(modelPath);
            [~, modelName] = fileparts(modelPath);
            load_system(modelPath);
            cleanup = onCleanup(@() evalc(['close_system(''' modelName ''',0)']));

            try
                rtwbuild(modelName);
                testCase.verifyTrue(true);
            catch me
                testCase.verifyFail(sprintf('rtwbuild failed targeting Pi: %s', me.message));
            end
        end
    end
end

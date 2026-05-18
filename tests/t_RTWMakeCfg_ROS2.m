classdef t_RTWMakeCfg_ROS2 < matlab.unittest.TestCase
    % Validate ROS2 link declaration selection in rtwmakecfg.

    methods (TestClassSetup)
        function addFixture(testCase)
            testCase.applyFixture(MujocoEnvFixture());
            repoRoot = fileparts(fileparts(mfilename('fullpath')));
            addpath(fullfile(repoRoot, 'blocks'));
            if ~ispref('mujoco', 'ros2Paths')
                testCase.assumeFail('ROS2 libs not installed (run install(''ros2''))');
            end
        end
    end

    methods (Test, TestTags = {'ROS2WSL'})
        function selectsLinuxX86Artifacts(testCase)
            modelName = testCase.loadRosModel();
            archCleanup = testCase.overrideRos2Arch('linux-x86_64');
            closeArchCleanup = onCleanup(@() delete(archCleanup)); %#ok<NASGU>

            set_param(modelName, 'Toolchain', 'Colcon Tools');
            makeInfo = rtwmakecfg();

            testCase.verifyTrue(any(contains(makeInfo.includePath, 'linux-x86_64')), ...
                'rtwmakecfg did not select linux-x86_64 MuJoCo include path.');
            testCase.verifyTrue(any(contains(makeInfo.linkLibsObjs, 'libmujoco.so.')), ...
                'rtwmakecfg did not emit versioned MuJoCo shared library linkage.');
            testCase.verifyTrue(any(strcmp(makeInfo.linkLibsObjs, 'glfw')), ...
                'rtwmakecfg did not emit glfw linkage token.');
            testCase.verifyTrue(any(strcmp(makeInfo.linkLibsObjs, 'GL')), ...
                'rtwmakecfg did not emit OpenGL linkage token.');
        end

        function selectsLinuxAarch64Artifacts(testCase)
            modelName = testCase.loadRosModel();
            archCleanup = testCase.overrideRos2Arch('linux-aarch64');
            closeArchCleanup = onCleanup(@() delete(archCleanup)); %#ok<NASGU>

            set_param(modelName, 'Toolchain', 'Colcon Tools');
            makeInfo = rtwmakecfg();

            testCase.verifyTrue(any(contains(makeInfo.includePath, 'linux-aarch64')), ...
                'rtwmakecfg did not select linux-aarch64 MuJoCo include path.');
            testCase.verifyTrue(any(contains(makeInfo.linkLibsObjs, 'libmujoco.so.')), ...
                'rtwmakecfg did not emit versioned MuJoCo shared library linkage.');
        end
    end

    methods (Access = private)
        function modelName = loadRosModel(testCase)
            modelPath = which('mj_monitorTune_ROS.slx');
            testCase.assumeNotEmpty(modelPath, 'mj_monitorTune_ROS.slx not on path');
            [~, modelName] = fileparts(modelPath);
            load_system(modelPath);
            testCase.addTeardown(@() evalc(['close_system(''' modelName ''',0)']));
        end

        function cleanupObj = overrideRos2Arch(testCase, arch)
            hadPref = ispref('mujoco', 'ros2TargetArch');
            oldArch = '';
            if hadPref
                oldArch = char(getpref('mujoco', 'ros2TargetArch'));
            end

            setpref('mujoco', 'ros2TargetArch', arch);
            cleanupObj = onCleanup(@() testCase.restoreRos2ArchPref(hadPref, oldArch));
        end
    end

    methods (Static, Access = private)
        function restoreRos2ArchPref(hadPref, oldArch)
            if hadPref
                setpref('mujoco', 'ros2TargetArch', oldArch);
            elseif ispref('mujoco', 'ros2TargetArch')
                rmpref('mujoco', 'ros2TargetArch');
            end
        end
    end
end

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
            mujocoLinks = makeInfo.linkLibsObjs(contains( ...
                makeInfo.linkLibsObjs, 'libmujoco.so.'));
            testCase.verifyNumElements(mujocoLinks, 1, ...
                'rtwmakecfg did not emit versioned MuJoCo shared library linkage.');
            testCase.verifyTrue(isfile(mujocoLinks{1}), ...
                'rtwmakecfg emitted a MuJoCo link artifact that does not exist.');
            testCase.verifyFalse(any(ismember(makeInfo.linkLibsObjs, ...
                {'glfw', 'GL'})), ...
                'Target system libraries must be added as precompiled link tokens.');
            testCase.verifyEqual({makeInfo.library.Name}, {'glfw', 'GL'}, ...
                'rtwmakecfg did not declare target system libraries.');
            testCase.verifyEqual({makeInfo.library.Location}, ...
                repmat({'/usr/lib/x86_64-linux-gnu'}, 1, 2), ...
                'rtwmakecfg selected the wrong x86_64 system library path.');
            testCase.verifyTrue(all(cellfun(@isempty, ...
                {makeInfo.library.Modules})), ...
                'Target system libraries must not declare local source modules.');
        end

        function selectsLinuxAarch64Artifacts(testCase)
            modelName = testCase.loadRosModel();
            archCleanup = testCase.overrideRos2Arch('linux-aarch64');
            closeArchCleanup = onCleanup(@() delete(archCleanup)); %#ok<NASGU>

            set_param(modelName, 'Toolchain', 'Colcon Tools');
            makeInfo = rtwmakecfg();

            testCase.verifyTrue(any(contains(makeInfo.includePath, 'linux-aarch64')), ...
                'rtwmakecfg did not select linux-aarch64 MuJoCo include path.');
            mujocoLinks = makeInfo.linkLibsObjs(contains( ...
                makeInfo.linkLibsObjs, 'libmujoco.so.'));
            testCase.verifyNumElements(mujocoLinks, 1, ...
                'rtwmakecfg did not emit versioned MuJoCo shared library linkage.');
            testCase.verifyTrue(isfile(mujocoLinks{1}), ...
                'rtwmakecfg emitted a MuJoCo link artifact that does not exist.');
            testCase.verifyEqual({makeInfo.library.Location}, ...
                repmat({'/usr/lib/aarch64-linux-gnu'}, 1, 2), ...
                'rtwmakecfg selected the wrong aarch64 system library path.');
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

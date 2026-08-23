classdef t_XacroGen3GripperE2E < matlab.unittest.TestCase
    % End-to-end regression test for the xacro -> MuJoCo pipeline.
    %
    % Drives generate_mujoco_from_xacro_workspace on the gen3 + Robotiq 2F-85
    % example (with the sensor package) and asserts the generated portable MJCF
    % matches tests/e2e_xacro_ros2/expected/gen3_robotiq_2f_85.expected.json.
    %
    % Windows-only: the converter invokes the bundled compile.exe under
    % lib/win64/mujoco/bin.

    properties
        MjcfText char = ''
        Spec struct = struct()
        Result struct = struct()
    end

    methods (TestClassSetup)
        function buildArtifacts(testCase)
            testCase.applyFixture(MujocoEnvFixture());
            testCase.assumeTrue(ispc, ...
                'compile.exe is Windows-only (lib/win64); skipping E2E test.');

            thisDir = fileparts(mfilename('fullpath'));
            fixtureRoot = fullfile(thisDir, 'fixtures', 'gen3_robotiq_ros2');
            xacro = fullfile(fixtureRoot, ...
                'kortex_description', 'robots', 'gen3_robotiq_2f_85.xacro');
            testCase.assumeEqual(exist(xacro, 'file'), 2, ...
                'gen3_robotiq_2f_85.xacro fixture missing');

            specFile = fullfile(thisDir, 'e2e_xacro_ros2', 'expected', ...
                'gen3_robotiq_2f_85.expected.json');
            testCase.assumeEqual(exist(specFile, 'file'), 2, ...
                'expected-entities spec missing');
            testCase.Spec = jsondecode(fileread(specFile));

            outDir = tempname;
            testCase.addTeardown(@() t_XacroGen3GripperE2E.safeRmdir(outDir));

            res = generate_mujoco_from_xacro_workspace(xacro, ...
                'WorkspaceRoot', fixtureRoot, ...
                'OutputDir', outDir, ...
                'Gripper', testCase.Spec.gripper, ...
                'ForceRebuild', true, ...
                'UnresolvedArgPolicy', 'warn');
            testCase.Result = res;

            testCase.assertEqual(exist(res.PortableMjcfFile, 'file'), 2, ...
                'Portable MJCF was not generated');
            testCase.MjcfText = fileread(res.PortableMjcfFile);
        end
    end

    methods (Test, TestTags = {'NewFeature', 'Xacro', 'E2E'})

        function artifactsExist(testCase)
            res = testCase.Result;
            testCase.verifyEqual(exist(res.PortableMjcfFile, 'file'), 2, ...
                'Portable MJCF missing');
            testCase.verifyEqual(exist(res.PortableUrdfFile, 'file'), 2, ...
                'Portable URDF missing');
            testCase.verifyEqual(exist(res.ManifestJsonFile, 'file'), 2, ...
                'Manifest JSON missing');
        end

        function compileSucceeded(testCase)
            % localRunMujocoCompile throws on a non-zero exit or "Error:" in the
            % output, so a populated result already implies both compiles passed.
            out = testCase.Result.CompileOutput;
            testCase.verifyClass(out.FromUrdf, 'char', ...
                'First compile (URDF -> MJCF) output missing');
            testCase.verifyClass(out.WithAttach, 'char', ...
                'Second compile (attach bake) output missing');
            testCase.verifyEmpty(regexp(out.FromUrdf, 'Error:', 'once'), ...
                'First compile reported an error');
            testCase.verifyEmpty(regexp(out.WithAttach, 'Error:', 'once'), ...
                'Second compile reported an error');
        end

        function rosGripperSubtreeStripped(testCase)
            if testCase.Spec.rosFingerBodiesExpectedZero
                count = numel(regexp(testCase.MjcfText, ...
                    '<body name="(left|right)_(outer|inner)_', 'start'));
                testCase.verifyEqual(count, 0, ...
                    'ROS Robotiq finger bodies were not stripped from the MJCF');
            end
        end

        function mujocoGripperAttached(testCase)
            prefix = testCase.Spec.attachPrefix;
            count = numel(regexp(testCase.MjcfText, ...
                ['name="' regexptranslate('escape', prefix)], 'start'));
            testCase.verifyGreaterThanOrEqual(count, testCase.Spec.minGripperBodies, ...
                sprintf('Expected >= %d %s-prefixed gripper entities', ...
                testCase.Spec.minGripperBodies, prefix));
        end

        function camerasInserted(testCase)
            for i = 1:numel(testCase.Spec.cameras)
                name = testCase.Spec.cameras{i};
                testCase.verifyTrue(testCase.hasEntity('camera', name), ...
                    sprintf('Camera "%s" missing from MJCF', name));
            end
        end

        function sitesInserted(testCase)
            for i = 1:numel(testCase.Spec.sites)
                name = testCase.Spec.sites{i};
                testCase.verifyTrue(testCase.hasEntity('site', name), ...
                    sprintf('Site "%s" missing from MJCF', name));
            end
        end

        function sensorsInserted(testCase)
            for i = 1:numel(testCase.Spec.sensorTypes)
                tag = testCase.Spec.sensorTypes{i};
                count = numel(regexp(testCase.MjcfText, ['<' tag '\s'], 'start'));
                testCase.verifyGreaterThan(count, 0, ...
                    sprintf('Sensor type "%s" missing from MJCF', tag));
            end
        end

        function armJointSensorsPerJoint(testCase)
            jp = numel(regexp(testCase.MjcfText, '<jointpos\s', 'start'));
            jv = numel(regexp(testCase.MjcfText, '<jointvel\s', 'start'));
            testCase.verifyEqual(jp, testCase.Spec.armJointCount, ...
                'jointpos sensor count does not match arm joint count');
            testCase.verifyEqual(jv, testCase.Spec.armJointCount, ...
                'jointvel sensor count does not match arm joint count');
        end

        function actuatorsPresent(testCase)
            % MuJoCo's compiler normalizes <position>/<velocity> shortcuts to
            % <general> in the saved MJCF.
            count = numel(regexp(testCase.MjcfText, '<general\s', 'start'));
            testCase.verifyGreaterThanOrEqual(count, testCase.Spec.minGeneralActuators, ...
                sprintf('Expected >= %d general actuators', ...
                testCase.Spec.minGeneralActuators));
        end
    end

    methods (Access = private)
        function tf = hasEntity(testCase, tag, name)
            pat = ['<' tag '\s[^>]*name="' regexptranslate('escape', name) '"'];
            tf = ~isempty(regexp(testCase.MjcfText, pat, 'once'));
        end
    end

    methods (Static, Access = private)
        function safeRmdir(folder)
            if isfolder(folder)
                try
                    rmdir(folder, 's');
                catch
                end
            end
        end
    end
end

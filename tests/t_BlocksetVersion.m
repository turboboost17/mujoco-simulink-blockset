classdef t_BlocksetVersion < matlab.unittest.TestCase
    % Validate mujocoBlocksetVersion against install.m and the release-tag rule.

    methods (Test, TestTags = {'Core','Version'})

        function releaseMatchesInstallRuntime(testCase)
            % The first three release fields are the MuJoCo version install.m fetches.
            v = mujocoBlocksetVersion();
            tok = regexp(fileread(fullfile(v.Root, 'install.m')), ...
                'MJ_VER\s*=\s*''([0-9.]+)''', 'tokens', 'once');
            testCase.assertNotEmpty(tok, 'MJ_VER not found in install.m');
            parts = strsplit(v.Release, '.');
            testCase.verifyNumElements(parts, 4);
            testCase.verifyEqual(strjoin(parts(1:3), '.'), tok{1});
        end

        function minimumReleaseCheck(testCase)
            v = mujocoBlocksetVersion();
            mujocoBlocksetVersion(v.Release);   % equal passes
            mujocoBlocksetVersion('3.3.1');     % older passes, short form
            testCase.verifyError(@() mujocoBlocksetVersion('99.0.0.0'), 'mujoco:blockset:VersionTooOld');
            testCase.verifyError(@() mujocoBlocksetVersion('3.x'), 'mujoco:blockset:BadVersion');
        end
    end
end

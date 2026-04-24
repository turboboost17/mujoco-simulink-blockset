classdef MujocoEnvFixture < matlab.unittest.fixtures.Fixture
    % MUJOCOENVFIXTURE Assumes-install for mujoco prefs and paths.
    %
    % Marks the test as assumption-failed (not hard failure) when the
    % mujoco libraries / prefs aren't available.

    methods
        function setup(fixture)
            repoRoot = fileparts(fileparts(mfilename('fullpath')));
            repoRoot = fileparts(repoRoot); % tests/fixtures -> tests -> repo
            addpath(fullfile(repoRoot, 'blocks'));
            addpath(fullfile(repoRoot, 'examples'));
            addpath(fullfile(repoRoot, 'src'));
            if ~ispref('mujoco', 'incPaths')
                error('MujocoEnvFixture:notInstalled', ...
                    'Run install() before running tests.');
            end
            if exist('mj_sfun', 'file') ~= 3
                error('MujocoEnvFixture:sfunMissing', ...
                    'mj_sfun MEX not found. Build with cd(''tools''); gmake build');
            end
        end

        function teardown(~)
            try; bdclose all; catch; end %#ok<NOSEMI>
        end
    end
end

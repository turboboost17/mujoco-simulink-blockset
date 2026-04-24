function results = runAllTests(varargin)
%RUNALLTESTS Run the mujoco-simulink-blockset regression suite.
%
%   results = runAllTests()
%   results = runAllTests('Tags', {'Core'})             % only tagged tests
%   results = runAllTests('Skip', {'ROS2Pi'})           % exclude tags
%   results = runAllTests('Report', 'tests/latest.json')
%
% Tag taxonomy:
%   Core        : command inputs / sensor outputs (no rendering)
%   Rendering   : any test using the MuJoCo offscreen render path
%   RGB         : rgb-rendering-only tests
%   Depth       : depth-rendering-only tests
%   Seg         : segmentation-rendering-only tests
%   Combo       : two-of-three or three-of-three rendering combinations
%   RenderOff   : rendering disabled (performance path)
%   ROS2WSL     : codegen targeting ROS2 on WSL
%   ROS2Pi      : codegen/deploy targeting Raspberry Pi
%   NewFeature  : tests for features merged from seg repo
%
% Results are written to tests/results/YYYYMMDD_HHMMSS.json and the most
% recent report is copied to tests/latest.json.

    arguments (Repeating)
        varargin
    end

    p = inputParser;
    p.addParameter('Tags', {}, @iscell);
    p.addParameter('Skip', {}, @iscell);
    p.addParameter('Report', '', @(x)ischar(x)||isstring(x));
    p.parse(varargin{:});
    opts = p.Results;

    thisDir = fileparts(mfilename('fullpath'));
    repoRoot = fileparts(thisDir);

    addpath(thisDir);
    addpath(fullfile(thisDir, 'utils'));
    addpath(fullfile(thisDir, 'fixtures'));
    addpath(fullfile(repoRoot, 'blocks'));
    addpath(fullfile(repoRoot, 'examples'));

    import matlab.unittest.TestSuite
    import matlab.unittest.TestRunner
    import matlab.unittest.selectors.HasTag
    import matlab.unittest.plugins.TestRunProgressPlugin
    import matlab.unittest.plugins.DiagnosticsOutputPlugin

    suite = TestSuite.fromFolder(thisDir, 'IncludingSubfolders', false);

    if ~isempty(opts.Tags)
        sel = HasTag(opts.Tags{1});
        for i = 2:numel(opts.Tags)
            sel = sel | HasTag(opts.Tags{i});
        end
        suite = suite.selectIf(sel);
    end

    for i = 1:numel(opts.Skip)
        suite = suite.selectIf(~HasTag(opts.Skip{i}));
    end

    runner = TestRunner.withNoPlugins();
    runner.addPlugin(TestRunProgressPlugin.withVerbosity( ...
        matlab.unittest.Verbosity.Concise));
    runner.addPlugin(DiagnosticsOutputPlugin());

    fprintf('[regression] running %d tests...\n', numel(suite));
    results = runner.run(suite);

    % -- persist report ---------------------------------------------------
    resultsDir = fullfile(thisDir, 'results');
    if ~exist(resultsDir, 'dir'); mkdir(resultsDir); end

    stamp = datestr(now, 'yyyymmdd_HHMMSS'); %#ok<TNOW1,DATST>
    reportFile = fullfile(resultsDir, [stamp '.json']);
    if strlength(opts.Report) > 0
        reportFile = char(opts.Report);
    end

    reportStruct = struct( ...
        'timestamp', stamp, ...
        'matlabRelease', version('-release'), ...
        'hostname', getenv('COMPUTERNAME'), ...
        'passed', sum([results.Passed]), ...
        'failed', sum([results.Failed]), ...
        'incomplete', sum([results.Incomplete]), ...
        'duration_s', sum([results.Duration]), ...
        'tests', struct('name', {}, 'passed', {}, 'failed', {}, ...
                        'incomplete', {}, 'duration', {}, 'details', {}) );

    for i = 1:numel(results)
        d = '';
        if ~isempty(results(i).Details) && isfield(results(i).Details, 'DiagnosticRecord')
            try
                drec = results(i).Details.DiagnosticRecord;
                if ~isempty(drec); d = char(drec(1).Report); end
            catch
            end
        end
        reportStruct.tests(end+1) = struct( ...
            'name', results(i).Name, ...
            'passed', results(i).Passed, ...
            'failed', results(i).Failed, ...
            'incomplete', results(i).Incomplete, ...
            'duration', results(i).Duration, ...
            'details', d);
    end

    fid = fopen(reportFile, 'w');
    fwrite(fid, jsonencode(reportStruct, 'PrettyPrint', true));
    fclose(fid);
    copyfile(reportFile, fullfile(thisDir, 'latest.json'));

    fprintf('[regression] %d passed, %d failed, %d incomplete (%.1fs)\n', ...
        reportStruct.passed, reportStruct.failed, reportStruct.incomplete, ...
        reportStruct.duration_s);
    fprintf('[regression] report: %s\n', reportFile);
end

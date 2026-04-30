function result = smoke_lego_sdf_plugin(opts)
%SMOKE_LEGO_SDF_PLUGIN Build and validate the Lego SDF plugin path.

arguments
    opts.MujocoRoot (1,:) char = ''
    opts.BuildDir (1,:) char = ''
    opts.PluginDir (1,:) char = ''
    opts.Build (1,1) logical = true
    opts.RunNative (1,1) logical = true
    opts.RunSimulink (1,1) logical = true
    opts.MaxSdfInitPoints (1,1) double = 8
    opts.MaxSdfIterations (1,1) double = 8
end

repoRoot = fileparts(fileparts(mfilename('fullpath')));
xmlPath = fullfile(repoRoot, 'examples', 'lego_sdf_2x4.xml');
localAssertConservativeSdfOptions(xmlPath, opts.MaxSdfInitPoints, opts.MaxSdfIterations);
addpath(fullfile(repoRoot, 'blocks'), '-begin');
addpath(fullfile(repoRoot, 'tools'), '-begin');

if opts.Build
    artifact = build_lego_sdf_plugin(MujocoRoot=opts.MujocoRoot, ...
        BuildDir=opts.BuildDir, PluginDir=opts.PluginDir);
    pluginDir = fileparts(artifact);
else
    pluginDir = opts.PluginDir;
    if isempty(pluginDir)
        pluginDir = getenv('MUJOCO_PLUGIN_DIR');
    end
    if isempty(pluginDir)
        error('legoSdfSmoke:noPluginDir', ...
            'Pass PluginDir or set MUJOCO_PLUGIN_DIR when Build=false.');
    end
    artifact = fullfile(pluginDir, localPluginLibraryName());
    if ~isfile(artifact)
        error('legoSdfSmoke:missingPlugin', 'Plugin artifact not found: %s', artifact);
    end
end

[mujocoRoot, mujocoBin] = localRuntimeFromPluginDir(pluginDir, opts.MujocoRoot);
localEnsureMexRuntimeDlls(repoRoot, mujocoRoot);
setenv('MUJOCO_PLUGIN_DIR', pluginDir);
setenv('PATH', [mujocoBin pathsep getenv('PATH')]);

result = struct();
result.artifact = artifact;
result.pluginDir = pluginDir;
result.xmlPath = xmlPath;

if opts.RunNative
    result.native = localRunNativeSmoke(repoRoot, opts.BuildDir, pluginDir, xmlPath);
end

result.sampleTime = mj_sampletime(xmlPath);
if abs(result.sampleTime - 0.002) > 1e-12
    error('legoSdfSmoke:sampleTime', 'Unexpected sample time: %.17g', result.sampleTime);
end

[geomNames, bodyNames, ngeom, ~, nbody, segIds, ~, ~, ~, nscenegeom] = mj_labelmap_mex(xmlPath);
result.ngeom = ngeom;
result.nbody = nbody;
result.nscenegeom = nscenegeom;
result.firstGeomName = geomNames{1};
result.firstBodyName = bodyNames{1};
result.firstSegId = segIds(1);

if result.ngeom < 2 || result.nbody < 2 || result.nscenegeom < 2
    error('legoSdfSmoke:labelmap', ...
        'Unexpected labelmap sizes: ngeom=%g nbody=%g nscenegeom=%g', ...
        result.ngeom, result.nbody, result.nscenegeom);
end

if opts.RunSimulink
    result.simTime = localRunSfunSmoke(xmlPath);
end

fprintf('Lego SDF smoke passed: sampleTime=%.6f ngeom=%g nscenegeom=%g\n', ...
    result.sampleTime, result.ngeom, result.nscenegeom);
end

function native = localRunNativeSmoke(repoRoot, buildDir, pluginDir, xmlPath)
if isempty(buildDir)
    buildDir = fullfile(repoRoot, 'temp', 'build', 'lego_sdf', computer('arch'));
end

if ispc
    smokeExe = fullfile(buildDir, 'Release', 'lego_sdf_smoke.exe');
else
    smokeExe = fullfile(buildDir, 'lego_sdf_smoke');
end

native = struct('command', '', 'output', '', 'status', []);
if ~isfile(smokeExe)
    error('legoSdfSmoke:missingNativeSmoke', 'Native smoke executable not found: %s', smokeExe);
end

native.command = sprintf('%s %s %s', localQuote(smokeExe), ...
    localQuote(pluginDir), localQuote(xmlPath));
[native.status, native.output] = system(native.command);
fprintf('%s', native.output);
if native.status ~= 0
    error('legoSdfSmoke:nativeFailed', 'Native smoke failed with status %d.', native.status);
end
end

function localAssertConservativeSdfOptions(xmlPath, maxInitPoints, maxIterations)
xmlDoc = xmlread(xmlPath);
optionNodes = xmlDoc.getElementsByTagName('option');
if optionNodes.getLength() == 0
    error('legoSdfSmoke:missingSdfOptions', ...
        'Smoke MJCF must explicitly set conservative sdf_initpoints and sdf_iterations.');
end

optionNode = optionNodes.item(0);
initPoints = localRequiredIntAttribute(optionNode, 'sdf_initpoints');
iterations = localRequiredIntAttribute(optionNode, 'sdf_iterations');

if initPoints > maxInitPoints || iterations > maxIterations
    error('legoSdfSmoke:sdfTetBudget', ...
        ['Smoke MJCF SDF settings are too high for crash-safe validation: ', ...
         'sdf_initpoints=%d (max %d), sdf_iterations=%d (max %d).'], ...
        initPoints, maxInitPoints, iterations, maxIterations);
end
end

function value = localRequiredIntAttribute(node, attributeName)
if ~node.hasAttribute(attributeName)
    error('legoSdfSmoke:missingSdfOption', ...
        'Smoke MJCF option is missing required attribute: %s', attributeName);
end

rawValue = char(node.getAttribute(attributeName));
value = str2double(rawValue);
if ~isfinite(value) || fix(value) ~= value
    error('legoSdfSmoke:invalidSdfOption', ...
        'Smoke MJCF option %s must be an integer, got: %s', attributeName, rawValue);
end
end

function simTime = localRunSfunSmoke(xmlPath)
modelName = 'tmp_lego_sdf_sfun_smoke';
if bdIsLoaded(modelName)
    close_system(modelName, 0);
end

new_system(modelName);
cleanup = onCleanup(@() close_system(modelName, 0));

add_block('simulink/Sources/Constant', [modelName '/u'], ...
    'Value', '0', 'Position', [40 78 70 102]);
add_block('simulink/User-Defined Functions/S-Function', [modelName '/mj_sfun'], ...
    'Position', [150 40 300 180]);

params = sprintf(['''%s'', ''None'', 0, 0, 0, 0, 0, 30, ', ...
    '0.033333333333, 0.002, 1, '''', 0, 0, 0, 0, 0'], xmlPath);
set_param([modelName '/mj_sfun'], 'FunctionName', 'mj_sfun', 'Parameters', params);

for outIdx = 1:4
    termName = sprintf('term%d', outIdx);
    add_block('simulink/Sinks/Terminator', [modelName '/' termName], ...
        'Position', [390 30 + outIdx * 35 420 45 + outIdx * 35]);
end

add_line(modelName, 'u/1', 'mj_sfun/1', 'autorouting', 'on');
for outIdx = 1:4
    add_line(modelName, sprintf('mj_sfun/%d', outIdx), ...
        sprintf('term%d/1', outIdx), 'autorouting', 'on');
end

set_param(modelName, 'StopTime', '0.006', ...
    'SimulationMode', 'normal', 'FastRestart', 'off');
simOut = sim(modelName, 'ReturnWorkspaceOutputs', 'on');
simTime = simOut.tout(:)';
expected = [0 0.002 0.004 0.006];
if numel(simTime) ~= numel(expected) || any(abs(simTime - expected) > 1e-12)
    error('legoSdfSmoke:simTime', 'Unexpected Simulink time vector: %s', mat2str(simTime));
end
end

function [mujocoRoot, mujocoBin] = localRuntimeFromPluginDir(pluginDir, mujocoRoot)
if isempty(mujocoRoot)
    mujocoBin = fileparts(pluginDir);
    mujocoRoot = fileparts(mujocoBin);
else
    mujocoBin = fullfile(mujocoRoot, 'bin');
end

if ~isfile(fullfile(mujocoBin, 'mujoco.dll')) && ispc
    error('legoSdfSmoke:missingMujocoDll', 'mujoco.dll not found under: %s', mujocoBin);
end
end

function localEnsureMexRuntimeDlls(repoRoot, mujocoRoot)
if ~ispc
    return
end

blocksDir = fullfile(repoRoot, 'blocks');
localCopyIfMissing(fullfile(mujocoRoot, 'bin', 'mujoco.dll'), ...
    fullfile(blocksDir, 'mujoco.dll'));

glfwDest = fullfile(blocksDir, 'glfw3.dll');
if isfile(glfwDest)
    return
end

glfwSource = localFindGlfwDll(mujocoRoot);
if isempty(glfwSource)
    error('legoSdfSmoke:missingGlfw', ...
        'glfw3.dll not found. Run install.m or copy glfw3.dll into blocks/.');
end
localCopyIfMissing(glfwSource, glfwDest);
end

function glfwSource = localFindGlfwDll(mujocoRoot)
glfwSource = '';
runtimeRoot = fileparts(fileparts(mujocoRoot));
checkoutRoot = fileparts(runtimeRoot);
candidates = [
    dir(fullfile(runtimeRoot, 'glfw', '**', 'glfw3.dll'))
    dir(fullfile(checkoutRoot, 'blocks', 'glfw3.dll'))
];

if ~isempty(candidates)
    glfwSource = fullfile(candidates(1).folder, candidates(1).name);
end
end

function localCopyIfMissing(sourceFile, destFile)
if isfile(destFile)
    return
end
if ~isfile(sourceFile)
    error('legoSdfSmoke:missingRuntimeFile', 'Runtime file not found: %s', sourceFile);
end
copyfile(sourceFile, destFile, 'f');
end

function libraryName = localPluginLibraryName()
if ispc
    libraryName = 'lego_sdf.dll';
elseif ismac
    libraryName = 'liblego_sdf.dylib';
else
    libraryName = 'liblego_sdf.so';
end
end

function quoted = localQuote(pathText)
quoted = ['"' char(pathText) '"'];
end
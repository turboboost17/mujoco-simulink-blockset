function artifact = build_brick_sdf_plugin(opts)
%BUILD_BRICK_SDF_PLUGIN Build and optionally install the brick SDF MuJoCo plugin.

arguments
    opts.MujocoRoot (1,:) char = ''
    opts.BuildDir (1,:) char = ''
    opts.PluginDir (1,:) char = ''
    opts.Config (1,:) char = 'Release'
    opts.Install (1,1) logical = true
end

repoRoot = fileparts(fileparts(mfilename('fullpath')));
pluginSourceDir = fullfile(repoRoot, 'plugins', 'brick_sdf');

mujocoRoot = opts.MujocoRoot;
if isempty(mujocoRoot)
    mujocoRoot = localFindMujocoRoot(repoRoot);
end

buildDir = opts.BuildDir;
if isempty(buildDir)
    buildDir = fullfile(repoRoot, 'temp', 'build', 'brick_sdf', computer('arch'));
end

pluginDir = opts.PluginDir;
if isempty(pluginDir)
    pluginDir = fullfile(mujocoRoot, 'bin', 'mujoco_plugin');
end

if ~isfolder(mujocoRoot)
    error('brickSdf:missingMujocoRoot', 'MuJoCo root does not exist: %s', mujocoRoot);
end

if ~isfile(fullfile(mujocoRoot, 'include', 'mujoco', 'mujoco.h'))
    error('brickSdf:missingMujocoHeaders', 'MuJoCo headers not found under: %s', mujocoRoot);
end

if ispc
    localBuildWithMsvc(pluginSourceDir, buildDir, mujocoRoot, opts.Config);
else
    configureCmd = sprintf('cmake -S %s -B %s -DMUJOCO_ROOT=%s -DCMAKE_BUILD_TYPE=%s -DBRICK_SDF_BUILD_SMOKE=ON', ...
        localQuote(pluginSourceDir), localQuote(buildDir), localQuote(mujocoRoot), localQuote(opts.Config));
    buildCmd = sprintf('cmake --build %s --config %s', localQuote(buildDir), localQuote(opts.Config));

    localRun(configureCmd);
    localRun(buildCmd);
end

if ispc
    artifact = fullfile(buildDir, opts.Config, 'brick_sdf.dll');
else
    artifact = fullfile(buildDir, 'libbrick_sdf.so');
end

if ~isfile(artifact)
    error('brickSdf:missingArtifact', 'Expected plugin artifact was not built: %s', artifact);
end

if opts.Install
    if ~isfolder(pluginDir)
        mkdir(pluginDir);
    end
    localSafeCopy(artifact, pluginDir);
    artifact = fullfile(pluginDir, localInstalledName(artifact));
end

fprintf('Brick SDF plugin ready: %s\n', artifact);
end

function mujocoRoot = localFindMujocoRoot(repoRoot)
candidate = fullfile(repoRoot, 'lib', computer('arch'), 'mujoco');
if isfolder(candidate)
    mujocoRoot = candidate;
    return
end

if ispref('mujoco', 'linkPaths')
    linkPaths = getpref('mujoco', 'linkPaths');
    for pathIndex = 1:numel(linkPaths)
        libPath = char(linkPaths{pathIndex});
        [parentDir, leafName] = fileparts(libPath);
        if strcmpi(leafName, 'lib') && isfile(fullfile(parentDir, 'include', 'mujoco', 'mujoco.h'))
            mujocoRoot = parentDir;
            return
        end
    end
end

error('brickSdf:noMujocoRoot', ...
    ['Unable to infer MuJoCo root. Run install.m for this checkout or pass ', ...
     'MujocoRoot=".../lib/win64/mujoco".']);
end

function localBuildWithMsvc(pluginSourceDir, buildDir, mujocoRoot, config)
compiler = mex.getCompilerConfigurations('C++', 'Selected');
if isempty(compiler)
    error('brickSdf:noCompiler', 'No selected C++ compiler. Run mex -setup C++ first.');
end

vcvars = fullfile(compiler.Location, 'VC', 'Auxiliary', 'Build', 'vcvars64.bat');
if ~isfile(vcvars)
    error('brickSdf:noVcvars', 'Could not find vcvars64.bat under compiler location: %s', compiler.Location);
end

outputDir = fullfile(buildDir, config);
if ~isfolder(outputDir)
    mkdir(outputDir);
end

includeFlag = ['/I' localQuote(fullfile(mujocoRoot, 'include'))];
libPathFlag = ['/LIBPATH:' localQuote(fullfile(mujocoRoot, 'lib'))];
objectDir = strrep([outputDir filesep], '\', '/');
objectDirFlag = ['/Fo' localQuote(objectDir)];
scriptFile = fullfile(outputDir, 'build_brick_sdf.bat');
fileId = fopen(scriptFile, 'w');
if fileId < 0
    error('brickSdf:buildScriptOpen', 'Could not open build script for writing: %s', scriptFile);
end
cleanup = onCleanup(@() fclose(fileId));
fprintf(fileId, '@echo off\r\n');
fprintf(fileId, 'call "%s" >nul\r\n', vcvars);
fprintf(fileId, 'if errorlevel 1 exit /b %%errorlevel%%\r\n');
fprintf(fileId, 'cl /nologo /LD /EHsc /std:c++17 /O2 %s %s "%s" "%s" /link %s mujoco.lib /OUT:"%s" /IMPLIB:"%s"\r\n', ...
    includeFlag, objectDirFlag, fullfile(pluginSourceDir, 'brick_shape.cc'), ...
    fullfile(pluginSourceDir, 'register.cc'), libPathFlag, ...
    fullfile(outputDir, 'brick_sdf.dll'), fullfile(outputDir, 'brick_sdf.lib'));
fprintf(fileId, 'if errorlevel 1 exit /b %%errorlevel%%\r\n');
fprintf(fileId, 'cl /nologo /EHsc /std:c++17 /O2 %s %s "%s" /link %s mujoco.lib /OUT:"%s"\r\n', ...
    includeFlag, objectDirFlag, fullfile(pluginSourceDir, 'smoke_main.cc'), libPathFlag, ...
    fullfile(outputDir, 'brick_sdf_smoke.exe'));
fprintf(fileId, 'if errorlevel 1 exit /b %%errorlevel%%\r\n');
fprintf(fileId, 'cl /nologo /EHsc /std:c++17 /O2 %s %s "%s" /link %s mujoco.lib /OUT:"%s"\r\n', ...
    includeFlag, objectDirFlag, fullfile(pluginSourceDir, 'stability_main.cc'), libPathFlag, ...
    fullfile(outputDir, 'brick_sdf_stability.exe'));
fprintf(fileId, 'exit /b %%errorlevel%%\r\n');
delete(cleanup);

localRun(localQuote(scriptFile));
end

function localRun(commandText)
fprintf('%s\n', commandText);
[status, output] = system(commandText);
fprintf('%s', output);
if status ~= 0
    error('brickSdf:commandFailed', 'Command failed with status %d: %s', status, commandText);
end
end

function quoted = localQuote(pathText)
quoted = ['"' char(pathText) '"'];
end

function localSafeCopy(srcFile, destDir)
[~, fileName, fileExt] = fileparts(srcFile);
destFile = fullfile(destDir, [fileName fileExt]);
try
    copyfile(srcFile, destFile, 'f');
catch firstError
    if isfile(destFile)
        oldFile = [destFile '.old'];
        if isfile(oldFile)
            stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmssSSS'));
            oldFile = [destFile '.old_' stamp];
        end
        movefile(destFile, oldFile, 'f');
        copyfile(srcFile, destFile, 'f');
    else
        rethrow(firstError);
    end
end
end

function installedName = localInstalledName(srcFile)
[~, fileName, fileExt] = fileparts(srcFile);
installedName = [fileName fileExt];
end
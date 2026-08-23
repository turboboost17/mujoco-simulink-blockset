function makeInfo = rtwmakecfg()
%RTWMAKECFG Declare MuJoCo S-function compile/link info for code generation.
%
% Keep core compile/link declarations in RTW makecfg fields so generated
% makefiles/CMake stay stable across MATLAB upgrades and target toolchains.
% PostCodeGenCommand is reserved for packaging/deployment artifacts only.

    repoRoot = fileparts(fileparts(mfilename('fullpath')));
    srcPathAbs = fullfile(repoRoot, 'src');
    srcPath = localNormalizePath(srcPathAbs);

    makeInfo = struct();
    makeInfo.includePath = {srcPath};
    makeInfo.sourcePath = {srcPath};
    makeInfo.sources = {'mj_sfun.cpp', 'mj.cpp'};
    makeInfo.precompile = 1;
    makeInfo.library = [];
    makeInfo.linkLibsObjs = {};

    toolchain = localGetToolchain();
    if strcmp(toolchain, 'Colcon Tools')
        makeInfo = localConfigureRos2Build(makeInfo, srcPathAbs);
    else
        makeInfo = localConfigureHostBuild(makeInfo);
    end
end

function makeInfo = localConfigureHostBuild(makeInfo)
% Windows/local host toolchains: register installed include + link artifacts.
    if ispref('mujoco', 'incPaths')
        hostInc = localNormalizePaths(getpref('mujoco', 'incPaths'));
        hostInc = cellfun(@localMakeInfoPath, hostInc, 'UniformOutput', false);
        makeInfo.includePath = localUniqueCell([makeInfo.includePath, hostInc]);
    end

    if ~ispref('mujoco', 'linkPaths')
        return
    end

    linkPaths = localNormalizePaths(getpref('mujoco', 'linkPaths'));
    if ispc && numel(linkPaths) >= 2
        candidates = { ...
            localNormalizePath(fullfile(linkPaths{1}, 'glfw3dll.lib')), ...
            localNormalizePath(fullfile(linkPaths{2}, 'mujoco.lib')) ...
        };
    else
        if ~ispref('mujoco', 'MJ_VER') || isempty(linkPaths)
            return
        end
        candidates = {localNormalizePath(fullfile(linkPaths{1}, ...
            ['libmujoco.so.' getpref('mujoco', 'MJ_VER')]))};
    end

    existing = candidates(cellfun(@isfile, candidates));
    makeInfo.linkLibsObjs = localUniqueCell([makeInfo.linkLibsObjs, existing]);
end

function makeInfo = localConfigureRos2Build(makeInfo, srcPathAbs)
% ROS2 toolchain: use target-arch MuJoCo headers/libs via makecfg fields.
    ctx = localResolveRos2Context();

    % Ensure mujoco/*.h is available under src/ so generated include staging
    % can resolve #include <mujoco/...> reliably.
    localMirrorMujocoHeaders(ctx.includePath, srcPathAbs);

    makeInfo.includePath = localUniqueCell([makeInfo.includePath, ...
        {localNormalizePath(ctx.includePath)}]);

    mjSoPath = localNormalizePath(fullfile(ctx.libPath, ctx.mjSoFile));
    if ~isfile(mjSoPath)
        error('mujoco:rtwmakecfg:missingRos2So', ...
            ['Expected ROS2 MuJoCo library not found: %s\n' ...
             'Run install(''ros2'') to refresh MuJoCo target libraries and prefs.'], ...
            mjSoPath);
    end

    localStageRos2Library(mjSoPath, srcPathAbs, ctx.mjSoFile);
    mjSoLinkObj = localNormalizePath(fullfile(srcPathAbs, ctx.mjSoFile));
    systemLibDir = localRos2SystemLibDir(ctx.arch);

    makeInfo.linkLibsObjs = localUniqueCell([makeInfo.linkLibsObjs, ...
        {mjSoLinkObj}]);
    makeInfo.library = struct( ...
        'Name', {'glfw', 'GL'}, ...
        'Location', {systemLibDir, systemLibDir}, ...
        'Modules', {'', ''});
end

function libDir = localRos2SystemLibDir(arch)
    if strcmp(arch, 'linux-aarch64')
        libDir = '/usr/lib/aarch64-linux-gnu';
    else
        libDir = '/usr/lib/x86_64-linux-gnu';
    end
end

function ctx = localResolveRos2Context()
    if ~ispref('mujoco', 'ros2Paths')
        error('mujoco:rtwmakecfg:noRos2Libs', ...
            ['ROS2 target libraries not found. ' ...
             'Run install(''ros2'') first to download Linux MuJoCo binaries.']);
    end

    ros2Paths = getpref('mujoco', 'ros2Paths');
    arch = localGetRos2TargetArch();
    archKey = strrep(arch, '-', '_');
    if ~isfield(ros2Paths, archKey)
        error('mujoco:rtwmakecfg:archNotFound', ...
            ['MuJoCo libraries for architecture ''%s'' not found. ' ...
             'Run install(''ros2'').'], arch);
    end

    if ~ispref('mujoco', 'MJ_VER')
        error('mujoco:rtwmakecfg:missingVersionPref', ...
            'MuJoCo version preference missing. Run install.m first.');
    end

    archPaths = ros2Paths.(archKey);
    ctx = struct();
    ctx.arch = arch;
    ctx.includePath = archPaths.incPath;
    ctx.libPath = archPaths.libPath;
    ctx.mjSoFile = ['libmujoco.so.' getpref('mujoco', 'MJ_VER')];
end

function arch = localGetRos2TargetArch()
% Detect the ROS2 target architecture with pref override first.
    hasArchPref = ispref('mujoco', 'ros2TargetArch');
    if hasArchPref
        arch = char(getpref('mujoco', 'ros2TargetArch'));
    else
        arch = 'linux-x86_64';
    end

    mdl = localGetCurrentModel();
    if isempty(mdl)
        return
    end

    try
        ctd = get_param(mdl, 'CoderTargetData');
        if ~isfield(ctd, 'BoardParameters') || ...
                ~isfield(ctd.BoardParameters, 'DeviceAddress')
            return
        end

        deviceAddr = string(ctd.BoardParameters.DeviceAddress);
        isLocalTarget = startsWith(deviceAddr, '172.') || ...
            strcmpi(deviceAddr, 'localhost') || strcmp(deviceAddr, '127.0.0.1');
        if isLocalTarget
            arch = 'linux-x86_64';
            return
        end

        if ~hasArchPref
            detectedArch = localDetectRemoteArch(ctd.BoardParameters);
            if ~isempty(detectedArch)
                arch = detectedArch;
            else
                arch = 'linux-aarch64';
            end
        end
    catch
    end
end

function arch = localDetectRemoteArch(boardParameters)
    arch = '';
    try
        ssh = ros.codertarget.internal.ssh2client( ...
            boardParameters.DeviceAddress, ...
            boardParameters.Username, ...
            boardParameters.Password, ...
            boardParameters.SSHPort);
        machine = lower(strtrim(execute(ssh, 'uname -m')));
    catch
        return
    end

    if contains(machine, 'x86_64') || contains(machine, 'amd64')
        arch = 'linux-x86_64';
    elseif contains(machine, 'aarch64') || contains(machine, 'arm64')
        arch = 'linux-aarch64';
    end
end

function toolchain = localGetToolchain()
    toolchain = '';
    mdl = localGetCurrentModel();
    if isempty(mdl)
        return
    end
    try
        toolchain = char(get_param(mdl, 'Toolchain'));
    catch
        toolchain = '';
    end
end

function localMirrorMujocoHeaders(includePath, srcPath)
% Mirror MuJoCo headers into src/mujoco so source-path staging carries them.
    headerDir = fullfile(includePath, 'mujoco');
    if ~isfolder(headerDir)
        return
    end

    headers = dir(fullfile(headerDir, '*.h'));
    if isempty(headers)
        return
    end

    dstDir = fullfile(srcPath, 'mujoco');
    if ~isfolder(dstDir)
        mkdir(dstDir);
    end
    for i = 1:numel(headers)
        copyfile(fullfile(headerDir, headers(i).name), ...
            fullfile(dstDir, headers(i).name), 'f');
    end
end

function paths = localNormalizePaths(paths)
    if ischar(paths)
        paths = {paths};
    elseif isstring(paths)
        paths = cellstr(paths(:));
    end
    paths = cellfun(@localNormalizePath, paths, 'UniformOutput', false);
end

function pathOut = localNormalizePath(pathIn)
    pathOut = strrep(char(pathIn), '\', '/');
end

function vals = localUniqueCell(vals)
    vals = vals(~cellfun(@isempty, vals));
    if isempty(vals)
        return
    end
    vals = unique(vals, 'stable');
end

function mdl = localGetCurrentModel()
    mdl = bdroot;
    if ~isempty(mdl) && ~strcmp(mdl, '0')
        return
    end

    loaded = find_system('SearchDepth', 0, 'Type', 'block_diagram');
    loaded = loaded(~strcmp(loaded, 'simulink'));
    if numel(loaded) == 1
        mdl = loaded{1};
    else
        mdl = '';
    end
end

function localStageRos2Library(mjSoPath, srcPath, mjSoFile)
% Stage the target MuJoCo shared library under src/ for ROS package import.
    stagedPath = fullfile(srcPath, mjSoFile);
    copyfile(mjSoPath, stagedPath, 'f');
end

function pathOut = localMakeInfoPath(pathIn)
% Prefer workspace-relative paths to avoid ROS project-builder path escapes.
    relPath = localRelativeToPwd(pathIn);
    if ~isempty(relPath)
        pathOut = localNormalizePath(relPath);
    else
        pathOut = localNormalizePath(pathIn);
    end
end

function relPath = localRelativeToPwd(targetPath)
    relPath = '';

    [baseRoot, baseParts] = localSplitAbsolutePath(pwd);
    [targetRoot, targetParts] = localSplitAbsolutePath(targetPath);
    if isempty(baseRoot) || isempty(targetRoot) || ~strcmpi(baseRoot, targetRoot)
        return
    end

    maxShared = min(numel(baseParts), numel(targetParts));
    firstDiff = maxShared + 1;
    for i = 1:maxShared
        if ~strcmpi(baseParts{i}, targetParts{i})
            firstDiff = i;
            break
        end
    end

    upCount = numel(baseParts) - firstDiff + 1;
    relParts = [repmat({'..'}, 1, max(0, upCount)), targetParts(firstDiff:end)];
    if isempty(relParts)
        relPath = '.';
    else
        relPath = strjoin(relParts, '/');
    end
end

function [root, parts] = localSplitAbsolutePath(pathIn)
    root = '';
    parts = {};

    pathIn = localNormalizePath(pathIn);
    if numel(pathIn) >= 2 && pathIn(2) == ':'
        root = lower(pathIn(1:2));
        tail = pathIn(3:end);
    elseif startsWith(pathIn, '/')
        root = '/';
        tail = pathIn(2:end);
    else
        return
    end

    if isempty(tail)
        parts = {};
        return
    end

    rawParts = strsplit(tail, '/');
    parts = rawParts(~cellfun(@isempty, rawParts));
end
function mj_postcodegen_grt(buildInfo)
%MJ_POSTCODEGEN_GRT Package MuJoCo runtime artifacts after code generation.
%
% Core compile/link declarations belong in rtwmakecfg. This hook is
% intentionally limited to packaging/deployment artifacts for ROS2 builds.
%
% Copyright 2022-2026 The MathWorks, Inc.

    modelName = buildInfo.ComponentName;
    toolchain = char(get_param(modelName, 'Toolchain'));
    if ~strcmp(toolchain, 'Colcon Tools')
        return
    end

    addRos2PackagingArtifacts(buildInfo);
end

function addRos2PackagingArtifacts(buildInfo)
    modelName = buildInfo.ComponentName;
    buildDir = getCodegenBuildDir(modelName);
    ctx = resolveRos2PackagingContext(modelName);
    packageLibDir = resolveRos2PackageLibDir(modelName);

    % Normalize link-object metadata so ROS package generation avoids fragile
    % ImportedLibs copy behavior on Windows while still producing linker-safe
    % MuJoCo tokens for both local and remote ROS2 builds.
    normalizeRos2LinkObjects(buildInfo, ctx.mjSoFile, packageLibDir);

    srcMjSo = fullfile(ctx.libPath, ctx.mjSoFile);
    dstMjSo = fullfile(buildDir, ctx.mjSoFile);
    dstMjSoLink = fullfile(buildDir, 'libmujoco.so');
    if ~isfile(srcMjSo)
        error('mujoco:postcodegen:missingRos2So', ...
            ['Expected ROS2 MuJoCo library not found: %s\n' ...
             'Run install(''ros2'') to refresh MuJoCo target libraries and prefs.'], ...
            srcMjSo);
    end

    copyfile(srcMjSo, dstMjSo, 'f');
    copyfile(srcMjSo, dstMjSoLink, 'f');
    buildInfo.addNonBuildFiles(normalizeBuildPath(dstMjSo), '', 'Copy');
    buildInfo.addNonBuildFiles(normalizeBuildPath(dstMjSoLink), '', 'Copy');

    bundleMjcfFiles(buildInfo, buildDir);
end

function ctx = resolveRos2PackagingContext(modelName)
    if ~ispref('mujoco', 'ros2Paths')
        error('mujoco:postcodegen:noRos2Libs', ...
            ['ROS2 target libraries not found. ' ...
             'Run install(''ros2'') first to download Linux MuJoCo binaries.']);
    end

    ros2Paths = getpref('mujoco', 'ros2Paths');
    arch = getRos2TargetArch(modelName);
    archKey = strrep(arch, '-', '_');
    if ~isfield(ros2Paths, archKey)
        error('mujoco:postcodegen:archNotFound', ...
            ['MuJoCo libraries for architecture ''%s'' not found. ' ...
             'Run install(''ros2'').'], arch);
    end
    if ~ispref('mujoco', 'MJ_VER')
        error('mujoco:postcodegen:missingVersionPref', ...
            'MuJoCo version preference missing. Run install.m first.');
    end

    archPaths = ros2Paths.(archKey);
    ctx = struct();
    ctx.arch = arch;
    ctx.libPath = archPaths.libPath;
    ctx.mjSoFile = ['libmujoco.so.' getpref('mujoco', 'MJ_VER')];
end

function xmlFiles = bundleMjcfFiles(buildInfo, buildDir)
% Copy MJCF XML files referenced by MuJoCo Plant blocks into build output.
    xmlFiles = {};
    modelName = buildInfo.ComponentName;
    mjBlocks = find_system(modelName, 'LookUnderMasks', 'all', ...
        'FollowLinks', 'on', 'MaskType', 'MuJoCo Plant');
    if isempty(mjBlocks)
        return
    end

    for i = 1:numel(mjBlocks)
        xmlPath = get_param(mjBlocks{i}, 'xmlFile');
        if isempty(xmlPath) || ~isfile(xmlPath)
            continue
        end

        [~, xmlName, xmlExt] = fileparts(xmlPath);
        xmlFileName = [xmlName, xmlExt];
        destFile = fullfile(buildDir, xmlFileName);
        if ~isfile(destFile)
            copyfile(xmlPath, destFile, 'f');
        end

        buildInfo.addNonBuildFiles(normalizeBuildPath(destFile), '', 'Copy');
        xmlFiles{end+1} = xmlFileName; %#ok<AGROW>
    end
end

function buildDir = getCodegenBuildDir(modelName)
    buildDirName = [modelName '_ert_rtw'];
    [~, currentDirName] = fileparts(pwd);
    if strcmp(currentDirName, buildDirName)
        buildDir = pwd;
    else
        buildDir = fullfile(pwd, buildDirName);
    end
end

function arch = getRos2TargetArch(modelName)
% Detect target architecture with pref override first.
    if ispref('mujoco', 'ros2TargetArch')
        arch = char(getpref('mujoco', 'ros2TargetArch'));
    else
        arch = 'linux-x86_64';
    end

    if ~bdIsLoaded(modelName)
        return
    end

    try
        ctd = get_param(modelName, 'CoderTargetData');
        if isfield(ctd, 'BoardParameters') && isfield(ctd.BoardParameters, 'DeviceAddress')
            deviceAddr = string(ctd.BoardParameters.DeviceAddress);
            isLocalTarget = startsWith(deviceAddr, '172.') || ...
                strcmpi(deviceAddr, 'localhost') || strcmp(deviceAddr, '127.0.0.1');
            if isLocalTarget
                arch = 'linux-x86_64';
            else
                detectedArch = detectRemoteArch(ctd.BoardParameters);
                if ~isempty(detectedArch)
                    arch = detectedArch;
                end
            end
        end
    catch
    end
end

function arch = detectRemoteArch(boardParameters)
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

function pathOut = normalizeBuildPath(pathIn)
% Normalize Windows paths for ROS tooling and generated CMake.
    pathOut = strrep(char(pathIn), '\\', '/');
end

function normalizeRos2LinkObjects(buildInfo, mjSoFile, packageLibDir)
    linkObjs = buildInfo.getLinkObjects();
    if isempty(linkObjs)
        return
    end

    for i = 1:numel(linkObjs)
        name = char(linkObjs(i).Name);
        isMuJoCo = strcmp(name, mjSoFile) || startsWith(name, 'libmujoco.so.');
        if isMuJoCo
            % Keep linker token stable and point search to the ROS package
            % source directory on target (fallback to relative package src).
            linkObjs(i).Name = mjSoFile;
            if ~isempty(packageLibDir)
                linkObjs(i).Path = packageLibDir;
            else
                linkObjs(i).Path = '$(START_DIR)/../src';
            end
            linkObjs(i).Precompiled = true;
            linkObjs(i).LinkOnly = false;
        elseif strcmpi(name, 'glfw') || strcmpi(name, 'GL')
            linkObjs(i).Precompiled = true;
            linkObjs(i).LinkOnly = false;
        end
    end
end

function packageLibDir = resolveRos2PackageLibDir(modelName)
% Resolve target ROS package source dir that contains copied libmujoco.so*.
    packageLibDir = '';
    workspaceDir = '';

    if bdIsLoaded(modelName)
        try
            ctd = get_param(modelName, 'CoderTargetData');
            if isfield(ctd, 'ROS2Install') && isfield(ctd.ROS2Install, 'Workspace')
                workspaceDir = char(ctd.ROS2Install.Workspace);
            end
        catch
        end
    end

    if isempty(workspaceDir) && ispref('ROS_Toolbox_ROS_Device', 'ROS2Workspace')
        workspaceDir = char(getpref('ROS_Toolbox_ROS_Device', 'ROS2Workspace'));
    end
    if isempty(workspaceDir)
        return
    end

    packageName = lower(modelName);
    % ROS ProjectTool normalizes library dirs by stripping one trailing
    % "src" segment; add a sentinel "src" so generated CMake resolves to
    % the actual package source directory that contains libmujoco.so*.
    packageLibDir = normalizeBuildPath(fullfile(workspaceDir, 'src', packageName, 'src', 'src'));
end


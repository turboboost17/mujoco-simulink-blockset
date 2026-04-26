function mj_postcodegen_grt(buildInfo)
% MJ_POSTCODEGEN_GRT Add MuJoCo/GLFW build artifacts to Simulink codegen.
%   Detects the build toolchain and provides platform-appropriate libraries:
%   - Windows (MSVC): links glfw3dll.lib and mujoco.lib
%   - ROS2 (Colcon Tools): bundles libmujoco.so and links system GLFW
% Copyright 2022-2026 The MathWorks, Inc.

    buildInfo.addCompileFlags('-O3 -fPIC', 'OPTS');

    buildInfo.addSourcePaths(normalizeBuildPaths(getpref('mujoco', 'srcPaths')));
    buildInfo.addSourceFiles({'mj_sfun.cpp', 'mj.cpp'});

    modelName = buildInfo.ComponentName;
    toolchain = get_param(modelName, 'Toolchain');
    isRos2Build = strcmp(toolchain, 'Colcon Tools');

    if isRos2Build
        addRos2BuildArtifacts(buildInfo);
    else
        addWindowsBuildArtifacts(buildInfo);
    end
end

function addWindowsBuildArtifacts(buildInfo)
% Add Windows .lib import libraries for local MEX/Simulink builds
    buildInfo.addIncludePaths(normalizeBuildPaths(getpref('mujoco', 'incPaths')));

    linkPaths = normalizeBuildPaths(getpref('mujoco', 'linkPaths'));
    linkObjs = {'glfw3dll.lib', 'mujoco.lib'};
    libPriority = '';
    libPreCompiled = true;
    libLinkOnly = true;
    for i = 1:length(linkObjs)
        buildInfo.addLinkObjects(linkObjs{i}, linkPaths{i}, ...
            libPriority, libPreCompiled, libLinkOnly);
    end
end

function addRos2BuildArtifacts(buildInfo)
% Add Linux shared libraries for ROS2 cross-compilation targets.
% MuJoCo .so is bundled in the deployment archive.
% GLFW is linked from the system package (libglfw3-dev) on the target.

    % Determine target architecture from device address / prefs
    ros2Arch = getRos2TargetArch(buildInfo);

    if ~ispref('mujoco', 'ros2Paths')
        error('mujoco:postcodegen:noRos2Libs', ...
            ['ROS2 target libraries not found. ' ...
             'Run install(''ros2'') first to download Linux MuJoCo binaries.']);
    end

    ros2Paths = getpref('mujoco', 'ros2Paths');
    archKey = strrep(ros2Arch, '-', '_');

    if ~isfield(ros2Paths, archKey)
        error('mujoco:postcodegen:archNotFound', ...
            ['MuJoCo libraries for architecture ''%s'' not found. ' ...
             'Run install(''ros2'') to download them.'], ros2Arch);
    end

    archPaths = ros2Paths.(archKey);

    % Include paths: use the Linux MuJoCo headers + source path
    srcPaths = normalizeBuildPaths(getpref('mujoco', 'srcPaths'));
    ros2IncPaths = {archPaths.incPath, srcPaths{1}};
    buildInfo.addIncludePaths(normalizeBuildPaths(ros2IncPaths));

    % Bundle libmujoco.so from the prefetched Linux binaries
    mjVer = getpref('mujoco', 'MJ_VER');
    mjSoFile = ['libmujoco.so.', mjVer];
    mjSoLinkFile = 'libmujoco.so';
    buildDir = getCodegenBuildDir(buildInfo.ComponentName);
    srcMjSo = fullfile(archPaths.libPath, mjSoFile);
    dstMjSo = fullfile(buildDir, mjSoFile);
    dstMjSoLink = fullfile(buildDir, mjSoLinkFile);
    if ~isfile(srcMjSo)
        error('mujoco:postcodegen:missingRos2So', ...
            ['Expected ROS2 MuJoCo library not found: %s\n' ...
             'Run install(''ros2'') to refresh MuJoCo target libraries and prefs.'], ...
            srcMjSo);
    end
    copyfile(srcMjSo, dstMjSo, 'f');
    copyfile(srcMjSo, dstMjSoLink, 'f');

    if isRos2RemoteBuild(buildInfo.ComponentName)
        libPreCompiled = true;
        libLinkOnly = true;
        buildInfo.addLinkObjects(mjSoFile, archPaths.libPath, '', ...
            libPreCompiled, libLinkOnly);
    else
        buildInfo.addNonBuildFiles(normalizeBuildPath(dstMjSo), '', 'Copy');
        buildInfo.addNonBuildFiles(normalizeBuildPath(dstMjSoLink), '', 'Copy');
        buildInfo.addSysLibPaths(normalizeBuildPath(buildDir));
        buildInfo.addSysLibs('mujoco', normalizeBuildPath(buildDir));
        buildInfo.addLinkFlags('-L${PROJECT_SOURCE_DIR}/src');
        buildInfo.addLinkFlags('-lmujoco');
    end

    % Link GLFW from system package (libglfw3-dev must be installed on target)
    buildInfo.addLinkFlags('-lglfw');

    % Link OpenGL (required by MuJoCo rendering)
    buildInfo.addLinkFlags('-lGL');

    % Bundle MJCF XML model files referenced by MuJoCo Plant blocks
    xmlFiles = bundleMjcfFiles(buildInfo);

    % Patch CMakeLists.txt to install runtime assets into the ROS package.
    patchRos2CMakeLists(buildInfo, {mjSoFile, mjSoLinkFile}, xmlFiles);
end

function xmlFiles = bundleMjcfFiles(buildInfo)
% Copy MJCF XML files referenced by MuJoCo Plant blocks into the build
% directory so they are included in the deployment archive.
    xmlFiles = {};
    modelName = buildInfo.ComponentName;
    mjBlocks = find_system(modelName, 'LookUnderMasks', 'all', ...
        'FollowLinks', 'on', 'MaskType', 'MuJoCo Plant');

    if isempty(mjBlocks)
        return
    end

    buildDir = getCodegenBuildDir(modelName);

    for i = 1:numel(mjBlocks)
        xmlPath = get_param(mjBlocks{i}, 'xmlFile');
        if isempty(xmlPath) || ~isfile(xmlPath)
            continue
        end
        [~, xmlName, xmlExt] = fileparts(xmlPath);
        xmlFileName = [xmlName, xmlExt];
        destFile = fullfile(buildDir, xmlFileName);
        if ~isfile(destFile)
            copyfile(xmlPath, destFile);
        end
        buildInfo.addNonBuildFiles(normalizeBuildPath(destFile), '', 'Copy');
        xmlFiles{end+1} = xmlFileName; %#ok<AGROW>
    end
end

function patchRos2CMakeLists(buildInfo, mjSoFiles, xmlFiles)
% Patch generated CMakeLists.txt so colcon installs runtime assets.
    modelName = buildInfo.ComponentName;
    packageName = lower(modelName);

    candidates = { ...
        fullfile(pwd, '..', packageName, 'CMakeLists.txt'), ...
        fullfile(pwd, '..', '..', 'src', packageName, 'CMakeLists.txt'), ...
        fullfile(pwd, '..', 'src', packageName, 'CMakeLists.txt') ...
    };

    existingFiles = candidates(cellfun(@isfile, candidates));
    existingFiles = unique(existingFiles, 'stable');

    if isempty(existingFiles)
        warning('mujoco:postcodegen:noCMakeLists', ...
            'Could not find CMakeLists.txt to patch install rules for %s.', ...
            packageName);
        return
    end

    rules = sprintf('\n# MuJoCo install rules (auto-generated by mj_postcodegen_grt)\n');
    for i = 1:numel(mjSoFiles)
        rules = [rules, sprintf( ...
            'install(FILES ${PROJECT_SOURCE_DIR}/src/%s DESTINATION lib)\n', ...
            mjSoFiles{i})]; %#ok<AGROW>
    end
    for i = 1:numel(xmlFiles)
        rules = [rules, sprintf( ...
            'install(FILES ${PROJECT_SOURCE_DIR}/src/%s DESTINATION lib/${PROJECT_NAME})\n', ...
            xmlFiles{i})]; %#ok<AGROW>
    end

    for i = 1:numel(existingFiles)
        cmakeFile = existingFiles{i};
        txt = fileread(cmakeFile);
        if contains(txt, '# MuJoCo install rules')
            continue
        end

        txt = strrep(txt, 'ament_package()', [rules, 'ament_package()']);
        fid = fopen(cmakeFile, 'w');
        if fid < 0
            warning('mujoco:postcodegen:cmakeOpenFailed', ...
                'Could not open %s to add MuJoCo install rules.', cmakeFile);
            continue
        end
        cleanup = onCleanup(@() fclose(fid));
        fprintf(fid, '%s', txt);
        delete(cleanup);
        fprintf('Patched %s with MuJoCo install rules.\n', cmakeFile);
    end
end

function arch = getRos2TargetArch(buildInfo)
% Detect the ROS2 target device architecture.
% Returns 'linux-aarch64' or 'linux-x86_64'.
%
% Detection order:
%   1. Explicit mujoco pref 'ros2TargetArch' (user override)
%   2. SSH to target device via CoderTargetData.BoardParameters.DeviceAddress
%   3. Default: 'linux-x86_64' (WSL2/localhost) or 'linux-aarch64' (remote)

    % 1. Check explicit override
    if ispref('mujoco', 'ros2TargetArch')
        arch = getpref('mujoco', 'ros2TargetArch');
        return
    end

    % 2. Try to detect from target device address
    arch = 'linux-x86_64'; % safe default (WSL2 / local Docker)
    try
        modelName = buildInfo.ComponentName;
        ctd = get_param(modelName, 'CoderTargetData');
        deviceAddr = ctd.BoardParameters.DeviceAddress;

        % Heuristic: if address is a WSL2 / localhost range, assume x86_64
        isLocalTarget = startsWith(deviceAddr, '172.') || ...
                        strcmp(deviceAddr, 'localhost') || ...
                        strcmp(deviceAddr, '127.0.0.1');
        if ~isLocalTarget
            % Remote device: default to aarch64 (Pi/Jetson are most common)
            arch = 'linux-aarch64';
        end
    catch
        % Fall through to default
    end

    % 3. Validate against available architectures
    if ispref('mujoco', 'ros2Archs')
        archs = getpref('mujoco', 'ros2Archs');
        if ~any(strcmp(archs, arch))
            % Requested arch not available; use whatever IS available
            if ~isempty(archs)
                arch = archs{1};
            end
        end
    end
end

function buildDir = getCodegenBuildDir(modelName)
    buildDirName = [modelName, '_ert_rtw'];
    [~, currentDirName] = fileparts(pwd);
    if strcmp(currentDirName, buildDirName)
        buildDir = pwd;
    else
        buildDir = fullfile(pwd, buildDirName);
    end
end

function tf = isRos2RemoteBuild(modelName)
    tf = false;
    try
        ctd = get_param(modelName, 'CoderTargetData');
        if isfield(ctd, 'ROS') && isfield(ctd.ROS, 'RemoteBuild')
            tf = logical(ctd.ROS.RemoteBuild);
        end
    catch
    end
end

function paths = normalizeBuildPaths(paths)
% Convert Windows backslashes before paths enter codegen/ROS packaging.
% Some downstream ROS ProjectBuilder code formats file paths through sprintf;
% a path like E:\Documents then triggers invalid escape warnings (\D) and
% broken globbing. MATLAB, MSVC, CMake, and Colcon all accept forward slashes
% on Windows.
    if ischar(paths) || isstring(paths)
        paths = {char(paths)};
    end
    paths = cellfun(@normalizeBuildPath, paths, 'UniformOutput', false);
end

function pathOut = normalizeBuildPath(pathIn)
    pathOut = strrep(char(pathIn), '\', '/');
end
function mj_postcodegen_grt(buildInfo)
% MJ_POSTCODEGEN_GRT Add MuJoCo/GLFW build artifacts to Simulink codegen.
%   Detects the build toolchain and provides platform-appropriate libraries:
%   - Windows (MSVC): links glfw3dll.lib and mujoco.lib
%   - ROS2 (Colcon Tools): bundles libmujoco.so and links system GLFW
% Copyright 2022-2026 The MathWorks, Inc.

    buildInfo.addCompileFlags('-O3 -fPIC', 'OPTS');

    buildInfo.addSourcePaths(getpref('mujoco', 'srcPaths'));
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
    buildInfo.addIncludePaths(getpref('mujoco', 'incPaths'));

    linkPaths = getpref('mujoco', 'linkPaths');
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

    % Determine target architecture from ROS2 device or default to x86_64
    ros2Arch = getRos2TargetArch();

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
    srcPaths = getpref('mujoco', 'srcPaths');
    ros2IncPaths = {archPaths.incPath, srcPaths{1}};
    buildInfo.addIncludePaths(ros2IncPaths);

    % Bundle libmujoco.so from the prefetched Linux binaries
    mjVer = getpref('mujoco', 'MJ_VER');
    mjSoFile = ['libmujoco.so.', mjVer];
    libPreCompiled = true;
    libLinkOnly = true;
    buildInfo.addLinkObjects(mjSoFile, archPaths.libPath, ...
        '', libPreCompiled, libLinkOnly);

    % Link GLFW from system package (libglfw3-dev must be installed on target)
    buildInfo.addLinkFlags('-lglfw');

    % Link OpenGL (required by MuJoCo rendering)
    buildInfo.addLinkFlags('-lGL');
end

function arch = getRos2TargetArch()
% Detect the ROS2 target device architecture.
% Returns 'linux-aarch64' or 'linux-x86_64'.
    arch = 'linux-x86_64';

    try
        % Attempt to detect from MATLAB ROS2 device preferences
        if ispref('mujoco', 'ros2Archs')
            archs = getpref('mujoco', 'ros2Archs');
            % Default to aarch64 if available (common for Raspberry Pi / Jetson)
            if any(strcmp(archs, 'linux-aarch64'))
                arch = 'linux-aarch64';
            end
        end
    catch
        % Fall through to default
    end
end
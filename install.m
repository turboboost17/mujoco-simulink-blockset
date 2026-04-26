function install(target)
% INSTALL Download MuJoCo and GLFW libraries for local MEX build and
%   optionally for ROS2 cross-compilation targets.
%
%   install()        - Download libraries for the current platform (Windows/Linux)
%   install('ros2')  - Also download Linux aarch64 MuJoCo for ROS2 deployment

%% Run this script once and follow the instructions
% Make sure you run this script from this folder.

arguments
    target {mustBeMember(target, {'', 'ros2'})} = ''
end

MJ_VER = '3.7.0';
GLFW_VER = '3.3.7';
urlsList = fileread("tools/links.json");
blockPath = './blocks/';
examplePath = './examples/';
srcPath = './src/';

glfwRunTimeLib = 'lib-static-ucrt';
% Universal C Run Time (UCRT) is installed in windows 10 or beyond by
% default

%% DOWNLOAD MUJOCO
clear mex %#ok<CLMEX>
mjPath = downloader(urlsList, "mujoco", MJ_VER);
if ~ispc
    folder = fullfile(mjPath, ['mujoco-', MJ_VER]);
    copyfile(fullfile(folder, '*'), mjPath);
    rmdir(folder, 's');
end

%% DOWNLOAD GLFW
if ispc
    glfwTopPath = downloader(urlsList, "glfw", GLFW_VER);
end

%% MATLAB PATH ADDITION
addpath(blockPath);
addpath(examplePath);
savepath
disp(' ')
disp("MuJoCo block library and examples added to MATLAB path and saved");

%% SHARED LIB COPY PATH ADDITION
% Alternatively you can add the dll location to system path
mujocoIncPath = fullfile(mjPath, 'include');
mujocoImportLibPath = fullfile(mjPath, 'lib');

if ispc
    mujocoDll = fullfile(mjPath, 'bin', 'mujoco.dll');
    safeCopyDll(mujocoDll, blockPath);

    glfwPath = fullfile(glfwTopPath, ['glfw-', GLFW_VER, '.bin.WIN64']);
    glfwIncPath = fullfile(glfwPath, 'include');
    glfwImportLibPath = fullfile(glfwPath, glfwRunTimeLib);

    glfwDll = fullfile(glfwImportLibPath, 'glfw3.dll');
    safeCopyDll(glfwDll, blockPath);
else
    mjSo = fullfile(mjPath, 'lib', ['libmujoco.so.', MJ_VER]);
    copyfile(mjSo, blockPath);
    ensureLinuxLibmujocoSymlink(fullfile(mjPath, 'lib'), MJ_VER);
end

%% Path (MATLAB)
addpath(srcPath);
addpath(mujocoIncPath);
if ispc
    addpath(glfwIncPath);
    linkPaths = {glfwImportLibPath, mujocoImportLibPath};
    incPaths = {mujocoIncPath, fullfile(pwd, srcPath), glfwIncPath};
else
    linkPaths = {mujocoImportLibPath};
    incPaths = {mujocoIncPath, fullfile(pwd, srcPath)};
end
savepath

%% MEX Build configuration
if ispref('mujoco')
    rmpref('mujoco');
end

addpref('mujoco', 'MJ_VER', MJ_VER);
addpref('mujoco', 'linkPaths', linkPaths);
addpref('mujoco', 'incPaths', incPaths);
addpref('mujoco', 'srcPaths', {fullfile(pwd, srcPath)});
if ispc
    addpref('mujoco', 'glfwIncPath', glfwIncPath);
    addpref('mujoco', 'glfwImportLibPath', glfwImportLibPath);
end

%% ROS2 TARGET PREFETCH
% Download Linux MuJoCo for cross-compilation to ROS2 targets.
% Both x86_64 and aarch64 are downloaded so the correct library is
% available regardless of the ROS2 target architecture.
% GLFW on Linux is provided by the system package (libglfw3-dev).
if strcmp(target, 'ros2')
    ros2Archs = {'linux-x86_64', 'linux-aarch64'};
    ros2Prefs = struct();

    for archIdx = 1:length(ros2Archs)
        ros2Arch = ros2Archs{archIdx};
        disp(' ')
        disp("=== Downloading MuJoCo for ROS2 target (" + ros2Arch + ") ===");

        ros2MjPath = downloadForArch(urlsList, "mujoco", MJ_VER, ros2Arch);

        % Flatten extracted directory (tar.gz extracts into a versioned subfolder)
        ros2MjSubfolder = fullfile(ros2MjPath, ['mujoco-', MJ_VER]);
        if isfolder(ros2MjSubfolder)
            copyfile(fullfile(ros2MjSubfolder, '*'), ros2MjPath);
            rmdir(ros2MjSubfolder, 's');
        end

        ros2MjIncPath = fullfile(ros2MjPath, 'include');
        ros2MjLibPath = fullfile(ros2MjPath, 'lib');

        % Recreate libmujoco.so -> libmujoco.so.<MJ_VER> symlink for the
        % cross-compile target. Windows tar.exe drops symlinks silently,
        % so without this the generated ROS2 node fails to dlopen
        % "libmujoco.so" on Linux/aarch64 hosts.
        ensureLinuxLibmujocoSymlink(ros2MjLibPath, MJ_VER);

        % Store per-architecture paths for preference saving
        ros2Prefs.(strrep(ros2Arch, '-', '_')).incPath = ros2MjIncPath;
        ros2Prefs.(strrep(ros2Arch, '-', '_')).libPath = ros2MjLibPath;
        ros2Prefs.(strrep(ros2Arch, '-', '_')).mjPath  = ros2MjPath;

        disp("  Installed to: " + ros2MjPath);
    end

    % Save ROS2 target-specific build preferences (both architectures)
    ros2PrefNames = {'ros2Archs', 'ros2Paths', 'ros2SrcPaths'};
    for k = 1:length(ros2PrefNames)
        if ispref('mujoco', ros2PrefNames{k})
            rmpref('mujoco', ros2PrefNames{k});
        end
    end
    addpref('mujoco', 'ros2Archs', ros2Archs);
    addpref('mujoco', 'ros2Paths', ros2Prefs);
    addpref('mujoco', 'ros2SrcPaths', {fullfile(pwd, srcPath)});

    disp(' ')
    disp("ROS2 MuJoCo libraries installed for architectures:");
    for archIdx = 1:length(ros2Archs)
        archKey = strrep(ros2Archs{archIdx}, '-', '_');
        disp("  " + ros2Archs{archIdx} + ": " + ros2Prefs.(archKey).libPath);
    end
    disp(' ')
    disp("Ensure the ROS2 target has libglfw3-dev installed:");
    disp("  sudo apt install libglfw3-dev libgl-dev");
end

%% Local functions
    function downloadfolder = downloader(urlsList, name, version)
    % Download library for the current MATLAB platform architecture
        downloadfolder = downloadForArch(urlsList, name, version, computer('arch'));
    end

    function downloadfolder = downloadForArch(urlsList, name, version, arch)
    % Download library for a specified architecture
        libraryFolder = 'lib';
        downloadfolder = fullfile(pwd, libraryFolder, arch, name);
        urlJson = jsondecode(urlsList);
        downloadLink = '';
        for i = 1:length(urlJson.files)
            obj = urlJson.files(i);
            if strcmp(obj.name, name) && strcmp(obj.version, version) && strcmp(obj.arch, arch)
                downloadLink = obj.downloadLink;
            end
        end

        if isempty(downloadLink)
            error('mujoco:install:noDownloadLink', ...
                'No download link found for %s v%s arch=%s in tools/links.json', ...
                name, version, arch);
        end

        disp(' ')
        disp('Download URL is:');
        disp(downloadLink);

        if isfolder(downloadfolder)
            disp(' ')
            disp('folder exists already. it will be overwritten');
        end

        [~, ~, ext] = fileparts(downloadLink);
        downloadFile = fullfile(libraryFolder, strcat('download_', arch, ext));
        mkdir(libraryFolder);
        websave(downloadFile, downloadLink);
        if strcmp(ext, '.zip')
            unzip(downloadFile, downloadfolder);
        elseif strcmp(ext, '.gz')
            untar(downloadFile, downloadfolder);
        else
            error('mujoco:install:unknownExtension', ...
                'Unknown extension %s. Unable to extract archive.', ext);
        end
        disp(' ')
        disp(name + " downloaded and extracted to this path:");
        disp(downloadfolder)
    end
end

function ensureLinuxLibmujocoSymlink(libDir, mjVer)
%ENSURELINUXLIBMUJOCOSYMLINK Recreate libmujoco.so -> libmujoco.so.X.Y.Z.
%
% Windows tar.exe silently fails to create symlinks when extracting Linux
% .tar.gz archives, so the libmujoco.so soname symlink is missing after
% download on a Windows host (and after re-extraction on Linux too if the
% archive was repacked on Windows). Without this link, runtime dlopen of
% "libmujoco.so" fails on Linux/WSL/arm64 deploy targets.
%
%   libDir : absolute path to ...lib/<arch>/mujoco/lib
%   mjVer  : MuJoCo version string (e.g. '3.7.0')
%
% On Windows we write a tiny shell script next to the archive describing
% the link the user (or the cross-compile target) must materialize. On
% Linux we create the symlink directly.

    target = ['libmujoco.so.', mjVer];
    linkName = fullfile(libDir, 'libmujoco.so');
    targetPath = fullfile(libDir, target);

    if ~isfile(targetPath)
        warning('mujoco:install:missingSo', ...
            'Expected %s not found; skipping symlink creation.', targetPath);
        return;
    end

    if isunix
        % Native Linux/macOS: create symlink directly.
        if isfile(linkName)
            try
                delete(linkName);
            catch
            end
        end
        cmd = sprintf('ln -sf "%s" "%s"', target, linkName);
        [status, out] = system(cmd);
        if status ~= 0
            warning('mujoco:install:lnFailed', ...
                'ln -sf failed (%d): %s', status, strtrim(out));
        end
    else
        % Windows: drop a small POSIX script next to the lib so the
        % deploy step (or a WSL preflight) can materialize the link on
        % the target file system. Idempotent; safe to re-run.
        scriptPath = fullfile(libDir, 'create_libmujoco_symlink.sh');
        fid = fopen(scriptPath, 'w');
        if fid < 0
            warning('mujoco:install:scriptOpen', ...
                'Could not create %s', scriptPath);
            return;
        end
        cleanup = onCleanup(@() fclose(fid));
        fprintf(fid, '#!/bin/sh\n');
        fprintf(fid, '# Auto-generated by install.m -- recreates the libmujoco.so soname\n');
        fprintf(fid, '# symlink that Windows tar.exe drops when extracting MuJoCo Linux\n');
        fprintf(fid, '# archives. Run this on the Linux/WSL/arm64 host before colcon build.\n');
        fprintf(fid, 'set -eu\n');
        fprintf(fid, 'cd "$(dirname "$0")"\n');
        fprintf(fid, 'ln -sf %s libmujoco.so\n', target);
        fprintf(fid, 'echo "Created libmujoco.so -> %s"\n', target);
        clear cleanup
        % Try WSL passthrough so Windows users get the link on the
        % Linux subsystem too. Best-effort, non-fatal.
        wslLibDir = winPathToWsl(libDir);
        if ~isempty(wslLibDir)
            cmd = sprintf('wsl -e sh -c "cd ''%s'' && ln -sf %s libmujoco.so" 2>nul', ...
                wslLibDir, target);
            [status, ~] = system(cmd);
            if status == 0
                disp("  WSL symlink created: " + wslLibDir + "/libmujoco.so -> " + target);
            end
        end
    end
end

function wslPath = winPathToWsl(winPath)
%WINPATHTOWSL Convert C:\Foo\Bar to /mnt/c/Foo/Bar (best effort).
    wslPath = '';
    if numel(winPath) < 3 || winPath(2) ~= ':'
        return;
    end
    drive = lower(winPath(1));
    rest = strrep(winPath(3:end), '\', '/');
    wslPath = ['/mnt/', drive, rest];
end

function safeCopyDll(srcFile, destDir)
%SAFECOPYDLL Copy a DLL into destDir, tolerating a locked destination.
%
% Windows refuses to overwrite a DLL while another process (typically
% another MATLAB instance with mj_sfun loaded) has it mapped. But it
% *does* allow renaming the locked file. So: rename the existing copy
% aside with a unique .old_* suffix, then copy the new file into place.
% The .old_* file is harmless and ignored by .gitignore; it can be
% removed after all MATLAB sessions release the mex.
    [~, name, ext] = fileparts(srcFile);
    destFile = fullfile(destDir, [name, ext]);
    if isfile(destFile)
        stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss_SSS'));
        oldFile = [destFile, '.old_', stamp];
        try
            movefile(destFile, oldFile, 'f');
        catch ME
            error('mujoco:install:dllLocked', ...
                ['Could not move locked destination DLL aside: %s\n' ...
                 'Close MATLAB/Simulink sessions using this DLL or run clear mex there, then retry.\n' ...
                 'Original error: %s'], destFile, ME.message);
        end
    end
    copyfile(srcFile, destDir, 'f');
end

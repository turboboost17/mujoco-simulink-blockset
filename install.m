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
    copyfile(mujocoDll, blockPath);

    glfwPath = fullfile(glfwTopPath, ['glfw-', GLFW_VER, '.bin.WIN64']);
    glfwIncPath = fullfile(glfwPath, 'include');
    glfwImportLibPath = fullfile(glfwPath, glfwRunTimeLib);

    glfwDll = fullfile(glfwImportLibPath, 'glfw3.dll');
    copyfile(glfwDll, blockPath);
else
    mjSo = fullfile(mjPath, 'lib', ['libmujoco.so.', MJ_VER]);
    copyfile(mjSo, blockPath);
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

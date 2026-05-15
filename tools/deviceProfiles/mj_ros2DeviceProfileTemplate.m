function cfg = mj_ros2DeviceProfileTemplate(templateName)
%MJ_ROS2DEVICEPROFILETEMPLATE Return a fill-in ROS 2 device profile template.
%
%   CFG = MJ_ROS2DEVICEPROFILETEMPLATE() returns a remote x86_64 Humble
%   template. Edit the fields marked with <...>, then pass CFG to
%   MJ_CREATEDEVICEPROFILEFROMTEMPLATE.
%
%   CFG = MJ_ROS2DEVICEPROFILETEMPLATE(NAME) returns one of:
%       "ubuntu-2204-x64-ros2humble"  Native/remote Ubuntu 22.04 x86_64 + Humble
%       "raspi-arm64-ros2jazzy"       Remote Ubuntu 24.04 aarch64 + Jazzy
%       "wsl-x64-ros2humble"          WSL2 Ubuntu 22.04 x86_64 + Humble
%
%   The legacy aliases "remote-x64-humble", "remote-arm64-jazzy", and
%   "wsl-x64-humble" are also accepted.
%
%   Example:
%       cfg = mj_ros2DeviceProfileTemplate("remote-x64-humble");
%       cfg.ProfileName = "lab-ubuntu-x64-ros2humble";
%       cfg.ROS2DevicePrefs.Hostname = "lab-ubuntu";
%       cfg.ROS2DevicePrefs.Username = "robot";
%       cfg.ROS2DevicePrefs.Password = "";
%       cfg.ROS2DevicePrefs.ROS2Workspace = "/home/robot/ros2_ws/mj";
%       mj_createDeviceProfileFromTemplate(cfg);
%
%   See also mj_createDeviceProfileFromTemplate, mj_saveDeviceProfile.

%   Copyright 2026 The MathWorks, Inc. (workflow helper)

arguments
    templateName (1,1) string = "remote-x64-humble"
end

templateName = lower(templateName);
cfg = localBaseTemplate();

switch templateName
    case {"ubuntu-2204-x64-ros2humble", "remote-x64-humble"}
        cfg.ProfileName = "ubuntu-2204-x64-ros2humble";
        cfg.Description = "Remote Ubuntu 22.04 x86_64 + ROS 2 Humble";
        cfg.TargetArch = "linux-x86_64";
        cfg.ROS2DevicePrefs.ROS2Install = "/opt/ros/humble";
        cfg.ModelConfig.RemoteBuild = true;
        cfg.ModelConfig.ProdHWDeviceType = "Intel->x86-64 (Linux 64)";
        cfg.ModelConfig.TargetHWDeviceType = "Intel->x86-64 (Linux 64)";

    case {"raspi-arm64-ros2jazzy", "remote-arm64-jazzy"}
        cfg.ProfileName = "raspi-arm64-ros2jazzy";
        cfg.Description = "Remote Ubuntu 24.04 aarch64 + ROS 2 Jazzy";
        cfg.TargetArch = "linux-aarch64";
        cfg.ROS2DevicePrefs.ROS2Install = "/opt/ros/jazzy";
        cfg.ModelConfig.RemoteBuild = true;
        cfg.ModelConfig.ProdHWDeviceType = "ARM Compatible->ARM Cortex-A (64-bit)";
        cfg.ModelConfig.TargetHWDeviceType = "ARM Compatible->ARM Cortex-A (64-bit)";

    case {"wsl-x64-ros2humble", "wsl-x64-humble"}
        cfg.ProfileName = "wsl-x64-ros2humble";
        cfg.Description = "WSL2 Ubuntu 22.04 x86_64 + ROS 2 Humble";
        cfg.TargetArch = "linux-x86_64";
        cfg.ROS2DevicePrefs.Hostname = "localhost";
        cfg.ROS2DevicePrefs.ROS2Install = "/opt/ros/humble";
        cfg.ModelConfig.RemoteBuild = false;
        cfg.ModelConfig.ProdHWDeviceType = "Intel->x86-64 (Linux 64)";
        cfg.ModelConfig.TargetHWDeviceType = "Intel->x86-64 (Linux 64)";

    otherwise
        error('mj_ros2DeviceProfileTemplate:UnknownTemplate', ...
            ['Unknown template "%s". Use "ubuntu-2204-x64-ros2humble", ' ...
             '"raspi-arm64-ros2jazzy", or "wsl-x64-ros2humble".'], templateName);
end

cfg.MuJoCoPrefs.ros2TargetArch = cfg.TargetArch;
cfg.TemplateFile = cfg.ProfileName + ".template.mat";
end

function cfg = localBaseTemplate()
profileDir = string(fileparts(mfilename('fullpath')));

cfg = struct();
cfg.SchemaVersion = 1;
cfg.ProfileName = "<profile-name>";
cfg.Description = "";
cfg.Model = "mj_monitorTune_ROS";
cfg.Destination = profileDir;
cfg.TargetArch = "linux-x86_64";

cfg.ROS2DevicePrefs = struct( ...
    'Hostname', "<hostname-or-ip>", ...
    'Username', "<linux-user>", ...
    'Password', "", ...
    'SSHPort', 22, ...
    'ROS2Install', "/opt/ros/humble", ...
    'ROS2Workspace', "/home/<user>/ros2_ws/<node>");

cfg.MuJoCoPrefs = struct( ...
    'ros2TargetArch', cfg.TargetArch);

cfg.ModelConfig = struct( ...
    'SystemTargetFile', "ert.tlc", ...
    'HardwareBoard', "Robot Operating System 2 (ROS 2)", ...
    'Toolchain', "Colcon Tools", ...
    'BuildConfiguration', "Faster Runs", ...
    'ProdHWDeviceType', "", ...
    'TargetHWDeviceType', "", ...
    'RuntimeBuildAction', "Build and load", ...
    'RemoteBuild', true, ...
    'GenCodeOnly', "off", ...
    'SimulationMode', "normal", ...
    'ExtMode', "off", ...
    'SupportNonInlinedSFcns', "on");

cfg.BuildRequirements = struct( ...
    'TargetSetupScript', "tools/setup_ros2_target.sh", ...
    'MATLABInstallCommand', "install('ros2')", ...
    'AptPackages', {{'build-essential', 'cmake', 'pkg-config', ...
        'libglfw3-dev', 'libgl-dev'}}, ...
    'RosdepKeys', {{'libglfw3-dev', 'libgl-dev'}}, ...
    'SharedLibraries', {{'libmujoco.so', 'libmujoco.so.<mujoco-version>'}}, ...
    'TLCBuildArtifacts', {{'mj_sfun.cpp', 'mj.cpp', ...
        'libmujoco.so', 'libmujoco.so.<mujoco-version>', 'MJCF XML files'}});

cfg.ModelOverrides = struct();
cfg.ModelOverrides.MuJoCoPlant = struct( ...
    'Path', 'MuJoCo Plant', ...
    'Values', struct('renderingType', 'None'));
end
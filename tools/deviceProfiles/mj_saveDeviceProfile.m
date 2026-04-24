function profilePath = mj_saveDeviceProfile(profileName, opts)
%MJ_SAVEDEVICEPROFILE Snapshot current model + ros2device into a reusable profile.
%
%   PATH = MJ_SAVEDEVICEPROFILE(NAME) captures:
%     * a freestanding copy of the active Simulink.ConfigSet of the current
%       model (or the model in OPTS.Model)
%     * the current ROS Toolbox "ROS_Toolbox_ROS_Device" preferences
%       (ros2device backing store: Hostname, Username, Password,
%        SSHPort, ROS2Install, ROS2Workspace, ...)
%     * optional per-block mask-value overrides (OPTS.ModelOverrides),
%       e.g. MuJoCo Plant renderingType, camera sample time
%
%   and writes them to <deviceProfiles>/<NAME>.mat.
%
%   Name-value arguments (OPTS):
%       Model           char/string, default bdroot
%       Description     char/string, free-text label
%       ModelOverrides  struct, fieldnames = full block paths, values = struct
%                       of MaskName -> string to apply on load
%       Destination     char/string, folder to write to; default is this
%                       function's folder
%
%   See also mj_applyDeviceProfile, ros2device.

%   Copyright 2026 The MathWorks, Inc. (workflow helper)

arguments
    profileName (1,1) string
    opts.Model (1,1) string = string(bdroot)
    opts.Description (1,1) string = ""
    opts.ModelOverrides struct = struct()
    opts.Destination (1,1) string = string(fileparts(mfilename('fullpath')))
end

mdl = char(opts.Model);
if isempty(mdl) || ~bdIsLoaded(mdl)
    error('mj_saveDeviceProfile:ModelNotLoaded', ...
        'Model "%s" is not loaded. Load it first or pass Model="name".', mdl);
end

profile = struct();
profile.Name        = char(profileName);
profile.Description = char(opts.Description);
profile.SavedAt     = datetime('now','TimeZone','local');
profile.SourceModel = mdl;

% --- ConfigSet (freestanding copy of active) ---
active = getActiveConfigSet(mdl);
% Before snapshotting, ensure CoderTargetData (which lives inside the config
% set) agrees with the ROS Toolbox device prefs. Three independent stores —
% ROS2Install.Folder/Workspace, BoardParameters.DeviceAddress, and
% BoardParameters.SSHPort/Username/Password — must stay in sync with
% getpref('ROS_Toolbox_ROS_Device') or deploy hooks will pop the "Configure
% ROS Device" dialog and post-codegen will pick the wrong target arch.
% See skill gotcha G10 and repo memory ros2-deployment-hook-dialog.md.
if ispref('ROS_Toolbox_ROS_Device')
    pTmp = getpref('ROS_Toolbox_ROS_Device');
    ctTmp = get_param(mdl,'CoderTargetData');
    changed = false;
    if isfield(ctTmp,'ROS2Install')
        if ~strcmp(ctTmp.ROS2Install.Folder, pTmp.ROS2Install)
            ctTmp.ROS2Install.Folder = pTmp.ROS2Install; changed = true;
        end
        if ~strcmp(ctTmp.ROS2Install.Workspace, pTmp.ROS2Workspace)
            ctTmp.ROS2Install.Workspace = pTmp.ROS2Workspace; changed = true;
        end
    end
    if isfield(ctTmp,'BoardParameters')
        if isfield(ctTmp.BoardParameters,'DeviceAddress') && ...
                ~strcmp(ctTmp.BoardParameters.DeviceAddress, pTmp.Hostname)
            ctTmp.BoardParameters.DeviceAddress = pTmp.Hostname; changed = true;
        end
        if isfield(ctTmp.BoardParameters,'SSHPort') && ...
                ctTmp.BoardParameters.SSHPort ~= pTmp.SSHPort
            ctTmp.BoardParameters.SSHPort = pTmp.SSHPort; changed = true;
        end
        if isfield(ctTmp.BoardParameters,'Username') && ...
                ~strcmp(ctTmp.BoardParameters.Username, pTmp.Username)
            ctTmp.BoardParameters.Username = pTmp.Username; changed = true;
        end
        if isfield(ctTmp.BoardParameters,'Password') && ...
                ~strcmp(ctTmp.BoardParameters.Password, pTmp.Password)
            ctTmp.BoardParameters.Password = pTmp.Password; changed = true;
        end
    end
    if changed
        set_param(mdl,'CoderTargetData',ctTmp);
        warning('mj_saveDeviceProfile:SyncedCoderTargetData', ...
            'Synced CoderTargetData to ROS_Toolbox_ROS_Device prefs before snapshot.');
        active = getActiveConfigSet(mdl);
    end
end
cs = copy(active);
set_param(cs, 'Name', sprintf('%s_ConfigSet', profile.Name));
profile.ConfigSet = cs;
profile.ConfigSummary = struct( ...
    'HardwareBoard',     get_param(cs,'HardwareBoard'), ...
    'SystemTargetFile',  get_param(cs,'SystemTargetFile'), ...
    'ProdHWDeviceType',  get_param(cs,'ProdHWDeviceType'), ...
    'TargetHWDeviceType',get_param(cs,'TargetHWDeviceType'), ...
    'BuildConfiguration',get_param(cs,'BuildConfiguration'), ...
    'Toolchain',         get_param(cs,'Toolchain'), ...
    'SolverType',        get_param(cs,'SolverType'), ...
    'FixedStep',         get_param(cs,'FixedStep'));

% --- ros2device preferences (complete) ---
if ispref('ROS_Toolbox_ROS_Device')
    profile.ROS2DevicePrefs = getpref('ROS_Toolbox_ROS_Device');
else
    profile.ROS2DevicePrefs = struct();
    warning('mj_saveDeviceProfile:NoROS2Prefs', ...
        'No ROS_Toolbox_ROS_Device preferences found; profile has empty device info.');
end

% --- optional mask-value overrides ---
profile.ModelOverrides = opts.ModelOverrides;

% --- write ---
if ~isfolder(opts.Destination)
    mkdir(opts.Destination);
end
profilePath = fullfile(char(opts.Destination), [profile.Name '.mat']);
save(profilePath, 'profile', '-v7.3');

fprintf('Saved device profile "%s" to %s\n', profile.Name, profilePath);
end

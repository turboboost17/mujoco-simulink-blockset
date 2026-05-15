function info = mj_applyDeviceProfile(profileName, opts)
%MJ_APPLYDEVICEPROFILE Apply a device profile to a model and ros2device.
%
%   INFO = MJ_APPLYDEVICEPROFILE(NAME) loads <deviceProfiles>/<NAME>.mat and:
%     1. Attaches the profile's Simulink.ConfigSet to the current model as
%        a freestanding configuration set and activates it. The model's
%        previous active ConfigSet is detached but kept on disk in
%        <modelDir>/<modelName>_preProfile.mat for rollback.
%     2. Writes ROS2DevicePrefs into the "ROS_Toolbox_ROS_Device"
%        preference group so ros2device() returns the profile's target.
%     3. Writes hardware-specific MuJoCo prefs such as ros2TargetArch.
%     4. Applies mask-value overrides from profile.ModelOverrides.
%
%   Name-value arguments (OPTS):
%       Model            char/string, default bdroot
%       Source           char/string, folder or direct file path. If a
%                        folder, <Source>/<NAME>.mat is loaded. Defaults
%                        to this function's folder.
%       Activate         logical, default true. If false, attach but do
%                        not activate the ConfigSet.
%       ApplyOverrides   logical, default true. If false, skip mask
%                        overrides.
%       UpdatePrefs      logical, default true. If false, do not touch
%                        ROS Toolbox preferences.
%       Save             logical, default false. If true, save the model
%                        after all changes applied.
%
%   OUT INFO: struct with fields
%       ProfilePath, BackupConfigSetPath, AppliedConfigSetName,
%       AppliedPrefs, AppliedMuJoCoPrefs, AppliedOverrides (cellstr of
%       applied block paths)
%
%   See also mj_saveDeviceProfile, ros2device, attachConfigSet,
%            setActiveConfigSet.

%   Copyright 2026 The MathWorks, Inc. (workflow helper)

arguments
    profileName (1,1) string
    opts.Model (1,1) string = string(bdroot)
    opts.Source (1,1) string = string(fileparts(mfilename('fullpath')))
    opts.Activate (1,1) logical = true
    opts.ApplyOverrides (1,1) logical = true
    opts.UpdatePrefs (1,1) logical = true
    opts.Save (1,1) logical = false
    opts.SeedROS2Workspace (1,1) logical = true
end

mdl = char(opts.Model);
if isempty(mdl) || ~bdIsLoaded(mdl)
    error('mj_applyDeviceProfile:ModelNotLoaded', ...
        'Model "%s" is not loaded.', mdl);
end

% Resolve profile file.
src = char(opts.Source);
if isfile(src)
    profilePath = src;
elseif isfolder(src)
    profilePath = fullfile(src, char(profileName) + ".mat");
    if ~isfile(profilePath)
        profilePath = fullfile(src, [char(profileName) '.mat']);
    end
else
    error('mj_applyDeviceProfile:BadSource', ...
        'Source "%s" is neither a file nor a folder.', src);
end
if ~isfile(profilePath)
    templatePath = fullfile(src, [char(profileName) '.template.mat']);
    if isfolder(src) && isfile(templatePath)
        profilePath = templatePath;
    else
        error('mj_applyDeviceProfile:ProfileMissing', ...
            'Profile file not found: %s', profilePath);
    end
end

S = load(profilePath, 'profile');
p = S.profile;
if isfield(p, 'IsTemplate') && p.IsTemplate
    error('mj_applyDeviceProfile:TemplateProfile', ...
        ['%s is a sanitized template, not an applyable device profile. ' ...
         'Create a filled profile with mj_ros2DeviceProfileTemplate and ' ...
         'mj_createDeviceProfileFromTemplate first.'], profilePath);
end

info = struct();
info.ProfilePath = profilePath;

% --- 1) Back up active ConfigSet, attach profile's set ---
modelDir = fileparts(get_param(mdl,'FileName'));
if isempty(modelDir), modelDir = pwd; end
backupPath = fullfile(modelDir, [mdl '_preProfile.mat']);
prevActive = copy(getActiveConfigSet(mdl));
set_param(prevActive, 'Name', [mdl '_preProfile']);
save(backupPath, 'prevActive');
info.BackupConfigSetPath = backupPath;

newCS = copy(p.ConfigSet);
% Avoid name collision with model's current config set(s).
desiredName = get_param(newCS,'Name');
existing = getConfigSets(mdl);
if any(strcmp(existing, desiredName))
    desiredName = matlab.lang.makeUniqueStrings(desiredName, existing);
    set_param(newCS, 'Name', desiredName);
end
attachConfigSet(mdl, newCS, true);
info.AppliedConfigSetName = get_param(newCS,'Name');

if opts.Activate
    setActiveConfigSet(mdl, info.AppliedConfigSetName);
end

% --- 2) ROS Toolbox device preferences ---
info.AppliedPrefs = struct();
if opts.UpdatePrefs && isstruct(p.ROS2DevicePrefs) && ~isempty(fieldnames(p.ROS2DevicePrefs))
    fn = fieldnames(p.ROS2DevicePrefs);
    for i = 1:numel(fn)
        setpref('ROS_Toolbox_ROS_Device', fn{i}, p.ROS2DevicePrefs.(fn{i}));
    end
    info.AppliedPrefs = p.ROS2DevicePrefs;
    if isfield(info.AppliedPrefs,'Password')
        info.AppliedPrefs.Password = '***';
    end
end

% --- 3) MuJoCo hardware preferences ---
info.AppliedMuJoCoPrefs = struct();
if opts.UpdatePrefs && isfield(p, 'MuJoCoPrefs') && isstruct(p.MuJoCoPrefs) && ...
        ~isempty(fieldnames(p.MuJoCoPrefs))
    fn = fieldnames(p.MuJoCoPrefs);
    for i = 1:numel(fn)
        setpref('mujoco', fn{i}, p.MuJoCoPrefs.(fn{i}));
    end
    info.AppliedMuJoCoPrefs = p.MuJoCoPrefs;
end

% --- 4) Mask-value overrides ---
info.AppliedOverrides = {};
if opts.ApplyOverrides && isstruct(p.ModelOverrides)
    blkPaths = fieldnames(p.ModelOverrides);
    for i = 1:numel(blkPaths)
        % Fieldnames can't contain '/' or spaces. Convention:
        %   profile.ModelOverrides is a cell array {blockPath, struct; ...}
        %   stored as struct with an '_entries_' field when necessary.
        % But allow a simple flat struct keyed by makeValidName.
        % To keep this pragmatic, expect profile authors to use
        % profile.ModelOverrides.(makeValidName(blockPath)).Path and .Values.
        entry = p.ModelOverrides.(blkPaths{i});
        if ~isstruct(entry) || ~isfield(entry,'Path') || ~isfield(entry,'Values')
            warning('mj_applyDeviceProfile:BadOverride', ...
                'ModelOverrides.%s is malformed (need .Path and .Values). Skipping.', blkPaths{i});
            continue
        end
        blk = [mdl '/' entry.Path];
        vfn = fieldnames(entry.Values);
        for k = 1:numel(vfn)
            try
                set_param(blk, vfn{k}, entry.Values.(vfn{k}));
            catch ME
                warning('mj_applyDeviceProfile:SetParamFailed', ...
                    'set_param(''%s'', ''%s'', ...) failed: %s', blk, vfn{k}, ME.message);
            end
        end
        info.AppliedOverrides{end+1} = blk;
    end
end

if opts.Save
    save_system(mdl);
end

% --- 4) Optionally seed the ROS 2 workspace over SSH so Simulink's
%        pre-deploy DeviceDiagnostics (which requires <ws>/src AND
%        <ws>/install/setup.bash) does NOT pop the "Configure ROS
%        device" dialog on a fresh or rm -rf'd workspace.  This runs an
%        empty colcon build which creates install/setup.bash without
%        building any packages.  See mcp-server-command-management
%        skill gotchas G10 + G11. ---
info.SeededROS2Workspace = false;
if opts.SeedROS2Workspace && opts.UpdatePrefs && ...
        isfield(p.ROS2DevicePrefs,'Hostname') && ~isempty(p.ROS2DevicePrefs.Hostname)
    try
        dev = p.ROS2DevicePrefs;
        ssh = ros.codertarget.internal.ssh2client(dev.Hostname, ...
            dev.Username, dev.Password, dev.SSHPort);
        checkCmd = sprintf( ...
            'test -f %s/install/setup.bash && echo OK || echo MISSING', ...
            dev.ROS2Workspace);
        status = strtrim(execute(ssh, checkCmd));
        if contains(status, 'MISSING')
            seedCmd = sprintf([ ...
                'mkdir -p %s/src && cd %s && ' ...
                'source %s/setup.bash && ' ...
                'colcon build --paths - 2>&1 | tail -n 5'], ...
                dev.ROS2Workspace, dev.ROS2Workspace, dev.ROS2Install);
            fprintf('  Seeding ROS 2 workspace at %s:%s ...\n', ...
                dev.Hostname, dev.ROS2Workspace);
            disp(execute(ssh, seedCmd));
            info.SeededROS2Workspace = true;
        else
            fprintf('  ROS 2 workspace at %s:%s already initialized (install/setup.bash present).\n', ...
                dev.Hostname, dev.ROS2Workspace);
        end
    catch ME
        warning('mj_applyDeviceProfile:SeedFailed', ...
            'Could not seed ROS 2 workspace: %s', ME.message);
    end
end

fprintf('Applied profile "%s" from %s to model "%s".\n', p.Name, profilePath, mdl);
fprintf('  ConfigSet: %s (active=%d)\n', info.AppliedConfigSetName, opts.Activate);
fprintf('  Prefs updated: %d\n', opts.UpdatePrefs);
fprintf('  Overrides applied: %d\n', numel(info.AppliedOverrides));
fprintf('  Backup of previous config: %s\n', backupPath);
end

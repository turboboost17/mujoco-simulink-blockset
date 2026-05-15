function profilePath = mj_createDeviceProfileFromTemplate(cfg, opts)
%MJ_CREATEDEVICEPROFILEFROMTEMPLATE Create a ROS 2 device profile from CFG.
%
%   PATH = MJ_CREATEDEVICEPROFILEFROMTEMPLATE(CFG) applies the explicit
%   fields from MJ_ROS2DEVICEPROFILETEMPLATE to an open or loadable model,
%   synchronizes ROS Toolbox preferences and CoderTargetData, then snapshots
%   the result with MJ_SAVEDEVICEPROFILE.
%
%   The generated profile includes:
%       * Simulink.ConfigSet for ROS 2 code generation
%       * ROS_Toolbox_ROS_Device prefs used by ros2device
%       * MuJoCo ROS 2 hardware prefs such as ros2TargetArch
%       * build requirements used by generated ROS package patching
%       * optional per-block mask overrides
%
%   Name-value arguments:
%       SaveModel          logical, default false. Save the configured model.
%       VerifyConnection   logical, default false. Call MJ_INITROS2WORKSPACE
%                          after preferences are written.
%       ForceWorkspaceSeed logical, default false. Pass Force=true when
%                          VerifyConnection is enabled.
%       AllowPlaceholders  logical, default false. Keep false for real
%                          profiles; true is only for template export.
%
%   See also mj_ros2DeviceProfileTemplate, mj_saveDeviceProfile,
%            mj_applyDeviceProfile.

%   Copyright 2026 The MathWorks, Inc. (workflow helper)

arguments
    cfg (1,1) struct
    opts.SaveModel (1,1) logical = false
    opts.VerifyConnection (1,1) logical = false
    opts.ForceWorkspaceSeed (1,1) logical = false
    opts.AllowPlaceholders (1,1) logical = false
end

cfg = localNormalizeTemplate(cfg);
localValidateTemplate(cfg, opts.AllowPlaceholders);

modelName = localLoadModel(cfg.Model);
localApplyROS2DevicePrefs(cfg.ROS2DevicePrefs);
localApplyMuJoCoPrefs(cfg.MuJoCoPrefs);
localApplyModelConfig(modelName, cfg.ModelConfig, cfg.ROS2DevicePrefs);

if opts.VerifyConnection
    mj_initROS2Workspace(Force=opts.ForceWorkspaceSeed);
end

profilePath = mj_saveDeviceProfile(cfg.ProfileName, ...
    Model=modelName, ...
    Description=cfg.Description, ...
    ModelOverrides=cfg.ModelOverrides, ...
    BuildRequirements=cfg.BuildRequirements, ...
    TemplateSource=cfg.TemplateFile, ...
    Destination=cfg.Destination);

if opts.SaveModel
    save_system(modelName);
end

fprintf('Created ROS 2 device profile "%s" for model "%s".\n', ...
    char(cfg.ProfileName), modelName);
end

function cfg = localNormalizeTemplate(cfg)
base = mj_ros2DeviceProfileTemplate("remote-x64-humble");
cfg = localMergeStruct(base, cfg);

cfg.TargetArch = string(cfg.TargetArch);
cfg.MuJoCoPrefs.ros2TargetArch = cfg.TargetArch;
if ~isfield(cfg, 'TemplateFile') || strlength(string(cfg.TemplateFile)) == 0
    cfg.TemplateFile = string(cfg.ProfileName) + ".template.mat";
end
end

function out = localMergeStruct(base, overlay)
out = base;
fields = fieldnames(overlay);
for fieldIndex = 1:numel(fields)
    fieldName = fields{fieldIndex};
    if isfield(out, fieldName) && isstruct(out.(fieldName)) && ...
            isstruct(overlay.(fieldName)) && isscalar(out.(fieldName)) && ...
            isscalar(overlay.(fieldName))
        out.(fieldName) = localMergeStruct(out.(fieldName), overlay.(fieldName));
    else
        out.(fieldName) = overlay.(fieldName);
    end
end
end

function localValidateTemplate(cfg, allowPlaceholders)
localRequireValue('ProfileName', cfg.ProfileName, allowPlaceholders);
localRequireValue('Model', cfg.Model, allowPlaceholders);
localRequireValue('TargetArch', cfg.TargetArch, allowPlaceholders);
localRequireValue('ROS2DevicePrefs.Hostname', cfg.ROS2DevicePrefs.Hostname, allowPlaceholders);
localRequireValue('ROS2DevicePrefs.Username', cfg.ROS2DevicePrefs.Username, allowPlaceholders);
localRequireValue('ROS2DevicePrefs.ROS2Install', cfg.ROS2DevicePrefs.ROS2Install, allowPlaceholders);
localRequireValue('ROS2DevicePrefs.ROS2Workspace', cfg.ROS2DevicePrefs.ROS2Workspace, allowPlaceholders);
localRequireValue('ModelConfig.SystemTargetFile', cfg.ModelConfig.SystemTargetFile, allowPlaceholders);
localRequireValue('ModelConfig.HardwareBoard', cfg.ModelConfig.HardwareBoard, allowPlaceholders);
localRequireValue('ModelConfig.Toolchain', cfg.ModelConfig.Toolchain, allowPlaceholders);

validArchs = ["linux-x86_64", "linux-aarch64"];
if ~any(strcmp(validArchs, string(cfg.TargetArch)))
    error('mj_createDeviceProfileFromTemplate:BadTargetArch', ...
        'TargetArch must be one of: %s.', strjoin(validArchs, ', '));
end
end

function localRequireValue(name, value, allowPlaceholders)
text = string(value);
if strlength(text) == 0 || (~allowPlaceholders && (contains(text, "<") || contains(text, ">")))
    error('mj_createDeviceProfileFromTemplate:PlaceholderValue', ...
        'Fill in template field %s before creating a device profile.', name);
end
end

function modelName = localLoadModel(modelRef)
modelRef = char(modelRef);
[~, ~, ext] = fileparts(modelRef);
if any(strcmpi(ext, {'.slx', '.mdl'})) || isfile(modelRef)
    load_system(modelRef);
    [~, modelName] = fileparts(modelRef);
else
    modelName = modelRef;
    if ~bdIsLoaded(modelName)
        load_system(modelName);
    end
end
end

function localApplyROS2DevicePrefs(prefs)
fields = fieldnames(prefs);
for fieldIndex = 1:numel(fields)
    fieldName = fields{fieldIndex};
    setpref('ROS_Toolbox_ROS_Device', fieldName, localPrefValue(prefs.(fieldName)));
end
end

function localApplyMuJoCoPrefs(prefs)
fields = fieldnames(prefs);
for fieldIndex = 1:numel(fields)
    fieldName = fields{fieldIndex};
    setpref('mujoco', fieldName, localPrefValue(prefs.(fieldName)));
end
end

function value = localPrefValue(value)
if isstring(value) && isscalar(value)
    value = char(value);
end
end

function localApplyModelConfig(modelName, modelConfig, rosPrefs)
localSetParam(modelName, 'SystemTargetFile', modelConfig.SystemTargetFile);
localSetParam(modelName, 'HardwareBoard', modelConfig.HardwareBoard);
localSetParam(modelName, 'Toolchain', modelConfig.Toolchain);
localSetParamIfNonempty(modelName, 'BuildConfiguration', modelConfig.BuildConfiguration);
localSetParamIfNonempty(modelName, 'ProdHWDeviceType', modelConfig.ProdHWDeviceType);
localSetParamIfNonempty(modelName, 'TargetHWDeviceType', modelConfig.TargetHWDeviceType);
localSetParamIfNonempty(modelName, 'GenCodeOnly', modelConfig.GenCodeOnly);
localSetParamIfNonempty(modelName, 'SimulationMode', modelConfig.SimulationMode);
localSetParamIfNonempty(modelName, 'ExtMode', modelConfig.ExtMode);
localSetParamIfNonempty(modelName, 'SupportNonInlinedSFcns', ...
    modelConfig.SupportNonInlinedSFcns);

configSet = getActiveConfigSet(modelName);
localSetCoderTargetParameter(configSet, 'Runtime.BuildAction', ...
    char(modelConfig.RuntimeBuildAction));
localSetCoderTargetParameter(configSet, 'ROS.RemoteBuild', ...
    logical(modelConfig.RemoteBuild));
localSyncCoderTargetData(modelName, modelConfig, rosPrefs);
end

function localSetParamIfNonempty(modelName, paramName, value)
if strlength(string(value)) > 0
    localSetParam(modelName, paramName, value);
end
end

function localSetParam(modelName, paramName, value)
try
    set_param(modelName, paramName, char(value));
catch errorInfo
    error('mj_createDeviceProfileFromTemplate:SetParamFailed', ...
        'Could not set %s on model "%s" to "%s": %s', ...
        paramName, modelName, char(value), errorInfo.message);
end
end

function localSetCoderTargetParameter(configSet, paramName, value)
try
    codertarget.data.setParameterValue(configSet, paramName, value);
catch errorInfo
    error('mj_createDeviceProfileFromTemplate:CoderTargetParameterFailed', ...
        'Could not set coder target parameter %s: %s', ...
        paramName, errorInfo.message);
end
end

function localSyncCoderTargetData(modelName, modelConfig, rosPrefs)
try
    coderTargetData = get_param(modelName, 'CoderTargetData');
catch
    return
end

if isfield(coderTargetData, 'ROS2Install')
    coderTargetData.ROS2Install.Folder = char(rosPrefs.ROS2Install);
    coderTargetData.ROS2Install.Workspace = char(rosPrefs.ROS2Workspace);
end

if isfield(coderTargetData, 'BoardParameters')
    coderTargetData.BoardParameters.DeviceAddress = char(rosPrefs.Hostname);
    coderTargetData.BoardParameters.Username = char(rosPrefs.Username);
    coderTargetData.BoardParameters.Password = char(rosPrefs.Password);
    coderTargetData.BoardParameters.SSHPort = rosPrefs.SSHPort;
end

if isfield(coderTargetData, 'ROS') && isfield(coderTargetData.ROS, 'RemoteBuild')
    coderTargetData.ROS.RemoteBuild = logical(modelConfig.RemoteBuild);
end

set_param(modelName, 'CoderTargetData', coderTargetData);
end
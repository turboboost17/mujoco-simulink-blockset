function templatePaths = mj_exportDeviceProfileTemplates(opts)
%MJ_EXPORTDEVICEPROFILETEMPLATES Write sanitized ROS 2 device profile MAT templates.
%
%   PATHS = MJ_EXPORTDEVICEPROFILETEMPLATES() creates commit-safe
%   <profile>.template.mat files for the standard ROS 2 hardware profiles.
%   Each file contains a profile struct with a freestanding ConfigSet,
%   placeholder ROS device preferences, MuJoCo target architecture prefs,
%   model overrides, and build requirements metadata.
%
%   Templates intentionally contain placeholders such as
%   /home/<user>/ros2_ws/<node> and cannot be applied directly. Use
%   MJ_ROS2DEVICEPROFILETEMPLATE to fill in a real configuration, then call
%   MJ_CREATEDEVICEPROFILEFROMTEMPLATE to create a private *.mat profile.
%
%   Name-value arguments:
%       TemplateNames string vector, default standard shipped templates
%       Destination   char/string, default this function's folder
%       Overwrite     logical, default true
%
%   See also mj_ros2DeviceProfileTemplate, mj_createDeviceProfileFromTemplate.

%   Copyright 2026 The MathWorks, Inc. (workflow helper)

arguments
    opts.TemplateNames (1,:) string = [ ...
        "ubuntu-2204-x64-ros2humble", ...
        "raspi-arm64-ros2jazzy", ...
        "wsl-x64-ros2humble"]
    opts.Destination (1,1) string = string(fileparts(mfilename('fullpath')))
    opts.Overwrite (1,1) logical = true
end

if ~isfolder(opts.Destination)
    mkdir(opts.Destination);
end

templatePaths = strings(size(opts.TemplateNames));
for templateIndex = 1:numel(opts.TemplateNames)
    cfg = mj_ros2DeviceProfileTemplate(opts.TemplateNames(templateIndex));
    profile = localCreateProfileFromTemplate(cfg);
    template = cfg;

    templatePath = fullfile(char(opts.Destination), char(cfg.TemplateFile));
    if isfile(templatePath) && ~opts.Overwrite
        error('mj_exportDeviceProfileTemplates:TemplateExists', ...
            'Template already exists: %s', templatePath);
    end

    save(templatePath, 'profile', 'template', '-v7.3');
    templatePaths(templateIndex) = string(templatePath);
    fprintf('Wrote sanitized device profile template: %s\n', templatePath);
end
end

function profile = localCreateProfileFromTemplate(cfg)
modelName = localCreateScratchModel();
cleanup = onCleanup(@() close_system(modelName, 0));

localApplyModelConfig(modelName, cfg.ModelConfig, cfg.ROS2DevicePrefs);

configSet = copy(getActiveConfigSet(modelName));
set_param(configSet, 'Name', sprintf('%s_ConfigSet', char(cfg.ProfileName)));

profile = struct();
profile.SchemaVersion = cfg.SchemaVersion;
profile.Name = char(cfg.ProfileName);
profile.Description = char(cfg.Description);
profile.SavedAt = NaT;
profile.SourceModel = '<template-scratch-model>';
profile.IsTemplate = true;
profile.TemplateSource = char(cfg.TemplateFile);
profile.TemplateInstructions = [ ...
    'Fill cfg = mj_ros2DeviceProfileTemplate("' char(cfg.ProfileName) '"); ' ...
    'replace placeholders, then call mj_createDeviceProfileFromTemplate(cfg).'];
profile.ConfigSet = configSet;
profile.ConfigSummary = localConfigSummary(configSet);
profile.ROS2DevicePrefs = cfg.ROS2DevicePrefs;
profile.MuJoCoPrefs = cfg.MuJoCoPrefs;
profile.ModelOverrides = cfg.ModelOverrides;
profile.BuildRequirements = cfg.BuildRequirements;

delete(cleanup);
end

function modelName = localCreateScratchModel()
uuid = char(java.util.UUID.randomUUID);
uuid = strrep(uuid, '-', '_');
modelName = ['mj_profile_template_' uuid];
new_system(modelName);
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
    error('mj_exportDeviceProfileTemplates:SetParamFailed', ...
        'Could not set %s on template model "%s" to "%s": %s', ...
        paramName, modelName, char(value), errorInfo.message);
end
end

function localSetCoderTargetParameter(configSet, paramName, value)
try
    codertarget.data.setParameterValue(configSet, paramName, value);
catch errorInfo
    error('mj_exportDeviceProfileTemplates:CoderTargetParameterFailed', ...
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

function summary = localConfigSummary(configSet)
summary = struct( ...
    'HardwareBoard', localGetParam(configSet, 'HardwareBoard'), ...
    'SystemTargetFile', localGetParam(configSet, 'SystemTargetFile'), ...
    'ProdHWDeviceType', localGetParam(configSet, 'ProdHWDeviceType'), ...
    'TargetHWDeviceType', localGetParam(configSet, 'TargetHWDeviceType'), ...
    'BuildConfiguration', localGetParam(configSet, 'BuildConfiguration'), ...
    'Toolchain', localGetParam(configSet, 'Toolchain'), ...
    'SupportNonInlinedSFcns', localGetParam(configSet, 'SupportNonInlinedSFcns'), ...
    'SolverType', localGetParam(configSet, 'SolverType'), ...
    'FixedStep', localGetParam(configSet, 'FixedStep'));
end

function value = localGetParam(configSet, paramName)
try
    value = get_param(configSet, paramName);
catch
    value = '';
end
end
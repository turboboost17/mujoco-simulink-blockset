function cfg = initialize_xacro_import_environment(varargin)
%INITIALIZE_XACRO_IMPORT_ENVIRONMENT Initialize xacro import environment.
%
%   CFG = INITIALIZE_XACRO_IMPORT_ENVIRONMENT() adds this MATLAB helper
%   folder to path, scans ROS package.xml files, and returns a configuration
%   struct intended for model initialization workflows.
%
%   Name-Value options:
%       WorkspaceRoot  - Root of the workspace repository
%       ExportToBase   - Export cfg as XACRO_IMPORT_CFG in base workspace

p = inputParser;
p.addParameter('WorkspaceRoot', '', @(x) ischar(x) || isstring(x));
p.addParameter('ExportToBase', true, @(x) islogical(x) && isscalar(x));
p.parse(varargin{:});

workspaceRoot = char(p.Results.WorkspaceRoot);
if isempty(workspaceRoot)
    workspaceRoot = fileparts(fileparts(mfilename('fullpath')));
end

matlabToolsDir = fullfile(workspaceRoot, 'matlab');
if isfolder(matlabToolsDir)
    addpath(matlabToolsDir);
end

cfg = struct;
cfg.WorkspaceRoot = workspaceRoot;
cfg.ToolsPath = matlabToolsDir;
cfg.InitializeTimestamp = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
cfg.ImporterFunction = 'importrobot_xacro_workspace';

if p.Results.ExportToBase
    assignin('base', 'XACRO_IMPORT_CFG', cfg);
end
end
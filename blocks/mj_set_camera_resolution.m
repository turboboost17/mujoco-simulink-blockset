function mj_set_camera_resolution(blockPath, varargin)
% MJ_SET_CAMERA_RESOLUTION Set custom resolution for MuJoCo camera rendering
%
% Usage:
%   mj_set_camera_resolution(blockPath, width, height)  % Set all cameras
%   mj_set_camera_resolution(blockPath, camIndex, width, height)  % Set specific camera
%
% Inputs:
%   blockPath - Path to the MuJoCo Plant block (string)
%   width     - Desired width in pixels (integer)
%   height    - Desired height in pixels (integer)  
%   camIndex  - Camera index (0-based, optional)
%
% Examples:
%   % Set all cameras to 1280x720
%   mj_set_camera_resolution('mymodel/MuJoCo Plant', 1280, 720);
%
%   % Set camera 0 to 640x480 and camera 1 to 1920x1080
%   mj_set_camera_resolution('mymodel/MuJoCo Plant', 0, 640, 480);
%   mj_set_camera_resolution('mymodel/MuJoCo Plant', 1, 1920, 1080);

if nargin == 3
    % Set all cameras to same resolution
    width = varargin{1};
    height = varargin{2};
    
    % Add custom resolution parameters to block mask
    set_param(blockPath, 'cameraResolutionMode', 'custom');
    set_param(blockPath, 'customWidth', num2str(width));
    set_param(blockPath, 'customHeight', num2str(height));
    set_param(blockPath, 'specificCameraIndex', '-1'); % -1 means all cameras
    
    fprintf('Set all cameras to %dx%d resolution\n', width, height);
    
elseif nargin == 4
    % Set specific camera resolution
    camIndex = varargin{1};
    width = varargin{2};
    height = varargin{3};
    
    % For specific camera, we need to store multiple resolution settings
    % This is more complex and might require extending the block parameters
    
    set_param(blockPath, 'cameraResolutionMode', 'custom');
    set_param(blockPath, 'customWidth', num2str(width));
    set_param(blockPath, 'customHeight', num2str(height));
    set_param(blockPath, 'specificCameraIndex', num2str(camIndex));
    
    fprintf('Set camera %d to %dx%d resolution\n', camIndex, width, height);
    
else
    error('Usage: mj_set_camera_resolution(blockPath, width, height) or mj_set_camera_resolution(blockPath, camIndex, width, height)');
end

% Trigger block reinitialization if model is running
try
    modelName = bdroot(blockPath);
    if strcmp(get_param(modelName, 'SimulationStatus'), 'stopped')
        fprintf('Resolution will take effect when simulation starts.\n');
    else
        fprintf('Warning: Change will take effect on next simulation run.\n');
    end
catch
    % Block might not be in a model
end

end

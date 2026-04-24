%% YOLO Dataset Export Example
% This script demonstrates how to export MuJoCo simulation segmentation
% data to YOLO training dataset format.
%
% Prerequisites:
%   - Run a Simulink simulation with segmentation output (mjRND_IDCOLOR)
%   - Simulation output stored in variable 'out' with field 'vid3'
%   - MuJoCo model XML file available

%% Example 1: Basic export (all visible objects except floor/world)
% Assumes out.vid3 contains segmentation data (HxWx3xN uint8)
% Skips frame 1 (pre-render), exports frames 2:end

mj_export_yolo_dataset(out, 'Complete_model.xml', 'datasets/robot_basic', ...
    SegField='vid3', ...
    StartFrame=2);

%% Example 2: Export specific classes only (robot arm links)
% Define classes of interest (robot links and gripper)
classesOfInterest = [
    "robot/link1"
    "robot/link2"
    "robot/link3"
    "robot/link4"
    "robot/link5"
    "robot/link6"
    "robotiq/base"
    "robotiq/left_finger"
    "robotiq/right_finger"
];

mj_export_yolo_dataset(out, 'Complete_model.xml', 'datasets/robot_arms_only', ...
    SegField='vid3', ...
    StartFrame=2, ...
    IncludeNames=classesOfInterest);

%% Example 3: Train/Val split
% Export first 80% of frames as training set
N = size(out.vid3, 4);
trainEnd = floor(0.8 * (N - 1));  % -1 because we skip frame 1

mj_export_yolo_dataset(out, 'Complete_model.xml', 'datasets/robot_split', ...
    SegField='vid3', ...
    StartFrame=2, ...
    EndFrame=trainEnd+1, ...
    Split='train', ...
    IncludeNames=classesOfInterest);

% Export last 20% as validation set
mj_export_yolo_dataset(out, 'Complete_model.xml', 'datasets/robot_split', ...
    SegField='vid3', ...
    StartFrame=trainEnd+2, ...
    Split='val', ...
    IncludeNames=classesOfInterest);

%% Example 4: With RGB images (if available)
% If your simulation has RGB camera output in out.vidRGB:
mj_export_yolo_dataset(out, 'Complete_model.xml', 'datasets/robot_rgb', ...
    SegField='vid3', ...
    RGBField='vidRGB', ...
    StartFrame=2, ...
    IncludeNames=classesOfInterest, ...
    ImageFormat='jpg', ...
    JPEGQuality=90);

%% Example 5: Detection bounding boxes instead of segmentation
mj_export_yolo_dataset(out, 'Complete_model.xml', 'datasets/robot_detect', ...
    SegField='vid3', ...
    StartFrame=2, ...
    Format='detect', ...          % Bounding boxes
    IncludeNames=classesOfInterest);

%% Example 6: Custom frame range and filename prefix
mj_export_yolo_dataset(out, 'Complete_model.xml', 'datasets/robot_custom', ...
    SegField='vid3', ...
    StartFrame=10, ...
    EndFrame=100, ...
    FilePrefix='robot_sim', ...   % Creates robot_sim_0001.jpg, etc.
    IncludeNames=classesOfInterest);

%% Verify dataset structure
% After export, the dataset directory should look like:
%
% datasets/robot_basic/
%   images/
%     train/
%       frame_0001.jpg
%       frame_0002.jpg
%       ...
%   labels/
%     train/
%       frame_0001.txt
%       frame_0002.txt
%       ...
%   classes.txt
%   data.yaml

%% Direct usage of mj_segmentation_to_yolo (low-level API)
% For manual control, you can call mj_segmentation_to_yolo directly:

% Initialize class map for consistency across frames
classMap = containers.Map('KeyType', 'char', 'ValueType', 'int32');

% Export each frame manually
for k = 2:size(out.vid3, 4)
    segFrame = out.vid3(:,:,:,k);
    frameName = sprintf('frame_%04d', k-1);
    
    classMap = mj_segmentation_to_yolo(segFrame, 'Complete_model.xml', ...
        'labels/', frameName, ...
        Format='segment', ...
        MinArea=20, ...
        IncludeNames=classesOfInterest, ...
        ClassMap=classMap);
end

%% Verify multiple instances handling
% mj_segmentation_to_yolo automatically handles multiple instances:
%   - Multiple objects with same class name -> multiple lines, same class_id
%   - Disconnected regions of same object -> multiple polygons, same class_id
%
% Example output in frame_0001.txt:
%   0 0.123 0.456 0.234 0.567 ... (first instance of class 0)
%   0 0.789 0.123 0.890 0.234 ... (second instance of class 0)
%   1 0.345 0.678 0.456 0.789 ... (instance of class 1)

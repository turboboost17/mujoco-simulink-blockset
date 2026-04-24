function mj_export_yolo_dataset(simOut, modelXML, datasetDir, opts)
% MJ_EXPORT_YOLO_DATASET Export MuJoCo simulation to YOLO dataset format.
%
%   mj_export_yolo_dataset(simOut, modelXML, datasetDir)
%   mj_export_yolo_dataset(..., Name=Value)
%
%   Exports segmentation data from a Simulink/MuJoCo simulation to YOLO
%   training dataset format. Creates standard YOLO directory structure:
%     datasetDir/
%       images/train/
%       labels/train/
%       classes.txt
%       data.yaml
%
% Inputs:
%   simOut      - Simulink output structure containing segmentation video.
%                 Expected field: vid3 (HxWx3xN uint8 segmentation frames).
%                 Optional field: vidRGB (HxWx3xN uint8 RGB camera frames).
%   modelXML    - Path to MuJoCo XML model file for label decoding.
%   datasetDir  - Root directory for YOLO dataset output.
%
% Name-Value Options:
%   SegField    - Name of field in simOut containing segmentation data
%                 (default: 'vid3'). Should be uint8 HxWx3xN array.
%   RGBField    - Name of field in simOut containing RGB camera images
%                 (default: 'vidRGB'). If empty or field doesn't exist,
%                 segmentation frames are saved as images.
%   StartFrame  - First frame to export (default: 2, skips pre-render).
%   EndFrame    - Last frame to export (default: all frames).
%   Split       - Dataset split name (default: 'train'). Can be 'train',
%                 'val', or 'test'. Creates images/labels subdirectories.
%   Format      - 'segment' (default) or 'detect' for YOLO format type.
%   MinArea     - Minimum area in pixels for object inclusion (default: 20).
%   IncludeNames- string array of class names to export (default: empty =
%                 export all except default exclusions like floor/world).
%                 Example: ["robot/link1", "robot/link2", "robotiq/base"]
%   FilePrefix  - Prefix for image/label filenames (default: 'frame').
%   ImageFormat - Image file format: 'jpg' (default), 'png', or 'bmp'.
%   JPEGQuality - JPEG quality 1-100 (default: 95).
%   Verbose     - Display progress messages (default: true).
%
% Example (basic):
%   mj_export_yolo_dataset(out, 'model.xml', 'datasets/robot_seg');
%
% Example (specific classes only):
%   classesOfInterest = ["robot/link1", "robot/link2", "robot/link3", ...
%                        "robot/link4", "robot/link5", "robot/link6", ...
%                        "robotiq/base", "robotiq/left_finger", "robotiq/right_finger"];
%   mj_export_yolo_dataset(out, 'Complete_model.xml', 'datasets/robot_arms', ...
%       IncludeNames=classesOfInterest, StartFrame=2, Split='train');
%
% Example (train/val split):
%   % Export training set (first 80% of frames)
%   N = size(out.vid3, 4);
%   trainEnd = floor(0.8 * N);
%   mj_export_yolo_dataset(out, 'model.xml', 'datasets/robot', ...
%       StartFrame=2, EndFrame=trainEnd, Split='train');
%   
%   % Export validation set (last 20% of frames)
%   mj_export_yolo_dataset(out, 'model.xml', 'datasets/robot', ...
%       StartFrame=trainEnd+1, Split='val');

    arguments
        simOut      struct
        modelXML    (1,:) char
        datasetDir  (1,:) char
        opts.SegField    (1,:) char = 'vid3'
        opts.RGBField    (1,:) char = 'vidRGB'
        opts.StartFrame  (1,1) double {mustBePositive, mustBeInteger} = 2
        opts.EndFrame    (1,1) double {mustBePositive, mustBeInteger} = inf
        opts.Split       (1,:) char {mustBeMember(opts.Split, {'train','val','test'})} = 'train'
        opts.Format      (1,:) char {mustBeMember(opts.Format, {'segment','detect'})} = 'segment'
        opts.MinArea     (1,1) double {mustBePositive} = 20
        opts.IncludeNames string = string.empty
        opts.FilePrefix  (1,:) char = 'frame'
        opts.ImageFormat (1,:) char {mustBeMember(opts.ImageFormat, {'jpg','png','bmp'})} = 'jpg'
        opts.JPEGQuality (1,1) double {mustBeInRange(opts.JPEGQuality, 1, 100)} = 95
        opts.Verbose     (1,1) logical = true
    end

    % --- Validate inputs ---
    if ~isfield(simOut, opts.SegField)
        error('Segmentation field "%s" not found in simOut structure.', opts.SegField);
    end
    segData = simOut.(opts.SegField);
    
    if ndims(segData) ~= 4 || size(segData, 3) ~= 3
        error('Segmentation data must be HxWx3xN uint8 array.');
    end
    
    [~, ~, ~, numFrames] = size(segData);
    
    % Check for RGB field
    hasRGB = false;
    if isfield(simOut, opts.RGBField)
        rgbData = simOut.(opts.RGBField);
        if ndims(rgbData) == 4 && size(rgbData, 3) == 3 && size(rgbData, 4) == numFrames
            hasRGB = true;
            if opts.Verbose
                fprintf('Found RGB field "%s" for image export.\n', opts.RGBField);
            end
        end
    end
    
    if ~hasRGB && opts.Verbose
        fprintf('No RGB field found, will save colorized segmentation as images.\n');
    end
    
    % Determine frame range
    startIdx = opts.StartFrame;
    endIdx = min(opts.EndFrame, numFrames);
    
    if startIdx > endIdx
        error('StartFrame (%d) is greater than EndFrame (%d).', startIdx, endIdx);
    end
    
    numExportFrames = endIdx - startIdx + 1;
    
    if opts.Verbose
        fprintf('Exporting %d frames (indices %d to %d) to dataset "%s"...\n', ...
            numExportFrames, startIdx, endIdx, datasetDir);
        if ~isempty(opts.IncludeNames)
            fprintf('Filtering to %d classes of interest.\n', numel(opts.IncludeNames));
        end
    end
    
    % --- Create directory structure ---
    imgDir = fullfile(datasetDir, 'images', opts.Split);
    lblDir = fullfile(datasetDir, 'labels', opts.Split);
    
    if ~isfolder(imgDir)
        mkdir(imgDir);
    end
    if ~isfolder(lblDir)
        mkdir(lblDir);
    end
    
    % --- Initialize class map for consistency ---
    classMap = containers.Map('KeyType', 'char', 'ValueType', 'int32');
    
    % --- Export frames ---
    for k = startIdx:endIdx
        frameNum = k - startIdx + 1;
        
        if opts.Verbose && mod(frameNum, 10) == 1
            fprintf('Processing frame %d/%d...\n', frameNum, numExportFrames);
        end
        
        % Build filename
        frameName = sprintf('%s_%04d', opts.FilePrefix, frameNum);
        imgFilename = [frameName '.' opts.ImageFormat];
        
        % --- Save image ---
        imgPath = fullfile(imgDir, imgFilename);
        if hasRGB
            img = rgbData(:,:,:,k);
        else
            % Use segmentation as image (could colorize here if desired)
            img = segData(:,:,:,k);
        end
        
        switch lower(opts.ImageFormat)
            case 'jpg'
                imwrite(img, imgPath, 'jpg', 'Quality', opts.JPEGQuality);
            case 'png'
                imwrite(img, imgPath, 'png');
            case 'bmp'
                imwrite(img, imgPath, 'bmp');
        end
        
        % --- Export YOLO annotation ---
        segFrame = segData(:,:,:,k);
        
        % Build call arguments
        yoloArgs = {'Format', opts.Format, 'MinArea', opts.MinArea, 'ClassMap', classMap};
        if ~isempty(opts.IncludeNames)
            yoloArgs = [yoloArgs, {'IncludeNames', opts.IncludeNames}];
        end
        
        classMap = mj_segmentation_to_yolo(segFrame, modelXML, lblDir, frameName, yoloArgs{:});
    end
    
    % --- Copy classes.txt to dataset root ---
    classesSource = fullfile(lblDir, 'classes.txt');
    classesDest = fullfile(datasetDir, 'classes.txt');
    if isfile(classesSource)
        copyfile(classesSource, classesDest);
    end
    
    % --- Write data.yaml for YOLO training ---
    localWriteDataYAML(datasetDir, opts.Split, numel(classMap), modelXML);
    
    if opts.Verbose
        fprintf('Dataset export complete!\n');
        fprintf('  Images: %s\n', imgDir);
        fprintf('  Labels: %s\n', lblDir);
        fprintf('  Classes: %d\n', numel(classMap));
        fprintf('  Total frames: %d\n', numExportFrames);
    end
end

function localWriteDataYAML(datasetDir, split, numClasses, modelXML)
% Write data.yaml file for YOLO training configuration.
    yamlPath = fullfile(datasetDir, 'data.yaml');
    
    % Read class names from classes.txt
    classesTxt = fullfile(datasetDir, 'classes.txt');
    if ~isfile(classesTxt)
        warning('classes.txt not found, cannot write complete data.yaml');
        return;
    end
    
    fid = fopen(classesTxt, 'r');
    if fid == -1
        return;
    end
    classNames = {};
    while ~feof(fid)
        line = fgetl(fid);
        if ischar(line) && ~isempty(line)
            classNames{end+1} = line; %#ok<AGROW>
        end
    end
    fclose(fid);
    
    % Write YAML
    fid = fopen(yamlPath, 'w');
    if fid == -1
        return;
    end
    
    fprintf(fid, '# YOLO dataset configuration\n');
    fprintf(fid, '# Generated by mj_export_yolo_dataset.m\n');
    fprintf(fid, '# Source model: %s\n\n', modelXML);
    
    fprintf(fid, 'path: %s\n', strrep(datasetDir, '\', '/'));
    fprintf(fid, 'train: images/%s\n', split);
    fprintf(fid, 'val: images/val\n');
    fprintf(fid, 'test: images/test\n\n');
    
    fprintf(fid, 'nc: %d\n', numClasses);
    fprintf(fid, 'names:\n');
    for i = 1:numel(classNames)
        fprintf(fid, '  %d: %s\n', i-1, classNames{i});
    end
    
    fclose(fid);
end

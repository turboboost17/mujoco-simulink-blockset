% Export paired RGB images and MuJoCo segmentation labels to YOLO format.

modelXML = localResolveExistingPath(fullfile('assets', 'Complete_model.xml'));
outputDir = fullfile(pwd, 'data');
startFrame = 2;
labelFormat = 'detect';
minArea = 1;

% Configure any matching RGB/segmentation video pairs here.
imageSets = [
    struct('RGBField', "vid0", 'SegField', "vidS0", 'FilePrefix', "wrist")
    struct('RGBField', "vid3", 'SegField', "vidS3", 'FilePrefix', "workpiece")
];

% Define the fixed training classes and how MuJoCo names map into them.
% MatchNames accepts exact names or wildcard patterns and matches against
% both full geom names and parent body names.
classDefinitions = [
    struct('ClassName', "brick_1x2", 'MatchNames', "*lego1x2*")
    struct('ClassName', "brick_2x2", 'MatchNames', "*lego2x2*")
    struct('ClassName', "brick_2x4", 'MatchNames', "*lego2x4*")
    struct('ClassName', "plate_1x2", 'MatchNames', "*plate1x2*")
    struct('ClassName', "plate_2x2", 'MatchNames', "*plate2x2*")
    struct('ClassName', "plate_2x4", 'MatchNames', "*plate2x4*")
];

if ~exist('out', 'var')
    error('This script requires the Simulink output variable "out" in the workspace.');
end

if ~isfolder(outputDir)
    mkdir(outputDir);
end

for setIdx = 1:numel(imageSets)
    localExportImageSet(out, imageSets(setIdx), modelXML, outputDir, startFrame, ...
        labelFormat, minArea, classDefinitions);
end

function localExportImageSet(simOut, imageSet, modelXML, outputDir, startFrame, labelFormat, minArea, classDefinitions)
    rgbFrames = localGetVideoField(simOut, imageSet.RGBField);
    segFrames = localGetVideoField(simOut, imageSet.SegField);

    if ndims(rgbFrames) ~= 4 || size(rgbFrames, 3) ~= 3
        error('Field "%s" must be an HxWx3xN RGB video array.', imageSet.RGBField);
    end
    if ndims(segFrames) ~= 4 || size(segFrames, 3) ~= 3
        error('Field "%s" must be an HxWx3xN segmentation video array.', imageSet.SegField);
    end
    if size(rgbFrames, 4) ~= size(segFrames, 4)
        error('Field "%s" has %d frames but "%s" has %d frames.', ...
            imageSet.RGBField, size(rgbFrames, 4), imageSet.SegField, size(segFrames, 4));
    end

    firstFrame = max(startFrame, 1);
    numFrames = size(segFrames, 4);
    if firstFrame > numFrames
        error('Start frame %d exceeds the number of frames (%d) in "%s".', ...
            firstFrame, numFrames, imageSet.SegField);
    end

    for frameIdx = firstFrame:numFrames
        exportIdx = frameIdx - firstFrame;
        frameName = sprintf('%s_frame_%04d', imageSet.FilePrefix, exportIdx);

        mj_segmentation_to_yolo(uint8(segFrames(:,:,:,frameIdx)), modelXML, outputDir, frameName, ...
            Format=labelFormat, ...
            MinArea=minArea, ...
            ClassDefinitions=classDefinitions, ...
            GroupBy='body');

        imwrite(uint8(rgbFrames(:,:,:,frameIdx)), fullfile(outputDir, [frameName '.png']), 'png');
    end
end

function data = localGetVideoField(simOut, fieldName)
    fieldName = char(fieldName);

    if isa(simOut, 'Simulink.SimulationOutput')
        availableNames = string(simOut.who);
        if ~ismember(fieldName, availableNames)
            error('Simulation output does not contain field "%s".', fieldName);
        end
        data = simOut.get(fieldName);
        return;
    end

    if isstruct(simOut)
        if ~isfield(simOut, fieldName)
            error('Structure does not contain field "%s".', fieldName);
        end
        data = simOut.(fieldName);
        return;
    end

    error('Unsupported simulation output type: %s', class(simOut));
end

function resolvedPath = localResolveExistingPath(candidatePath)
    searchPaths = string(candidatePath);

    if ~isfile(candidatePath)
        searchPaths(end + 1) = string(fullfile(pwd, candidatePath));
    end

    [candidateDir, candidateName, candidateExt] = fileparts(candidatePath);
    if strlength(string(candidateDir)) == 0
        searchPaths(end + 1) = string(fullfile(pwd, 'assets', [candidateName candidateExt]));
    end

    for idx = 1:numel(searchPaths)
        if isfile(searchPaths(idx))
            info = dir(char(searchPaths(idx)));
            resolvedPath = fullfile(info.folder, info.name);
            return;
        end
    end

    error('Unable to locate required file: %s', candidatePath);
end
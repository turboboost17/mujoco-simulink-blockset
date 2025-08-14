function mj_debug_segmentation(segmentationData, width, height)
% MJ_DEBUG_SEGMENTATION Visualize segmentation output from MuJoCo
%
% mj_debug_segmentation(segmentationData, width, height)
%
% Inputs:
%   segmentationData - Raw segmentation RGB data from MuJoCo
%   width - Image width
%   height - Image height
%
% This function helps debug the segmentation camera output by:
% 1. Visualizing the raw RGB data
% 2. Decoding the segmentation IDs based on the RGB values
% 3. Creating a false color visualization where each unique object has a different color
%
% Copyright 2023 The MathWorks, Inc.

% Check if data length matches expected size
expectedLength = width * height * 3;
if length(segmentationData) ~= 921600
    warning('Data length (%d) does not match expected size for %dx%d image (%d)', ...
        length(segmentationData), width, height, expectedLength);
end

% Reshape the segmentation data into an image
% MuJoCo stores image in interleaved RGB format where pixels are in row-major order
% We need to reshape to height x width x 3
try
    % First reshape to width*height x 3 (each row is a pixel, each column is R,G,B)
    pixelData = reshape(segmentationData, [3, 640, 480]);
    
    % Then reshape to height x width x 3
    segImage = permute(pixelData, [3,2,1]);
catch e
    error('Failed to reshape data: %s\nCheck image dimensions. Data length: %d, Expected: %d', ...
        e.message, length(segmentationData), expectedLength);
end

% Display the raw segmentation data
figure('Name', 'Segmentation Debug', 'NumberTitle', 'off');

subplot(2, 2, 1);
imshow(uint8(segImage));
title('Raw Segmentation Output');

% Calculate the segmentation IDs
R = double(segImage(:,:,1));
G = double(segImage(:,:,2));
B = double(segImage(:,:,3));
segIDs = R + G*256 + B*(256^2) - 1;

% Generate a colormap for unique IDs
uniqueIDs = unique(segIDs(:));
numUniqueIDs = length(uniqueIDs);
fprintf('Found %d unique object IDs in segmentation image\n', numUniqueIDs);

% Create fake color image where each ID gets a unique color
idColormap = hsv(numUniqueIDs);
segColored = zeros(size(segImage));

% Create an ID visualization
subplot(2, 2, 2);
imagesc(segIDs);
colorbar;
title('Object IDs');

% Map each ID to a unique color
idToColorMap = containers.Map('KeyType', 'double', 'ValueType', 'any');
for i = 1:numUniqueIDs
    idToColorMap(uniqueIDs(i)) = idColormap(i,:);
end

% Create a colored visualization
coloredSeg = zeros(size(segImage));
for i = 1:numUniqueIDs
    id = uniqueIDs(i);
    mask = (segIDs == id);
    for c = 1:3
        tmp = coloredSeg(:,:,c);
        tmp(mask) = idColormap(i,c);
        coloredSeg(:,:,c) = tmp;
    end
end

subplot(2, 2, 3);
imshow(coloredSeg);
title('Colored Segmentation');

% Print the ID values and counts
idCounts = zeros(numUniqueIDs, 1);
for i = 1:numUniqueIDs
    idCounts(i) = sum(segIDs(:) == uniqueIDs(i));
end

% Display ID frequencies
subplot(2, 2, 4);
bar(1:numUniqueIDs, idCounts);
set(gca, 'XTick', 1:numUniqueIDs);
if numUniqueIDs <= 20
    set(gca, 'XTickLabel', arrayfun(@num2str, uniqueIDs, 'UniformOutput', false));
end
title('Object ID Frequency');
xlabel('Object ID');
ylabel('Pixel Count');
grid on;

% Print ID information
fprintf('\nID Statistics:\n');
fprintf('-------------\n');
for i = 1:numUniqueIDs
    fprintf('ID: %d - Pixel count: %d (%.2f%%)\n', uniqueIDs(i), idCounts(i), 100*idCounts(i)/numel(segIDs));
end

% Check if all pixels have the same ID (which would indicate a problem)
if numUniqueIDs == 1
    fprintf('\nWARNING: All pixels have the same ID (%d).\n', uniqueIDs(1));
    fprintf('This suggests the segmentation rendering is not working correctly.\n');
end

% Check if any ID values are -1 (no object)
if any(uniqueIDs < 0)
    fprintf('\nBackground pixels (ID < 0) detected.\n');
end

% Check if the IDs seem to follow the expected MuJoCo object ID pattern
if any(uniqueIDs > 0) && all(uniqueIDs < 10000)
    fprintf('\nID values are within expected range for MuJoCo object IDs.\n');
else
    fprintf('\nWARNING: ID values seem unusual for MuJoCo segmentation.\n');
end

end
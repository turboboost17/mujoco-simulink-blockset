function [ segNames, types] = mj_segmentation_decoder(segImage, modelFile)
% MJ_SEGMENTATION_DECODER Decodes segmentation image to object IDs and names
%
% [segNames, types] = mj_segmentation_decoder(segImage, modelFile)
%
% Inputs:
%   segImage - Uint8 RGB image from MuJoCo's mjRND_IDCOLOR rendering
%   modelFile - Path to the MuJoCo XML model file
%
% Outputs:
%   
%   segNames - Cell array of names corresponding to the unique IDs in segIDs
%   types    - Cell array of types corresponding to the unique IDs in segIDs
%

% segIDs   - Matrix of same size as segmentation height/width containing geom IDs

% Check inputs
if ndims(segImage) ~= 3 || size(segImage, 3) ~= 3
    error('Segmentation image must be an RGB image');
end
if ~exist(modelFile, 'file')
    error('Model file not found: %s', modelFile);
end

% Extract color channels
R = double(segImage(:,:,1));
G = double(segImage(:,:,2));
B = double(segImage(:,:,3));

% Decode ID from RGB colors
% ID = R + G*256 + B*256^2 - 1
segIDs = R + G*256 + B*(256^2) - 1;

% Get unique IDs (excluding background ID = -1)
uniqueIDs = unique(segIDs(:));
uniqueIDs = uniqueIDs(uniqueIDs >= 0);

% Initialize output arrays
segNames = cell(length(uniqueIDs), 1);
types = cell(length(uniqueIDs), 1);

% Plot the segmentation image with random colors
% This is useful for debugging and visualization   
figure('Name', 'Segmentation Output', 'NumberTitle', 'off');
% Assign random colors to each unique ID
segImage = zeros(size(segImage), 'uint8');
for i = 1:length(uniqueIDs)
    % Generate a random color
    color = uint8(randi([0, 255], 1, 3));
    % Assign the color to all pixels with the current ID
	temp = ones(size(segIDs), 'uint8');
	temp( segIDs == uniqueIDs(i))= color(1); segImage(:,:,1)= segImage(:,:,1) + temp; temp = zeros(size(segIDs), 'uint8'); 
	temp( segIDs == uniqueIDs(i))= color(2); segImage(:,:,2)= segImage(:,:,2) + temp; temp = zeros(size(segIDs), 'uint8');
	temp( segIDs == uniqueIDs(i))= color(3); segImage(:,:,3)= segImage(:,:,3) + temp; 
    % segImage(repmat(segIDs == uniqueIDs(i), [1, 1, 3])) = color;
imshow(segImage);
drawnow();
input('');
end 

title('Segmentation Image');   

% Load MuJoCo model to get names
try
    % Initialize a MuJoCo model instance
    mi = MujocoModelInstance();
    if mi.initMdl(modelFile, false) ~= 0
        error('Failed to load MuJoCo model: %s', modelFile);
    end
    
    % Get pointer to mjModel
    m = mi.get_m();
    
    % Define MuJoCo object types
    mjOBJ_BODY = 1;
    mjOBJ_GEOM = 5;
    mjOBJ_SITE = 6;
    mjOBJ_CAMERA = 7;
    mjOBJ_LIGHT = 8;
    
    % Map IDs to names
    for i = 1:length(uniqueIDs)
        id = uniqueIDs(i);
        
        % Try different object types (geom is most common for segmentation)
        name = mj_id2name_mex(m, mjOBJ_GEOM, id);
        if ~isempty(name)
            types{i} = 'geom';
            segNames{i} = name;
            continue;
        end
        
        % Try body
        name = mj_id2name_mex(m, mjOBJ_BODY, id);
        if ~isempty(name)
            types{i} = 'body';
            segNames{i} = name;
            continue;
        end
        
        % Try site
        name = mj_id2name_mex(m, mjOBJ_SITE, id);
        if ~isempty(name)
            types{i} = 'site';
            segNames{i} = name;
            continue;
        end
        
        % Try camera
        name = mj_id2name_mex(m, mjOBJ_CAMERA, id);
        if ~isempty(name)
            types{i} = 'camera';
            segNames{i} = name;
            continue;
        end
        
        % Try light
        name = mj_id2name_mex(m, mjOBJ_LIGHT, id);
        if ~isempty(name)
            types{i} = 'light';
            segNames{i} = name;
            continue;
        end
        
        % If no match found
        types{i} = 'unknown';
        segNames{i} = ['unknown_' num2str(id)];
    end
catch me
    % If we can't load MuJoCo model, just return numeric IDs
    warning('Could not map IDs to names: %s' , '%s', me.message);
    for i = 1:length(uniqueIDs)
        segNames{i} = ['ID_' num2str(uniqueIDs(i))];
        types{i} = 'unknown';
    end
end
end
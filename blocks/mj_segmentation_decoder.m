function [segIDs, segNames, types, idSummary] = mj_segmentation_decoder(segImage, labelSource)
% MJ_SEGMENTATION_DECODER Decode MuJoCo segmentation RGB image to IDs and labels.
%
% [segIDs, segNames, types] = mj_segmentation_decoder(segImage)
% [segIDs, segNames, types] = mj_segmentation_decoder(segImage, labelSource)
% [segIDs, segNames, types, idSummary] = mj_segmentation_decoder(...)
%
% Inputs:
%   segImage    - uint8 RGB image from MuJoCo mjRND_IDCOLOR rendering.
%   labelSource - (optional) one of:
%       1) table with columns: ID, Name, and optionally ObjectType, BodyName
%       2) path to MJCF XML file (uses mj_xml_labelmap)
%
% Outputs:
%   segIDs    - decoded ID image, same HxW as input
%   segNames  - cellstr names for unique IDs (background -1 excluded)
%   types     - cellstr object types for unique IDs
%   idSummary - table for unique IDs with columns:
%               ID, R, G, B, Name, BodyName, ObjectType, IsMapped
%
% Notes:
%   MuJoCo encoding: ID = R + 256*G + 256^2*B - 1

    if nargin < 1 || nargin > 2
        error('Expected 1 or 2 inputs: segImage and optional labelSource.');
    end

    if ndims(segImage) ~= 3 || size(segImage, 3) ~= 3 || ~isa(segImage, 'uint8')
        error('segImage must be a uint8 RGB image (HxWx3).');
    end

    r = double(segImage(:, :, 1));
    g = double(segImage(:, :, 2));
    b = double(segImage(:, :, 3));

    segIDs = r + g*256 + b*(256^2) - 1;
    uniqueIDs = unique(segIDs(:));
    uniqueIDs = uniqueIDs(uniqueIDs >= 0);
    uniqueIDs = uniqueIDs(:);  % ensure column vector

    n = numel(uniqueIDs);
    names = strings(n, 1);
    typeNames = strings(n, 1);
    bodyNameStrs = strings(n, 1);
    names(:) = "";
    typeNames(:) = "unknown";
    bodyNameStrs(:) = "";
    isMapped = false(n, 1);

    if nargin == 2 && ~isempty(labelSource)
        [names, typeNames, bodyNameStrs, isMapped] = localResolveLabels(uniqueIDs, labelSource);
    end

    for i = 1:n
        if strlength(names(i)) == 0
            names(i) = "ID_" + string(uniqueIDs(i));
        end
    end

    rgb = localIdToRgb(uint32(uniqueIDs));
    idSummary = table( ...
        uint32(uniqueIDs), rgb(:,1), rgb(:,2), rgb(:,3), ...
        cellstr(names), cellstr(bodyNameStrs), cellstr(typeNames), isMapped, ...
        'VariableNames', {'ID', 'R', 'G', 'B', 'Name', 'BodyName', 'ObjectType', 'IsMapped'});

    segNames = cellstr(names);
    types = cellstr(typeNames);
end

function [names, typeNames, bodyNames, isMapped] = localResolveLabels(uniqueIDs, labelSource)
    n = numel(uniqueIDs);
    names = strings(n, 1);
    typeNames = strings(n, 1);
    bodyNames = strings(n, 1);
    names(:) = "";
    typeNames(:) = "unknown";
    bodyNames(:) = "";
    isMapped = false(n, 1);

    if istable(labelSource)
        [names, typeNames, bodyNames, isMapped] = localMapFromTable(uniqueIDs, labelSource);
        return;
    end

    if ischar(labelSource) || isstring(labelSource)
        src = char(labelSource);
        srcResolved = localResolveFilePath(src);
        if isempty(srcResolved)
            warning('Label source file not found: %s', src);
            return;
        end

        [~, ~, ext] = fileparts(srcResolved);
        if strcmpi(ext, '.xml')
            t = mj_xml_labelmap(srcResolved);
            [names, typeNames, bodyNames, isMapped] = localMapFromTable(uniqueIDs, t);
            return;
        end

        warning('Unsupported label source file extension: %s', ext);
        return;
    end

    warning('Unsupported labelSource type. Use table or XML path.');
end

function [names, typeNames, bodyNames, isMapped] = localMapFromTable(uniqueIDs, labelTable)
    n = numel(uniqueIDs);
    names = strings(n, 1);
    typeNames = strings(n, 1);
    bodyNames = strings(n, 1);
    names(:) = "";
    typeNames(:) = "unknown";
    bodyNames(:) = "";
    isMapped = false(n, 1);

    if ~ismember('ID', labelTable.Properties.VariableNames) || ...
       ~ismember('Name', labelTable.Properties.VariableNames)
        warning('Label table must contain columns ID and Name.');
        return;
    end

    if ~ismember('ObjectType', labelTable.Properties.VariableNames)
        labelTable.ObjectType = repmat({'unknown'}, height(labelTable), 1);
    end

    hasBodyName = ismember('BodyName', labelTable.Properties.VariableNames);

    idsT = double(labelTable.ID);
    namesT = string(labelTable.Name);
    typesT = string(labelTable.ObjectType);

    [tf, loc] = ismember(double(uniqueIDs), idsT);
    isMapped(tf) = true;
    names(tf) = namesT(loc(tf));
    typeNames(tf) = typesT(loc(tf));

    if hasBodyName
        bodyNamesT = string(labelTable.BodyName);
        bodyNames(tf) = bodyNamesT(loc(tf));
    end
end

function rgb = localIdToRgb(ids)
    idPlusOne = uint32(ids) + uint32(1);
    r = uint8(bitand(idPlusOne, uint32(255)));
    g = uint8(bitand(bitshift(idPlusOne, -8), uint32(255)));
    b = uint8(bitand(bitshift(idPlusOne, -16), uint32(255)));
    rgb = [r, g, b];
end

function resolvedPath = localResolveFilePath(inputPath)
    resolvedPath = '';

    if isfile(inputPath)
        resolvedPath = inputPath;
        return;
    end

    candidate = fullfile(pwd, inputPath);
    if isfile(candidate)
        resolvedPath = candidate;
        return;
    end

    [inputDir, inputName, inputExt] = fileparts(inputPath);
    if isempty(inputDir)
        candidate = fullfile(pwd, 'assets', [inputName inputExt]);
        if isfile(candidate)
            resolvedPath = candidate;
            return;
        end
    end

    inPath = which(inputPath);
    if ~isempty(inPath)
        resolvedPath = inPath;
        return;
    end

    if exist(inputPath, 'file') == 2
        resolvedPath = inputPath;
    end
end
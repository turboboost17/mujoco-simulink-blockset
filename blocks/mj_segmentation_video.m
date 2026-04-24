function mj_segmentation_video(vidData, labelSource, outputFile, opts)
% MJ_SEGMENTATION_VIDEO Write a colorized segmentation video from MuJoCo output.
%
%   mj_segmentation_video(vidData, labelSource, outputFile)
%   mj_segmentation_video(..., Name=Value)
%
%   Reads MuJoCo segmentation frames (mjRND_IDCOLOR), decodes IDs, and
%   writes a video where all geoms for a given decoded name share one color.
%   Colors are assigned once from the definitive label list (XML/CSV/table)
%   before any frames are processed.
%
%   Floor/world geom (ID 0) is black; background (no object) is white.
%
% Inputs:
%   vidData      - uint8 HxWx3xN segmentation video tensor.
%   labelSource  - XML path or table (same as mj_segmentation_decoder).
%   outputFile   - Output video file path (e.g. 'seg_wrist.avi').
%
% Name-Value Options:
%   FrameRate       - Video frame rate (default: 30).
%   FlipUD          - Flip each frame vertically (default: false).
%   FloorColor      - 1x3 uint8 RGB for floor/world geom (default: [0 0 0]).
%   BackgroundColor - 1x3 uint8 RGB for background pixels (default: [255 255 255]).
%   FallbackColor   - 1x3 uint8 RGB for any unknown/unmapped geom (default: [128 128 128]).
%   Profile         - VideoWriter profile: 'Indexed AVI' or 'MPEG-4' (default: 'MPEG-4').
%   Quality         - VideoWriter quality 0-100 for MPEG-4 (default: 80).

    arguments
        vidData       uint8
        labelSource
        outputFile    (1,:) char
        opts.FrameRate      (1,1) double {mustBePositive} = 30
        opts.FlipUD         (1,1) logical = false
        opts.FloorColor     (1,3) uint8 = uint8([0 0 0])
        opts.BackgroundColor(1,3) uint8 = uint8([255 255 255])
        opts.FallbackColor  (1,3) uint8 = uint8([128 128 128])
        opts.Profile        (1,:) char {mustBeMember(opts.Profile, {'Indexed AVI','MPEG-4'})} = 'MPEG-4'
        opts.Quality        (1,1) double {mustBeInRange(opts.Quality, 0, 100)} = 80
    end

    [H, W, C, N] = size(vidData);
    if C ~= 3
        error('vidData must be HxWx3xN (got %d channels).', C);
    end

    % === Build definitive label table from source (no frame scanning) ===
    labelTable = localLabelTableFromSource(labelSource);

    if isempty(labelTable) || height(labelTable) == 0
        error(['Could not build label table from labelSource. ' ...
               'Provide an XML path or table with ID and Name columns.']);
    end

    % === Build colormap: all colors assigned once up front ===
    %   Index 1 = background (white)
    %   Index 2 = floor/world (black)
    %   Index 3 = fallback/unknown (grey)
    %   Index 4+ = one per unique name
    cmap = zeros(3, 3);
    cmap(1,:) = double(opts.BackgroundColor) / 255;
    cmap(2,:) = double(opts.FloorColor) / 255;
    cmap(3,:) = double(opts.FallbackColor) / 255;

    BACKGROUND_IDX = uint16(1);
    FLOOR_IDX      = uint16(2);
    FALLBACK_IDX   = uint16(3);

    % Collect unique names (excluding floor names) and assign palette slots
    allNames = string(labelTable.Name);
    uniqueNames = unique(allNames, 'stable');
    nonFloorNames = uniqueNames(~arrayfun(@(s) localIsFloorName(char(s)), uniqueNames));
    nColors = numel(nonFloorNames);

    paletteColors = localDistinguishableColors(nColors);
    name2idx = containers.Map('KeyType', 'char', 'ValueType', 'uint16');
    for i = 1:nColors
        nm = char(nonFloorNames(i));
        idx = uint16(3 + i);  % starts at index 4
        name2idx(nm) = idx;
        cmap(end+1,:) = paletteColors(i,:); %#ok<AGROW>
    end

    % === Build ID -> palette index LUT (vectorized per-frame lookup) ===
    maxID = max(double(labelTable.ID));
    id2idxLut = repmat(FALLBACK_IDX, maxID + 1, 1);

    for i = 1:height(labelTable)
        gid = double(labelTable.ID(i));
        nm  = char(labelTable.Name(i));
        if localIsFloorName(nm)
            id2idxLut(gid + 1) = FLOOR_IDX;
        elseif isKey(name2idx, nm)
            id2idxLut(gid + 1) = name2idx(nm);
        else
            id2idxLut(gid + 1) = FALLBACK_IDX;
        end
    end

    % === Open video writer ===
    vw = VideoWriter(outputFile, opts.Profile);
    vw.FrameRate = opts.FrameRate;
    if strcmp(opts.Profile, 'Indexed AVI')
        vw.Colormap = cmap;
    else
        vw.Quality = opts.Quality;
    end
    open(vw);
    cleanupObj = onCleanup(@() close(vw)); %#ok<NASGU>

    % === Write frames ===
    for k = 1:N
        frame = vidData(:,:,:,k);
        if opts.FlipUD
            frame = flipud(frame);
        end

        % Decode IDs: R + 256*G + 256^2*B - 1
        segIDs = double(frame(:,:,1)) ...
               + double(frame(:,:,2)) * 256 ...
               + double(frame(:,:,3)) * 65536 - 1;

        valid = segIDs >= 0;

        indexedFrame = repmat(BACKGROUND_IDX, H, W);
        if any(valid(:))
            sid = segIDs(valid);

            % Extend LUT if an ID exceeds the known range (rare)
            maxSid = max(sid(:));
            if maxSid + 1 > numel(id2idxLut)
                id2idxLut(end+1 : maxSid+1) = FALLBACK_IDX;
            end

            indexedFrame(valid) = id2idxLut(sid + 1);
        end

        if strcmp(opts.Profile, 'Indexed AVI')
            writeVideo(vw, uint8(indexedFrame));
        else
            writeVideo(vw, im2uint8(ind2rgb(indexedFrame, cmap)));
        end
    end
end

% =========================================================================
function t = localLabelTableFromSource(labelSource)
% Build a definitive ID/Name table without decoding any video frame.
    t = table();

    if istable(labelSource)
        if ismember('ID', labelSource.Properties.VariableNames) && ...
           ismember('Name', labelSource.Properties.VariableNames)
            t = table(double(labelSource.ID), string(labelSource.Name), ...
                'VariableNames', {'ID','Name'});
        end
        return;
    end

    if ischar(labelSource) || isstring(labelSource)
        src = char(labelSource);
        [~, ~, ext] = fileparts(src);

        if strcmpi(ext, '.xml')
            raw = mj_xml_labelmap(src);
            t = table(double(raw.ID), string(raw.Name), ...
                'VariableNames', {'ID','Name'});
        end
    end
end

% =========================================================================
function tf = localIsFloorName(nm)
% Returns true for names that should be colored as floor/background.
    tf = contains(nm, 'floor', 'IgnoreCase', true) || ...
         strcmpi(nm, 'world') || ...
         startsWith(nm, 'world/geom', 'IgnoreCase', true);
end

% =========================================================================
function colors = localDistinguishableColors(n)
% Generate n visually distinguishable colors using golden-ratio hue spacing
% with varied saturation and value (intensity) for maximum contrast.
% Returns nx3 double in [0,1].
    colors = zeros(n, 3);
    goldenAngle = 0.618033988749895;

    % Saturation/value pairs cycle through 3 levels for visual separation
    satLevels = [0.95, 0.70, 0.55];
    valLevels = [0.95, 0.85, 0.70];
    nLevels   = numel(satLevels);

    for i = 1:n
        hue = mod((i - 1) * goldenAngle, 1);
        lvl = mod(i - 1, nLevels) + 1;
        sat = satLevels(lvl);
        val = valLevels(lvl);
        colors(i,:) = hsv2rgb([hue, sat, val]);
    end
end

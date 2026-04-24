function t = mj_xml_labelmap(xmlPath)
% MJ_XML_LABELMAP Build segmentation ID -> name table from an MJCF XML file.
%
%   t = mj_xml_labelmap(xmlPath)
%
%   Uses mj_labelmap_mex to load the MJCF model and build an abstract
%   scene via mjv_updateScene (same code path as the Simulink S-function).
%   Returns the scene-level segid assigned to each visible model geom.
%
%   IMPORTANT: MuJoCo segmentation does NOT use model geom indices.
%   The segid is the position of each geom in the mjvScene.geoms[] array,
%   assigned during mjv_updateScene. Only visible geoms (non-zero alpha,
%   enabled group/category) receive segids. This function returns the
%   scene-level segids that match actual rendered segmentation pixels
%   (pixel_color = segid + 1).
%
%   Requires mj_labelmap_mex on the MATLAB path. Build it with:
%     run('tools/build_labelmap_mex.m')
%
% Input:
%   xmlPath - Path to the top-level MJCF XML file.
%
% Output:
%   t       - Table with columns:
%               ID         (uint32)  - scene-level segid (matches pixels)
%               Name       (cellstr) - "parentBody/geomName"
%               BodyName   (cellstr) - parent body name only
%               ObjectType (cellstr) - always 'geom' for model geoms

    if nargin < 1
        error('Usage: t = mj_xml_labelmap(xmlPath)');
    end

    xmlPath = char(xmlPath);

    % Resolve the file path
    resolved = localAbsPath(xmlPath, pwd);
    if isempty(resolved)
        onPath = which(xmlPath);
        if ~isempty(onPath)
            resolved = onPath;
        else
            error('XML file not found: %s', xmlPath);
        end
    end

    % Require the MEX — scene-level segids cannot be determined without it
    if exist('mj_labelmap_mex', 'file') ~= 3
        error('mj_xml_labelmap:mexRequired', ...
            ['mj_labelmap_mex not found. Build it with: ', ...
             'run(''tools/build_labelmap_mex.m'')']);
    end

    t = localBuildTableViaMex(resolved);
end

% =========================================================================
function t = localBuildTableViaMex(xmlPath)
% Call mj_labelmap_mex to get scene-level segid mapping.
% The MEX calls mjv_updateScene (same as the Simulink S-function) and
% returns the segid assigned to each scene geom.

    [~, ~, ~, ~, ~, segIds, segObjTypes, ~, segNames, ~] = ...
        mj_labelmap_mex(xmlPath);

    % Filter to model geoms only (mjOBJ_GEOM == 5)
    isModelGeom = (segObjTypes == 5);

    ids   = uint32(segIds(isModelGeom));
    names = segNames(isModelGeom);
    types = repmat({'geom'}, sum(isModelGeom), 1);

    % Extract body name from "bodyName/geomName" format
    nRows = numel(names);
    bodyNames = cell(nRows, 1);
    for k = 1:nRows
        nm = names{k};
        slashPos = find(nm == '/', 1, 'last');
        if ~isempty(slashPos)
            bodyNames{k} = nm(1:slashPos-1);
        else
            bodyNames{k} = '';
        end
    end

    t = table(ids, names, bodyNames, types, ...
        'VariableNames', {'ID', 'Name', 'BodyName', 'ObjectType'});
end

% =========================================================================
function absPath = localAbsPath(filePath, baseDir)
    absPath = '';
    if isempty(filePath), return; end

    if isfile(filePath)
        absPath = char(java.io.File(filePath).getCanonicalPath);
        return;
    end

    candidate = fullfile(baseDir, filePath);
    if isfile(candidate)
        absPath = char(java.io.File(candidate).getCanonicalPath);
        return;
    end

    onPath = which(filePath);
    if ~isempty(onPath)
        absPath = onPath;
    end
end

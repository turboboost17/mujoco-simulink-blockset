function classMap = mj_segmentation_to_yolo(segImage, labelSource, outputDir, imageFilename, opts)
% MJ_SEGMENTATION_TO_YOLO Export MuJoCo segmentation to YOLO annotation files.
%
%   classMap = mj_segmentation_to_yolo(segImage, labelSource, outputDir, imageFilename)
%   classMap = mj_segmentation_to_yolo(..., Name=Value)
%
%   Writes one YOLO-format .txt annotation file per image. Each line is:
%     <class_id> <x_center> <y_center> <width> <height>      (detect)
%     <class_id> <x1> <y1> <x2> <y2> ... <xn> <yn>          (segment)
%
%   Also writes/updates classes.txt in outputDir with the class name list.
%
% Inputs:
%   segImage      - uint8 HxWx3 RGB segmentation image (mjRND_IDCOLOR).
%   labelSource   - XML path or table (same as mj_segmentation_decoder).
%   outputDir     - Directory for output .txt files and classes.txt.
%   imageFilename - Base name for the annotation file (e.g. 'frame_0001').
%
% Name-Value Options:
%   Format        - 'segment' (default) or 'detect'.
%   MinArea       - Minimum object/component area in pixels to include.
%   IncludeNames  - string array of full names or body names to include.
%   ExcludeNames  - string array of full names or body names to exclude.
%   ClassDefinitions - struct array or table with ClassName and MatchNames.
%                   MatchNames accepts exact names or wildcard patterns and
%                   is checked against both full geom names and parent body
%                   names. When provided, class IDs are fixed by the order
%                   of the unique ClassName values in ClassDefinitions.
%   GroupBy       - 'auto' (default), 'body', or 'geom'. 'auto' uses the
%                   parent body when available, otherwise the geom name.
%   ClassMap      - Legacy name->class_id map used only when
%                   ClassDefinitions is not provided.
%   PreseedFromLabelSource - When true (default), pre-populates the legacy
%                   ClassMap from the full label source.
%
% Output:
%   classMap      - containers.Map(name -> class_id) used for this export.

    arguments
        segImage      uint8
        labelSource
        outputDir     (1,:) char
        imageFilename (1,:) char
        opts.Format   (1,:) char {mustBeMember(opts.Format, {'segment','detect'})} = 'segment'
        opts.MinArea  (1,1) double {mustBePositive} = 1
        opts.IncludeNames string = string.empty
        opts.ExcludeNames string = string.empty
        opts.ClassDefinitions = struct([])
        opts.GroupBy  (1,:) char {mustBeMember(opts.GroupBy, {'auto','body','geom'})} = 'auto'
        opts.ClassMap = []
        opts.PreseedFromLabelSource (1,1) logical = true
        opts.Debug (1,1) logical = false
        opts.DebugMaxItems (1,1) double {mustBePositive, mustBeInteger} = 15
    end

    [segIDs, ~, ~, idSummary] = mj_segmentation_decoder(segImage, labelSource);
    [H, W] = size(segIDs);

    hasBodyNameCol = ismember('BodyName', idSummary.Properties.VariableNames);
    bodyNamesFromSummary = strings(height(idSummary), 1);
    if hasBodyNameCol
        bodyNamesFromSummary = string(idSummary.BodyName);
    end

    classDefinitions = localNormalizeClassDefinitions(opts.ClassDefinitions);
    useClassDefinitions = ~isempty(classDefinitions);
    useIncludeFilter = ~isempty(opts.IncludeNames);
    useDefaultExclude = isempty(opts.ExcludeNames) && ~useIncludeFilter && ~useClassDefinitions;
    includeNames = string(opts.IncludeNames);
    excludeNames = string(opts.ExcludeNames);

    if useClassDefinitions
        classMap = localBuildFixedClassMap(classDefinitions);
    elseif isempty(opts.ClassMap)
        classMap = containers.Map('KeyType', 'char', 'ValueType', 'int32');
    else
        classMap = opts.ClassMap;
    end

    if opts.Debug
        fprintf('[mj_segmentation_to_yolo] image="%s" size=%dx%d uniqueVisibleIDs=%d mappedIDs=%d\n', ...
            imageFilename, H, W, height(idSummary), nnz(idSummary.IsMapped));
        fprintf('[mj_segmentation_to_yolo] filters: include=%d exclude=%d classDefs=%d groupBy=%s\n', ...
            numel(includeNames), numel(excludeNames), numel(classDefinitions), opts.GroupBy);
        if useIncludeFilter
            localPrintNameList('includeNames', includeNames, opts.DebugMaxItems);
        end
        if useClassDefinitions
            localPrintNameList('training classes', string({classDefinitions.ClassName}), opts.DebugMaxItems);
        end
    end

    if ~useClassDefinitions && isempty(opts.ClassMap) && opts.PreseedFromLabelSource
        labelTable = localGetLabelTable(labelSource);
        for rowIdx = 1:height(labelTable)
            rowName = string(labelTable.Name(rowIdx));
            rowBody = "";
            if ismember('BodyName', labelTable.Properties.VariableNames)
                rowBody = string(labelTable.BodyName(rowIdx));
            end

            if ~localShouldIncludeName(rowName, rowBody, useIncludeFilter, useDefaultExclude, includeNames, excludeNames)
                continue;
            end

            exportKey = localResolveExportKey(rowName, rowBody, opts.GroupBy);
            if strlength(exportKey) == 0
                continue;
            end

            exportKey = char(exportKey);
            if ~classMap.isKey(exportKey)
                classMap(exportKey) = int32(classMap.Count);
            end
        end
    end

    if ~isfolder(outputDir)
        mkdir(outputDir);
    end

    [~, baseName, ~] = fileparts(imageFilename);
    txtPath = fullfile(outputDir, [baseName '.txt']);
    fid = fopen(txtPath, 'w');
    if fid == -1
        error('Cannot open file for writing: %s', txtPath);
    end
    cleanupObj = onCleanup(@() fclose(fid));

    instanceKeys = strings(height(idSummary), 1);
    for rowIdx = 1:height(idSummary)
        rowName = string(idSummary.Name(rowIdx));
        rowBody = bodyNamesFromSummary(rowIdx);
        instanceKeys(rowIdx) = localResolveExportKey(rowName, rowBody, opts.GroupBy);
    end
    uniqueKeys = unique(instanceKeys(strlength(instanceKeys) > 0), 'stable');

    linesWritten = 0;
    skippedByNameFilter = 0;
    skippedByClassFilter = 0;
    skippedByArea = 0;
    skippedNoPixels = 0;
    exportedInstances = 0;

    for keyIdx = 1:numel(uniqueKeys)
        instanceKey = uniqueKeys(keyIdx);
        rowMask = (instanceKeys == instanceKey);
        rowIdx = find(rowMask, 1, 'first');
        rowName = string(idSummary.Name(rowIdx));
        rowBody = bodyNamesFromSummary(rowIdx);

        if ~localShouldIncludeName(rowName, rowBody, useIncludeFilter, useDefaultExclude, includeNames, excludeNames)
            skippedByNameFilter = skippedByNameFilter + 1;
            continue;
        end

        if useClassDefinitions
            [isAssigned, className] = localResolveTrainingClass(rowName, rowBody, instanceKey, classDefinitions);
            if ~isAssigned
                skippedByClassFilter = skippedByClassFilter + 1;
                continue;
            end
        else
            className = instanceKey;
            classKey = char(className);
            if ~classMap.isKey(classKey)
                classMap(classKey) = int32(classMap.Count);
            end
        end

        geomIDs = double(idSummary.ID(rowMask));
        mask = false(H, W);
        for geomIdx = 1:numel(geomIDs)
            mask = mask | (segIDs == geomIDs(geomIdx));
        end

        pixelCount = nnz(mask);
        if pixelCount == 0
            skippedNoPixels = skippedNoPixels + 1;
            continue;
        end
        if pixelCount < opts.MinArea
            skippedByArea = skippedByArea + 1;
            continue;
        end

        classID = classMap(char(className));
        exportedInstances = exportedInstances + 1;

        if strcmp(opts.Format, 'detect')
            [rows, cols] = find(mask);
            x1 = (min(cols) - 1) / W;
            y1 = (min(rows) - 1) / H;
            x2 = max(cols) / W;
            y2 = max(rows) / H;
            xc = (x1 + x2) / 2;
            yc = (y1 + y2) / 2;
            bw = x2 - x1;
            bh = y2 - y1;
            fprintf(fid, '%d %.6f %.6f %.6f %.6f\n', classID, xc, yc, bw, bh);
            linesWritten = linesWritten + 1;
            continue;
        end

        CC = bwconncomp(mask);
        for compIdx = 1:CC.NumObjects
            if numel(CC.PixelIdxList{compIdx}) < opts.MinArea
                skippedByArea = skippedByArea + 1;
                continue;
            end

            compMask = false(H, W);
            compMask(CC.PixelIdxList{compIdx}) = true;
            boundaries = bwboundaries(compMask, 'noholes');
            if isempty(boundaries)
                continue;
            end

            boundary = localSelectLargestBoundary(boundaries);
            if size(boundary, 1) > 200
                step = floor(size(boundary, 1) / 200);
                boundary = boundary(1:step:end, :);
            end
            if size(boundary, 1) < 3
                continue;
            end

            xn = (boundary(:, 2) - 0.5) / W;
            yn = (boundary(:, 1) - 0.5) / H;
            xn = max(0, min(1, xn));
            yn = max(0, min(1, yn));

            fprintf(fid, '%d', classID);
            for pointIdx = 1:numel(xn)
                fprintf(fid, ' %.6f %.6f', xn(pointIdx), yn(pointIdx));
            end
            fprintf(fid, '\n');
            linesWritten = linesWritten + 1;
        end
    end

    if opts.Debug
        fprintf(['[mj_segmentation_to_yolo] summary: linesWritten=%d classCount=%d ' ...
                 'instances=%d skipped(name=%d class=%d area=%d noPixels=%d)\n'], ...
                 linesWritten, classMap.Count, exportedInstances, skippedByNameFilter, ...
                 skippedByClassFilter, skippedByArea, skippedNoPixels);
    end

    localWriteClassesTxt(classMap, outputDir);
end

function tf = localShouldIncludeName(name, bodyName, useIncludeFilter, useDefaultExclude, includeNames, excludeNames)
    name = string(name);
    bodyName = string(bodyName);

    if strlength(name) == 0 && strlength(bodyName) == 0
        tf = false;
        return;
    end

    if useIncludeFilter
        tf = ismember(name, includeNames) || ismember(bodyName, includeNames);
        return;
    end

    if useDefaultExclude
        tf = ~(contains(name, 'floor', 'IgnoreCase', true) || ...
               startsWith(name, 'world/geom', 'IgnoreCase', true) || ...
               startsWith(name, 'ID_', 'IgnoreCase', true) || ...
               strcmpi(bodyName, 'world'));
        return;
    end

    tf = ~(ismember(name, excludeNames) || ismember(bodyName, excludeNames));
end

function exportKey = localResolveExportKey(name, bodyName, groupBy)
    name = string(name);
    bodyName = string(bodyName);

    switch groupBy
        case 'geom'
            exportKey = name;
        case 'body'
            exportKey = bodyName;
            if strlength(exportKey) == 0
                exportKey = name;
            end
        otherwise
            if strlength(bodyName) > 0
                exportKey = bodyName;
            else
                exportKey = name;
            end
    end
end

function classDefinitions = localNormalizeClassDefinitions(rawDefinitions)
    classDefinitions = struct('ClassName', {}, 'MatchNames', {});
    if isempty(rawDefinitions)
        return;
    end

    if istable(rawDefinitions)
        if ~ismember('ClassName', rawDefinitions.Properties.VariableNames) || ...
           ~ismember('MatchNames', rawDefinitions.Properties.VariableNames)
            error('ClassDefinitions table must contain ClassName and MatchNames columns.');
        end

        classDefinitions = repmat(struct('ClassName', "", 'MatchNames', string.empty), height(rawDefinitions), 1);
        for idx = 1:height(rawDefinitions)
            classDefinitions(idx).ClassName = string(rawDefinitions.ClassName(idx));
            classDefinitions(idx).MatchNames = string(rawDefinitions.MatchNames{idx});
        end
        return;
    end

    if ~isstruct(rawDefinitions)
        error('ClassDefinitions must be a struct array or a table.');
    end
    if ~all(isfield(rawDefinitions, {'ClassName', 'MatchNames'}))
        error('Each ClassDefinitions entry must contain ClassName and MatchNames fields.');
    end

    classDefinitions = repmat(struct('ClassName', "", 'MatchNames', string.empty), numel(rawDefinitions), 1);
    for idx = 1:numel(rawDefinitions)
        classDefinitions(idx).ClassName = string(rawDefinitions(idx).ClassName);
        classDefinitions(idx).MatchNames = string(rawDefinitions(idx).MatchNames);
    end
end

function classMap = localBuildFixedClassMap(classDefinitions)
    classNames = strings(numel(classDefinitions), 1);
    for idx = 1:numel(classDefinitions)
        classNames(idx) = string(classDefinitions(idx).ClassName);
    end
    classNames = unique(classNames(strlength(classNames) > 0), 'stable');

    classMap = containers.Map('KeyType', 'char', 'ValueType', 'int32');
    for idx = 1:numel(classNames)
        classMap(char(classNames(idx))) = int32(idx - 1);
    end
end

function [isAssigned, className] = localResolveTrainingClass(name, bodyName, exportKey, classDefinitions)
    targets = [string(name), string(bodyName), string(exportKey)];
    targets = unique(targets(strlength(targets) > 0), 'stable');

    isAssigned = false;
    className = "";
    for idx = 1:numel(classDefinitions)
        if localMatchesAnyTarget(targets, classDefinitions(idx).MatchNames)
            isAssigned = true;
            className = string(classDefinitions(idx).ClassName);
            return;
        end
    end
end

function tf = localMatchesAnyTarget(targets, patterns)
    targets = string(targets);
    targets = targets(strlength(targets) > 0);
    patterns = string(patterns);
    patterns = patterns(strlength(patterns) > 0);

    tf = false;
    for patternIdx = 1:numel(patterns)
        pattern = patterns(patternIdx);
        useWildcard = contains(pattern, '*') || contains(pattern, '?');
        if useWildcard
            expr = regexptranslate('wildcard', char(pattern));
            for targetIdx = 1:numel(targets)
                if ~isempty(regexp(char(targets(targetIdx)), ['^' expr '$'], 'once'))
                    tf = true;
                    return;
                end
            end
        elseif any(targets == pattern)
            tf = true;
            return;
        end
    end
end

function boundary = localSelectLargestBoundary(boundaries)
    lengths = cellfun(@(pts) size(pts, 1), boundaries);
    [~, idx] = max(lengths);
    boundary = boundaries{idx};
end

function labelTable = localGetLabelTable(labelSource)
    if istable(labelSource)
        labelTable = labelSource;
        return;
    end

    labelTable = table();
    if ~(ischar(labelSource) || isstring(labelSource))
        return;
    end

    srcResolved = localResolveFilePath(char(labelSource));
    if isempty(srcResolved)
        return;
    end

    [~, ~, ext] = fileparts(srcResolved);
    if strcmpi(ext, '.xml')
        labelTable = mj_xml_labelmap(srcResolved);
    end
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

function localPrintNameList(label, names, maxItems)
    names = unique(string(names), 'stable');
    names = names(strlength(names) > 0);
    if isempty(names)
        fprintf('[mj_segmentation_to_yolo] %s: <none>\n', label);
        return;
    end

    n = min(numel(names), maxItems);
    fprintf('[mj_segmentation_to_yolo] %s (showing %d/%d):\n', label, n, numel(names));
    for idx = 1:n
        fprintf('  - %s\n', names(idx));
    end
end

function localWriteClassesTxt(classMap, outputDir)
    names = classMap.keys;
    ids = cell2mat(classMap.values);
    [~, order] = sort(ids);
    names = names(order);

    fid = fopen(fullfile(outputDir, 'classes.txt'), 'w');
    if fid == -1
        return;
    end
    cleanupObj = onCleanup(@() fclose(fid));

    for idx = 1:numel(names)
        fprintf(fid, '%s\n', names{idx});
    end
end
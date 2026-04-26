function mj_parser_maskinit(blk, kind)
%MJ_PARSER_MASKINIT Refresh RGB/Depth parser mask state from current bus.
%
% Called from the MaskInitialization of the MuJoCo RGB Parser and
% MuJoCo Depth Parser library blocks (and from their dropdown
% callbacks) to keep the Selector / Reshape dimensions in sync with
% whatever camera bus the upstream MuJoCo Plant has produced.
%
%   mj_parser_maskinit(blk, 'rgb')
%   mj_parser_maskinit(blk, 'depth')
%
% Resolution staleness background:
%
%   mj_initbus_mex names the base-workspace Simulink.Bus objects with
%   a content-dependent hash, e.g. 'mj_bus_rgb_1401838870990032169'.
%   The hash changes whenever camera names or per-camera resolutions
%   change. A saved parser's 'inputBusType' literal can then refer to
%   a bus that no longer exists (or has a different shape), which used
%   to require the user to open each parser dialog and re-select the
%   camera before the model would compile.
%
%   This helper auto-rebinds 'inputBusType' to the bus carried by the
%   parser's actual input signal, or by the connected upstream MuJoCo
%   Plant. Only unconnected parsers fall back to scanning the base
%   workspace for the requested prefix. This avoids binding to stale
%   buses left over from old Plant mask initializations or other Plants
%   in the same model.
%
% Copyright 2022-2026 The MathWorks, Inc.

    prefix = sprintf('mj_bus_%s_', kind);
    [busName, busOptions] = resolveInputBus(blk, kind, prefix);

    if isempty(busName)
        % Nothing to bind to yet -- the Plant mask has not run yet,
        % or this parser is sitting in a model without a Plant. Leave
        % mask values untouched so user edits are preserved.
        return;
    end

    set_param(blk, 'inputBusType', busName);

    try
        inputStruct = Simulink.Bus.createMATLABStruct(busName);
    catch
        % Variable exists but cannot be materialised (e.g. partial
        % initialisation). Skip refresh; callback will retry next cycle.
        return;
    end

    fields = fieldnames(inputStruct);
    if isempty(fields)
        return;
    end

    % Refresh the 'Select Camera' dropdown's allowed values.
    mo = Simulink.Mask.get(blk);
    try
        mo.Parameters(1).TypeOptions = busOptions;
        mo.Parameters(2).TypeOptions = fields;
    catch
        % Non-fatal if the parameter shape differs.
    end

    % Reselect the camera if the previously-chosen one is gone.
    selectedCamera = get_param(blk, 'selectedCamera');
    camIndex = find(strcmp(selectedCamera, fields), 1);
    if isempty(camIndex)
        selectedCamera = fields{1};
        camIndex = 1;
        set_param(blk, 'selectedCamera', selectedCamera);
    end

    selectedData = inputStruct.(selectedCamera);
    selectedSize = size(selectedData);
    imageRows = selectedSize(1);
    imageCols = selectedSize(2);

    % Contiguous slice into the packed output vector -- computed from
    % numel() so per-camera resolutions and channel counts propagate
    % automatically.
    startingIndex = 1;
    for i = 1:(camIndex - 1)
        startingIndex = startingIndex + numel(inputStruct.(fields{i}));
    end
    endingIndex = startingIndex + numel(selectedData) - 1;

    set_param(blk, 'imageRows',     num2str(imageRows));
    set_param(blk, 'imageCols',     num2str(imageCols));
    set_param(blk, 'startingIndex', num2str(startingIndex));
    set_param(blk, 'endingIndex',   num2str(endingIndex));
end

function [busName, busOptions] = resolveInputBus(blk, kind, prefix)
    busName = compiledInputBus(blk, prefix);
    if ~isempty(busName)
        busOptions = {busName};
        return;
    end

    busName = connectedPlantBus(blk, kind);
    if ~isempty(busName)
        busOptions = {busName};
        return;
    end

    candidates = evalin('base', sprintf("who('-regexp','^%s')", prefix));
    candidates = candidates(:)';
    busOptions = candidates;

    currentBus = get_param(blk, 'inputBusType');
    if ~isempty(currentBus) && ischar(currentBus) && any(strcmp(currentBus, candidates))
        busName = currentBus;
    elseif ~isempty(candidates)
        busName = candidates{end};
    else
        busName = '';
    end
end

function busName = compiledInputBus(blk, prefix)
    busName = '';
    try
        dtypes = get_param(blk, 'CompiledPortDataTypes');
        if ~isfield(dtypes, 'Inport') || isempty(dtypes.Inport)
            return;
        end
        dtype = dtypes.Inport;
        if iscell(dtype)
            dtype = dtype{1};
        end
        dtype = char(dtype);
        dtype = regexprep(dtype, '^Bus:\s*', '');
        if startsWith(dtype, prefix)
            busName = dtype;
        end
    catch
    end
end

function busName = connectedPlantBus(blk, kind)
    busName = '';
    plant = connectedSourceBlock(blk);
    if isempty(plant) || ~isMuJoCoPlant(plant)
        return;
    end

    try
        xmlFile = get_param(plant, 'xmlFile');
        camWidth = numericMaskValue(plant, 'camWidth');
        camHeight = numericMaskValue(plant, 'camHeight');
        [~, ~, rgbBus, depthBus, ~] = mj_initbus(xmlFile, camWidth, camHeight);
    catch
        return;
    end

    switch kind
        case 'rgb'
            busName = rgbBus;
        case 'depth'
            busName = depthBus;
    end
end

function src = connectedSourceBlock(blk)
    src = '';
    try
        pc = get_param(blk, 'PortConnectivity');
        if isempty(pc) || pc(1).SrcBlock == -1
            return;
        end
        src = getfullname(pc(1).SrcBlock);
    catch
        src = '';
    end
end

function tf = isMuJoCoPlant(blk)
    tf = false;
    try
        ref = get_param(blk, 'ReferenceBlock');
        tf = strcmp(ref, 'mjLib/MuJoCo Plant');
    catch
    end
end

function value = numericMaskValue(blk, paramName)
    value = str2num(get_param(blk, paramName)); %#ok<ST2NM>
    if isempty(value)
        value = 0;
    end
end

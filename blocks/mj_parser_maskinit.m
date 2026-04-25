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
%   This helper auto-rebinds 'inputBusType' to the current bus of the
%   requested kind ('rgb' or 'depth') by scanning the base workspace
%   for the appropriate prefix, then recomputes imageRows/imageCols/
%   startingIndex/endingIndex from the current bus definition.
%
% Copyright 2022-2026 The MathWorks, Inc.

    prefix = sprintf('mj_bus_%s_', kind);

    % Candidate buses of the requested kind currently in the base
    % workspace.
    candidates = evalin('base', sprintf("who('-regexp','^%s')", prefix));

    busName = get_param(blk, 'inputBusType');
    valid = ~isempty(busName) && ischar(busName) && any(strcmp(busName, candidates));

    if ~valid
        if isempty(candidates)
            % Nothing to bind to yet -- the Plant mask has not run yet,
            % or this parser is sitting in a model without a Plant.
            % Leave mask values untouched so user edits are preserved.
            return;
        end
        busName = candidates{end};   % newest matching definition wins
        set_param(blk, 'inputBusType', busName);
    end

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

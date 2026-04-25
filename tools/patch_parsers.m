function patch_parsers(libPath)
%PATCH_PARSERS Programmatic fix for MuJoCo RGB/Depth Parser staleness.
%
%   patch_parsers('blocks/mjLib.slx')
%
% Wires the parser masks so they self-refresh from the current bus
% definitions at compile / load / parameter-change time. Previously
% this only happened when the user manually opened the mask dialog.
%
% Changes:
%   - Adds MaskInitialization bodies that call mj_parser_maskinit(gcb,...).
%   - Replaces the parameter-change callbacks with the same helper so
%     dialog interaction keeps working.
%   - Clears the Depth Parser's default 'inputBusType' (was an 'rgb_'
%     hash copy-paste) so first-drop auto-detect can bind correctly.
%   - Removes the Depth Parser's assignin('base','imageRows'/'imageCols',...)
%     pollution.

    arguments
        libPath (1,:) char = 'blocks/mjLib.slx'
    end

    [~, libName] = fileparts(libPath);
    load_system(libPath);

    set_param(libName, 'Lock', 'off');
    cleanup = onCleanup(@() localSaveAndLock(libName, libPath));

    rgb   = [libName '/MuJoCo RGB Parser'];
    depth = [libName '/MuJoCo Depth Parser'];

    % ---------- MuJoCo RGB Parser ----------
    setMaskInit(rgb,   "mj_parser_maskinit(gcb, 'rgb');");
    setCallback(rgb, 1, "mj_parser_maskinit(gcb, 'rgb');");  % inputBusType
    setCallback(rgb, 2, "mj_parser_maskinit(gcb, 'rgb');");  % selectedCamera

    % ---------- MuJoCo Depth Parser ----------
    setMaskInit(depth, "mj_parser_maskinit(gcb, 'depth');");
    setCallback(depth, 1, "mj_parser_maskinit(gcb, 'depth');");  % inputBusType
    setCallback(depth, 2, "mj_parser_maskinit(gcb, 'depth');");  % selectedCamera

    % Clear bad default 'inputBusType' on Depth Parser (was 'mj_bus_rgb_...')
    % so auto-detect picks a depth bus on first use.
    mv = get_param(depth, 'MaskValues');
    mn = get_param(depth, 'MaskNames');
    idx = find(strcmp(mn, 'inputBusType'), 1);
    if ~isempty(idx) && startsWith(mv{idx}, 'mj_bus_rgb_')
        % Use a stable non-hash placeholder: helper will auto-rebind on
        % first MaskInitialization when the real depth bus exists in the
        % base workspace.
        mv{idx} = 'mj_bus_depth_pending';
        set_param(depth, 'MaskValues', mv);
    end

    fprintf('Patched parsers in %s\n', libPath);
end

function localSaveAndLock(libName, libPath)
    try
        set_param(libName, 'Lock', 'on');
    catch
    end
    save_system(libName, libPath);
    fprintf('Saved %s\n', libPath);
end

function setMaskInit(blk, body)
    set_param(blk, 'MaskInitialization', char(body));
end

function setCallback(blk, paramIdx, body)
    cb = get_param(blk, 'MaskCallbacks');
    cb{paramIdx} = char(body);
    set_param(blk, 'MaskCallbacks', cb);
end

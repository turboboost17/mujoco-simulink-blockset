function [simOut, simMeta] = tRunSim(modelPath, opts)
%TRUNSIM Run a Simulink model with controlled mask parameters.
%
%   [simOut, simMeta] = tRunSim(modelPath)
%   [simOut, simMeta] = tRunSim(modelPath, Name=Value)
%
%   Loads the model, applies mj block mask overrides via mask parameter
%   name, runs the model for a short stop-time, and returns the SimulationOutput
%   and a metadata struct.
%
% Name-Value options:
%   StopTime          - default '0.05' (50 ms of sim time)
%   SolverMode        - 'Normal' or 'Accelerator' (default Normal)
%   MjBlockPath       - full path to the mujoco block (auto-detected if empty)
%   RgbOut            - 'on' | 'off'  (default [] = leave as-is)
%   DepthOut          - 'on' | 'off'  (default [] = leave as-is)
%   SegOut            - 'on' | 'off'  (default [] = leave as-is)
%   RenderingType     - 'Local' | 'Global' | 'None'   (default [] = leave)
%   CustomWidth       - numeric (0 = MJCF default, [] = leave)
%   CustomHeight      - numeric (0 = MJCF default, [] = leave)

    arguments
        modelPath (1,:) char
        opts.StopTime      (1,:) char = '0.05'
        opts.SolverMode    (1,:) char {mustBeMember(opts.SolverMode, {'Normal','Accelerator'})} = 'Normal'
        opts.MjBlockPath   (1,:) char = ''
        opts.RgbOut        char      = ''
        opts.DepthOut      char      = ''
        opts.SegOut        char      = ''
        opts.RenderingType char      = ''
        opts.CustomWidth            = []
        opts.CustomHeight           = []
    end

    [~, modelName] = fileparts(modelPath);
    simMeta.model = modelName;
    simMeta.startWall = tic;

    load_system(modelPath);
    c = onCleanup(@() closeIfOpen(modelName));

    mjBlk = opts.MjBlockPath;
    if isempty(mjBlk)
        candidates = find_system(modelName, 'LookUnderMasks','all', 'FollowLinks','on', 'ReferenceBlock','mjLib/MuJoCo Plant');
        if isempty(candidates)
            candidates = find_system(modelName, 'LookUnderMasks','all', 'FollowLinks','on', 'RegExp','on', 'Name','MuJoCo Plant');
        end
        assert(~isempty(candidates), 'tRunSim:noMjBlock', ...
            'No MuJoCo Plant block found in model %s', modelName);
        mjBlk = candidates{1};
    end
    simMeta.mjBlk = mjBlk;

    % Ensure xmlFile resolves on the current machine BEFORE touching any
    % other mask param that would force mask init to re-run mj_initbus.
    % Saved example models sometimes carry an absolute developer path.
    currentXml = get_param(mjBlk, 'xmlFile');
    if exist(currentXml, 'file') ~= 2
        resolvedXml = which('dummy.xml');
        if isempty(resolvedXml)
            resolvedXml = fullfile(fileparts(which('mj_maskinit')), 'dummy.xml');
        end
        assert(exist(resolvedXml,'file')==2, 'tRunSim:xmlNotFound', ...
            'dummy.xml not found on path; install.m may not have been run.');
        set_param(mjBlk, 'xmlFile', resolvedXml);
        simMeta.xmlRebased = resolvedXml;
    end

    safeSet = @(param, val) setIfPresent(mjBlk, param, val);
    if ~isempty(opts.RgbOut);        safeSet('rgbOutOption', opts.RgbOut); end
    if ~isempty(opts.DepthOut);      safeSet('depthOutOption', opts.DepthOut); end
    if ~isempty(opts.SegOut);        safeSet('segmentationOutOption', opts.SegOut); end
    if ~isempty(opts.RenderingType); safeSet('renderingType', opts.RenderingType); end
    if ~isempty(opts.CustomWidth)
        safeSet('camWidth',  mat2str(opts.CustomWidth));
    end
    if ~isempty(opts.CustomHeight); safeSet('camHeight', mat2str(opts.CustomHeight)); end

    set_param(modelName, 'StopTime', opts.StopTime, ...
                         'SimulationMode', opts.SolverMode, ...
                         'FastRestart','off');

    simOut = sim(modelName, 'ReturnWorkspaceOutputs','on');
    simMeta.wallTime = toc(simMeta.startWall);
end

function setIfPresent(blk, param, val)
    try
        get_param(blk, param); %#ok<GPRM>
        set_param(blk, param, val);
    catch me
        if contains(me.identifier, 'InvalidParameter') || contains(me.identifier, 'UnrecognizedParameter')
            % silently ignore params that don't exist on this mask revision
            return
        end
        rethrow(me);
    end
end

function closeIfOpen(m)
    try; close_system(m, 0); catch; end %#ok<NOSEMI>
end

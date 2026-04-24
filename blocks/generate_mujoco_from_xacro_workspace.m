function result = generate_mujoco_from_xacro_workspace(xacroFile, varargin)
%GENERATE_MUJOCO_FROM_XACRO_WORKSPACE Generate cached URDF and MJCF artifacts.
%
%   RESULT = GENERATE_MUJOCO_FROM_XACRO_WORKSPACE(XACROFILE) resolves a
%   workspace xacro file to URDF using importrobot_xacro_workspace, then calls
%   MuJoCo compile.exe twice: first to convert the URDF to MJCF, then again
%   to bake in any MuJoCo attach-based submodels.
%
%   Name-Value options:
%       WorkspaceRoot        - Workspace repository root
%       OutputDir            - Artifact root directory
%       CompileExe           - Full path to MuJoCo compile.exe
%       ArgDefaults          - containers.Map or struct of xacro arg defaults
%       RobotiqCompat        - Inject Robotiq launch-arg fallbacks (default true)
%       UnresolvedArgPolicy  - 'error' | 'warn' | 'empty'
%       ForceRebuild         - Ignore existing cache when true
%       KeepIntermediate     - Keep temporary xacro->urdf temp folder
%
%   RESULT fields:
%       CacheKey, ArtifactDir, ResolvedUrdfFile, BaseCompiledMjcfFile,
%       AttachSourceMjcfFile, CompiledMjcfFile, ManifestJsonFile,
%       CompileExe, CompileOutput

p = inputParser;
p.addRequired('xacroFile', @(x) ischar(x) || isstring(x));
p.addParameter('WorkspaceRoot', '', @(x) ischar(x) || isstring(x));
p.addParameter('OutputDir', '', @(x) ischar(x) || isstring(x));
p.addParameter('CompileExe', '', @(x) ischar(x) || isstring(x));
p.addParameter('ArgDefaults', [], @(x) isempty(x) || isa(x, 'containers.Map') || isstruct(x));
p.addParameter('RobotiqCompat', true, @(x) islogical(x) && isscalar(x));
p.addParameter('UnresolvedArgPolicy', 'warn', @(x) ischar(x) || isstring(x));
p.addParameter('ForceRebuild', false, @(x) islogical(x) && isscalar(x));
p.addParameter('KeepIntermediate', false, @(x) islogical(x) && isscalar(x));
p.parse(xacroFile, varargin{:});

xacroFile = char(p.Results.xacroFile);
if ~isfile(xacroFile)
    error('Xacro file not found: %s', xacroFile);
end
xacroFile = localCanonicalPath(xacroFile);

workspaceRoot = char(p.Results.WorkspaceRoot);
if isempty(workspaceRoot)
    workspaceRoot = fileparts(fileparts(mfilename('fullpath')));
end
workspaceRoot = localCanonicalPath(workspaceRoot);

initialize_xacro_import_environment('WorkspaceRoot', workspaceRoot, 'ExportToBase', false);

outputDir = char(p.Results.OutputDir);
if isempty(outputDir)
    outputDir = fullfile(workspaceRoot, 'matlab', 'generated_mujoco');
end
if ~isfolder(outputDir)
    mkdir(outputDir);
end
outputDir = localCanonicalPath(outputDir);

compileExe = char(p.Results.CompileExe);
if isempty(compileExe)
    compileExe = fullfile(workspaceRoot, '..', 'mujoco-simulink-blockset', 'lib', 'win64', 'mujoco', 'bin', 'compile.exe');
end
if ~isfile(compileExe)
    error('MuJoCo compile.exe not found: %s', compileExe);
end
compileExe = localCanonicalPath(compileExe);

cacheKey = localBuildCacheKey(xacroFile, p.Results.ArgDefaults, p.Results.RobotiqCompat, p.Results.UnresolvedArgPolicy);
artifactDir = fullfile(outputDir, cacheKey);
if ~isfolder(artifactDir)
    mkdir(artifactDir);
end

resolvedUrdfFile = fullfile(artifactDir, 'resolved_importrobot.urdf');
baseCompiledMjcfFile = fullfile(artifactDir, 'compiled_base_model.xml');
attachSourceMjcfFile = fullfile(artifactDir, 'attach_source_model.xml');
compiledMjcfFile = fullfile(artifactDir, 'compiled_model.xml');
manifestJsonFile = fullfile(artifactDir, 'manifest.json');

portableMjcfFile = fullfile(artifactDir, 'mujoco_model.xml');
portableUrdfFile = fullfile(artifactDir, 'robot_cell_full.urdf');
artifactExists = isfile(portableMjcfFile) && isfile(portableUrdfFile) && isfile(manifestJsonFile);
if artifactExists && ~p.Results.ForceRebuild
    result = localLoadManifest(manifestJsonFile);
    return
end

[~, info] = importrobot_xacro_workspace(xacroFile, ...
    'WorkspaceRoot', workspaceRoot, ...
    'ArgDefaults', p.Results.ArgDefaults, ...
    'RobotiqCompat', p.Results.RobotiqCompat, ...
    'RemoveRobotiqGripper', true, ...
    'UnresolvedArgPolicy', p.Results.UnresolvedArgPolicy, ...
    'DataFormat', 'struct', ...
    'KeepTempFiles', true);

copyfile(info.ResolvedUrdfFile, resolvedUrdfFile, 'f');
localEnsureUrdfMujocoCompilerBlock(resolvedUrdfFile);
localStripRobotiqFromUrdf(resolvedUrdfFile);
localPrepareMeshFallbackCopies(resolvedUrdfFile, artifactDir);

firstCompileOutput = localRunMujocoCompile(compileExe, resolvedUrdfFile, baseCompiledMjcfFile);
stagedRobotiqMjcfFile = localStageRobotiqMjcfAssets(artifactDir, workspaceRoot);
localAugmentCompiledMjcf(baseCompiledMjcfFile, attachSourceMjcfFile, resolvedUrdfFile, stagedRobotiqMjcfFile);
secondCompileOutput = localRunMujocoCompile(compileExe, attachSourceMjcfFile, compiledMjcfFile);

if ~p.Results.KeepIntermediate && isfolder(info.TempRoot)
    try
        rmdir(info.TempRoot, 's');
    catch
    end
end

meshesDir = fullfile(artifactDir, 'meshes');
localMakePortableMjcf(compiledMjcfFile, portableMjcfFile, meshesDir);

localExportPortableUrdf(xacroFile, meshesDir, portableUrdfFile, ...
    workspaceRoot, p.Results.ArgDefaults, p.Results.RobotiqCompat, ...
    p.Results.UnresolvedArgPolicy);

localCleanupIntermediateArtifacts(artifactDir);

manifest = struct;
manifest.CacheKey = cacheKey;
manifest.WorkspaceRoot = workspaceRoot;
manifest.SourceXacroFile = xacroFile;
manifest.ArtifactDir = artifactDir;
manifest.ResolvedUrdfFile = resolvedUrdfFile;
manifest.PortableMjcfFile = portableMjcfFile;
manifest.PortableUrdfFile = portableUrdfFile;
manifest.MeshesDir = meshesDir;
manifest.ManifestJsonFile = manifestJsonFile;
manifest.CompileExe = compileExe;
manifest.CompileOutput = struct('FromUrdf', firstCompileOutput, 'WithAttach', secondCompileOutput);
manifest.GenerateTimestamp = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));

localWriteText(manifestJsonFile, jsonencode(manifest, 'PrettyPrint', true));
result = manifest;
end

function key = localBuildCacheKey(xacroFile, argDefaults, robotiqCompat, unresolvedArgPolicy)
xacroText = fileread(xacroFile);
argDefaultsText = localSerializeArgDefaults(argDefaults);
keyText = [xacroFile newline xacroText newline argDefaultsText newline char(string(robotiqCompat)) newline char(unresolvedArgPolicy)];
key = localSha256Hex(keyText);
end

function out = localSerializeArgDefaults(argDefaults)
if isempty(argDefaults)
    out = '';
    return
end
if isa(argDefaults, 'containers.Map')
    k = sort(keys(argDefaults));
    parts = cell(1, numel(k));
    for i = 1:numel(k)
        parts{i} = [char(k{i}) '=' char(string(argDefaults(k{i})))];
    end
    out = strjoin(parts, ';');
    return
end
if isstruct(argDefaults)
    f = sort(fieldnames(argDefaults));
    parts = cell(1, numel(f));
    for i = 1:numel(f)
        parts{i} = [f{i} '=' char(string(argDefaults.(f{i})))];
    end
    out = strjoin(parts, ';');
    return
end
error('Unsupported ArgDefaults type.');
end

function hex = localSha256Hex(textIn)
md = java.security.MessageDigest.getInstance('SHA-256');
bytes = uint8(textIn);
md.update(bytes);
digest = typecast(md.digest(), 'uint8');
hexParts = arrayfun(@(x) sprintf('%02x', x), digest, 'UniformOutput', false);
hex = [hexParts{:}];
end

function p = localCanonicalPath(p)
try
    p = char(java.io.File(p).getCanonicalPath());
catch
    p = char(p);
end
end

function result = localLoadManifest(manifestJsonFile)
textIn = fileread(manifestJsonFile);
result = jsondecode(textIn);
end

function localWriteText(filePath, textIn)
fid = fopen(filePath, 'w');
if fid < 0
    error('Unable to open file for writing: %s', filePath);
end
fwrite(fid, textIn);
fclose(fid);
end

function localEnsureUrdfMujocoCompilerBlock(urdfFile)
textIn = fileread(urdfFile);

if contains(textIn, '<mujoco>')
    if ~contains(textIn, 'fusestatic=')
        textIn = regexprep(textIn, '<compiler', '<compiler strippath="false" fusestatic="false"', 'once');
        localWriteText(urdfFile, textIn);
    end
    return
end

block = [newline '  <mujoco>' newline ...
    '    <compiler strippath="false" fusestatic="false" balanceinertia="true" discardvisual="false"/>' newline ...
    '  </mujoco>'];

tagStart = strfind(textIn, '<robot');
if isempty(tagStart)
    error('Unable to locate <robot ...> tag while inserting URDF MuJoCo block.');
end
tagEnd = strfind(textIn(tagStart(1):end), '>');
if isempty(tagEnd)
    error('Unable to locate end of <robot ...> tag while inserting URDF MuJoCo block.');
end
tagEnd = tagStart(1) + tagEnd(1) - 1;
textOut = [textIn(1:tagEnd) block textIn(tagEnd + 1:end)];
localWriteText(urdfFile, textOut);
end

function localPrepareMeshFallbackCopies(urdfFile, artifactDir)
textIn = fileread(urdfFile);
textIn = regexprep(textIn, '<!--.*?-->', '', 'dotall');
tok = regexp(textIn, '<mesh\b[^>]*filename\s*=\s*"([^"]+)"', 'tokens');
if isempty(tok)
    return
end

for i = 1:numel(tok)
    src = strtrim(tok{i}{1});

    if startsWith(src, 'package://')
        continue
    end

    if startsWith(src, 'file://')
        src = extractAfter(src, 'file://');
    end

    srcPath = char(src);
    if ~isfile(srcPath)
        continue
    end

    [~, name, ext] = fileparts(srcPath);
    dst = fullfile(artifactDir, [name ext]);

    if ~isfile(dst)
        try
            copyfile(srcPath, dst, 'f');
        catch
            % Best-effort fallback for compile path stripping behavior.
        end
    end
end
end

function output = localRunMujocoCompile(compileExe, inputFile, outputFile)
%localRunMujocoCompile Invoke compile.exe with overwrite-safe behavior.
if isfile(outputFile)
    delete(outputFile);
end

compileCommand = sprintf('"%s" "%s" "%s"', compileExe, inputFile, outputFile);
[status, output] = system(compileCommand);
if status ~= 0 || contains(output, 'Error:')
    error('MuJoCo compile failed (exit %d): %s', status, output);
end
end

function stagedMjcfFile = localStageRobotiqMjcfAssets(artifactDir, workspaceRoot)
%localStageRobotiqMjcfAssets Copy the Robotiq MJCF and collision meshes into meshes/robotiq/.
sourceMjcfFile = fullfile(workspaceRoot, 'gripper_workspace', 'src', 'ros2_robotiq_gripper-humble', 'robotiq_description', 'mujoco', 'robotiq_2f_85_mujoco.xml');
sourceMeshDir = fullfile(workspaceRoot, 'gripper_workspace', 'src', 'ros2_robotiq_gripper-humble', 'robotiq_description', 'meshes', 'collision', '2f_85');
robotiqDir = fullfile(artifactDir, 'meshes', 'robotiq');
stagedMjcfFile = fullfile(artifactDir, 'robotiq_2f_85_mujoco.xml');

if ~isfile(sourceMjcfFile)
    warning('Robotiq MJCF not found; skipping staged submodel generation: %s', sourceMjcfFile);
    stagedMjcfFile = '';
    return
end

if ~isfolder(robotiqDir), mkdir(robotiqDir); end

meshFiles = dir(fullfile(sourceMeshDir, '*.stl'));
for i = 1:numel(meshFiles)
    copyfile(fullfile(meshFiles(i).folder, meshFiles(i).name), fullfile(robotiqDir, meshFiles(i).name), 'f');
end

modelText = fileread(sourceMjcfFile);
modelText = regexprep(modelText, '\s*meshdir="[^"]*"', '', 'once');
modelText = regexprep(modelText, '<body name="base_plate"([^>]*)pos="[^"]*"([^>]*)quat="[^"]*"([^>]*)>', '<body name="base_plate"$1pos="0 0 0"$2quat="1 0 0 0"$3>', 'once');
% Rewrite mesh file references to point at meshes/robotiq/
modelText = regexprep(modelText, 'file="([^"]+\.stl)"', 'file="meshes/robotiq/$1"');
localWriteText(stagedMjcfFile, modelText);
end

function localAugmentCompiledMjcf(inputMjcfFile, outputMjcfFile, urdfFile, robotiqMjcfFile)
textIn = fileread(inputMjcfFile);

[textIn, didInsertSite] = localInsertCamerasAndSites(textIn, urdfFile);
textIn = localAttachRobotiqGripper(textIn, outputMjcfFile, robotiqMjcfFile);
textIn = localInsertDefaultsBlock(textIn);
textIn = localInsertActuatorBlock(textIn);
textIn = localInsertEqualityBlock(textIn);
textIn = localInsertSensorBlock(textIn, didInsertSite);

localWriteText(outputMjcfFile, textIn);
end

function [textOut, didInsertSite] = localInsertCamerasAndSites(textIn, urdfFile)
%localInsertCamerasAndSites Insert camera/site elements into existing MJCF bodies.
%   Parses the resolved URDF for camera metadata in comments preceding
%   *_optical_frame links and inserts <camera> elements into the
%   corresponding bodies in the compiled MJCF.  Inserts a <site> into
%   the force_torque_frame body for force/torque sensing.
textOut = textIn;

cameraSpecs = localParseCameraSpecsFromUrdf(urdfFile);

for i = 1:numel(cameraSpecs)
    bodyName = cameraSpecs(i).BodyName;
    cameraName = cameraSpecs(i).CameraName;
    attrs = cameraSpecs(i).Attributes;

    if contains(textOut, sprintf('<camera name="%s"', cameraName))
        continue
    end

    attrStr = sprintf('name="%s" mode="fixed"', cameraName);
    if ~isempty(attrs)
        attrStr = [attrStr ' ' attrs]; %#ok<AGROW>
    end
    % ROS2 optical frame: X-right, Y-down, Z-forward.
    % MuJoCo camera frame: X-right, Y-up, Z-backward.
    % Apply 180deg rotation around X: diag([1 -1 -1]).
    if ~contains(attrStr, 'quat=') && ~contains(attrStr, 'euler=') && ~contains(attrStr, 'xyaxes=')
        attrStr = [attrStr ' quat="0 1 0 0"']; %#ok<AGROW>
    end

    cameraElem = ['<camera ' attrStr '/>'];
    textOut = localInsertChildIntoBody(textOut, bodyName, cameraElem);
end

if contains(textOut, 'name="force_torque_site"')
else
    updatedText = localInsertChildIntoBody(textOut, 'force_torque_frame', ...
        '<site name="force_torque_site" type="sphere" size="0.003" rgba="1 0.2 0.2 1"/>');
    textOut = updatedText;
end

didInsertSite = contains(textOut, 'name="force_torque_site"');
end

function textOut = localInsertChildIntoBody(textIn, bodyName, childElem)
textOut = textIn;

escapedBodyName = regexptranslate('escape', bodyName);
exprSelfClosing = sprintf('([ \t]*)<body name="%s"([^>]*)/>', escapedBodyName);
[matchSelf, tokSelf] = regexp(textOut, exprSelfClosing, 'match', 'tokens', 'once');
if ~isempty(matchSelf)
    indent = tokSelf{1};
    attrs = tokSelf{2};
    newTag = [indent '<body name="' bodyName '"' attrs '>' newline ...
              indent '  ' childElem newline ...
              indent '</body>'];
    textOut = strrep(textOut, matchSelf, newTag);
    return
end

exprOpen = sprintf('([ \t]*)<body name="%s"([^>]*)>', escapedBodyName);
[matchOpen, tokOpen] = regexp(textOut, exprOpen, 'match', 'tokens', 'once');
if isempty(matchOpen)
    return
end

indent = tokOpen{1};
newTag = [matchOpen newline indent '  ' childElem];
textOut = strrep(textOut, matchOpen, newTag);
end

function specs = localParseCameraSpecsFromUrdf(urdfFile)
%localParseCameraSpecsFromUrdf Extract camera metadata from URDF comments.
%   Finds comments containing <camera .../> immediately preceding
%   *_optical_frame link definitions and returns structured specs.
urdfText = fileread(urdfFile);
lines = splitlines(urdfText);

specs = struct('BodyName', {}, 'CameraName', {}, 'Attributes', {});

for i = 1:numel(lines)
    linkTok = regexp(lines{i}, '<link\s+name="([^"]*optical_frame[^"]*)"\s*/>', 'tokens', 'once');
    if isempty(linkTok)
        continue
    end
    bodyName = linkTok{1};

    cameraAttrs = '';
    for j = i-1:-1:max(1, i-5)
        camTok = regexp(lines{j}, '<!--.*?<camera\s+(.*?)\/?>\s*-->', 'tokens', 'once');
        if ~isempty(camTok)
            cameraAttrs = strtrim(camTok{1});
            break
        end
        stripped = strtrim(lines{j});
        if ~isempty(stripped) && ~startsWith(stripped, '<!--')
            break
        end
    end

    if isempty(cameraAttrs)
        continue
    end

    cameraName = regexprep(bodyName, '_color_optical_frame$', '');
    cameraName = regexprep(cameraName, '_optical_frame$', '');

    attrs = localProcessCameraAttrs(cameraAttrs);

    spec = struct;
    spec.BodyName = bodyName;
    spec.CameraName = cameraName;
    spec.Attributes = attrs;
    specs(end + 1) = spec; %#ok<AGROW>
end
end

function attrsOut = localProcessCameraAttrs(attrsIn)
%localProcessCameraAttrs Remove projection attribute; keep MuJoCo-compatible attrs.
attrsOut = regexprep(attrsIn, '\s*projection\s*=\s*"[^"]*"', '');
attrsOut = strtrim(attrsOut);
end

function textOut = localAttachRobotiqGripper(textIn, mjcfOutputFile, robotiqModelFile)
%localAttachRobotiqGripper Insert Robotiq MJCF submodel via MuJoCo attach.
%   The Robotiq URDF subtree is stripped during xacro preprocessing, and the
%   staged Robotiq MJCF is compiled in a second pass so the attach is baked.
textOut = textIn;

if isempty(robotiqModelFile) || ~isfile(robotiqModelFile)
    warning('Robotiq MJCF not found; skipping attach integration: %s', robotiqModelFile);
    return
end

modelFileForMjcf = localRelativePath(robotiqModelFile, fileparts(mjcfOutputFile));
modelFileForMjcf = strrep(modelFileForMjcf, '\\', '/');
assetLine = sprintf('    <model name="robotiq_2f85_model" file="%s"/>', modelFileForMjcf);
if ~contains(textOut, 'name="robotiq_2f85_model"')
    closeAsset = strfind(textOut, '</asset>');
    if ~isempty(closeAsset)
        idx = closeAsset(1);
        textOut = [textOut(1:idx-1) assetLine newline textOut(idx:end)];
    end
end

attachLine = '<attach model="robotiq_2f85_model" body="base_plate" prefix="rq_"/>';
if contains(textOut, attachLine)
    return
end

[tok, ~, endIdx] = regexp(textOut, '([ \t]*)<body name="gripper_base_link"[^>]*>', 'tokens', 'start', 'end', 'once');
if isempty(tok)
    warning('gripper_base_link body not found; skipping Robotiq attach insertion.');
    return
end

indent = tok{1};
textOut = [textOut(1:endIdx) newline indent '  ' attachLine textOut(endIdx+1:end)];
end

function localStripRobotiqFromUrdf(urdfFile)
%localStripRobotiqFromUrdf Remove Robotiq gripper links and joints from URDF.
%   Strips all <link> and <joint> elements whose name starts with
%   "robotiq_85_" so that compile.exe never sees the gripper subtree.
textIn = fileread(urdfFile);

% Remove <link name="robotiq_85_...">...</link> (multi-line)
textOut = regexprep(textIn, '\s*<link\s+name="robotiq_85_[^"]*"[^>]*>.*?</link>', '', 'dotall');
% Remove self-closing <link name="robotiq_85_..."/>
textOut = regexprep(textOut, '\s*<link\s+name="robotiq_85_[^"]*"[^/]*/>', '');
% Remove <joint name="robotiq_85_...">...</joint>
textOut = regexprep(textOut, '\s*<joint\s+name="robotiq_85_[^"]*"[^>]*>.*?</joint>', '', 'dotall');

if ~strcmp(textIn, textOut)
    localWriteText(urdfFile, textOut);
end
end

function relPath = localRelativePath(pathValue, baseDir)
pathValue = localCanonicalPath(pathValue);
baseDir = localCanonicalPath(baseDir);

baseWithSep = [baseDir filesep];
if strncmpi(pathValue, baseWithSep, numel(baseWithSep))
    relPath = pathValue(numel(baseWithSep) + 1:end);
else
    relPath = pathValue;
end
end

function textOut = localInsertDefaultsBlock(textIn)
if contains(textIn, '<default class="main">')
    textOut = textIn;
    return
end

block = [newline ...
    '  <default class="main">' newline ...
    '    <joint damping="100" armature="0.1" frictionloss="0"/>' newline ...
    '    <geom group="4" density="1"/>' newline ...
    '  </default>'];

insertIdx = strfind(textIn, '</asset>');
if ~isempty(insertIdx)
    idx = insertIdx(1) + numel('</asset>');
    textOut = [textIn(1:idx) block textIn(idx + 1:end)];
    return
end

insertIdx = strfind(textIn, '<worldbody>');
if ~isempty(insertIdx)
    idx = insertIdx(1) - 1;
    textOut = [textIn(1:idx) block newline textIn(idx + 1:end)];
    return
end

textOut = textIn;
end

function textOut = localInsertActuatorBlock(textIn)
if contains(textIn, '<actuator>')
    textOut = textIn;
    return
end

joints = {'J1','J2','J3','J4','J5','J6'};
lines = cell(1, numel(joints) + 3);
lines{1} = sprintf('\n  <actuator>');
for i = 1:numel(joints)
    lines{i + 1} = sprintf('    <position name="%s_ctrl" joint="%s" kp="300" kv="40"/>', joints{i}, joints{i});
end
k = numel(joints) + 2;
lines{k} = sprintf('  </actuator>\n');
block = strjoin(lines(1:k), '\n');

closeIdx = strfind(textIn, '</mujoco>');
if isempty(closeIdx)
    textOut = textIn;
    return
end
closeIdx = closeIdx(end);
textOut = [textIn(1:closeIdx-1) block textIn(closeIdx:end)];
end

function textOut = localInsertEqualityBlock(textIn)
%localInsertEqualityBlock No-op: gripper equality constraints are defined in
%   the standalone Robotiq MJCF submodel and injected via attach.
textOut = textIn;
end

function textOut = localInsertSensorBlock(textIn, didInsertSite)
if contains(textIn, '<sensor>')
    textOut = textIn;
    return
end

joints = {'J1','J2','J3','J4','J5','J6'};
lines = cell(1, 2 * numel(joints) + 4);
k = 1;
lines{k} = sprintf('\n  <sensor>');
k = k + 1;
for i = 1:numel(joints)
    lines{k} = sprintf('    <jointpos name="%s_pos" joint="%s"/>', joints{i}, joints{i});
    k = k + 1;
    lines{k} = sprintf('    <jointvel name="%s_vel" joint="%s"/>', joints{i}, joints{i});
    k = k + 1;
end
if didInsertSite
    lines{k} = '    <force name="force_torque_force" site="force_torque_site"/>';
    k = k + 1;
    lines{k} = '    <torque name="force_torque_torque" site="force_torque_site"/>';
    k = k + 1;
end
lines{k} = sprintf('  </sensor>\n');

block = strjoin(lines(1:k), '\n');
closeIdx = strfind(textIn, '</mujoco>');
if isempty(closeIdx)
    textOut = textIn;
    return
end
closeIdx = closeIdx(end);
textOut = [textIn(1:closeIdx-1) block textIn(closeIdx:end)];
end

function localCleanupIntermediateArtifacts(artifactDir)
%localCleanupIntermediateArtifacts Remove intermediate build files from the artifact dir.
intermediateFiles = {
    'compiled_base_model.xml'
    'attach_source_model.xml'
    'compiled_model.xml'
    'robotiq_2f_85_mujoco.xml'
    };
for i = 1:numel(intermediateFiles)
    f = fullfile(artifactDir, intermediateFiles{i});
    if isfile(f)
        delete(f);
    end
end
end

function localMakePortableMjcf(compiledMjcfFile, portableMjcfFile, meshesDir)
%localMakePortableMjcf Create a portable MJCF with relative mesh paths.
%   Copies all referenced mesh files into meshesDir organized by category
%   (visual, collision, robotiq) and rewrites file= attributes to relative paths.
sourceDir = fileparts(compiledMjcfFile);

visualDir = fullfile(meshesDir, 'visual');
collisionDir = fullfile(meshesDir, 'collision');
robotiqDir = fullfile(meshesDir, 'robotiq');
if ~isfolder(visualDir), mkdir(visualDir); end
if ~isfolder(collisionDir), mkdir(collisionDir); end
if ~isfolder(robotiqDir), mkdir(robotiqDir); end

textIn = fileread(compiledMjcfFile);

meshElems = regexp(textIn, '<mesh\s[^>]*/>', 'match');
for i = 1:numel(meshElems)
    elem = meshElems{i};
    nameTok = regexp(elem, '\sname="([^"]+)"', 'tokens', 'once');
    fileTok = regexp(elem, '\sfile="([^"]+)"', 'tokens', 'once');
    if isempty(nameTok) || isempty(fileTok)
        continue
    end
    meshName = nameTok{1};
    meshFileRef = fileTok{1};

    srcPath = strrep(meshFileRef, '/', filesep);
    if ~contains(srcPath, ':') && ~startsWith(srcPath, filesep)
        srcPath = fullfile(sourceDir, srcPath);
    end

    [~, srcName, srcExt] = fileparts(srcPath);
    if isempty(srcExt), srcExt = '.stl'; end

    if startsWith(meshName, 'rq_')
        category = 'robotiq';
    elseif contains(lower(srcPath), [filesep 'collision' filesep])
        category = 'collision';
    else
        category = 'visual';
    end

    dstFilename = [srcName srcExt];
    dstPath = fullfile(meshesDir, category, dstFilename);
    if isfile(srcPath)
        srcFull = java.io.File(srcPath).getCanonicalPath();
        dstFull = java.io.File(dstPath).getCanonicalPath();
        if ~strcmp(char(srcFull), char(dstFull))
            copyfile(srcPath, dstPath, 'f');
        end
    end

    newFileRef = ['meshes/' category '/' dstFilename];
    newElem = strrep(elem, ['file="' meshFileRef '"'], ['file="' newFileRef '"']);
    textIn = strrep(textIn, elem, newElem);
end

localWriteText(portableMjcfFile, textIn);
end

function localExportPortableUrdf(xacroFile, meshesDir, portableUrdfFile, workspaceRoot, argDefaults, robotiqCompat, unresolvedArgPolicy)
%localExportPortableUrdf Export a portable URDF with Robotiq and relative mesh paths.
visualDir = fullfile(meshesDir, 'visual');
collisionDir = fullfile(meshesDir, 'collision');
robotiqDir = fullfile(meshesDir, 'robotiq');
if ~isfolder(visualDir), mkdir(visualDir); end
if ~isfolder(collisionDir), mkdir(collisionDir); end
if ~isfolder(robotiqDir), mkdir(robotiqDir); end

[~, info] = importrobot_xacro_workspace(xacroFile, ...
    'WorkspaceRoot', workspaceRoot, ...
    'ArgDefaults', argDefaults, ...
    'RobotiqCompat', robotiqCompat, ...
    'RemoveRobotiqGripper', false, ...
    'UnresolvedArgPolicy', unresolvedArgPolicy, ...
    'DataFormat', 'struct', ...
    'KeepTempFiles', true);

urdfText = fileread(info.ResolvedUrdfFile);

expr = '<mesh\b[^>]*filename\s*=\s*"([^"]+)"';
[meshToks, tokenExtents] = regexp(urdfText, expr, 'tokens', 'tokenExtents');
rewritten = containers.Map('KeyType', 'char', 'ValueType', 'char');

for i = numel(meshToks):-1:1
    srcFileRef = strtrim(meshToks{i}{1});
    if rewritten.isKey(srcFileRef)
        newRef = rewritten(srcFileRef);
    else
        srcPath = strrep(srcFileRef, '/', filesep);
        if startsWith(srcPath, 'file://')
            srcPath = extractAfter(srcPath, 'file://');
        end

        if ~isfile(srcPath)
            continue
        end

        [~, name, ext] = fileparts(srcPath);
        if contains(lower(srcPath), ['robotiq_description' filesep 'meshes' filesep])
            category = 'robotiq';
        elseif contains(lower(srcPath), [filesep 'collision' filesep])
            category = 'collision';
        else
            category = 'visual';
        end

        dstFilename = [name ext];
        dstPath = fullfile(meshesDir, category, dstFilename);
        srcFull = char(java.io.File(srcPath).getCanonicalPath());
        dstFull = char(java.io.File(dstPath).getCanonicalPath());
        if ~strcmp(srcFull, dstFull)
            copyfile(srcPath, dstPath, 'f');
        end

        newRef = ['meshes/' category '/' dstFilename];
        rewritten(srcFileRef) = newRef;
    end

    tokenExtent = tokenExtents{i}(1, :);
    urdfText = [urdfText(1:tokenExtent(1) - 1) newRef urdfText(tokenExtent(2) + 1:end)];
end

localWriteText(portableUrdfFile, urdfText);

if isfolder(info.TempRoot)
    try
        rmdir(info.TempRoot, 's');
    catch
    end
end
end


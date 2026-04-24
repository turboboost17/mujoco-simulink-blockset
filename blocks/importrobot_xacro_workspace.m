function [robot, info] = importrobot_xacro_workspace(xacroFile, varargin)
%IMPORTROBOT_XACRO_WORKSPACE Import xacro with ROS substitution support.
%
%   ROBOT = IMPORTROBOT_XACRO_WORKSPACE(XACROFILE) preprocesses xacro files
%   to resolve ROS package substitutions such as $(find pkg), resolves
%   package:// mesh references, converts to URDF, and imports the result as
%   a rigidBodyTree using importrobot.
%
%   [ROBOT, INFO] = IMPORTROBOT_XACRO_WORKSPACE(...) also returns resolver
%   metadata for diagnostics and integration.
%
%   Name-Value options:
%       WorkspaceRoot           - Workspace root path
%       PackageMap              - containers.Map(packageName -> packageDir)
%       ArgDefaults             - containers.Map or struct of arg defaults
%       DataFormat              - 'struct' | 'row' | 'column'
%       MaxNumBodies            - max bodies for codegen workflows
%       CollisionDecomposition  - false/true/vhacdOptions
%       RobotiqCompat           - inject Robotiq launch-arg fallbacks
%       RemoveRobotiqGripper    - exclude Robotiq tooling xacro during preprocessing
%       UnresolvedArgPolicy     - 'error' | 'warn' | 'empty'
%       KeepTempFiles           - keep generated temp files when true

p = inputParser;
p.addRequired('xacroFile', @(x) ischar(x) || isstring(x));
p.addParameter('WorkspaceRoot', '', @(x) ischar(x) || isstring(x));
p.addParameter('PackageMap', [], @(x) isempty(x) || isa(x, 'containers.Map'));
p.addParameter('ArgDefaults', [], @(x) isempty(x) || isa(x, 'containers.Map') || isstruct(x));
p.addParameter('DataFormat', 'struct', @(x) ischar(x) || isstring(x));
p.addParameter('MaxNumBodies', 0, @(x) isnumeric(x) && isscalar(x) && x >= 0);
p.addParameter('CollisionDecomposition', false);
p.addParameter('RobotiqCompat', true, @(x) islogical(x) && isscalar(x));
p.addParameter('RemoveRobotiqGripper', false, @(x) islogical(x) && isscalar(x));
p.addParameter('UnresolvedArgPolicy', 'warn', @(x) ischar(x) || isstring(x));
p.addParameter('KeepTempFiles', false, @(x) islogical(x) && isscalar(x));
p.parse(xacroFile, varargin{:});

xacroFile = char(p.Results.xacroFile);
if ~isfile(xacroFile)
    error('Xacro file not found: %s', xacroFile);
end

workspaceRoot = char(p.Results.WorkspaceRoot);
if isempty(workspaceRoot)
    workspaceRoot = localInferWorkspaceRoot(xacroFile);
end

if isempty(p.Results.PackageMap)
    packageMap = localBuildPackageMap(workspaceRoot);
else
    packageMap = p.Results.PackageMap;
end

tempRoot = tempname;
mkdir(tempRoot);
cleanupObj = onCleanup(@() localCleanupTemp(tempRoot, p.Results.KeepTempFiles));

emptyArgDefaults = containers.Map('KeyType', 'char', 'ValueType', 'char');
globalArgDefaults = localCreateGlobalArgDefaults(p.Results.ArgDefaults, p.Results.RobotiqCompat);
argPolicy = lower(char(p.Results.UnresolvedArgPolicy));
processedRootXacro = localPreprocessXacroRecursive(xacroFile, tempRoot, workspaceRoot, packageMap, emptyArgDefaults, globalArgDefaults, argPolicy, p.Results.RemoveRobotiqGripper);

robotics.manip.internal.xacroSupport.convertXacroToURDF(processedRootXacro, 'FILE', tempRoot);
[~, xacroName] = fileparts(processedRootXacro);
generatedUrdf = fullfile(tempRoot, [xacroName, '.urdf']);
if ~isfile(generatedUrdf)
    error('URDF generation failed for xacro: %s', processedRootXacro);
end

urdfText = fileread(generatedUrdf);
urdfText = localResolveFindExpressions(urdfText, packageMap);
urdfText = localResolvePackageUriToAbsolute(urdfText, packageMap);

resolvedUrdfFile = fullfile(tempRoot, 'resolved_importrobot.urdf');
localWriteText(resolvedUrdfFile, urdfText);

robot = importrobot(resolvedUrdfFile, 'urdf', ...
    'DataFormat', p.Results.DataFormat, ...
    'MaxNumBodies', p.Results.MaxNumBodies, ...
    'CollisionDecomposition', p.Results.CollisionDecomposition);

info = struct;
info.WorkspaceRoot = workspaceRoot;
info.TempRoot = tempRoot;
info.ProcessedRootXacro = processedRootXacro;
info.ResolvedUrdfFile = resolvedUrdfFile;
info.PackageMap = packageMap;
info.GlobalArgDefaults = globalArgDefaults;
info.ProcessedFileCount = NaN;
info.KeepTempFiles = p.Results.KeepTempFiles;

if ~p.Results.KeepTempFiles
    clear cleanupObj
    localCleanupTemp(tempRoot, false);
end
end

function workspaceRoot = localInferWorkspaceRoot(seedFile)
cur = fileparts(seedFile);
while true
    if isfolder(fullfile(cur, '.git'))
        workspaceRoot = cur;
        return
    end
    parent = fileparts(cur);
    if strcmp(parent, cur)
        workspaceRoot = fileparts(seedFile);
        return
    end
    cur = parent;
end
end

function packageMap = localBuildPackageMap(workspaceRoot)
pkgXmlList = dir(fullfile(workspaceRoot, '**', 'package.xml'));
nameToCandidates = containers.Map('KeyType', 'char', 'ValueType', 'any');

for i = 1:numel(pkgXmlList)
    pkgXml = fullfile(pkgXmlList(i).folder, pkgXmlList(i).name);
    pkgDir = pkgXmlList(i).folder;
    pkgName = localReadPackageName(pkgXml);
    if isempty(pkgName)
        [~, pkgName] = fileparts(pkgDir);
    end

    if nameToCandidates.isKey(pkgName)
        candidates = nameToCandidates(pkgName);
        candidates{end + 1} = pkgDir;
        nameToCandidates(pkgName) = candidates;
    else
        nameToCandidates(pkgName) = {pkgDir};
    end
end

packageMap = containers.Map('KeyType', 'char', 'ValueType', 'char');
pkgNames = keys(nameToCandidates);
for i = 1:numel(pkgNames)
    pkgName = pkgNames{i};
    candidates = nameToCandidates(pkgName);
    bestIdx = 1;
    bestScore = inf;
    for j = 1:numel(candidates)
        score = localPackagePriorityScore(candidates{j});
        if score < bestScore
            bestScore = score;
            bestIdx = j;
        end
    end
    packageMap(pkgName) = candidates{bestIdx};
end
end

function score = localPackagePriorityScore(pathValue)
pathValue = lower(strrep(pathValue, '/', filesep));
if contains(pathValue, [filesep 'src' filesep])
    score = 1;
elseif contains(pathValue, [filesep 'install' filesep]) && contains(pathValue, [filesep 'share' filesep])
    score = 2;
else
    score = 3;
end
end

function pkgName = localReadPackageName(pkgXml)
pkgName = '';
try
    xDoc = xmlread(pkgXml);
    nodes = xDoc.getElementsByTagName('name');
    if nodes.getLength > 0
        firstNode = nodes.item(0);
        if ~isempty(firstNode) && ~isempty(firstNode.getTextContent)
            pkgName = strtrim(char(firstNode.getTextContent));
        end
    end
catch
    pkgName = '';
end
end

function outFile = localPreprocessXacroRecursive(srcFile, tempRoot, workspaceRoot, packageMap, inheritedArgDefaults, globalArgDefaults, argPolicy, removeRobotiqGripper)
srcFile = char(java.io.File(srcFile).getCanonicalPath());

raw = fileread(srcFile);
raw = localResolveFindExpressions(raw, packageMap);
rawForParsing = localStripXmlComments(raw);

localArgDefaults = localCollectArgDefaults(rawForParsing);
allArgDefaults = localMergeArgDefaults(inheritedArgDefaults, localArgDefaults);
raw = localResolveArgExpressions(raw, allArgDefaults, globalArgDefaults, argPolicy, srcFile);

includeTokens = regexp(rawForParsing, '<xacro:include[^>]*\sfilename\s*=\s*"([^"]+)"[^>]*/?>', 'tokens');
for includeIdx = 1:numel(includeTokens)
    includeExpr = includeTokens{includeIdx}{1};
    includeResolved = localResolveFindExpressions(includeExpr, packageMap);
    includeSrcAbs = localResolvePath(includeResolved, fileparts(srcFile));
    if removeRobotiqGripper && localShouldExcludeXacroInclude(includeSrcAbs)
        includePattern = ['\s*<xacro:include[^>]*filename\s*=\s*"' regexptranslate('escape', includeExpr) '"[^>]*/?>'];
        raw = regexprep(raw, includePattern, '', 'once');
        continue
    end

    includeOutAbs = localPreprocessXacroRecursive(includeSrcAbs, tempRoot, workspaceRoot, packageMap, allArgDefaults, globalArgDefaults, argPolicy, removeRobotiqGripper);

    pattern = ['filename\s*=\s*"' regexptranslate('escape', includeExpr) '"'];
    replacement = ['filename="' strrep(includeOutAbs, '\', '/') '"'];
    raw = regexprep(raw, pattern, replacement, 'once');
end

raw = localResolvePackageUriToAbsolute(raw, packageMap);

outFile = localMapSourceToTempPath(srcFile, tempRoot, workspaceRoot);
if ~isfolder(fileparts(outFile))
    mkdir(fileparts(outFile));
end
localWriteText(outFile, raw);
end

function textOut = localStripXmlComments(textIn)
%localStripXmlComments Remove XML comments before regex-based xacro parsing.
textOut = regexprep(textIn, '<!--.*?-->', '', 'dotall');
end

function tf = localShouldExcludeXacroInclude(includePath)
includePath = lower(strrep(includePath, '/', filesep));

excludedSuffixes = {
    [filesep 'src' filesep 'tooling_description' filesep 'urdf' filesep 'gripper.xacro']
    [filesep 'robotiq_description' filesep 'urdf' filesep 'robotiq_2f_85_macro.urdf.xacro']
    [filesep 'robotiq_description' filesep 'urdf' filesep '2f_85.ros2_control.xacro']
    };

tf = false;
for i = 1:numel(excludedSuffixes)
    if endsWith(includePath, excludedSuffixes{i})
        tf = true;
        return
    end
end
end

function argDefaults = localCollectArgDefaults(textIn)
argDefaults = containers.Map('KeyType', 'char', 'ValueType', 'char');

argTags = regexp(textIn, '<xacro:arg\b([^>]*)/?>', 'tokens');
for argTagIdx = 1:numel(argTags)
    attrs = argTags{argTagIdx}{1};
    nameTok = regexp(attrs, 'name\s*=\s*"([^"]+)"', 'tokens', 'once');
    if isempty(nameTok)
        continue
    end
    defaultTok = regexp(attrs, 'default\s*=\s*"([^"]*)"', 'tokens', 'once');
    if isempty(defaultTok)
        continue
    end
    argName = strtrim(nameTok{1});
    argDefault = defaultTok{1};
    argDefaults(argName) = argDefault;
end
end

function merged = localMergeArgDefaults(parentMap, childMap)
merged = containers.Map('KeyType', 'char', 'ValueType', 'char');

parentKeys = keys(parentMap);
for parentIdx = 1:numel(parentKeys)
    key = parentKeys{parentIdx};
    merged(key) = parentMap(key);
end

childKeys = keys(childMap);
for childIdx = 1:numel(childKeys)
    key = childKeys{childIdx};
    merged(key) = childMap(key);
end
end

function resolved = localResolveArgExpressions(textIn, argMap, globalArgMap, argPolicy, srcFile)
resolved = textIn;

argUses = regexp(resolved, '\$\(arg\s+([^)\s]+)\)', 'tokens');
for argUseIdx = 1:numel(argUses)
    argName = strtrim(argUses{argUseIdx}{1});
    if argMap.isKey(argName)
        argValue = argMap(argName);
    elseif globalArgMap.isKey(argName)
        argValue = globalArgMap(argName);
    else
        switch argPolicy
            case 'error'
                error('Unable to resolve xacro argument $(arg %s) in file: %s', argName, srcFile);
            case 'warn'
                warning('importrobot_xacro_workspace:UnresolvedArg', ...
                    'Unresolved xacro argument $(arg %s) in %s. Replacing with empty string.', argName, srcFile);
                argValue = '';
            case 'empty'
                argValue = '';
            otherwise
                error('Unsupported UnresolvedArgPolicy: %s', argPolicy);
        end
    end
    pattern = ['\$\(arg\s+' regexptranslate('escape', argName) '\s*\)'];
    resolved = regexprep(resolved, pattern, argValue);
end
end

function argDefaults = localCreateGlobalArgDefaults(userDefaults, robotiqCompat)
argDefaults = containers.Map('KeyType', 'char', 'ValueType', 'char');

if robotiqCompat
    argDefaults('use_fake_hardware') = 'true';
    argDefaults('com_port') = '/dev/ttyUSB0';
end

if isempty(userDefaults)
    return
end

if isa(userDefaults, 'containers.Map')
    userKeys = keys(userDefaults);
    for idx = 1:numel(userKeys)
        key = char(userKeys{idx});
        argDefaults(key) = char(string(userDefaults(key)));
    end
elseif isstruct(userDefaults)
    fields = fieldnames(userDefaults);
    for idx = 1:numel(fields)
        key = char(fields{idx});
        argDefaults(key) = char(string(userDefaults.(key)));
    end
else
    error('ArgDefaults must be a containers.Map or struct.');
end
end

function outPath = localMapSourceToTempPath(srcPath, tempRoot, workspaceRoot)
workspaceRoot = char(java.io.File(workspaceRoot).getCanonicalPath());
srcPath = char(java.io.File(srcPath).getCanonicalPath());

rootWithSep = [workspaceRoot filesep];
if strncmpi(srcPath, rootWithSep, numel(rootWithSep))
    relPath = srcPath(numel(rootWithSep) + 1:end);
    outPath = fullfile(tempRoot, relPath);
else
    [~, base, ext] = fileparts(srcPath);
    key = char(java.util.UUID.randomUUID);
    outPath = fullfile(tempRoot, 'external', [base '_' key ext]);
end
end

function resolved = localResolveFindExpressions(textIn, packageMap)
resolved = textIn;
tokens = regexp(textIn, '\$\(find\s+([^)\s]+)\)', 'tokens');
for i = 1:numel(tokens)
    pkg = strtrim(tokens{i}{1});
    if ~packageMap.isKey(pkg)
        error('Unable to resolve ROS package in $(find ...): %s', pkg);
    end
    pkgPath = strrep(packageMap(pkg), '\', '/');
    pattern = ['\$\(find\s+' regexptranslate('escape', pkg) '\s*\)'];
    resolved = regexprep(resolved, pattern, pkgPath);
end
end

function resolved = localResolvePackageUriToAbsolute(textIn, packageMap)
tokens = regexp(textIn, 'package://([^/"\s]+)/', 'tokens');
resolved = textIn;
for i = 1:numel(tokens)
    pkg = tokens{i}{1};
    if ~packageMap.isKey(pkg)
        error('Unable to resolve package URI reference for package: %s', pkg);
    end
    pkgPath = strrep(packageMap(pkg), '\', '/');
    expr = ['package://' regexptranslate('escape', pkg) '/'];
    resolved = regexprep(resolved, expr, [pkgPath '/']);
end
end

function p = localResolvePath(pathExpr, baseDir)
pathExpr = strtrim(pathExpr);
if isempty(pathExpr)
    error('Empty include filename in xacro include.');
end

if contains(pathExpr, '$(')
    error('Unsupported unresolved substitution in include filename: %s', pathExpr);
end

if ~isempty(regexp(pathExpr, '^[A-Za-z]:[\\/]', 'once')) || startsWith(pathExpr, '/') || startsWith(pathExpr, '\\')
    p = pathExpr;
else
    p = fullfile(baseDir, pathExpr);
end

try
    p = char(java.io.File(p).getCanonicalPath());
catch
    p = strrep(p, '/', filesep);
    if ~isfile(p)
        error('Failed to canonicalize include path: %s (base: %s)', pathExpr, baseDir);
    end
end

if ~isfile(p)
    error('Included xacro file not found: %s', p);
end
end

function localWriteText(filePath, textIn)
fid = fopen(filePath, 'w');
if fid < 0
    error('Unable to open file for writing: %s', filePath);
end
fwrite(fid, textIn);
fclose(fid);
end

function localCleanupTemp(tempRoot, keepTempFiles)
if keepTempFiles
    return
end
if isfolder(tempRoot)
    try
        rmdir(tempRoot, 's');
    catch
    end
end
end

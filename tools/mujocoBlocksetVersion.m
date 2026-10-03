function v = mujocoBlocksetVersion(minRelease)
%MUJOCOBLOCKSETVERSION Release of this blockset and the MuJoCo runtime it bundles.
%   v = mujocoBlocksetVersion() returns a struct with fields
%     Release  blockset release tag 'M.m.p.r' (see README "Release Tags")
%     MuJoCo   MuJoCo runtime version 'M.m.p' (MJ_VER in install.m)
%     Root     blockset root folder
%
%   mujocoBlocksetVersion(minRelease) also errors with
%   'mujoco:blockset:VersionTooOld' when Release is older than minRelease
%   ('M.m.p.r', missing trailing fields count as 0). Dependent projects call
%   this from their startup check.

% Bump with each release tag; the first three fields follow MJ_VER in install.m.
release = '3.12.0.0';

root = fileparts(fileparts(mfilename('fullpath')));
v = struct('Release', release, 'MuJoCo', localMuJoCoVersion(root), 'Root', root);

if nargin > 0
    if localCompare(release, char(minRelease)) < 0
        error('mujoco:blockset:VersionTooOld', ...
            'MuJoCo Simulink blockset %s at %s is older than the required %s.', ...
            release, root, char(minRelease));
    end
end
end

function ver = localMuJoCoVersion(root)
% The installed runtime when install.m has run, else what install.m would fetch.
ver = '';
if ispref('mujoco', 'MJ_VER')
    ver = char(getpref('mujoco', 'MJ_VER'));
    return
end
installFile = fullfile(root, 'install.m');
if isfile(installFile)
    tok = regexp(fileread(installFile), 'MJ_VER\s*=\s*''([0-9.]+)''', 'tokens', 'once');
    if ~isempty(tok)
        ver = tok{1};
    end
end
end

function c = localCompare(a, b)
% -1, 0, 1 for a < b, a == b, a > b on dotted numeric versions.
x = localParts(a);
y = localParts(b);
n = max(numel(x), numel(y));
x(end+1:n) = 0;
y(end+1:n) = 0;
d = find(x ~= y, 1);
if isempty(d)
    c = 0;
else
    c = sign(x(d) - y(d));
end
end

function p = localParts(s)
p = str2double(strsplit(s, '.'));
if any(isnan(p))
    error('mujoco:blockset:BadVersion', 'Version "%s" is not dotted numeric (M.m.p.r).', s);
end
end

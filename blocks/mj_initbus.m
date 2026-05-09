function [a,b,c,d,e,f] = mj_initbus(xmlPath, camWidths, camHeights)
% Copyright 2022-2023 The MathWorks, Inc.
% mj_initbus_mex only reads model metadata and creates buses. Keep it in the
% MATLAB process so model/plugin loading uses the same environment as the
% runtime MEX functions.
%
% Inputs:
%   xmlPath    - Path to MuJoCo XML file
%   camWidths  - (optional) Scalar or vector of custom camera widths per camera (<=0 means use MJCF default)
%   camHeights - (optional) Scalar or vector of custom camera heights per camera (<=0 means use MJCF default)
%
% Per-camera resolution control:
%   - Scalar: applies to all cameras
%   - Vector: applies per-camera (missing entries use MJCF default)
%   - Values <= 0: use MJCF default offwidth/offheight
%
if nargin < 2
    camWidths = 0;  % Use MJCF default
end
if nargin < 3
    camHeights = 0;  % Use MJCF default
end

xmlPath = resolveXmlPath(xmlPath);
[a,b,c,d,e,f] = mj_initbus_mex(xmlPath, camWidths, camHeights);
end

function resolvedPath = resolveXmlPath(xmlPath)
resolvedPath = char(xmlPath);
matlabPathMatch = which(resolvedPath);
if ~isempty(matlabPathMatch)
    resolvedPath = matlabPathMatch;
elseif isfile(resolvedPath) && ~isAbsolutePath(resolvedPath)
    resolvedPath = fullfile(pwd, resolvedPath);
end
end

function tf = isAbsolutePath(filePath)
if ispc
    tf = ~isempty(regexp(filePath, '^[A-Za-z]:[\/]|^\\', 'once'));
else
    tf = startsWith(filePath, filesep);
end
end
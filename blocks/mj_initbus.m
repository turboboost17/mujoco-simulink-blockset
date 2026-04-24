function [a,b,c,d,e,f] = mj_initbus(xmlPath, camWidths, camHeights)
% Copyright 2022-2023 The MathWorks, Inc.
% Lets just be on safe side and run mj_initbus_mex in a separate
% process. It calls glfw functions which work best in a main thread of
% a separate process.
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
persistent mh
if ~(isa(mh,'matlab.mex.MexHost') && isvalid(mh))
    mh = mexhost;
end

if nargin < 2
    camWidths = 0;  % Use MJCF default
end
if nargin < 3
    camHeights = 0;  % Use MJCF default
end

[a,b,c,d,e,f] = feval(mh, 'mj_initbus_mex', xmlPath, camWidths, camHeights);
%     [a,b,c,d,e,f] = mj_initbus_mex(xmlPath, camWidths, camHeights);
end
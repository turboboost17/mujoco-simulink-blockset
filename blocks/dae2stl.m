function stlFiles = dae2stl(inputPath)
%DAE2STL Convert COLLADA .dae mesh files to .stl files.
%   stlFiles = DAE2STL(inputPath) converts the COLLADA file(s) referenced by
%   inputPath to STL. inputPath may be a single .dae file or a folder. When a
%   folder is supplied, every .dae file found within it (searched
%   recursively) is converted. Each STL is written next to its source .dae
%   using the same base name. The full paths of the generated STL files are
%   returned in the cell array stlFiles.
%
%   This function relies only on built-in MATLAB functionality:
%   READSURFACEMESH (COLLADA reader) and WRITESURFACEMESH (binary STL writer).
%
%   Example:
%       % Convert a single file
%       dae2stl('robot/meshes/link0.dae');
%
%       % Convert every .dae under a folder tree
%       dae2stl('robot/meshes');
%
%   See also READSURFACEMESH, WRITESURFACEMESH, SURFACEMESH.

    arguments
        inputPath (1,:) char {mustBeNonempty}
    end

    % Gather the list of .dae files to convert.
    if isfolder(inputPath)
        listing = dir(fullfile(inputPath, '**', '*.dae'));
        daeFiles = fullfile({listing.folder}, {listing.name});
    elseif isfile(inputPath)
        [~, ~, ext] = fileparts(inputPath);
        if ~strcmpi(ext, '.dae')
            error('dae2stl:notDae', '"%s" is not a .dae file.', inputPath);
        end
        daeFiles = {inputPath};
    else
        error('dae2stl:invalidPath', ...
            'Input "%s" is not an existing file or folder.', inputPath);
    end

    if isempty(daeFiles)
        warning('dae2stl:noFiles', 'No .dae files found in "%s".', inputPath);
        stlFiles = {};
        return
    end

    stlFiles = cell(1, numel(daeFiles));
    for k = 1:numel(daeFiles)
        daeFile = daeFiles{k};
        [folder, base] = fileparts(daeFile);
        stlFile = fullfile(folder, [base '.stl']);

        mesh = readSurfaceMesh(daeFile);
        writeSurfaceMesh(mesh, stlFile, Encoding="binary");

        stlFiles{k} = stlFile;
        fprintf('Converted %s -> %s\n', daeFile, stlFile);
    end
end

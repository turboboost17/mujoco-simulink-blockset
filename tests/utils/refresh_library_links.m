function refresh_library_links(modelName)
%REFRESH_LIBRARY_LINKS Force-restore library links in a Simulink model.
%   Used by the regression harness to reconcile example .slx files with
%   the current mjLib library after S-function port changes.

    load_system('mjLib');
    load_system(modelName);

    % Find all linked blocks and restore them from the library
    linked = find_system(modelName, 'LookUnderMasks','all', ...
        'FollowLinks','off', 'RegExp','on', 'LinkStatus','(resolved|implicit|inactive)');
    for i = 1:numel(linked)
        try
            set_param(linked{i}, 'LinkStatus', 'restore');
        catch
            % silently ignore blocks that do not support restore
        end
    end

    % Ensure mask init has run
    mjPlants = find_system(modelName, 'LookUnderMasks','all', ...
        'FollowLinks','on', 'ReferenceBlock','mjLib/MuJoCo Plant');
    for i = 1:numel(mjPlants)
        try
            set_param(mjPlants{i}, 'OpenFcn', get_param(mjPlants{i},'OpenFcn'));
        catch; end
    end
end

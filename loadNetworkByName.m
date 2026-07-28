function [net, inputSize] = loadNetworkByName(name)
% loadNetworkByName  Load a SPECIFIC pretrained network by name (no
% fallback). Errors clearly if that network's Add-On isn't installed.
%
%   [net, inputSize] = loadNetworkByName('resnet18')

try
    net = feval(name);
catch ME
    error(['Could not load "%s". Make sure its Add-On is installed ' ...
        '(Home tab -> Add-Ons -> Get Add-Ons -> search "%s").\n' ...
        'Original error: %s'], name, name, ME.message);
end

sz = net.Layers(1).InputSize;
inputSize = sz(1:2);
fprintf('Loaded network: %s (input size %dx%d)\n', name, inputSize(1), inputSize(2));

end

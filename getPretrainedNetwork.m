function [net, netName, inputSize] = getPretrainedNetwork()
% getPretrainedNetwork  Return the first available pretrained CNN.
%
%   Tries, in order: AlexNet, GoogLeNet, ResNet18.
%   Each requires its corresponding Add-On:
%     "Deep Learning Toolbox Model for AlexNet Network"
%     "Deep Learning Toolbox Model for GoogLeNet Network"
%     "Deep Learning Toolbox Model for ResNet-18 Network"
%
%   Install missing add-ons via: Home tab -> Add-Ons -> Get Add-Ons

candidates = {'alexnet', 'googlenet', 'resnet18'};

for i = 1:numel(candidates)
    name = candidates{i};
    try
        net = feval(name);
        netName = name;
        sz = net.Layers(1).InputSize;
        inputSize = sz(1:2);   % [H W]
        fprintf('Using pretrained network: %s (input size %dx%d)\n', ...
            netName, inputSize(1), inputSize(2));
        return;
    catch
        fprintf('%s not available, trying next option...\n', name);
    end
end

error(['No pretrained network found. Install at least one of: ' ...
    'AlexNet, GoogLeNet, or ResNet18 via Add-On Explorer ' ...
    '(Home tab -> Add-Ons -> Get Add-Ons).']);

end
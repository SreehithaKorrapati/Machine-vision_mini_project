function lgraphOrLayers = buildTransferNetwork(net, netName, classNames)
% buildTransferNetwork  Swap the final learnable + classification layers
% of a pretrained network so it outputs numel(classNames) classes
% instead of the original 1000 ImageNet classes.
%
%   lgraphOrLayers = buildTransferNetwork(net, netName, classNames)
%
%   net        : network object returned by getPretrainedNetwork
%   netName    : 'alexnet' | 'googlenet' | 'resnet18'
%   classNames : cellstr / categorical categories, e.g. {'DR','nonDR'}

numClasses = numel(classNames);

switch lower(netName)

    case 'alexnet'
        % AlexNet is a SeriesNetwork -> work with a plain layer array
        layers = net.Layers;

        newFC = fullyConnectedLayer(numClasses, ...
            'Name', 'fc_transfer', ...
            'WeightLearnRateFactor', 10, ...
            'BiasLearnRateFactor', 10);

        newOutput = classificationLayer('Name', 'classoutput_transfer');

        layers(end-2) = newFC;      % replace 'fc8'
        layers(end)   = newOutput;  % replace 'output'

        lgraphOrLayers = layers;

    case {'googlenet', 'resnet18'}
        % DAG networks -> work with a layerGraph
        lgraph = layerGraph(net);

        if strcmpi(netName, 'googlenet')
            fcName  = 'loss3-classifier';
            outName = 'output';
        else % resnet18
            fcName  = 'fc1000';
            outName = 'ClassificationLayer_predictions';
        end

        newFC = fullyConnectedLayer(numClasses, ...
            'Name', 'fc_transfer', ...
            'WeightLearnRateFactor', 10, ...
            'BiasLearnRateFactor', 10);

        newOutput = classificationLayer('Name', 'classoutput_transfer');

        lgraph = replaceLayer(lgraph, fcName, newFC);
        lgraph = replaceLayer(lgraph, outName, newOutput);

        lgraphOrLayers = lgraph;

    otherwise
        error('Unrecognized network name: %s', netName);
end

end

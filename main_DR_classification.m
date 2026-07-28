%% main_DR_classification.m
% Diabetic Retinopathy (DR) vs nonDR classification via transfer learning
%
% Pipeline:
%   1. Sort raw Train/Test images into DR / nonDR folders
%   2. For each network in networksToCompare (e.g. AlexNet, ResNet18):
%      sweep learning rates x epochs, retraining final layers each time
%   3. Record test accuracy for every (network, LR, epoch) combo in a table
%   4. Summarize accuracy per network architecture (comparison table + bar chart)
%   5. For the single best combo overall: plot ROC curve + confusion matrix
%
% EDIT THESE PATHS to point at your unzipped DS_IDRID folder:
rawTrainFolder = fullfile('DS_IDRID', 'DS_IDRID', 'Train');
rawTestFolder  = fullfile('DS_IDRID', 'DS_IDRID', 'Test');

resultsFolder = 'results';
if ~exist(resultsFolder, 'dir'), mkdir(resultsFolder); end

rng(0); % reproducibility

%% 1. Organize raw images into DR / nonDR class folders
trainSortedFolder = organizeIDRiDData(rawTrainFolder, fullfile('sorted_data', 'Train'));
testSortedFolder  = organizeIDRiDData(rawTestFolder,  fullfile('sorted_data', 'Test'));

imdsTrain = imageDatastore(trainSortedFolder, ...
    'IncludeSubfolders', true, 'LabelSource', 'foldernames');
imdsTest  = imageDatastore(testSortedFolder, ...
    'IncludeSubfolders', true, 'LabelSource', 'foldernames');

fprintf('Train set: %d images\n', numel(imdsTrain.Labels));
fprintf('Test set : %d images\n', numel(imdsTest.Labels));
disp('Train class counts:'); disp(countEachLabel(imdsTrain));
disp('Test class counts:');  disp(countEachLabel(imdsTest));

classNames = categories(imdsTrain.Labels); % e.g. {'DR';'nonDR'}
positiveClass = 'DR';  % the "positive" class for ROC purposes

%% 2. Networks to compare
% List every network you have the Add-On for. The script will train
% and compare ALL of them across the learning-rate/epoch grid below.
% Common options: 'alexnet', 'googlenet', 'resnet18', 'resnet50', 'vgg16'
networksToCompare = {'alexnet', 'resnet18'};

%% 3. Hyperparameter sweep: networks x learning rates x epochs
learningRates = [1e-4, 1e-3, 1e-2];
epochsList    = [5, 10, 20];

nRuns = numel(networksToCompare) * numel(learningRates) * numel(epochsList);
netNameCol   = strings(nRuns,1);
lrCol        = zeros(nRuns,1);
epochCol     = zeros(nRuns,1);
accCol       = NaN(nRuns,1);   % NaN = run failed / not completed

trainedNets  = cell(nRuns,1);
scoresCell   = cell(nRuns,1);   % test-set predicted scores per run
predsCell    = cell(nRuns,1);   % test-set predicted labels per run

runIdx = 0;
for ni = 1:numel(networksToCompare)
    netName = networksToCompare{ni};
    [net, inputSize] = loadNetworkByName(netName);

    % Resize images to whatever this network expects, with mild
    % augmentation on the training set to help a fairly small dataset
    % generalize
    augmenter = imageDataAugmenter( ...
        'RandXReflection', true, ...
        'RandRotation', [-10 10]);

    augTrain = augmentedImageDatastore(inputSize, imdsTrain, ...
        'DataAugmentation', augmenter);
    augTest  = augmentedImageDatastore(inputSize, imdsTest);

    for lr = learningRates
        for ep = epochsList
            runIdx = runIdx + 1;
            fprintf('\n=== Run %d/%d: %s, LR = %g, Epochs = %d ===\n', ...
                runIdx, nRuns, netName, lr, ep);

            netNameCol(runIdx) = netName;
            lrCol(runIdx)      = lr;
            epochCol(runIdx)   = ep;

            try
                lgraphOrLayers = buildTransferNetwork(net, netName, classNames);

                options = trainingOptions('sgdm', ...
                    'InitialLearnRate', lr, ...
                    'MaxEpochs', ep, ...
                    'MiniBatchSize', 16, ...
                    'Shuffle', 'every-epoch', ...
                    'ValidationData', augTest, ...
                    'ValidationFrequency', 10, ...
                    'Verbose', false, ...
                    'Plots', 'none');

                trainedNet = trainNetwork(augTrain, lgraphOrLayers, options);

                [predLabels, scores] = classify(trainedNet, augTest);
                acc = mean(predLabels == imdsTest.Labels);

                fprintf('Test accuracy: %.4f\n', acc);

                accCol(runIdx)      = acc;
                trainedNets{runIdx} = trainedNet;
                scoresCell{runIdx}  = scores;
                predsCell{runIdx}   = predLabels;

            catch ME
                fprintf(2, 'Run %d FAILED (%s) - skipping. Reason: %s\n', ...
                    runIdx, netName, ME.message);
                % accCol(runIdx) stays NaN; trainedNets/scores/preds stay empty
            end

            % Free memory before the next run (helps avoid OOM on long sweeps)
            close all force;
            clear trainedNet lgraphOrLayers options predLabels scores
            drawnow;
        end
    end
end

%% 4. Results table
resultsTable = table(netNameCol, lrCol, epochCol, accCol, ...
    'VariableNames', {'Network','LearningRate','Epochs','TestAccuracy'});
resultsTable = sortrows(resultsTable, 'TestAccuracy', 'descend', ...
    'MissingPlacement', 'last');
disp(resultsTable);
if any(isnan(accCol))
    fprintf('Note: %d run(s) failed/were skipped (see NaN rows above).\n', sum(isnan(accCol)));
end

writetable(resultsTable, fullfile(resultsFolder, 'accuracy_results.csv'));

% Per-network summary (best and mean accuracy per architecture) -
% useful for the report's network-comparison discussion
netSummary = groupsummary(resultsTable, 'Network', {'max','mean'}, 'TestAccuracy');
disp('Per-network summary (best / mean test accuracy):');
disp(netSummary);
writetable(netSummary, fullfile(resultsFolder, 'network_comparison_summary.csv'));

figure('Name', 'Network Comparison');
bar(categorical(netSummary.Network), netSummary.max_TestAccuracy);
ylabel('Best Test Accuracy');
title('Best Test Accuracy by Network Architecture');
grid on;
saveas(gcf, fullfile(resultsFolder, 'network_comparison_bar.png'));

%% 5. Best model: ROC curve + confusion matrix
[~, bestIdx] = max(accCol);  % NaN entries are automatically ignored by max()
bestNet    = trainedNets{bestIdx};
bestScores = scoresCell{bestIdx};
bestPreds  = predsCell{bestIdx};

fprintf('\nBest run: %s | LR = %g | Epochs = %d | Test Acc = %.4f\n', ...
    netNameCol(bestIdx), lrCol(bestIdx), epochCol(bestIdx), accCol(bestIdx));

posClassCol = find(strcmp(classNames, positiveClass));

figure('Name', 'ROC Curve');
[Xroc, Yroc, ~, AUC] = perfcurve(imdsTest.Labels, bestScores(:,posClassCol), positiveClass);
plot(Xroc, Yroc, 'LineWidth', 2);
xlabel('False Positive Rate');
ylabel('True Positive Rate');
title(sprintf('ROC Curve (%s, LR=%g, Epochs=%d) - AUC = %.3f', ...
    netNameCol(bestIdx), lrCol(bestIdx), epochCol(bestIdx), AUC));
grid on;
saveas(gcf, fullfile(resultsFolder, 'roc_curve_best.png'));

figure('Name', 'Confusion Matrix');
confusionchart(imdsTest.Labels, bestPreds);
title(sprintf('Confusion Matrix (%s, LR=%g, Epochs=%d)', ...
    netNameCol(bestIdx), lrCol(bestIdx), epochCol(bestIdx)));
saveas(gcf, fullfile(resultsFolder, 'confusion_matrix_best.png'));

save(fullfile(resultsFolder, 'best_model.mat'), 'bestNet', 'resultsTable', 'AUC');

fprintf('\nAll results saved to "%s" folder.\n', resultsFolder);

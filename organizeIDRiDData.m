function outFolder = organizeIDRiDData(srcFolder, outFolder)
% organizeIDRiDData  Sort IDRiD images into DR / nonDR class subfolders.
%
%   outFolder = organizeIDRiDData(srcFolder, outFolder)
%
%   srcFolder : folder containing images named like IDRiD_118_-0.jpg
%               (label is the number right before ".jpg", after the
%               final "-")
%   outFolder : destination folder; two subfolders "DR" and "nonDR"
%               will be created inside it.
%
%   Labeling rule (per assignment spec):
%       Label 0            -> nonDR
%       Label 3 or Label 4 -> DR
%       Label 1, Label 2   -> excluded (not part of this binary task)

if nargin < 2 || isempty(outFolder)
    outFolder = [srcFolder '_sorted'];
end

drFolder    = fullfile(outFolder, 'DR');
nonDrFolder = fullfile(outFolder, 'nonDR');

if ~exist(drFolder, 'dir'),    mkdir(drFolder);    end
if ~exist(nonDrFolder, 'dir'), mkdir(nonDrFolder); end

files = dir(fullfile(srcFolder, '*.jpg'));
if isempty(files)
    files = dir(fullfile(srcFolder, '*.jpeg'));
end

nDR = 0; nNonDR = 0; nSkipped = 0;

for k = 1:numel(files)
    fname = files(k).name;

    % Extract the label: the digits between the LAST '-' and the
    % extension, e.g. "IDRiD_118_-0.jpg" -> label = 0
    tok = regexp(fname, '-(\d+)\.jpe?g$', 'tokens', 'once');

    if isempty(tok)
        warning('Could not parse label from filename: %s (skipped)', fname);
        nSkipped = nSkipped + 1;
        continue;
    end

    label = str2double(tok{1});
    srcPath = fullfile(files(k).folder, fname);

    switch label
        case 0
            copyfile(srcPath, fullfile(nonDrFolder, fname));
            nNonDR = nNonDR + 1;
        case {3, 4}
            copyfile(srcPath, fullfile(drFolder, fname));
            nDR = nDR + 1;
        otherwise
            % Labels 1 and 2 are not used in this binary DR/nonDR task
            nSkipped = nSkipped + 1;
    end
end

fprintf('%s -> DR: %d, nonDR: %d, skipped (label 1/2 or unparsed): %d\n', ...
    srcFolder, nDR, nNonDR, nSkipped);

end

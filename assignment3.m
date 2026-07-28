clc;
clear;
close all;

%% Morphological Filter 
img = imread('morphology.png');
if size(img,3) == 3
    img = rgb2gray(img);
end

bw = imbinarize(img);
se = strel('disk', 2);

opened = imopen(bw, se);
cleaned = imclose(opened, se);

figure
subplot(1,2,1)
imshow(bw)
title('Input Image (Noisy "2")')

subplot(1,2,2)
imshow(cleaned)
title('Output Image (Opening + Closing)')

saveas(gcf, 'morphology_comparison.png');

%% Morphological Filter vs Median Filter 
fp = imread('fingerprint_BW.png');
if size(fp,3) == 3
    fp = rgb2gray(fp);
end

fp_bw = imbinarize(fp);
se2 = strel('disk', 1);

fp_open = imopen(fp_bw, se2);
fp_morph = imclose(fp_open, se2);

fp_median = medfilt2(fp_bw, [3 3]);

figure
subplot(1,3,1)
imshow(fp_bw)
title('Original Fingerprint')

subplot(1,3,2)
imshow(fp_morph)
title('Morphological Filter (Open + Close)')

subplot(1,3,3)
imshow(fp_median)
title('Median Filter (3x3)')

saveas(gcf, 'fingerprint_comparison.png');
%% Laplacian Filtering 
moon = imread('moon.jpg');
if size(moon,3) == 3
    moon = rgb2gray(moon);
end

moon = im2double(moon);

H = fspecial('laplacian', 0.2);
lap = imfilter(moon, H, 'replicate');

enhanced = moon + lap;
enhanced = max(0, min(1, enhanced));

figure
subplot(1,3,1)
imshow(moon)
title('Original Moon Image')

subplot(1,3,2)
imshow(lap, [])
title('Laplacian Filtered')

subplot(1,3,3)
imshow(enhanced)
title('Enhanced Image (Original + Laplacian)')

saveas(gcf, 'moon_comparison.png');
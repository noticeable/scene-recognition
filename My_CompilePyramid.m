function [ pyramid_all ] = My_CompilePyramid( imageFileList, dataBaseDir, poseletSuffix )
%function [ pyramid_all ] = My_CompilePyramid( imageFileList, dataBaseDir, poseletSuffix )
%
% Generate the pyramid from the poselet lablels
%
% For each image the texton labels are loaded. Then the histograms are
% calculated for the finest level. The rest of the pyramid levels are
% generated by combining the histograms of the higher level.
%
% imageFileList: cell of file paths
% dataBaseDir: the base directory for the data files that are generated
%  by the algorithm. If this dir is the same as imageBaseDir the files
%  will be generated in the same location as the image file
% textonSuffix: this is the suffix appended to the image file name to
%  denote the data file that contains the textons indices and coordinates. 
%  Its default value is '_texton_ind_%d.mat' where %d is the dictionary
%  size.
% dictionarySize: size of descriptor dictionary (200 has been found to be
%  a good size)
% pyramidLevels: number of levels of the pyramid to build
% canSkip: if true the calculation will be skipped if the appropriate data 
%  file is found in dataBaseDir. This is very useful if you just want to
%  update some of the data or if you've added new images.

fprintf('Building Spatial Pyramid of PEOPLEEEEEE\n\n');

%% parameters
pyramidLevels = 3;

binsHigh = 2^(pyramidLevels-1);

pyramid_all = [];

for f = 1:size(imageFileList,1)
    %% load image
    imageFName = imageFileList{f};
    [dirN base] = fileparts(imageFName);
    baseFName = fullfile(dirN, base);
    
    outFName = fullfile(dataBaseDir, sprintf('%s_poselet_pyramid_%d.mat', baseFName, pyramidLevels));
    if(size(dir(outFName),1)~=0)
        fprintf('Skipping %s\n', imageFName);
        load(outFName, 'pyramid');
        pyramid_all(f, :) = pyramid;
        continue;
    end
    
    %% load poselet indices
    in_fname = fullfile(dataBaseDir, sprintf('%s%s', baseFName, poseletSuffix));
    load(in_fname, 'poselet_ind');
    
    %% get width and height of input image
    wid = poselet_ind.wid;
    hgt = poselet_ind.hgt;

    fprintf('Loaded %s: wid %d, hgt %d\n', ...
             imageFName, wid, hgt);

    pyramid_cell = cell(pyramidLevels,1);
    peopleMark = zeros(1, length(poselet_ind.x));

    %% compute counts
    for l = (pyramidLevels:-1:1)
        binWidthAtThisLevel = wid/(2^(l-1));
        binHeightAtThisLevel = hgt/(2^(l-1));
        for i=1:floor(wid/binWidthAtThisLevel)
            for j=1:floor(hgt/binHeightAtThisLevel)
                % find the coordinates of the current bin in the current
                % pyramid level
                x_lo = floor(binWidthAtThisLevel * (i-1));
                x_hi = floor(binWidthAtThisLevel * i);
                y_lo = floor(binHeightAtThisLevel * (j-1));
                y_hi = floor(binHeightAtThisLevel * j);
                
                % mark the poselets we found
                peopleMark((poselet_ind.x > x_lo) & (poselet_ind.x + poselet_ind.pWid <= x_hi) & ...
                     (poselet_ind.y > y_lo) & (poselet_ind.y + poselet_ind.pHgt <= y_hi)) = 1;
                
                %poselet_count = length(temp((poselet_ind.x > x_lo) & (poselet_ind.x + poselet_ind.pWid <= x_hi) & ...
                %                            (poselet_ind.y > y_lo) & (poselet_ind.y + poselet_ind.pHgt <= y_hi)));
                poselet_count = sum(peopleMark);
                
                % zero out the poselets that we found
                poselet_ind.x(peopleMark == 1) = -1;
                poselet_ind.y(peopleMark == 1) = -1;
                poselet_ind.pHgt(peopleMark == 1) = -1;
                poselet_ind.pWid(peopleMark == 1) = -1;
                
                % reset peopleMark
                peopleMark = zeros(length(poselet_ind.x), 1);
                
                % make histogram of features in bin
                pyramid_cell{l}(i,j,:) = poselet_count;
            end
        end
    end

    %% stack all the counts
    pyramid = [];
    for l = 1:pyramidLevels
        pyramid = [pyramid pyramid_cell{l}(:)']; % We do not penalize for large people
    end
    
    % save pyramid
    save(outFName, 'pyramid');

    pyramid_all = [pyramid_all; pyramid];

end % f

outFName = fullfile(dataBaseDir, sprintf('poselet_pyramids_all_%d.mat', pyramidLevels));
save(outFName, 'pyramid_all', '-v7.3');

end

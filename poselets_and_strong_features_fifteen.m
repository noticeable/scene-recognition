% set up poselet stuff VERY FIRST
% note that init CLEARS EVERYTHING IN THE WORKSPACE
% SO REALLY, DO IT FIRST
global config;
init;

disp('using 15-scene files...');
NUM_TRAINING_EXAMPLES_PER_CLASS = 100;
train_image_dir = 'data/train';
test_image_dir = 'data/test';
data_dir = 'data/data';

% for other parameters, see BuildPyramid
train_fnames = dir(fullfile(train_image_dir, '*.jpg'));
num_train_files = size(train_fnames,1);
train_filenames = cell(num_train_files,1);

for f = 1:num_train_files
	train_filenames{f} = train_fnames(f).name;
end

% for other parameters, see BuildPyramid
test_fnames = dir(fullfile(test_image_dir, '*.jpg'));
num_test_files = size(test_fnames,1);
test_filenames = cell(num_test_files,1);

current_head = 'not a head';
test_class_counts = [];
counter = 0;
class_idx = 0;

for f = 1:num_test_files
	test_filenames{f} = test_fnames(f).name;
    if isempty(strfind(test_fnames(f).name, current_head))
        if class_idx > 0
            test_class_counts(class_idx) = counter;
        end
        current_head = strtok(test_fnames(f).name, '-');
        counter = 1;
        class_idx = class_idx + 1;
    else
        counter = counter + 1;
    end
end
test_class_counts(class_idx) = counter;

test_classes = [];
for i=1:class_idx
    truez = ones(test_class_counts(i))*i;
    test_classes = vertcat(test_classes, truez(:,1));
end

% return pyramid descriptors for all files in train and test
pyramid_train = BuildPyramid(train_filenames,train_image_dir,data_dir);
pyramid_test = BuildPyramid(test_filenames,test_image_dir,data_dir);

% compute histogram intersection kernel
disp('hist_isecting...');
train_feature_vect = [(1:num_train_files)' , hist_isect(pyramid_train, pyramid_train)]; 
test_feature_vect = [(1:num_test_files)' , hist_isect(pyramid_test, pyramid_train)];

disp('poseletting...');

config.DETECTION_IMG_MIN_NUM_PIX = 500^2;  % if the number of pixels in a detection image is < DETECTION_IMG_SIDE^2, scales up the image to meet that threshold
config.DETECTION_IMG_MAX_NUM_PIX = 750^2;
config.PYRAMID_SCALE_RATIO = 2;

load('data/model.mat'); % loads model

train_people = [];
for f = 1:num_train_files
    disp(['poselets for train ', f, ' of ', num_train_files]);
    clear output poselet_patches fg_masks;
    img = imread([train_image_dir, '/', train_filenames{f}]);
    [bounds_predictions,~,~]=detect_objects_in_image(img,model);
    num_people_in_scene = length(bounds_predictions);
    train_people(f) = num_people_in_scene;
end

test_people = [];
for f = 1:num_test_files
    disp(['poselets for test ', f, ' of ', num_test_files]);
    clear output poselet_patches fg_masks;
    img = imread([test_image_dir, '/', test_filenames{f}]);
    [bounds_predictions,~,~]=detect_objects_in_image(img,model);
    num_people_in_scene = length(bounds_predictions);
    test_people(f) = num_people_in_scene;
end

% strap the poselet values onto the feature vectors
train_feature_vect = [train_feature_vect, train_people'];
test_feature_vect = [test_feature_vect, test_people'];

decision_values = [];

% make one-vs-all classifiers for each scene type
% and run it to get a confidence vector for each test image
for i=1:class_idx
    disp(['builing classifier for class #', class_idx]);
    % build the vector describing training labels; 0 for not this class, 1
    % for this class
    train_class = zeros(num_train_files);
    train_class = train_class(:,1);
    train_class((i-1)*NUM_TRAINING_EXAMPLES_PER_CLASS+1:i*NUM_TRAINING_EXAMPLES_PER_CLASS) = 1;
    
    % build the vector describing test labels; 0 for not this class, 1 for
    % this class
    test_class = zeros(num_test_files);
    test_class = test_class(:,1);
    if i > 1
        test_class(sum(test_class_counts(1:i-1)):sum(test_class_counts(1:i))) = 1;
    else
        test_class(1:sum(test_class_counts(1:i))) = 1;
    end

    %# train and test
    model = svmtrain(train_class, train_feature_vect, '-t 4');
    disp('making predictions...');
    [predicted_class, ~, decision_value] = svmpredict(test_class, test_feature_vect, model);
    decision_values(:,i) = abs(decision_value);
end

% boil down the confidence vectors to just the class with highest
% confidence for each test image
disp('finding highest confidence values...');
ultimate_decisions = [];
for i=1:num_test_files
    [value, idx] = min(decision_values(i,:));
    ultimate_decisions(i) = idx;
end
ultimate_decisions = ultimate_decisions';

% confusion matrix
C = confusionmat(test_classes, ultimate_decisions)

correct = 0;
for i=1:num_test_files
    if ultimate_decisions(i) == test_classes(i)
        correct = correct + 1;
    end
end

accuracy = correct/num_test_files
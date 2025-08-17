% Script to generate a dataset of binaural audio files with source positions.
% NB : use with Audio3DServer

% Parameters
n = 100 ;  % Number of files to generate
sourceFolder = '';  % Path to source .wav files
noiseFolder = ''; % Path to distroctor .wav files
outputFolder = '';  % Path to save generated files
csvFilename = 'dataset_configurations.csv';  % CSV file to store configurations
v = 1;%index of generated file

% Ensure output folder exists
if ~exist(outputFolder, 'dir')
    mkdir(outputFolder);
end

% Get list of source .wav files (target)
sourceFiles = dir(fullfile(sourceFolder, '*.wav'));
numSources = length(sourceFiles);
if numSources == 0
    error('No .wav files found in the specified source folder.');
end

% Get list of distractor .wav files
noiseFiles = dir(fullfile(noiseFolder, '*.wav'));
numNoise = length(noiseFiles);
if numNoise == 0
    error ('No .wav files found in the specified source folder.');
end

% Open CSV file for writing
csvFile = fopen(fullfile(outputFolder, csvFilename), 'w');
if csvFile == -1
    error('Could not create CSV file.');
end

% Write CSV header
fprintf(csvFile, 'filename,source_file,angle_source,distance_source,noise_file,angle_noise,distance_noise\n');

% Fixed room and listener configurations : default values
room_width = 4;
room_depth = 3;
room_height = 2.5;
reflect_wall = 0.9;
reflect_floor = 0.7;
reflect_ceiling = 0.7;
listener_x = 2;
listener_y = 1.5;
listener_z = 1.25;

% Initialize Audio3D
if (Audio3D_Open('localhost', 8080) == 0)
    error('Could not open Audio3DServer');
end

% Set up the room properties
Audio3D_SetProperty('room_width', room_width);
Audio3D_SetProperty('room_depth', room_depth);
Audio3D_SetProperty('room_height', room_height);
Audio3D_SetProperty('reflect_wall', reflect_wall);
Audio3D_SetProperty('reflect_floor', reflect_floor);
Audio3D_SetProperty('reflect_ceiling', reflect_ceiling);

% Set listener's position
Audio3D_SetProperty('listener_x', listener_x);
Audio3D_SetProperty('listener_y', listener_y);
Audio3D_SetProperty('listener_z', listener_z);

% Other fixed properties (modify as needed)
Audio3D_SetProperty('render_errors', 0);

% Report current status (optional)
fprintf('Current Audio3D status:\n');
propertiesToReport = {'render_device', 'mixer_rate', 'mixer_level', 'reverb_time', ...
                      'hrir_filename', 'hrir_max_pca', 'hrir_pca', ...
                      'room_width', 'room_depth', 'room_height', ...
                      'reflect_wall', 'reflect_floor', 'reflect_ceiling', ...
                      'listener_x', 'listener_y', 'listener_z', ...
                      'listener_azimuth', 'listener_elevation'};
for i = 1:length(propertiesToReport)
    prop = propertiesToReport{i};
    value = Audio3D_GetProperty(prop);
    fprintf('\t%s\t%s\n', prop, num2str(value));
end

% Generate n files
for i = 1:n
    fprintf('Generating file %d/%d...\n', i, n);
    
    % Select a random source file
    sourceIdx = randi(numSources);
    sourceFile = sourceFiles(sourceIdx).name;
    sourcePath = fullfile(sourceFolder, sourceFile);
    
    % Select a random distractor file
    noiseIdx = randi(numNoise);
    noiseFile = noiseFiles(noiseIdx).name;
    noisePath = fullfile(noiseFolder, noiseFile);
    
    % Read the source audio
    [x, fs] = audioread(sourcePath);
    
    % Read the distractor audio
    [y, fn] = audioread(noisePath);
    
    % Choose random polar coordinates for source
    angle_source = rand() * 360;        % Angle between 0 and 360 degrees
    distance_s = 0.5 + rand() * 1.5; % Distance between 0.5m and 2m (adjust as needed)
    
    % Convert polar to Cartesian coordinates relative to listener
    angle_rad_s = deg2rad(angle_source);
    source_x = listener_x + distance_s * sin(angle_rad_s);
    source_y = listener_y + distance_s * cos(angle_rad_s);
    source_z = listener_z; % Keeping z the same; modify if vertical positioning is needed
    
    % Set source location
    Audio3D_SetSourceLocation(0, source_x, source_y, source_z);
    
    % Set source level and looping
    Audio3D_SetSourceLevel(0, 'fix');
    Audio3D_SetSourceLoop(0, 0);
    
    % Set source data
    Audio3D_SetSourceData(0, x, fs);
    
    
    % Choose random polar coordinates for distractor
    angle_noise = rand() * 360;        % Angle between 0 and 360 degrees
    distance_noise = 0.5 + rand() * 1.5; % Distance between 0.5m and 2m (adjust as needed)
    
    % Convert polar to Cartesian coordinates relative to listener
    angle_rad_noise = deg2rad(angle_noise);
    noise_x = listener_x + distance_noise * sin(angle_rad_noise);
    noise_y = listener_y + distance_noise * cos(angle_rad_noise);
    noise_z = listener_z; % Keeping z the same; modify if vertical positioning is needed
    
    % Set distractor location
    Audio3D_SetSourceLocation(1, noise_x, noise_y, noise_z);
    
    % Set distractor level and looping
    Audio3D_SetSourceLevel(1, 'fix');
    Audio3D_SetSourceLoop(1, 0);
    
    % Set distractor data
    Audio3D_SetSourceData(1, y, fn);
    
    
    % Start replay and capture source 
    Audio3D_SetProperty('capture', 1);
    Audio3D_Play(1);
    
    % Start capture noise
    Audio3D_Play(2);
    
    % Define capture duration (in seconds)
    capture_duration = 5; % Shortened for faster generation; adjust as needed
    
    pause(capture_duration);
    
    % Stop replay
    Audio3D_Pause(1);
    Audio3D_Pause(2);
    
    % Stop capturing
    Audio3D_SetProperty('capture', 0);
    
    % Define output filename
    outputFilename = sprintf('capture_%03d.wav', v);
    outputPath = fullfile(outputFolder, outputFilename);
    
    % Save captured data
    tempFilename = 'temp_capture.wav'; % Temporary file in the current directory
    status = Audio3D_GetCaptureData(tempFilename);

% Check if capture was successful
    if status == 0
        fprintf('Warning: Capture status for file %s is %d\n', tempFilename, status);
    else
        % Move the file to the output folder
        movefile(tempFilename, outputPath);
        fprintf('File saved to %s\n', outputPath);
    end
    
    % Optionally, read the captured file to verify (commented out)
    %[cap, capfs] = audioread(outputPath);
    %fprintf('Captured %d samples at %d samp/sec\n', length(cap), capfs);
    
    % Write configuration to CSV
    fprintf(csvFile, '%s,%s,%.2f,%.2f,%s,%.2f,%.2f\n', outputFilename, sourceFile, angle_source, distance_s, noiseFile, angle_noise, distance_noise);
    
    % Optional: Add a short pause to ensure server processes the request
    pause(0.5);
    v = v+1;
end

% Close CSV file
fclose(csvFile);

fprintf('Dataset generation complete. Configurations saved to %s\n', fullfile(outputFolder, csvFilename));


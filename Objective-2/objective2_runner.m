clear; 
clc; 
close all;

%% -----------------------------------------------------------------
%  SETUP
% -----------------------------------------------------------------
file_list = {'male1.wav', 'male2.wav', 'female1.wav', 'female2.wav'};

results = table('Size', [length(file_list), 5], ...
    'VariableTypes', {'string', 'double', 'double', 'double', 'double'}, ...
    'VariableNames', {'File', 'Actual_Bitrate_kbps', 'Run_Time_sec', 'NB_PESQ', 'SegSNR_dB'});

rng(0); 

% --- CELP 13K PARAMETERS ---
TARGET_FS = 8000;      
N = 160;               
L = 20;                
M = 12;                
c = 0.9;               
Pidx = [20 160];       

% Codebook (Pink Noise)
CB_Size = 1024;
raw_cb = randn(L, CB_Size);
b_smooth = [1 0.5]; 
cb = filter(b_smooth, 1, raw_cb);
for k=1:CB_Size, cb(:,k) = cb(:,k) / norm(cb(:,k)); end

fprintf('=== CELP 13000 bps (Using pesqbin) ===\n');
fprintf('Configuration: 8 Subframes/Frame, LPC Order 12\n');
fprintf('------------------------------------------------------\n');

%% -----------------------------------------------------------------
%  PROCESSING LOOP
% -----------------------------------------------------------------
for i = 1:length(file_list)
    filename = file_list{i};
    fprintf('Processing %s ... ', filename);
    
    try
        [x, fs_orig] = audioread(filename);
        if size(x,2)>1, x=mean(x,2); end
    catch
        fprintf('Error reading file.\n'); continue;
    end
    
    % Resample to 8kHz
    if fs_orig ~= TARGET_FS
        x = resample(x, TARGET_FS, fs_orig);
    end
    sr = TARGET_FS;
    
    % Align length
    nFrames = floor(length(x)/N);
    x = x(1 : nFrames*N);
    
    % RUN CELP
    t_start = tic;
    [xhat, e, k, theta0, P, b] = celp13k(x, N, L, M, c, cb, Pidx);
    run_time = toc(t_start);
    
    % Post-Processing
    xhat = filter(1, [1 -0.7], xhat); 
    x = x - mean(x);
    xhat = xhat - mean(xhat);
    xhat = xhat * (std(x)/std(xhat));

    % 1. BITRATE
    bitrate_bps = 268 * (sr/N); 
    
    % 2. PESQ (Using pesqbin)
    try
        % pesqbin returns [Raw, LQO] or [Raw, Raw]
        scores = pesqbin(x, xhat, sr, 'nb');
        pesq_val = scores(1);
    catch
        pesq_val = NaN;
    end
    
    % 3. SEGMENTAL SNR (Robust)
    [b_w, a_w] = butter(4, [300 3400]/(sr/2)); 
    x_w = filter(b_w, a_w, x);
    xhat_w = filter(b_w, a_w, xhat);
    snr_val = segsnr(x_w, xhat_w, N);
    
    % SAVE
    out_name = [filename(1:end-4), '_celp_13kbps.wav'];
    audiowrite(out_name, xhat, sr);
    
    results.File(i) = filename;
    results.Actual_Bitrate_kbps(i) = bitrate_bps / 1000;
    results.Run_Time_sec(i) = run_time;
    results.NB_PESQ(i) = pesq_val;
    results.SegSNR_dB(i) = snr_val;
    
    fprintf('Done. PESQ: %.2f | SegSNR: %.2f dB\n', pesq_val, snr_val);
end

fprintf('\n=== FINAL REPORT ===\n');
disp(results);
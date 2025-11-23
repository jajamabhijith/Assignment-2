clear; 
clc; 
close all;

%% -----------------------------------------------------------------
%  SETUP: Define file list and parameters
% -----------------------------------------------------------------
file_list = {'male1.wav', 'male2.wav', 'female1.wav', 'female2.wav'};

results = table('Size', [length(file_list), 5], ...
                'VariableTypes', {'string', 'double', 'double', 'double', 'double'}, ...
                'VariableNames', {'File', 'SegSNR_Plain_dB', 'SegSNR_Voice_dB', 'RunTime_s', 'SampleRate'});

rng(0); % Consistent random noise

%% -----------------------------------------------------------------
%  PARAMETERS
% -----------------------------------------------------------------
fr = 20; % Frame rate (ms)
fs = 30; % Frame size (ms)

% --- Plain LPC Parameters ---
L_plain = 16; 

% --- Voice-Excited LPC Parameters ---
L_voice = 16; 
bit_rate_target = 16000; 
bits_per_coeff = 8; 

% Calculate K (number of DCT coefficients to keep)
fps = 1000 / fr; 
bits_per_frame_total = bit_rate_target / fps; 
bits_for_lpc = (L_voice + 1) * bits_per_coeff; 
bits_for_residual = bits_per_frame_total - bits_for_lpc; 
K = floor(bits_for_residual / bits_per_coeff); 

% Ensure K is valid (min 1)
if K < 1, K = 1; end

%% -----------------------------------------------------------------
%  PROCESSING LOOP
% -----------------------------------------------------------------
fprintf('=== STARTING VOCODER PROCESSING ===\n');
fprintf('Plain LPC Order: %d\n', L_plain);
fprintf('Voice-Excited Residual: Keeping K=%d DCT coefficients.\n', K);
fprintf('(Note: At 44/48kHz, K=%d covers only ~400Hz bandwidth. HFR is enabled to fix this.)\n\n', K);

for i = 1:length(file_list)
    filename = file_list{i};
    try
        [data, sr] = audioread(filename);
    catch
        fprintf('Error: Could not read %s. Skipping.\n', filename);
        continue;
    end
    
    % Ensure mono
    if size(data, 2) > 1, data = mean(data, 2); end
    
    fprintf('--- Processing %s (sr=%d Hz) ---\n', filename, sr);
    tic; 
    
    % ======================================
    %  1. PLAIN LPC VOCODER
    % ======================================
    [aCoeff_p, ~, pitch_p, G_p] = proclpc(data, sr, L_plain, fr, fs);
    synWave_plain = synlpc_plain(aCoeff_p, pitch_p, sr, G_p, fr, fs);
    
    % --- GLOBAL ENERGY MATCHING (Fixes Clipping/Noise) ---
    % Remove DC and scale to match original signal standard deviation
    synWave_plain = synWave_plain - mean(synWave_plain);
    len_p = min(length(data), length(synWave_plain));
    scale_p = std(data(1:len_p)) / (std(synWave_plain(1:len_p)) + eps);
    synWave_plain = synWave_plain * scale_p;
    
    audiowrite([filename(1:end-4), '_plain.wav'], synWave_plain, sr);
    
    
    % ======================================
    %  2. VOICE-EXCITED LPC VOCODER (With HFR)
    % ======================================
    [aCoeff_v, resid, ~, G_v] = proclpc(data, sr, L_voice, fr, fs);
    
    [~, num_frames] = size(resid);
    quantized_resid = zeros(size(resid));
    
    for f_idx = 1:num_frames
        orig_frame = resid(:, f_idx);
        
        % --- ENCODER: Compression ---
        dct_coeffs = dct(orig_frame);
        % Keep only low frequency coefficients (Transmission)
        dct_baseband = dct_coeffs;
        dct_baseband(K+1:end) = 0; 
        
        % --- DECODER: Reconstruction with High Frequency Regeneration ---
        % 1. Reconstruct the Baseband (Low Frequencies)
        baseband_resid = idct(dct_baseband);
        
        % 2. High Frequency Regeneration (HFR)
        % Since K is small, we have lost all high frequencies (mumbling).
        % We synthesize them by rectifying the baseband to generate harmonics.
        rectified_resid = abs(baseband_resid); 
        
        % Convert generated harmonics back to DCT domain
        dct_rectified = dct(rectified_resid);
        
        % 3. Mix Baseband and Synthesized High Band
        dct_reconstructed = zeros(size(dct_coeffs));
        
        % Keep exact transmitted low frequencies
        dct_reconstructed(1:K) = dct_baseband(1:K); 
        
        % Fill missing high frequencies with generated harmonics
        % We apply a slight decay to keep it natural
        dct_reconstructed(K+1:end) = dct_rectified(K+1:end);
        
        % 4. Inverse DCT
        recon_frame = idct(dct_reconstructed);
        
        % 5. Frame Energy Normalization
        % Ensure the excited residual has the same power as the original residual
        e_in = norm(orig_frame);
        e_out = norm(recon_frame);
        if e_out > 0
             recon_frame = recon_frame * (e_in / e_out);
        end
        
        quantized_resid(:, f_idx) = recon_frame;
    end
    
    synWave_voice = synlpc_voice(aCoeff_v, quantized_resid, sr, G_v, fr, fs);
    
    % --- GLOBAL ENERGY MATCHING ---
    synWave_voice = synWave_voice - mean(synWave_voice);
    len_v = min(length(data), length(synWave_voice));
    scale_v = std(data(1:len_v)) / (std(synWave_voice(1:len_v)) + eps);
    synWave_voice = synWave_voice * scale_v;
    
    audiowrite([filename(1:end-4), '_voice.wav'], synWave_voice, sr);
    
    total_time = toc;

    % ======================================
    %  3. CALCULATE SegSNR
    % ======================================
    snr_plain = segsnr(data(1:len_p), synWave_plain(1:len_p), sr);
    snr_voice = segsnr(data(1:len_v), synWave_voice(1:len_v), sr);
    
    results(i, :) = {filename, snr_plain, snr_voice, total_time, sr};
    
    fprintf('    Plain SegSNR: %.2f dB\n', snr_plain);
    fprintf('    Voice SegSNR: %.2f dB\n', snr_voice);
end

fprintf('\n=================================================================\n');
disp(results);
fprintf('=================================================================\n');
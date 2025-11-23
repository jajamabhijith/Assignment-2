function synWave = synlpc_plain(aCoeff, pitch, sr, G, fr, fs, preemp)
% SYNLPC_PLAIN Synthesizes speech using Plain LPC with Phase Continuity

if (nargin < 5), fr = 20; end 
if (nargin < 6), fs = 30; end 
if (nargin < 7), preemp = .9378; end 

msfs = round(sr*fs/1000); % Frame size in samples 
msfr = round(sr*fr/1000); % Frame rate (shift) in samples 
msoverlap = msfs - msfr; 
ramp = [0:1/(msoverlap-1):1]'; 

[~, nframe] = size(aCoeff); 

% Initialize variables
synWave = [];
prev_overlap = zeros(msoverlap, 1); 
pulse_count = 1; % Tracks the location of the next pitch pulse across frames

for frameIndex = 1:nframe 
    A = aCoeff(:, frameIndex); 
    P = pitch(frameIndex); % Pitch lag in samples
    
    % --- EXCITATION GENERATION ---
    if (P == 0) 
        % UNVOICED: White Noise
        residFrame = randn(msfs, 1); 
    else 
        % VOICED: Phase-Continuous Impulse Train
        residFrame = zeros(msfs, 1);
        
        % Start placing pulses where the previous frame left off
        start_idx = pulse_count;
        
        while start_idx <= msfs
            residFrame(start_idx) = 1; % Place impulse
            start_idx = start_idx + P; % Move to next pitch period
        end
        
        % Update pulse_count for the NEXT frame (shift relative to start of next frame)
        pulse_count = start_idx - msfr; 
        
        % Safety check: ensure index is valid (at least 1)
        if pulse_count < 1, pulse_count = 1; end 
        
        % Energy Normalization: Voiced pulses need scaling to match noise power
        % A pulse train with period P has power 1/P. We scale by sqrt(P) to get unit power.
        residFrame = residFrame * sqrt(P);
    end 
    
    % --- SYNTHESIS FILTER ---
    % Apply Gain (G) and LPC Filter
    synFrame = filter(G(frameIndex), A', residFrame); 
    
    % --- OVERLAP-ADD ---
    if (frameIndex == 1) 
        synWave = synFrame(1:msfr);
        prev_overlap = synFrame(msfr+1:end);
    else 
        current_overlap = synFrame(1:msoverlap);
        
        % Blend the overlap regions
        len_ov = min(length(prev_overlap), length(current_overlap));
        overlapped_segment = (prev_overlap(1:len_ov) .* flipud(ramp(1:len_ov))) + ...
                             (current_overlap(1:len_ov) .* ramp(1:len_ov));
        
        synWave = [synWave; overlapped_segment; synFrame(msoverlap+1:msfr)];
        prev_overlap = synFrame(msfr+1:end);
    end 
    
    % Handle tail of the last frame
    if (frameIndex == nframe)
        synWave = [synWave; prev_overlap];
    end
end 

% De-emphasis filter
synWave = filter(1, [1 -preemp], synWave); 

end
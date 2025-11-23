function [ scores ] = pesqbin( reference, degraded, fs, mode )
% PESQBIN (Robust Version) - MATLAB wrapper for PESQ binary
% Modified to support multiple output formats and local paths.

    % usage information
    usage = 'usage: [ pesq_mos ] = pesqbin( reference, degraded, fs, mode );';

    % default settings
    switch( nargin )
    case { 0, 1 }, error( usage );
    case 2, mode='nb'; if ~ischar(reference) || ~ischar(degraded), error( usage ); end;
    case 3, mode='nb';
    case 4, 
    otherwise, error( usage );
    end 

    % Use CURRENT DIRECTORY for temp files (Fixes "File not found")
    tmpdir = pwd();
    ref_file = fullfile(tmpdir, 'temp_ref_pesq.wav');
    deg_file = fullfile(tmpdir, 'temp_deg_pesq.wav');

    % 1. PREPARE AUDIO FILES
    if ischar(reference)
        [d, f_s] = audioread(reference);
        audiowrite(ref_file, d, f_s);
        fs = f_s; 
    else
        mx = max(abs(reference));
        if mx > 0, reference = 0.999 * reference / mx; end
        audiowrite(ref_file, reference, fs);
    end 

    if ischar(degraded)
        [d, f_s] = audioread(degraded);
        audiowrite(deg_file, d, f_s);
    else
        mx = max(abs(degraded));
        if mx > 0, degraded = 0.999 * degraded / mx; end
        audiowrite(deg_file, degraded, fs);
    end 

    % 2. SELECT BINARY
    if isunix()
        binary = './pesq'; 
    else 
        binary = 'pesq.exe'; 
    end
    
    if exist(binary, 'file') ~= 2
        fprintf('[PESQ Error: %s not found in current folder]\n', binary);
        scores = [NaN, NaN];
        return;
    end

    % 3. RUN COMMAND
    if strcmpi(mode, 'wb') || strcmpi(mode, '+wb')
        cmd = sprintf('%s +%d +wb "%s" "%s"', binary, fs, ref_file, deg_file);
    else
        cmd = sprintf('%s +%d "%s" "%s"', binary, fs, ref_file, deg_file);
    end
    
    [status, stdout] = system(cmd);

    % 4. PARSE OUTPUT (Robust)
    if status ~= 0 
        scores = [NaN, NaN];
    else
        scores = parse_pesq_output(stdout);
    end

    % Cleanup
    if exist(ref_file, 'file'), delete(ref_file); end
    if exist(deg_file, 'file'), delete(deg_file); end
end

function [ scores ] = parse_pesq_output( text )
    % Try Pattern 1: Your specific binary output
    % "Prediction : PESQ_MOS = 4.500"
    pat1 = 'Prediction\s*:\s*PESQ_MOS\s*=\s*([\d\.]+)';
    tokens = regexp(text, pat1, 'tokens');
    
    if ~isempty(tokens)
        val = str2double(tokens{1}{1});
        scores = [val, val]; % Return same for both if only one exists
        return;
    end

    % Try Pattern 2: Standard ITU output
    % "Prediction (Raw MOS, MOS-LQO):  = 3.500  3.100"
    pat2 = 'Prediction.*=\s*([\d\.]+)\s+([\d\.]+)';
    tokens = regexp(text, pat2, 'tokens');
    
    if ~isempty(tokens)
        v1 = str2double(tokens{1}{1});
        v2 = str2double(tokens{1}{2});
        scores = [v1, v2];
        return;
    end
    
    % Try Pattern 3: Single number at end
    pat3 = 'Prediction.*=\s*([\d\.]+)';
    tokens = regexp(text, pat3, 'tokens');
    if ~isempty(tokens)
        val = str2double(tokens{1}{1});
        scores = [val, val];
        return;
    end

    scores = [NaN, NaN];
end
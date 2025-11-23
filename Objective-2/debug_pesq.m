clear; clc;

fprintf('=== PESQ DIAGNOSTIC TOOL ===\n');

% 1. Check if pesq.exe exists
if exist('pesq.exe', 'file') ~= 2
    fprintf('ERROR: pesq.exe NOT found in current folder.\n');
    fprintf('Current Folder: %s\n', pwd);
    return;
else
    fprintf('OK: pesq.exe found.\n');
end

% 2. Create dummy wav files for testing
fs = 8000;
t = 0:1/fs:0.5;
sig = sin(2*pi*440*t);
audiowrite('test_ref.wav', sig, fs);
audiowrite('test_deg.wav', sig*0.9, fs); % Slightly quieter

% 3. Run PESQ command manually
cmd = 'pesq.exe +8000 test_ref.wav test_deg.wav';
fprintf('Running Command: %s\n', cmd);

[status, output] = system(cmd);

% 4. Show Results
fprintf('\n--- RAW OUTPUT FROM PESQ.EXE ---\n');
disp(output);
fprintf('--------------------------------\n');

if status == 0
    fprintf('STATUS: Success (0)\n');
    % Try to find the number
    pat = 'Prediction \(Raw MOS, MOS-LQO\):\s*=\s*([\d\.]+)';
    tokens = regexp(output, pat, 'tokens');
    if ~isempty(tokens)
        fprintf('PARSED SCORE: %s\n', tokens{1}{1});
    else
        fprintf('PARSED SCORE: [Could not find number in output]\n');
    end
else
    fprintf('STATUS: Failed (Code %d)\n', status);
    fprintf('HINT: If status is -1073741515, you are missing DLLs (libgcc/mingw).\n');
end

% Cleanup
delete('test_ref.wav');
delete('test_deg.wav');
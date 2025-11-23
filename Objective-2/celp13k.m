function [xhat,e,k,theta0,P,b] = celp13k(x,N,L,M,c,cb,Pidx)
% CELP13K: 13kbps CELP with Robust Range Quantization
%   Frame Size (N): 160 (20ms)
%   Subframe Size (L): 20 (2.5ms)

Nx = length(x);                         
F  = fix(Nx/N);          % Number of Frames               
J  = N/L;                % Subframes per frame (8)

% Initialize output signals
xhat   = zeros(Nx,1);                   
e      = zeros(Nx,1);                   
k      = zeros(J,F);                    
theta0 = zeros(J,F);                    
P      = zeros(J,F);
b      = zeros(J,F);

% Buffers
ebuf  = zeros(Pidx(2),1);               
ebuf2 = ebuf; 
bbuf = 0;                 
Zf = []; Zw = []; Zi = [];              

for f=1:F
  n = (f-1)*N+1:f*N; % Current Frame Indices

  % --- 1. ANALYSIS ---
  [kappa,kf,theta0f,Pf,bf,ebuf,Zf,Zw] = celpana(x(n),L,M,c,cb,Pidx,bbuf,...
                                                                ebuf,Zf,Zw);

  % --- 2. QUANTIZATION ---
  
  % LPC: 5 bits (Range [-1, 1])
  % uencode is fine here as default peak is 1
  sigma  = 2/pi*asin(kappa);
  sigma  = udecode(uencode(sigma,5),5);
  kappa  = sin(pi/2*sigma);
  
  % --- LOGARITHMIC GAIN QUANTIZATION (Fixed) ---
  % Stochastic Gain (theta0): 4 bits
  % Decompose into Sign (1 bit) and Magnitude (3 bits Log)
  sign_t = sign(theta0f);
  mag_t  = abs(theta0f);
  mag_t(mag_t < 1e-4) = 1e-4; % Floor to prevent log(0)
  
  % Quantize Log Magnitude: Range [-4, 0]
  log_t = log10(mag_t);
  log_t_q = quantize_range(log_t, 3, -4, 0); % 3 bits for mag
  theta0f = sign_t .* (10.^log_t_q);
  
  % Pitch Gain (b): 4 bits
  % Range [-0.5, 1.2]
  bf = quantize_range(bf, 4, -0.5, 1.2);
  
  % Stability Clamp (Prevent Buzz)
  bf(bf > 0.95) = 0.95; 
  bf(bf < -0.5) = -0.5;

  % --- 3. SYNTHESIS ---
  [xhat(n),ebuf2,Zi] = celpsyn(cb,kappa,kf,theta0f,Pf,bf,ebuf2,Zi);

  % Store parameters
  e(n)        = ebuf(Pidx(2)-N+1:Pidx(2));
  k(:,f)      = kf;
  theta0(:,f) = theta0f;
  P(:,f)      = Pf;
  b(:,f)      = bf; 
  bbuf        = bf(J); 
end
end

% --- HELPER FUNCTION: Manual Quantization ---
function val_q = quantize_range(val, bits, min_val, max_val)
    % Maps value to integer index 0..(2^bits-1) within [min, max]
    levels = 2^bits;
    step = (max_val - min_val) / (levels - 1);
    
    % Encode
    idx = round((val - min_val) / step);
    idx = max(0, min(levels-1, idx)); % Clamp index
    
    % Decode
    val_q = idx * step + min_val;
end
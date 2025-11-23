function synWave = synlpc_voice(aCoeff,source,sr,G,fr,fs,preemp) 

if (nargin < 5), fr = 20; end 
if (nargin < 6), fs = 30; end 
if (nargin < 7), preemp = .9378; end 
msfs = round(sr*fs/1000); 
msfr = round(sr*fr/1000); 
msoverlap = msfs - msfr; 
ramp = [0:1/(msoverlap-1):1]'; 
[L1 nframe] = size(aCoeff); % L1 = 1+number of LPC coeffs 
[row col] = size(source); 
if(row==1 | col==1) % continous stream; must be windowed 
postFilter = 0; duration = length(source); frameIndex = 1; 
for sampleIndex=1:msfr:duration-msfs+1 
resid(:,frameIndex) = source(sampleIndex:(sampleIndex+msfs-1))'; 
frameIndex = frameIndex+1; 
end 
else 
postFilter = 1; resid = source; 
end 
[row col] = size(resid); 
if col<nframe 
nframe=col; 
end 
for frameIndex=1:nframe 
A = aCoeff(:,frameIndex); 
residFrame = resid(:,frameIndex)*G(frameIndex); 
synFrame = filter(1, A', residFrame); % synthesize speech from LPC coeffs 
if(frameIndex==1) % add synthesized frames using a trapezoidal window 
synWave = synFrame(1:msfr); 
else 
synWave = [synWave; overlap+synFrame(1:msoverlap).*ramp; ... 
synFrame(msoverlap+1:msfr)]; 
end 
if(frameIndex==nframe) 
synWave = [synWave; synFrame(msfr+1:msfs)]; 
else 
overlap = synFrame(msfr+1:msfs).*flipud(ramp); 
end 
end
if(postFilter) 
synWave = filter(1, [1 -preemp], synWave); 
end 

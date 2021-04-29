module GetSpectrum

using DSP 
using FFTW 

export getSpectrum
export getWaterfall 
#greet() = print("Hello World!")

function getSpectrum(fs,sig;N=nothing)
	if isnothing(N) 
		N = length(sig);
	end
    freqAx = collect(((0:N-1)./N .- 0.5)*fs);
	ss	   = @view sig[1:N];
	y	   = 10*log10.(abs2.(fftshift(fft(ss))));
	return (freqAx,y);
end
getSpectrum(sig) = getSpectrum(1,sig);



function getWaterfall(fe,sig;sizeFFT=1024)
    nbSeg   = length(sig) ÷ sizeFFT;
    ss      =  @views sig[1:nbSeg*sizeFFT];
    ss      = reshape(ss,sizeFFT,nbSeg)
    sMatrix = zeros(Float64,sizeFFT,nbSeg);
    for iN = 1 : 1 : nbSeg 
        sMatrix[:,iN] = abs2.(fftshift(fft(ss[:,iN])));
    end
    fAx = collect(((0:1:sizeFFT-1)./sizeFFT .- 0.5) .* fe);
    tAx = (0:nbSeg-1) * (sizeFFT/fe);
    return tAx,fAx,sMatrix;
end
getWaterfall(sig;sizeFFT=1024) = getWaterfall(1,sig;sizeFFT=sizeFFT);
end # module

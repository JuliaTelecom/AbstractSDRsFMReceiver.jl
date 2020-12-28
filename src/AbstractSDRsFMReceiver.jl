module AbstractSDRsFMReceiver

using AbstractSDRs;
using DSP; 
using FFTW;
using GetSpectrum
include("Audio.jl");
using .Audio

using Blink;        # For GUI in electron 
using Interact;      # For Widget and interactions 
using PlotlyJS; 


FLAG = false;

"""
Apply FM demodulation to the input signal
It applies Arg(sig[n+1] sig*[n]) where * stands for complex conjugate
# --- Syntax
out = fmDemod(sig)
# --- Input parameters
- sig : Input signal (expected to be complex Vector)
# --- Output parameters
- out : Demodulated signal (Float64 Vector)
"""
function fmDemod(sig)
    out = zeros(Float64,length(sig));
    @inbounds @simd for n ∈ (1:length(sig)-1)
        out[n+1] = angle(sig[n+1]*conj(sig[n]));
    end
    return out;
end

"""
Init a Low pass filter (based on FIR filter synthesis) that cut @bandPass
# --- Syntax
h = genFilter(sizeL,bandPass,samplingRate)
# --- Input parameters
- sizeL : Desired filter size 
- bandPass : Max frequency in bandpass 
- samplingRate : sampling frequency 
# --- Output parameters
- h : filter (Vector{Float64}(sizeL,1))
"""
function genFilter(sizeL,bandPass,samplingRate)
    # --- Init frequency response 
    cuttOff = bandPass / samplingRate;
    fRep  = zeros(Complex{Float64},sizeL);
    # --- Set passband value 
    fRep[1:Int(floor(sizeL*cuttOff))] .= 1;
    # --- Adding linear phase term
    pulsation   = 2*pi*(0:sizeL-1) ./sizeL;# --- Pulsation \Omega 
    groupDelay  = - (sizeL-1)/2;# --- Group delay 
    fRep        .= fRep .* exp.(1im * groupDelay .* pulsation);
    # --- Get to time domain
    # With a force to cast in real domain 
    hRep  = real(ifft(fRep));
    # --- Generates window 
    wind  = hamming(sizeL);
    # --- Apply windowing (apodisation)
    h  = hRep .* wind;
end 

"""
Apply the filter by direct convoltuion and downsample 
# --- Syntax
 out = applyFilter(sig,h,decim)
# --- Input parameters
- sig : Signal to be filtered and downsampled (of size N)
- h : Filter to apply 
- decim : Desired decimation factor (should be Int)
# --- Output parameters
- out : filtered and downsampled data (size N÷decim)
"""
function applyFilter(x,h,decim)
    l = length(h)÷2;
    return conv(x,h)[1+l:decim:end-l];
end

"""
Compute Power Spectral Density (PSD) of signal and returns a tuple (frequency,power) ready to be computed 
# --- Syntax
(fs,pow) = getSpectrum(f,sig,N)
# --- Input parameters
- f : sampling frequency (in Hz)
- sig : Signal to be analyzed
# --- Output parameters
- fs : Vector of frequencies 
- pow: Vector of power
"""
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


function main(sdr,carrierFreq,gain=20,p=nothing;kwargs...)
    # --- Simulation parameters
    global FLAG = true;
    global newCarrierFreq	  = carrierFreq;		# --- Starting frequency
    samplingRate  			  = 48e3*4;
    # --- Duration and buffer size 
    duration                  = 0.5;
    nbSamples                 = Int( duration * samplingRate);
    # --- Update radio configuration
    global radio			= openSDR(sdr,newCarrierFreq,samplingRate,gain;kwargs...); 
    # --- Create FIR filter 
    audioRendering = 48e3;
    decim          = Int(samplingRate ÷ audioRendering);
    h              = genFilter(128,48e3,samplingRate);
    # --- Audio rendering 
    stream = Audio.createAudioBuffer();
    try 
        while(true) 
            # --- We get buffer 
            sig = recv(radio,nbSamples);
            # --- FM demodulator
            out = fmDemod(sig);
            # --- Audio decimation 
            audio = applyFilter(out,h,decim);
            # --- Audio rendering 
            Audio.play(stream,audio);
            # --- Plot 
            deletetraces!(p,0);
            (x,y) = getSpectrum(samplingRate,sig[1:128]);
            pl1	  = scatter(; x,y, name=" ");
            addtraces!(p,pl1);
            # Exit 
            if FLAG == false;
                print("BREAK");
                break;
            end
        end
    catch exception;
        close(stream);
        close(radio);
        rethrow(exception);
    end 
    close(stream);
    close(radio);
end

"""
Main call to the Graphical User Interace (GUI)
# --- Syntax
gui()
# --- Input parameters
- 
# --- Output parameters
- 
"""
function gui()
    global FLAG = false;
    # ----------------------------------------------------
    # --- Define widgets
    # ---------------------------------------------------- 
    # --- Creating widget for FM frequencies 
    frequencies = widget(88:0.1:107, label="FM frequencies (MHz)");
    widgetGain        = widget(0:50, label="Radio Gain");
    # --- Creating some stuff related to args 
    widgetArgs = textbox(hint=""; value="addr=192.168.10.13");
    # --- Widget for radio configuration 
    sdrList = AbstractSDRs.getSupportedSDRs();
    options = Observable(sdrList);
    wdg = dropdown(options);
    # --- Start button 
    startButton = button("Start !"; value=0)
    # ---------------------------------------------------- 
    # --- 
    w = Window(Blink.@d(:width=>600, :height=>600));
    title(w,"FM receiver in Julia");
    # --- Horizontal axis 
    layout = hbox(pad(1em,wdg),pad(1em,widgetArgs));
    layout = vbox(layout,frequencies);
    layout = vbox(layout,widgetGain);
    layout = hbox(layout,pad(3em,startButton));
    # 
    plotLayout = Layout(;
        width = 600,
        height = 400,
        title=" Spectrum ",
        xaxis_title=" Frequency  ",
        yaxis_title=" Power ",
        xaxis_showgrid=true, yaxis_showgrid=true,
        yaxis_range =[-80,0]
        )
    N = 100;
    x = 0:N-1;
    y = zeros(N);
    pl1	  = scatter(; x,y, name=" ");
    p = plot(pl1,plotLayout)
    layout = vbox(layout,p);

    body!(w,layout);
    # ----------------------------------------------------
    # --- 
    # ---------------------------------------------------- 
    # --- Update Frequency 
    on(updateC,frequencies);
    # --- Update Gain 
    on(updateG,widgetGain);
    # --- Starting routine 
    h = on(startButton) do click 
        startButton["is-loading"][]=true
        #@show click
        #if click == 1 
        #    map!(fromStartToStop,startButton,12,16)
        #end
        sdr =  wdg[];
        carrierFreq = frequencies[]*1e6
        gain        = widgetGain[];
        kwargs = (;args=widgetArgs[]);
        @async main(sdr,carrierFreq,gain,p;kwargs...);
        # @async main(:e310,carrierFreq;args="addr=192.168.10.13");
    end
    success(w.shell.proc)
    global FLAG=false; 
    close(radio);
    # We get the hand back and can close the radio 
    return nothing
end

function updateC(val)
    if FLAG == true 
        carrierFreq = val*1e6;
        updateCarrierFreq!(radio,carrierFreq);
    end
end
function updateG(val)
    if FLAG == true 
        gain = val;
        updateGain!(radio,gain);
    end
end




    end # module

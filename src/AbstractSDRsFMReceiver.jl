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

function fmDemod(sig)
    out = zeros(Float64,length(sig));
    @inbounds @simd for n ∈ (1:length(sig)-1)
        out[n+1] = angle(sig[n+1]*conj(sig[n]));
    end
    return out;
end

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

function applyFilter(x,h,decim)
    l = length(h)÷2;
    return conv(x,h)[1+l:decim:end-l];
end

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
    options = Observable([:e310,:uhd])
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

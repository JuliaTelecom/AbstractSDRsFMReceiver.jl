module GUI


using Blink;        # For GUI in electron 
using Interact;      # For Widget and interactions 

export setup;


function gui()
    # ----------------------------------------------------
    # --- Define widgets
    # ---------------------------------------------------- 
    # --- Creating widget for FM frequencies 
    frequencies = widget(88e6:0.5e3:107e6, label="FM frequencies");
    # --- Creating some stuff related to args 
    widgetArgs = textbox(hint=""; value="addr=192.168.10.13");
    # --- Widget for radio configuration 
    options = Observable([:e310,:uhd])
    wdg = dropdown(options);
    # --- Start button 
    startButton = button("Start !"; value=0)

    # ----------------------------------------------------
    # --- Create window
    # ---------------------------------------------------- 
    # --- 
    w = Window();
    # --- Horizontal axis 
    layout = hbox(pad(1em,wdg),pad(1em,widgetArgs));
    layout = vbox(layout,frequencies);
    layout = hbox(layout,pad(3em,startButton));
    body!(w,layout);


    # ----------------------------------------------------
    # --- 
    # ---------------------------------------------------- 
    on(updateC,frequencies);
    h = on(startButton) do click 
        startButton["is-loading"][]=true
        #@show click
        #if click == 1 
        #    map!(fromStartToStop,startButton,12,16)
        #end
        @show click 
        @show frequencies[]
        @show widgetArgs[]
        @show wdg[]
    end

    success(w.shell.proc)
    # We get the hand back and can close the radio 
    return nothing
end

function updateC(val)
    global carrierFreq = freq;
    updateCarrierFreq!(radio,freq);
end


function fromStartToStop(startButton,val1,val2)
    @show startButton
    println("$(val1),$(val2)");
end


end

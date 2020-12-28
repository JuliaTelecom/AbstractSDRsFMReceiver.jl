module Audio 

# Audio modules (to load and monitor data)
using PortAudio		  # Handle audio
using FileIO
using Suppressor	  # Disable warning from PortAudio
import LibSndFile
using DSP

# --- Calling audio functions
#include("functions_play.jl");
export  play, play44,  play2, playbis
export createAudioBuffer, play

""" play
---
Play a sound based on input buffer
# --- Syntax
  play(buffer)
# --- Input parameters
- buffer  : Vector to be played [Array{Int}]
# --- Output parameters
- []
# ---
# v 1.0 - Robin Gerzaguet.
"""
function play(buffer)
	# --- Due to macro, need to create Any stream
	devices = PortAudio.devices()
	stream = Any;
	# --- Suprress to avoid underflow warnings
	@suppress let
		# --- Create default streamer,
		stream = PortAudioStream();
	end
	# --- Playing file through device
	@suppress write(stream,buffer);
	close(stream);
	# We need to close the streamer.
end



function createAudioBuffer()
	# --- Due to macro, need to create Any stream
	devices = PortAudio.devices()
	stream = Any;
	# --- Suprress to avoid underflow warnings
	@suppress let
		# --- Create default streamer,
		stream = PortAudioStream();
	end
	return stream;
end 
function play(stream,buffer)
	 write(stream,buffer);
end


""" play
---
Play a sound based on input buffer with a 2kHz-> 44kHz upscaling
# --- Syntax
  play(buffer)
# --- Input parameters
- buffer  : Vector to be played [Array{Int}]
# --- Output parameters
- []
# ---
# v 1.0 - Corentin Lavaud
"""
function play44(buffer,fe)
	# --- Due to macro, need to create Any stream
	devices = PortAudio.devices()
	stream = Any;
	buf2 = to44(buffer,fe)
	# --- Suprress to avoid underflow warnings
	@suppress let
		# --- Create default streamer,
		stream = PortAudioStream();
	end
	# --- Playing file through device
	@suppress write(stream,buf2);
	close(stream);
	# We need to close the streamer.
end


""" playbis
---
Play a sound based on input buffer
# --- Syntax
  play2(buffer)
# --- Input parameters
- buffer  : Vector to be played [Array{Int}]
# --- Output parameters
- []
# ---
# v 1.0 - Corentin Lavaud.
"""
function playbis(buffer)
	# config
	buf_size = 256
	sample_rate = 44100;
	# simply play a single buffer
	#play(buffer, sample_rate);
	# use default device
	devID = -1
	# or retrieve a specific device by name
	#devID = PortAudio.find_device("default")

	# open a stream and write audio to the output
	stream = open(devID, (0, 2), sample_rate, buf_size)
	write(stream, buffer)
	close(stream)
end


"""
---
Resample input audio buffer of frequency fe to 44100 Hz for play() routine
--- Syntax
y = to44(x,fe)
# --- Input parameters
- x	  : Input signal @fe
- fe  : Audio sampling frequency of x
# --- Output parameters
- y	  : Audio buffer from x @44100 Hz
# ---
# v 1.0 - Robin Gerzaguet.
# """
function to44(sig,fe)

	rate = (44100 / fe);
	return resample(sig,rate);
end


end
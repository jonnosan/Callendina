#!/usr/bin/ruby
dir = File.dirname(File.expand_path(__FILE__))
$LOAD_PATH.unshift dir + "/../lib"

require "callendina"
require "unimidi"

include CallendinaConstants #so I,II,IV etc works

song=Callendina.new do
	bpm 120
	key "Gm"
	key "Ab4"
	key "C#4M"
	key "C4"
	

	bass=Instrument.new {
		channel 8
	}

	kick=PolyBeat.new {
		channel 10
	}

	open_hh=PolyBeat.new {
		channel 10
		cycle 1
		note 42
	}
	
	snare=PolyBeat.new {
		channel 10
		cycle 8
		offset 7
		note 40
	}


	clave=PolyBeat.new {
		channel 10
		cycle 3
		offset 1
		note 50
	}


	drums=[kick,open_hh,snare,clave]

	pad=Pad.new 
	
	part(:intro) {
		bpm 120
		key "Am"
		chords [I,V,IV,VII] 
		instruments [pad,drums]
	}
	
	
	part(:chorus) {
		chords [I,II,III,IV] 
		instruments [bass,drums-[clave],pad]

	}


end


	if (UniMIDI::Output.all.length)>1 then
		output = UniMIDI::Output.gets
	else
		output = UniMIDI::Output.all.first
	end

song.dump

song.play(output) {
		intro (4.bars)		
		chorus (16.bars)	
}


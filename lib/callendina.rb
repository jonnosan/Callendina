#!/usr/bin/ruby

require "unimidi"



module CallendinaConstants
	I=1
	II=2
	III=3
	IV=4
	V=5
	VI=6
	VII=7
	VIII=8
	
	TICKS_PER_SIXTEENTH_NOTE=6
	TICKS_PER_QUARTER_NOTE=24

end


class Fixnum
	def bars
		return self		
	end
	
	def bar
		return self		
	end

end




class Instrument
	attr_accessor :name
	def channel	(c=nil)
		return @channel if c.nil?
		@channel=c
	end
	
	def initialize(&block)
		@channel=1
		instance_eval &block if block_given?
		
	end

	def play_tick(output,tick_info)

		if tick_info.tick%TICKS_PER_SIXTEENTH_NOTE==0 then
			play_sixteenth(output,tick_info)
		end
	end
	

	#basic arpegiator
	def play_sixteenth(output,tick_info)
		if (tick_info.sixteenth % 2 ==0)
			@active_note=tick_info.current_bar_chords[tick_info.sixteenth % tick_info.current_bar_chords.length]
			output.puts(0x8F+@channel,@active_note,100)
		else
				output.puts(0x8F+@channel,@active_note,0) #turn off last note
		end		
	end
	
	
end


class Pad < Instrument
	def play_tick(output,tick_info)
		if tick_info.tick==0 then
				tick_info.current_bar_chords.each do |note|
					output.puts(0x8F+@channel,note,100)
				end
		end
		
		if tick_info.tick==tick_info.ticks_in_bar-1 then
				tick_info.current_bar_chords.each do |note|
					output.puts(0x8F+@channel,note,0)
				end
		end
		
	end

end


class Drum < Instrument
	def	note (n=nil)
		return @note if n.nil?
		@note=n
	end
	
	def initialize(&block)
		note 36
		super(&block)
	end

end


class PolyBeat < Drum
	def	cycle(c=nil)
		return @cycle if c.nil?
		@cycle=c
	end

	def	offset(val=nil)
		return @offset if val.nil?
		@offset=val
	end
	
	def initialize(&block)
		cycle 4	
		offset 0
		super(&block)
	end
  
 	def play_sixteenth(output,tick_info)
		if (tick_info.sixteenth % cycle ==offset)
			output.puts(0x8F+@channel,note,100)
			output.puts(0x8F+@channel,note,0)
		end		
	end

end

class TickInfo
	attr_accessor	:key,:current_bar_chords,:next_bar_chords,:tick,:ticks_in_bar,:bar
	
	def sixteenth
		@tick/TICKS_PER_SIXTEENTH_NOTE
	end
end

class Callendina

	attr_accessor :name,:enclosing_song
	SCALE={
		:minor=>[0,2,3,5,7,8,10], #Minor
		:major=>[0,2,4,5,7,9,11], #Major
	}



	#midi notes in octave 0
	NOTES={
		'C'=>0,
		'D'=>2,
		'E'=>4,
		'F'=>5,
		'G'=>7,
		'A'=>9,
		'B'=>11
	}	
	
	def initialize(&block)
		bpm 120
		key "C3M"
		measure_length 4
		@name="::MAIN"
		@parts={}
		@instruments={}
		@chords=nil
		@enclosing_song=self
		instance_eval &block if block_given?
		

	end	

	def bpm(val)
		@bpm=val
	end

	def measure_length(val=nil)
		@measure_length=val unless val.nil?
		@measure_length
	end

	
	def key(s)
		m=/^([ABCDEFG])([b#]{0,1})(\d{0,1})([Mm]{0,1})$/.match(s)
		raise("ERROR: invalid key #{s}") if m.nil?
		@key_note=m[1]+m[2]
		@octave=m[3].to_i unless m[3]==""
		@key_type=(m[4]=='m' ? :minor : :major)
		@key=s
		@root_note=NOTES[@key_note[0]]+(12*@octave)
		@root_note+=1 if(@key_note[1]=='#')
		@root_note-=1 if(@key_note[1]=='b')
	end
	
	def dump(indent=0)
		log("--PART: #{name}",indent)
		log("BPM: #{@bpm}",indent)
		log("KEY NOTE: #{@key_note}",indent)
		log("OCTAVE: #{@octave}",indent)
		log("KEY TYPE: #{@key_type}",indent)
		log("CHORDS: #{@chords}",indent)

		instruments.each do |inst|
			log("--INSTRUMENT: #{inst.class} : CHANNEL #{inst.channel}",indent)
		end

		
		@parts.each_value do |part|
			part.dump(indent+1)
		end
			
	end

	
	
	def log(s,indent=0)
		puts "#{'  '*indent}#{s}"
	end
	
	def chords(chordlist=nil)
		return @chords if chordlist.nil?
		@chords=[]
		chordlist.each do |chord|
			
			if chord.is_a? Integer then
				c=[]
				[0,2,4].each do |delta|
					offset=SCALE[@key_type][(delta+chord-1) % SCALE[@key_type].length]
					offset+=12 if ((delta+chord-1) >= SCALE[@key_type].length)
					c<<(offset+@root_note)
					#log("#{chord}/#{delta}/#{offset}/#{final}")

				end	
				@chords<<c
			end		
		end
	end

	def chords=(chordlist)
		@chords=chordlist
	end



	def part(part_name,&block)
		new_part=Callendina.new
		new_part.bpm @bpm
		new_part.key @key
		new_part.chords=@chords
		new_part.instance_eval &block
		new_part.name=part_name.to_s
		new_part.enclosing_song=enclosing_song
		@parts[part_name]=new_part
		
	end	

	def play_bar(output,bar)
	
		ticks_per_second=@bpm*24.0/60.0
		tick_duration = 1.0/(ticks_per_second)

		tick_info=TickInfo.new
		tick_info.current_bar_chords=@chords[bar % @chords.length]
		tick_info.next_bar_chords=@chords[(1+bar) % @chords.length]
		tick_info.ticks_in_bar=(TICKS_PER_QUARTER_NOTE*measure_length)
		tick_info.tick=0
		tick_info.bar=bar
		tick_info.ticks_in_bar.times do
			
			output.puts(0xF8) 		#send a click
			
			instruments.each do |instrument|
				instrument.play_tick(output,tick_info)				
			end
			tick_info.tick+=1
			sleep(tick_duration)
			
		end
	end
	
	def method_missing(m, *args, &block)
		part=@parts[m.to_sym]
		if ! part.nil? then     		
			bars=(args.length==0 ? part.chords.length : args[0] )
			bars.times do |bar|
				log ("PLAYING: bar #{bar} of #{bars}  of #{m}")
				part.play_bar(@output,bar)
			end
	    else
    	  raise ArgumentError.new("Method `#{m}` doesn't exist.")
	    end
	end
	
	def play(output,&block)
		output.puts(0xFA) 		#send a start
	
		@output=output
		instance_eval &block if block_given?
		output.puts(0xFC) 		#send a stop
		
	end
	


	def instruments(list=nil)
		return @instruments.flatten if list.nil?
		@instruments=list
	end
end





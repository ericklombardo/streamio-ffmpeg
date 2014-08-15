$LOAD_PATH.unshift File.dirname(__FILE__)

require 'logger'
require 'stringio'

require 'ffmpeg/version'
require 'ffmpeg/errors'
require 'ffmpeg/movie'
require 'ffmpeg/io_monkey'
require 'ffmpeg/transcoder'
require 'ffmpeg/encoding_options'

module FFMPEG
  # FFMPEG logs information about its progress when it's transcoding.
  # Jack in your own logger through this method if you wish to.
  #
  # @param [Logger] log your own logger
  # @return [Logger] the logger you set
  def self.logger=(log)
    @logger = log
  end

  # Get FFMPEG logger.
  #
  # @return [Logger]
  def self.logger
    return @logger if @logger
    logger = Logger.new(STDOUT)
    logger.level = Logger::INFO
    @logger = logger
  end

  # Set the path of the ffmpeg binary.
  # Can be useful if you need to specify a path such as /usr/local/bin/ffmpeg
  #
  # @param [String] path to the ffmpeg binary
  # @return [String] the path you set
  def self.ffmpeg_binary=(bin)
    @ffmpeg_binary = bin
  end

  # Get the path to the ffmpeg binary, defaulting to 'ffmpeg'
  #
  # @return [String] the path to the ffmpeg binary
  def self.ffmpeg_binary
    @ffmpeg_binary || 'ffmpeg'
  end

  def self.run(input_file,output_file,input_options,output_options) 
    command = "#{FFMPEG.ffmpeg_binary} -y #{input_options} -i #{Shellwords.escape(input_file)} #{output_options} #{Shellwords.escape(output_file)}"
    FFMPEG.logger.info("Running command...\n#{command}\n")
    output = ""
  
    Open3.popen3(command) do |stdin, stdout, stderr, wait_thr|
  	begin
  	  yield if block_given?
  	  next_line = Proc.new do |line|
  		fix_encoding(line)
  		output << line
  		if line.include?("time=")
  		  if line =~ /time=(\d+):(\d+):(\d+.\d+)/ # ffmpeg 0.8 and above style
  			time = ($1.to_i * 3600) + ($2.to_i * 60) + $3.to_f
  		  else # better make sure it wont blow up in case of unexpected output
  			time = 0.0
  		  end
  		  #progress = time / @movie.duration
  		  yield  if block_given?
  		end
  	  end
      
      FFMPEG.logger.error "Failed encoding...\n#{command}\n\n#{output}\n" unless File.exists?(output_file)
      
  	rescue Timeout::Error => e
  	  FFMPEG.logger.error "Process hung...\ncommand\n#{command}\nOutput\n#{output}\n"
  	  raise Error, "Process hung. Full output: #{output}"
  	end
    end
  end

  def self.fix_encoding(output)
    output[/test/]
  rescue ArgumentError
    output.force_encoding("ISO-8859-1")
  end  
  
end

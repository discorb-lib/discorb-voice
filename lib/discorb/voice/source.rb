# frozen_string_literal: true
require "open3"
require "tmpdir"

module Discorb
  module Voice
    #
    # The source of audio data.
    # @abstract
    #
    class Source
      #
      # The audio ogg stream. This MUST be implemented by subclasses.
      #
      # @return [#read] The audio ogg stream.
      #
      def io
        raise NotImplementedError
      end

      #
      # Clean up the source.
      # This does nothing by default.
      #
      def cleanup
        # noop
      end
    end

    #
    # Plays audio from a source, using FFmpeg.
    # @note You must install FFmpeg and should be on the PATH.
    #
    class FFmpegAudio
      attr_reader :stdin, :stdout, :stderr, :process

      #
      # Creates a new FFmpegAudio.
      #
      # @param [String, IO] source The source of audio data.
      # @param [Integer] bitrate The bitrate of the audio.
      # @param [{String => String}] extra_options Extra options for FFmpeg. This will be passed before `-i`.
      # @param [{String => String}] extra_options2 Extra options for FFmpeg. This will be passed after `-i`.
      #
      def initialize(source, bitrate: 128, extra_options: {}, extra_options2: {})
        if source.is_a?(String)
          source_path = source
          @tmp_path = nil
        else
          source_path = "#{Dir.tmpdir}/#{Process.pid}.#{source.object_id}"
          @tmp_path = source_path
          File.open(source_path, "wb") do |f|
            while chunk = source.read(4096)
              f.write(chunk)
            end
          end
        end
        args = %w[ffmpeg]
        extra_options.each do |key, value|
          args += ["-#{key}", "#{value}"]
        end
        args += %W[
          -i #{source_path}
          -f opus
          -c:a libopus
          -ar 48000
          -ac 2
          -b:a #{bitrate}k
          -loglevel warning
          -map_metadata -1]
        extra_options2.each do |key, value|
          args += ["-#{key}", "#{value}"]
        end
        args += %w[pipe:1]
        @stdin, @stdout, @process = Open3.popen2(*args)
      end

      def io
        @stdout
      end

      #
      # Kills the FFmpeg process, and closes io.
      #
      def cleanup
        @process.kill
        @stdin.close
        @stdout.close
        File.delete(@tmp_path) if @tmp_path
      end
    end

    #
    # Plays audio from a ogg file.
    #
    class OggAudio
      attr_reader :io

      #
      # Opens an ogg file.
      #
      # @param [String, IO] src The ogg file to open, or an IO object.
      #
      def initialize(src)
        @io = if src.is_a?(String)
            File.open(src, "rb")
          else
            src
          end
      end
    end
  end
end

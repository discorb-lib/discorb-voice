require "open3"

module Discorb::Voice
  class FFmpegAudio
    attr_reader :stdin, :stdout, :stderr, :process

    def initialize(source, bitrate: 128)
      @stdin, @stdout, @stderr, @process = Open3.popen3(
        *(%W[ffmpeg -i #{source} -map_metadata -1 -f opus -c:a libopus -ar 48000 -ac 2 -b:a #{bitrate}k -loglevel warning pipe:1"])
      )
    end

    def io
      @stdout
    end

    def kill
      @process.kill
    end
  end

  class OggAudio
    attr_reader :io

    def initialize(src)
      @io = File.open(src, "rb")
    end
  end
end

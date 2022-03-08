# frozen_string_literal: true

require "discorb"
begin
  require "rbnacl"
rescue LoadError
  raise LoadError, <<~ERROR, cause: nil
                               Could not load libsodium library.
                               Follow the instructions at https://github.com/discorb-lib/discorb-voice#install-libsodium
                             ERROR
end
require "open3"
begin
  ffmpeg_version = Open3.capture2e("ffmpeg -version")[0]
rescue Errno::ENOENT
  raise LoadError, <<~ERROR, cause: nil
                               Could not find ffmpeg.
                               Follow the instructions at https://github.com/discorb-lib/discorb-voice#install-ffmpeg
                             ERROR
else
  line = ffmpeg_version.split("\n").find { |l| l.start_with?("configuration: ") }
  unless line.include? "--enable-libopus"
    raise LoadError, <<~ERROR, cause: nil
                                 Your ffmpeg version does not support opus.
                                 Install ffmpeg with opus support.
                               ERROR
  end
end
require_relative "voice/version"
require_relative "voice/extend"
require_relative "voice/core"
require_relative "voice/ogg"
require_relative "voice/source"

module Discorb
  module Voice
    class Error < StandardError; end
  end
end

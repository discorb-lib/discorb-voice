# frozen_string_literal: true

require "discorb"
begin
  require "discorb/voice/lib/sodium"
rescue LoadError => e
  puts e.message.force_encoding("SJIS")
  raise LoadError, "Could not load libsodium library.  Please install it."
end

require_relative "voice/version"
require_relative "voice/extend"
require_relative "voice/core"

module Discorb
  module Voice
    class Error < StandardError; end
  end
end

# frozen_string_literal: true

require "discorb"
begin
  require "rbnacl"
rescue LoadError => e
  # puts e.message.force_encoding("SJIS")
  raise LoadError, "Could not load libsodium library.  Please install it.", cause: nil
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

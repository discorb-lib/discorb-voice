# frozen_string_literal: true

require "discorb"
require_relative "voice/version"
require_relative "voice/extend"
require_relative "voice/core"

module Discorb
  module Voice
    class Error < StandardError; end
  end
end

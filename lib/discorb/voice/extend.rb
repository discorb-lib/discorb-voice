# frozen_string_literal: true

require_relative "./lib/client"

module Discorb::Voice
  module ClientVoicePrepend
    def initialize(...)
      super
      @voice_clients = Discorb::Dictionary.new
      @voice_conditions = {}
    end
  end

  module ClientVoiceInclude
    def event_voice_server_update(data)
      client = Discorb::Voice::VoiceClient.new(self, data)
      @voice_clients[data[:guild_id]] = client
      @voice_conditions[data[:guild_id]].signal client
    end

    def connect_to(channel)
      Async do
        send_gateway(4, **{
                          "guild_id": channel.guild.id.to_s,
                          "channel_id": channel.id.to_s,
                          "self_mute": channel.guild.me.voice_state&.self_mute?,
                          "self_deaf": channel.guild.me.voice_state&.self_deaf?,
                        })
        condition = Async::Condition.new
        @voice_conditions[channel.guild.id.to_s] = condition
        condition.wait
      end
    end
  end
end

class Discorb::Client
  attr_accessor :voice_clients

  include Discorb::Voice::ClientVoiceInclude
  prepend Discorb::Voice::ClientVoicePrepend
end

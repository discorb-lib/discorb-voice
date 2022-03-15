# frozen_string_literal: true
# rubocop:disable Style/Documentation

module Discorb
  module Voice
    # @private
    module ClientVoicePrepend
      attr_reader :voice_conditions
      attr_reader :voice_mutexes

      def initialize(*, **)
        super
        @voice_clients = Discorb::Dictionary.new
        @voice_conditions = {}
        @voice_mutexes = {}
      end

      def event_voice_server_update(data)
        @log.debug("Received VOICE_SERVER_UPDATE")
        client = Discorb::Voice::Client.new(self, data)
        @voice_clients[data[:guild_id]] = client
        client.connect_condition.wait
        @voice_conditions[data[:guild_id]].signal client
      end

      def disconnect_voice(guild_id)
        send_gateway(
          4,
          guild_id: guild_id,
          channel_id: nil,

        )
      end

      def connect_to(channel)
        Async do
          @log.debug("Connecting to #{channel.id}")
          send_gateway(
            4,
            guild_id: channel.guild.id.to_s,
            channel_id: channel.id.to_s,
            self_mute: channel.guild.me.voice_state&.self_mute?,
            self_deaf: channel.guild.me.voice_state&.self_deaf?,

          )
          condition = Async::Condition.new
          @voice_conditions[channel.guild.id.to_s] = condition
          condition.wait
        end
      end
    end
  end

  class Client
    # @return [Discorb::Dictionary{String => Discorb::Voice::Client}] The voice clients.
    attr_accessor :voice_clients

    prepend Discorb::Voice::ClientVoicePrepend
  end

  class Guild
    # @!attribute [r] voice_client
    #   @return [Discorb::Voice::Client] The voice client.
    #   @return [nil] If the client is not connected to the voice server.
    def voice_client
      @client.voice_clients[@id.to_s]
    end
  end

  module Connectable
    def connect
      Async do
        @client.connect_to(self).wait
      end
    end
  end
end

# rubocop:enable Style/Documentation

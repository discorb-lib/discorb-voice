# frozen_string_literal: true

require "async/io"
require "async/websocket"

module Discorb
  module Connectable
    def connect
      Async do
        @client.connect_to(self).wait
      end
    end
  end

  module Voice
    DATA_LENGTH = 1920 * 2

    class Client
      def initialize(client, data)
        @client = client
        @token = data[:token]
        @guild_id = data[:guild_id]
        @endpoint = data[:endpoint]
        Async do
          start_receive
        end
      end

      def speaking(high_priority: false)
        send_connection_message(5, {
          speaking: 1 + (high_priority ? 1 << 2 : 0),
          delay: 0,
        })
      end

      def stop_speaking
        send_connection_message(5, {
          speaking: false,
          delay: 0,
        })
      end

      private

      def start_receive
        Async do
          endpoint = Async::HTTP::Endpoint.parse("wss://" + @endpoint + "?v=4", alpn_protocols: Async::HTTP::Protocol::HTTP11.names)
          Async::WebSocket::Client.connect(endpoint, handler: Discorb::Gateway::RawConnection) do |conn|
            @connection = conn
            send_connection_message(
              0,
              {
                server_id: @guild_id,
                user_id: @client.user.id,
                session_id: @client.session_id,
                token: @token,
              }
            )
            while (raw_message = @connection.read)
              message = JSON.parse(raw_message, symbolize_names: true)
              pp message
              handle_voice_connection(message)
            end
          end
        end
      end

      def handle_voice_connection(message)
        data = message[:d]
        case message[:op]
        when 8
          @heartbeat_task = handle_heartbeat(data[:heartbeat_interval])
        when 2
          @endpoint = Async::IO::Endpoint.udp(data[:ip], data[:port])
          @udp_connection = @endpoint.connect
          send_connection_message(1, {
            protocol: "udp",
            data: {
              address: data[:ip],
              port: data[:port],
              mode: "xsalsa20_poly1305",
            },
          })
          @ssrc = data[:ssrc]
          @secret_key = data[:secret_key].pack("C*")
          @sequence = 0
          @timestamp = 0
        end
      end

      def create_header
        "\x80\x72" + [@sequence, @sequence * 960, ssrc].pack("nNN")
      end

      def encrypt_audio(buf, nonce)
        raise "No secret key found, despite encryption being enabled!" unless @secret_key

        secret_box = Discorb::Voice::SecretBox.new(@secret_key)

        secret_box.box(nonce.ljust(24, "\0"), buf)
      end

      def send_packet
        @sequence += 1
        @timestamp += 64
      end

      def handle_heartbeat(interval)
        Async do
          loop do
            sleep(interval / 1000.0 * 0.9)
            send_connection_message(3, rand(0..0xFFFF))
          end
        end
      end

      def send_connection_message(op, data)
        @connection.write(
          {
            op: op,
            d: data,
          }.to_json
        )
      end
    end
  end
end

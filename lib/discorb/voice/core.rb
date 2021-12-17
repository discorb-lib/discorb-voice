# frozen_string_literal: true

require "async"
require "async/websocket"
require "rbnacl"
require "socket"

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
    OPUS_SAMPLE_RATE = 48000
    OPUS_FRAME_LENGTH = 20

    class Client
      attr_reader :connect_condition

      def initialize(client, data)
        @client = client
        @token = data[:token]
        @guild_id = data[:guild_id]
        @endpoint = data[:endpoint]
        @connect_condition = Async::Condition.new
        Async do
          start_receive false
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

      def play(data)
        task = Async do
          speaking
          stream = OggStream.new(data.io)
          loops = 0
          start_time = Time.now.to_f
          delay = OPUS_FRAME_LENGTH / 1000.0

          stream.packets.each_with_index do |packet, i|
            @timestamp += (OPUS_SAMPLE_RATE / 1000.0 * OPUS_FRAME_LENGTH).to_i
            @sequence += 1
            # puts packet.data[...10].unpack1("H*")
            # puts packet[-10..]&.unpack1("H*")
            send_audio(packet)
            # puts "Sent packet #{i}"
            loops += 1
            next_time = start_time + (delay * loops)
            sleep(next_time - Time.now.to_f) if next_time > Time.now.to_f
            # @voice_connection.flush
          end

          stop_speaking
        end
        @playing_task = task
      end

      def stop
        playing_task.stop
        send_audio(OPUS_SILENCE)
        stop_speaking
      end

      def disconnect
        @connection.close
        cleanup
      end

      private

      OPUS_SILENCE = [0xF8, 0xFF, 0xFE].pack("C*")

      def cleanup
        @heartbeat_task&.stop

        @voice_connection&.close
      end

      def send_audio(data)
        header = create_header
        @voice_connection.send(
          header + encrypt_audio(
            data,
            header
          ),
          0
          # @sockaddr
        )
      rescue IOError
        sleep 5
      end

      def start_receive(resume)
        Async do
          endpoint = Async::HTTP::Endpoint.parse("wss://" + @endpoint + "?v=4", alpn_protocols: Async::HTTP::Protocol::HTTP11.names)
          @client.log.info("Connecting to #{endpoint}")
          Async::WebSocket::Client.connect(endpoint, handler: Discorb::Gateway::RawConnection) do |conn|
            @connection = conn
            if resume
              send_connection_message(
                7,
                {
                  server_id: @guild_id,
                  session_id: @client.session_id,
                  token: @token,
                }
              )
            else
              send_connection_message(
                0,
                {
                  server_id: @guild_id,
                  user_id: @client.user.id,
                  session_id: @client.session_id,
                  token: @token,
                }
              )
            end
            while (raw_message = @connection.read)
              message = JSON.parse(raw_message, symbolize_names: true)
              handle_voice_connection(message)
            end
          rescue Protocol::WebSocket::ClosedError => e
            case e.code
            when 4014
              cleanup
            when 4015, 1001, 4009
              start_receive true
            end
          end
        end
      end

      def handle_voice_connection(message)
        data = message[:d]
        # pp data
        case message[:op]
        when 8
          @heartbeat_task = handle_heartbeat(data[:heartbeat_interval])
        when 2
          @port, @ip = data[:port], data[:ip]
          @sockaddr = Socket.pack_sockaddr_in(@port, @ip)
          @voice_connection = UDPSocket.new
          @voice_connection.connect(@ip, @port)
          @ssrc = data[:ssrc]

          @local_ip, @local_port = discover_ip.wait
          # p @local_ip, @local_port
          send_connection_message(1, {
            protocol: "udp",
            data: {
              address: @local_ip,
              port: @local_port,
              mode: "xsalsa20_poly1305",
            },
          })
          @sequence = 0
          @timestamp = 0
        when 4
          @secret_key = data[:secret_key].pack("C*")
          @box = RbNaCl::SecretBox.new(@secret_key)
          @connect_condition.signal
        end
      end

      def create_header
        [0x80, 0x78, @sequence, @timestamp, @ssrc].pack("CCnNN").ljust(12, "\0")
      end

      def encrypt_audio(buf, nonce)
        @box.box(nonce.ljust(24, "\0"), buf)
      end

      def discover_ip
        Async do
          packet = [
            1, 70, @ssrc,
          ].pack("S>S>I>").ljust(70, "\0")
          @voice_connection.send(packet, 0, @sockaddr)
          recv = @voice_connection.recv(70)
          ip_start = 4
          ip_end = recv.index("\0", ip_start)
          [recv[ip_start...ip_end], recv[-2, 2].unpack1("S>")]
        end
      end

      def handle_heartbeat(interval)
        Async do
          loop do
            sleep(interval / 1000.0 * 0.9)
            send_connection_message(3, Time.now.to_i)
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
        @connection.flush
      end
    end
  end
end

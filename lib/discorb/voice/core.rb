# frozen_string_literal: true

require "async"
require "async/websocket"
require "rbnacl"
require "socket"

module Discorb
  module Voice
    OPUS_SAMPLE_RATE = 48_000
    OPUS_FRAME_LENGTH = 20

    #
    # Client for voice connection.
    #
    class Client
      # @private
      attr_reader :connect_condition
      # @return [:connecting, :connected, :closed, :ready, :reconnecting] The current status of the voice connection
      attr_reader :status
      # @return [:stopped, :playing] The current status of playing audio
      attr_reader :playing_status
      # @return [Async::Condition] The condition of playing audio
      attr_reader :playing_condition

      # @private
      def initialize(client, data)
        @client = client
        @token = data[:token]
        @guild_id = data[:guild_id]
        @endpoint = data[:endpoint]
        @status = :connecting
        @playing_status = :stopped
        @connect_condition = Async::Condition.new
        @paused_condition = Async::Condition.new
        @play_condition = Async::Condition.new
        Async do
          start_receive false
        end
      end

      #
      # Sends a speaking indicator to the server.
      #
      # @param [Boolean] high_priority Whether to send audio in high priority.
      #
      def speaking(high_priority: false)
        flag = 1
        flag |= 1 << 2 if high_priority
        send_connection_message(5, {
          speaking: flag,
          delay: 0,
          ssrc: @ssrc,
        })
      end

      def stop_speaking
        send_connection_message(5, {
          speaking: false,
          delay: 0,
          ssrc: @ssrc,
        })
      end

      #
      # Plays audio from a source.
      #
      # @param [Discorb::Voice::Source] source data The audio source
      # @param [Boolean] high_priority Whether to play audio in high priority
      #
      def play(source, high_priority: false)
        @playing_task = Async do
          speaking(high_priority: high_priority)
          @playing_status = :playing
          @playing_condition = Async::Condition.new
          stream = OggStream.new(source.io)
          loops = 0
          @start_time = Time.now.to_f
          delay = OPUS_FRAME_LENGTH / 1000.0

          stream.packets.each_with_index do |packet, _i|
            if @playing_status == :stopped
              source.cleanup
              break
            elsif @playing_status == :paused
              @paused_condition.wait
            elsif @status != :ready
              sleep 0.02 while @status != :ready

              speaking(high_priority: high_priority)
            end
            # p i
            @timestamp += (OPUS_SAMPLE_RATE / 1000.0 * OPUS_FRAME_LENGTH).to_i
            @sequence += 1
            # puts packet.data[...10].unpack1("H*")
            # puts packet[-10..]&.unpack1("H*")
            send_audio(packet)
            # puts "Sent packet #{i}"
            loops += 1
            next_time = @start_time + (delay * (loops + 1))
            # p [next_time, Time.now.to_f, delay]
            sleep(next_time - Time.now.to_f) if next_time > Time.now.to_f
            # @voice_connection.flush
          end
          # p :e
          @playing_status = :stopped
          @playing_condition.signal
          source.cleanup
          stop_speaking
        end
      end

      # NOTE: This is commented out because it raises an error.
      #    It's not clear why this is happening.
      # #
      # # Pause playing audio.
      # #
      # def pause
      #   raise VoiceError, "Not playing" unless @playing_status == :playing
      #   send_audio(OPUS_SILENCE)
      #   @paused_condition = Async::Condition.new
      #   @paused_offset = Time.now.to_f - @start_time
      #   @playing_status = :paused
      # end

      # #
      # # Resumes playing audio.
      # #
      # def resume
      #   raise VoiceError, "Not paused" unless @playing_status == :paused
      #   @paused_condition.signal
      #   @start_time = Time.now.to_f - @paused_offset
      # end

      #
      # Stop playing audio.
      #
      def stop
        @playing_status = :stopped
        send_audio(OPUS_SILENCE)
      end

      #
      # Disconnects from the voice server.
      #
      def disconnect
        begin
          @connection.close
        rescue StandardError
          nil
        end
        @client.disconnect_voice(@guild_id)
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
        @client.log.warn("Voice UDP connection closed")
        @playing_task.stop if @status != :closed
      end

      def start_receive(resume)
        Async do
          @client.voice_mutexes[@guild_id] ||= Mutex.new
          next if @client.voice_mutexes[@guild_id].locked?
          @client.voice_mutexes[@guild_id].synchronize do
            endpoint = Async::HTTP::Endpoint.parse("wss://" + @endpoint + "?v=4", alpn_protocols: Async::HTTP::Protocol::HTTP11.names)
            @client.log.info("Connecting to #{endpoint}")
            @connection = Async::WebSocket::Client.connect(endpoint, handler: Discorb::Gateway::RawConnection)
            @status = :connected
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
          rescue Async::Wrapper::Cancelled
            @status = :closed
            cleanup
          rescue Errno::EPIPE, EOFError
            @status = :reconnecting
            @connect_condition = Async::Condition.new
            start_receive true
          rescue Protocol::WebSocket::ClosedError => e
            case e.code
            when 4014
              @status = :closed
              cleanup
            when 4006
              @status = :reconnecting
              @connect_condition = Async::Condition.new
              start_receive false
            else
              @status = :closed
              cleanup
            end
          end
        end
      end

      def handle_voice_connection(message)
        @client.log.debug("Voice connection message: #{message}")
        data = message[:d]
        # pp data
        case message[:op]
        when 8
          @heartbeat_task = handle_heartbeat(data[:heartbeat_interval])
        when 2
          @port, @ip = data[:port], data[:ip]
          @client.log.debug("Connecting to voice UDP, #{@ip}:#{@port}")
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
          @status = :ready
        when 9
          @connect_condition.signal
          @status = :ready
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

      def send_connection_message(opcode, data)
        @connection.write(
          {
            op: opcode,
            d: data,
          }.to_json
        )
        @connection.flush
      rescue IOError, Errno::EPIPE
        return if @status == :reconnecting
        @status = :reconnecting
        @client.log.warn("Voice Websocket connection closed")
        @connection.close
        @connect_condition = Async::Condition.new
        start_receive true
      end
    end
  end
end

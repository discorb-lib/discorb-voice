# frozen_string_literal: true
module Discorb
  module Voice
  #
  # Represents a Ogg stream.
  #
  class OggStream
    #
    # Creates a new Ogg stream.
    #
    # @param [IO] io The audio ogg stream.
    #
    def initialize(io)
      @io = io
    end

    #
    # Enumerates the packets of the Ogg stream.
    #
    # @return [Enumerator<Discorb::Voice::OggStream::Page::Packet>] The packets of the Ogg stream.
    #
    def packets
      Enumerator.new do |enum|
        part = +""
        raw_packets.each do |packet|
          part << packet.data
          unless packet.partial
            enum << part
            part = +""
          end
        end
      end
    end

    #
    # Enumerates the raw packets of the Ogg stream.
    # This may include partial packets.
    #
    # @return [Enumerator<Discorb::Voice::OggStream::Page::Packet>] The raw packets of the Ogg stream.
    #
    def raw_packets
      Enumerator.new do |enum|
        loop do
          # p c += 1
          break if @io.read(4) != "OggS"
          pg = Page.new(@io)
          pg.packets.each do |packet|
            enum << packet
          end
          # enum << pg.packets.next
        end
      end
    end

    #
    # Represents a page of the Ogg stream.
    #
    class Page
      # @return [Struct] The struct of the packet
      Packet = Struct.new(:data, :partial, :page)
      # @return [Integer] The version of the page.
      attr_reader :version
      # @return [Integer] The header type of the page.
      attr_reader :header_type
      # @return [Integer] The granule position of the page.
      attr_reader :granule_position
      # @return [Integer] The bitstream serial number of the page.
      attr_reader :bitstream_serial_number
      # @return [Integer] The page sequence number of the page.
      attr_reader :page_sequence_number
      # @return [Integer] The CRC checksum of the page.
      attr_reader :crc_checksum
      # @return [Integer] The length of the page segment table.
      attr_reader :page_segments
      # @return [String] The body of the page.
      attr_reader :body

      #
      # Creates a new page.
      #
      # @param [IO] io The audio ogg stream.
      # @note This method will seek the io.
      #
      def initialize(io)
        @version, @header_type, @granule_position, @bitstream_serial_number, @page_sequence_number, @crc_checksum, @page_segments =
          io.read(23).unpack("CCQ<L<L<L<C")
        @segtable = io.read(@page_segments)
        len = @segtable.unpack("C*").sum
        @body = io.read(len)
      end

      #
      # Enumerates the packets of the page.
      #
      # @return [Enumerator<Discorb::Voice::OggStream::Page::Packet>] The packets of the page.
      #
      def packets
        Enumerator.new do |enum|
          offset = 0
          length = 0
          partial = true
          @segtable.bytes.each do |seg|
            if seg == 255
              length += 255
              partial = true
            else
              length += seg
              partial = false
              enum << Packet.new(@body[offset, length], partial, self)
              offset += length
              length = 0
            end
          end

          enum << Packet.new(@body[offset, length], partial, self) if partial
        end
      end
    end
  end
  end
end

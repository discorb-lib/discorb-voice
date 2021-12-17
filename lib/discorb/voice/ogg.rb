module Discorb::Voice
  class OggStream
    def initialize(io)
      @io = io
    end

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

    def raw_packets
      Enumerator.new do |enum|
        loop do
          if @io.read(4) != "OggS"
            break
          end
          pg = Page.new(@io)
          pg.packets.each do |packet|
            enum << packet
          end
          # enum << pg.packets.next
          # p pg.header_type
        end
      end
    end

    class Page
      Packet = Struct.new(:data, :partial, :page)
      attr_reader :version, :header_type, :granule_position, :bitstream_serial_number, :page_sequence_number, :crc_checksum, :page_segments, :body

      def initialize(io)
        @version, @header_type, @granule_position, @bitstream_serial_number, @page_sequence_number, @crc_checksum, @page_segments =
          io.read(23).unpack("CCQ<L<L<L<C")
        @segtable = io.read(@page_segments)
        len = @segtable.unpack("C*").sum
        @body = io.read(len)
      end

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

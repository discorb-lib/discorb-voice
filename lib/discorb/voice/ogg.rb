module Discorb::Voice
  class OggStream
    def initialize(io)
      @io = io
    end

    def pages
      Enumerator.new do |enum|
        loop do
          pg = Page.new(@io)
          pg.packets.each do |packet|
            enum << packet
          end
          # enum << pg.packets.next
          # p pg.header_type
          break if pg.header_type == 4
        end
      end
    end

    class Page
      Packet = Struct.new(:data, :partial)
      attr_reader :version, :header_type, :granule_position, :bitstream_serial_number, :page_sequence_number, :crc_checksum, :page_segments, :body

      def initialize(io)
        @version, @header_type, @granule_position, @bitstream_serial_number, @page_sequence_number, @crc_checksum, @page_segments =
          io.read(27).unpack("@4CCQ<L<L<L<C")
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
              enum << Packet.new(@body[offset, length], partial)
              offset += length
              length = 0
            end
          end

          enum << Packet.new(@body[offset, length], partial) if partial
        end
      end
    end
  end
end

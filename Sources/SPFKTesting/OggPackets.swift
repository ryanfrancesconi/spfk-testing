// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-testing

import Foundation

/// A single-stream Ogg file's pages and packets, read without any metadata library. Every page's
/// CRC is checked, so a file a writer left inconsistent fails to read rather than misreads.
public struct OggPackets: Equatable, Sendable {
    public enum ReadError: Error, Equatable {
        case notOgg
        case badCRC(page: UInt32)
        case malformed(String)
    }

    /// One page: its header fields and body, as stored.
    public struct Page: Equatable, Sendable {
        public let headerType: UInt8
        public let granulePosition: UInt64
        public let serialNumber: UInt32
        public let sequenceNumber: UInt32
        public let lacingValues: [UInt8]
        public let body: Data

        public init(headerType: UInt8, granulePosition: UInt64, serialNumber: UInt32, sequenceNumber: UInt32, lacingValues: [UInt8], body: Data) {
            self.headerType = headerType
            self.granulePosition = granulePosition
            self.serialNumber = serialNumber
            self.sequenceNumber = sequenceNumber
            self.lacingValues = lacingValues
            self.body = body
        }

        /// Whether the page's first packet began on an earlier page.
        public var isContinued: Bool {
            headerType & 0x01 != 0
        }

        /// The page as stored, with `crc` in its checksum field.
        public func encoded(crc: UInt32) -> Data {
            var data = Data("OggS".utf8) + Data([0, headerType])
            data += OggPackets.le(granulePosition, 8) + OggPackets.le(UInt64(serialNumber), 4) + OggPackets.le(UInt64(sequenceNumber), 4)
            data += OggPackets.le(UInt64(crc), 4) + Data([UInt8(lacingValues.count)]) + Data(lacingValues) + body
            return data
        }

        /// The page as stored, with its checksum computed.
        public var encoded: Data {
            encoded(crc: OggPackets.crc(encoded(crc: 0)))
        }
    }

    /// One packet and the index of the page it ends on.
    public struct Packet: Equatable, Sendable {
        public let data: Data
        public let lastPage: Int
    }

    public let pages: [Page]
    /// Every complete packet, in order.
    public let packets: [Packet]

    public init(_ data: Data) throws {
        let bytes = Data(data)
        guard bytes.starts(with: Data("OggS".utf8)) else { throw ReadError.notOgg }

        var pages: [Page] = []
        var offset = 0

        while offset < bytes.count {
            guard offset + 27 <= bytes.count, bytes.subdata(in: offset ..< offset + 4) == Data("OggS".utf8) else {
                throw ReadError.malformed("no page at \(offset)")
            }

            let count = Int(bytes[offset + 26])
            guard offset + 27 + count <= bytes.count else { throw ReadError.malformed("lacing overruns at \(offset)") }

            let lacing = [UInt8](bytes.subdata(in: offset + 27 ..< offset + 27 + count))
            let bodyStart = offset + 27 + count
            let bodyEnd = bodyStart + lacing.reduce(0) { $0 + Int($1) }
            guard bodyEnd <= bytes.count else { throw ReadError.malformed("body overruns at \(offset)") }

            let page = Page(
                headerType: bytes[offset + 5],
                granulePosition: Self.uint(bytes, at: offset + 6, 8),
                serialNumber: UInt32(Self.uint(bytes, at: offset + 14, 4)),
                sequenceNumber: UInt32(Self.uint(bytes, at: offset + 18, 4)),
                lacingValues: lacing,
                body: bytes.subdata(in: bodyStart ..< bodyEnd)
            )

            var stored = bytes.subdata(in: offset ..< bodyEnd)
            stored.replaceSubrange(22 ..< 26, with: Data(count: 4))
            guard Self.crc(stored) == UInt32(Self.uint(bytes, at: offset + 22, 4)) else { throw ReadError.badCRC(page: page.sequenceNumber) }

            pages.append(page)
            offset = bodyEnd
        }

        self.pages = pages
        packets = Self.packets(in: pages)
    }

    public init(contentsOf url: URL) throws {
        try self.init(Data(contentsOf: url))
    }

    /// The comment header's Vorbis comment: Vorbis's `\x03vorbis` packet or Opus's `OpusTags`.
    public func comment() throws -> VorbisComment? {
        guard packets.count >= 2 else { return nil }
        let packet = packets[1].data

        if packet.starts(with: Self.vorbisCommentMagic) {
            return try VorbisComment(Data(packet.dropFirst(Self.vorbisCommentMagic.count)))
        }

        if packet.starts(with: Self.opusTagsMagic) {
            return try VorbisComment(Data(packet.dropFirst(Self.opusTagsMagic.count)))
        }

        return nil
    }

    /// How many leading packets are headers: three for Vorbis, two for Opus.
    public var headerPacketCount: Int {
        packets.first?.data.starts(with: Data("OpusHead".utf8)) == true ? 2 : 3
    }

    /// The pages after the last header packet's, from which the audio packets are read.
    public var audioPages: ArraySlice<Page> {
        guard packets.count >= headerPacketCount else { return [] }
        return pages[(packets[headerPacketCount - 1].lastPage + 1)...]
    }

    public static let vorbisCommentMagic = Data([0x03]) + Data("vorbis".utf8)
    public static let opusTagsMagic = Data("OpusTags".utf8)

    // MARK: - Helpers

    private static func packets(in pages: [Page]) -> [Packet] {
        var packets: [Packet] = []
        var current = Data()

        for (index, page) in pages.enumerated() {
            var offset = 0

            for value in page.lacingValues {
                current += page.body.subdata(in: offset ..< offset + Int(value))
                offset += Int(value)

                if value < 255 {
                    packets.append(Packet(data: current, lastPage: index))
                    current = Data()
                }
            }
        }

        return packets
    }

    /// Ogg's CRC-32: polynomial `0x04C11DB7`, no reflection, zero initial value and no final XOR.
    /// Over raw buffers, which an unoptimized test build runs far faster than an iteration of `Data`.
    public static func crc(_ data: Data) -> UInt32 {
        crcTable.withUnsafeBufferPointer { table in
            data.withUnsafeBytes { bytes in
                var crc: UInt32 = 0
                for byte in bytes {
                    crc = crc << 8 ^ table[Int(crc >> 24 ^ UInt32(byte))]
                }
                return crc
            }
        }
    }

    private static let crcTable: [UInt32] = (0 ..< 256).map { index in
        (0 ..< 8).reduce(UInt32(index) << 24) { value, _ in
            value & 0x8000_0000 != 0 ? value << 1 ^ 0x04C1_1DB7 : value << 1
        }
    }

    static func uint(_ data: Data, at offset: Int, _ count: Int) -> UInt64 {
        data.dropFirst(offset).prefix(count).reversed().reduce(0) { $0 << 8 | UInt64($1) }
    }

    static func le(_ value: UInt64, _ count: Int) -> Data {
        Data((0 ..< count).map { UInt8(truncatingIfNeeded: value >> (8 * UInt64($0))) })
    }
}

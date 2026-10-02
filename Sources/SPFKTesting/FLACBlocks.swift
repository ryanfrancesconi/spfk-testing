// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-testing

import Foundation

/// A FLAC file's metadata blocks, read without any metadata library: their types, payloads and
/// order, `STREAMINFO`'s rate and length, `APPLICATION` IDs with the `riff` foreign-metadata
/// wrapper's inner chunk, `VORBIS_COMMENT` and `PICTURE`.
public struct FLACBlocks: Equatable, Sendable {
    public enum ReadError: Error, Equatable {
        case notFLAC
        case malformed(String)
    }

    public enum BlockType: UInt8, Sendable {
        case streamInfo = 0, padding, application, seekTable, vorbisComment, cueSheet, picture
    }

    /// One metadata block: its type and its payload, without the four-byte header.
    public struct Block: Equatable, Sendable {
        public let type: UInt8
        public let payload: Data

        public init(type: UInt8, payload: Data) {
            self.type = type
            self.payload = payload
        }

        public init(_ type: BlockType, payload: Data) {
            self.init(type: type.rawValue, payload: payload)
        }

        public var blockType: BlockType? {
            BlockType(rawValue: type)
        }

        /// An `APPLICATION` block's four-character ID; nil for any other block.
        public var applicationID: String? {
            guard blockType == .application, payload.count >= 4 else { return nil }
            return RIFFChunks.fourCC(payload.prefix(4))
        }

        /// The RIFF chunk inside an `APPLICATION` block with ID `riff`. The payload is what follows
        /// the chunk header, up to the declared size: `flac --keep-foreign-metadata` stores the
        /// `RIFF` and `data` headers alone, whose sizes count bytes held elsewhere.
        public func riffChunk() throws -> RIFFChunks.Chunk? {
            guard applicationID == "riff" else { return nil }
            guard payload.count >= 12 else { throw ReadError.malformed("riff block of \(payload.count) bytes") }

            let size = Int(RIFFChunks.uint32(payload, at: 8))
            let body = payload.dropFirst(12).prefix(size)

            return RIFFChunks.Chunk(id: RIFFChunks.fourCC(payload.dropFirst(4).prefix(4)), payload: Data(body))
        }

        /// A `riff` block's declared chunk size.
        public var riffChunkSize: UInt32? {
            guard applicationID == "riff", payload.count >= 12 else { return nil }
            return RIFFChunks.uint32(payload, at: 8)
        }
    }

    /// Bytes before `fLaC`: a leading ID3v2 tag, or nothing.
    public let prefix: Data
    /// The metadata blocks in file order.
    public let blocks: [Block]
    /// Everything after the last metadata block.
    public let audio: Data

    public init(_ data: Data) throws {
        let bytes = Data(data)
        guard let start = Self.streamStart(bytes) else { throw ReadError.notFLAC }

        prefix = bytes.subdata(in: 0 ..< start)

        var blocks: [Block] = []
        var offset = start + 4
        var isLast = false

        while !isLast {
            guard offset + 4 <= bytes.count else { throw ReadError.malformed("block header at \(offset) past the end") }

            let header = bytes[offset]
            let size = Int(Self.uint24(bytes, at: offset + 1))
            guard offset + 4 + size <= bytes.count else {
                throw ReadError.malformed("block of \(size) bytes at \(offset) overruns \(bytes.count)")
            }

            blocks.append(Block(type: header & 0x7F, payload: bytes.subdata(in: offset + 4 ..< offset + 4 + size)))
            isLast = header & 0x80 != 0
            offset += 4 + size
        }

        self.blocks = blocks
        audio = bytes.subdata(in: offset ..< bytes.count)
    }

    public init(contentsOf url: URL) throws {
        try self.init(Data(contentsOf: url))
    }

    /// Whether `data` is a FLAC stream, after any leading ID3v2 tag.
    public static func isFLAC(_ data: Data) -> Bool {
        streamStart(Data(data)) != nil
    }

    public func blocks(_ type: BlockType) -> [Block] {
        blocks.filter { $0.type == type.rawValue }
    }

    // MARK: - STREAMINFO

    public var sampleRate: UInt32? {
        streamInfoBits.map { UInt32($0 >> 44) }
    }

    public var totalSamples: UInt64? {
        streamInfoBits.map { $0 & 0xF_FFFF_FFFF }
    }

    /// `STREAMINFO` bytes 10-17: rate, channels, depth and total samples.
    private var streamInfoBits: UInt64? {
        guard let info = blocks(.streamInfo).first, info.payload.count >= 18 else { return nil }
        return info.payload.dropFirst(10).prefix(8).reduce(0) { $0 << 8 | UInt64($1) }
    }

    // MARK: - VORBIS_COMMENT and PICTURE

    /// The first `VORBIS_COMMENT` block, decoded; nil when there is none.
    public func vorbisComment() throws -> VorbisComment? {
        try blocks(.vorbisComment).first.map { try VorbisComment($0.payload) }
    }

    /// Every `PICTURE` block, decoded, in file order.
    public func pictures() throws -> [Picture] {
        try blocks(.picture).map { try Picture($0.payload) }
    }

    /// A `PICTURE` block's body, which is also the decoded form of a `METADATA_BLOCK_PICTURE`
    /// comment field.
    public struct Picture: Equatable, Sendable {
        public let pictureType: UInt32
        public let mimeType: String
        public let description: String
        public let width: UInt32
        public let height: UInt32
        public let colorDepth: UInt32
        public let colorCount: UInt32
        public let data: Data

        public init(_ payload: Data) throws {
            let bytes = Data(payload)
            var offset = 0

            func uint32() throws -> UInt32 {
                guard offset + 4 <= bytes.count else { throw ReadError.malformed("PICTURE ends at \(offset)") }
                defer { offset += 4 }
                return UInt32(bytes[offset]) << 24 | UInt32(bytes[offset + 1]) << 16 | UInt32(bytes[offset + 2]) << 8 | UInt32(bytes[offset + 3])
            }

            func field() throws -> Data {
                let length = try Int(uint32())
                guard offset + length <= bytes.count else { throw ReadError.malformed("PICTURE field of \(length) bytes at \(offset)") }
                defer { offset += length }
                return bytes.subdata(in: offset ..< offset + length)
            }

            pictureType = try uint32()
            mimeType = try String(decoding: field(), as: UTF8.self)
            description = try String(decoding: field(), as: UTF8.self)
            width = try uint32()
            height = try uint32()
            colorDepth = try uint32()
            colorCount = try uint32()
            data = try field()
        }
    }

    // MARK: - Helpers

    /// The offset of `fLaC`, after a leading ID3v2 tag if there is one; nil when it is not there.
    private static func streamStart(_ bytes: Data) -> Int? {
        var start = 0

        if bytes.count >= 10, bytes.prefix(3) == Data("ID3".utf8) {
            let size = (6 ..< 10).reduce(0) { $0 << 7 | Int(bytes[$1] & 0x7F) }
            start = 10 + size + (bytes[5] & 0x10 != 0 ? 10 : 0)
        }

        guard bytes.count >= start + 4, bytes.subdata(in: start ..< start + 4) == Data("fLaC".utf8) else { return nil }
        return start
    }

    private static func uint24(_ data: Data, at offset: Int) -> UInt32 {
        data.dropFirst(offset).prefix(3).reduce(0) { $0 << 8 | UInt32($1) }
    }
}

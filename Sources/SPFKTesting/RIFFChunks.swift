// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-testing

import Foundation

/// A little-endian RIFF file's chunks, read without any metadata library: the top-level list,
/// `LIST` sub-chunks, `INFO` items, `cue ` points, `adtl` labels and the `bext` fixed layout.
///
/// Refuses RF64 and BW64, whose 64-bit sizes live in `ds64`, rather than misreading them.
public struct RIFFChunks: Equatable, Sendable {
    public enum ReadError: Error, Equatable {
        case notRIFF
        /// RF64 and BW64 carry their sizes in `ds64`, which this reader does not read.
        case unsupportedForm(String)
        case malformed(String)
    }

    /// One chunk: its four-character ID and its payload, without the pad byte.
    public struct Chunk: Equatable, Sendable {
        public let id: String
        public let payload: Data

        public init(id: String, payload: Data) {
            self.id = id
            self.payload = payload
        }

        /// A `LIST` chunk's type (`INFO`, `adtl`); nil for any other chunk.
        public var listType: String? {
            guard id == "LIST", payload.count >= 4 else { return nil }
            return RIFFChunks.fourCC(payload.prefix(4))
        }

        /// A `LIST` chunk's sub-chunks, in order.
        public func subchunks() throws -> [Chunk] {
            guard listType != nil else { throw ReadError.malformed("\(id) is not a LIST") }
            return try RIFFChunks.chunks(in: Data(payload.dropFirst(4)))
        }
    }

    /// The form type after `RIFF`'s size: `WAVE`, `AVI `.
    public let formType: String
    /// The top-level chunks, in file order.
    public let chunks: [Chunk]

    public init(_ data: Data) throws {
        guard data.count >= 12 else { throw ReadError.notRIFF }

        let magic = Self.fourCC(data.prefix(4))
        if magic == "RF64" || magic == "BW64" { throw ReadError.unsupportedForm(magic) }
        guard magic == "RIFF" else { throw ReadError.notRIFF }

        formType = Self.fourCC(data.dropFirst(8).prefix(4))
        chunks = try Self.chunks(in: Data(data.dropFirst(12)))
    }

    public init(contentsOf url: URL) throws {
        try self.init(Data(contentsOf: url))
    }

    /// The first top-level chunk with this ID.
    public func first(_ id: String) -> Chunk? {
        chunks.first { $0.id == id }
    }

    /// The first `LIST` chunk of this type.
    public func list(_ type: String) -> Chunk? {
        chunks.first { $0.listType == type }
    }

    /// `fmt `'s sample rate.
    public var sampleRate: UInt32? {
        guard let format = first("fmt "), format.payload.count >= 8 else { return nil }
        return Self.uint32(format.payload, at: 4)
    }

    // MARK: - INFO

    /// The `LIST`/`INFO` items in order, each value up to its first NUL, decoded as UTF-8 where
    /// valid and as Latin-1 otherwise.
    public func infoItems() throws -> [(id: String, value: String)] {
        guard let info = list("INFO") else { return [] }
        return try info.subchunks().map { ($0.id, Self.text($0.payload)) }
    }

    // MARK: - Markers

    /// One `cue ` point.
    public struct CuePoint: Equatable, Sendable {
        public let id: UInt32
        public let position: UInt32
        public let chunkID: String
        public let chunkStart: UInt32
        public let blockStart: UInt32
        public let sampleOffset: UInt32
    }

    /// The `cue ` chunk's points in stored order; empty when there is no chunk.
    public func cuePoints() throws -> [CuePoint] {
        guard let cue = first("cue ") else { return [] }
        let payload = cue.payload
        guard payload.count >= 4 else { throw ReadError.malformed("cue of \(payload.count) bytes") }

        let count = Int(Self.uint32(payload, at: 0))
        guard payload.count >= 4 + count * 24 else { throw ReadError.malformed("cue declares \(count) points in \(payload.count) bytes") }

        return (0 ..< count).map { index in
            let offset = 4 + index * 24
            return CuePoint(
                id: Self.uint32(payload, at: offset),
                position: Self.uint32(payload, at: offset + 4),
                chunkID: Self.fourCC(payload.dropFirst(offset + 8).prefix(4)),
                chunkStart: Self.uint32(payload, at: offset + 12),
                blockStart: Self.uint32(payload, at: offset + 16),
                sampleOffset: Self.uint32(payload, at: offset + 20)
            )
        }
    }

    /// The first `LIST`/`adtl`'s sub-chunks, in order; empty when there is none.
    public func associatedData() throws -> [Chunk] {
        try list("adtl")?.subchunks() ?? []
    }

    /// `labl` text keyed by cue point ID.
    public func labels() throws -> [UInt32: String] {
        var labels: [UInt32: String] = [:]

        for chunk in try associatedData() where chunk.id == "labl" {
            guard chunk.payload.count >= 4 else { throw ReadError.malformed("labl of \(chunk.payload.count) bytes") }
            labels[Self.uint32(chunk.payload, at: 0)] = Self.text(chunk.payload.dropFirst(4))
        }

        return labels
    }

    // MARK: - Helpers

    /// Stops at a chunk that overruns `data`.
    static func chunks(in data: Data) throws -> [Chunk] {
        var chunks: [Chunk] = []
        var offset = 0

        while offset + 8 <= data.count {
            let id = fourCC(data.dropFirst(offset).prefix(4))
            let size = Int(uint32(data, at: offset + 4))
            let body = offset + 8

            guard body + size <= data.count else {
                throw ReadError.malformed("chunk \(id) of \(size) bytes at \(offset) overruns \(data.count)")
            }

            chunks.append(Chunk(id: id, payload: data.subdata(in: data.startIndex + body ..< data.startIndex + body + size)))
            offset = body + size + (size & 1)
        }

        return chunks
    }

    static func fourCC(_ bytes: Data) -> String {
        String(bytes.map { Character(Unicode.Scalar($0)) })
    }

    static func uint32(_ data: Data, at offset: Int) -> UInt32 {
        data.dropFirst(offset).prefix(4).reversed().reduce(0) { $0 << 8 | UInt32($1) }
    }

    static func uint16(_ data: Data, at offset: Int) -> UInt16 {
        data.dropFirst(offset).prefix(2).reversed().reduce(0) { $0 << 8 | UInt16($1) }
    }

    /// Up to the first NUL; UTF-8 where valid, else Latin-1.
    static func text(_ bytes: Data) -> String {
        let end = bytes.firstIndex(of: 0) ?? bytes.endIndex
        let field = Data(bytes[bytes.startIndex ..< end])
        return String(data: field, encoding: .utf8) ?? String(field.map { Character(Unicode.Scalar($0)) })
    }
}

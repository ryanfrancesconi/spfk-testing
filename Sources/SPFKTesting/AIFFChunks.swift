// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-testing

import Foundation

/// An AIFF or AIFF-C file's chunks, read without any metadata library: the big-endian `FORM`
/// list, `COMM`'s sample rate, `MARK` markers, `COMT` comments, `APPL` chunks and the text chunks.
public struct AIFFChunks: Equatable, Sendable {
    public typealias Chunk = RIFFChunks.Chunk
    public typealias ReadError = RIFFChunks.ReadError

    /// The form type after `FORM`'s size: `AIFF` or `AIFC`.
    public let formType: String
    /// The top-level chunks, in file order.
    public let chunks: [Chunk]

    public init(_ data: Data) throws {
        guard data.count >= 12, RIFFChunks.fourCC(data.prefix(4)) == "FORM" else { throw ReadError.notRIFF }

        formType = RIFFChunks.fourCC(data.dropFirst(8).prefix(4))
        chunks = try Self.chunks(in: Data(data.dropFirst(12)))
    }

    public init(contentsOf url: URL) throws {
        try self.init(Data(contentsOf: url))
    }

    /// The first top-level chunk with this ID.
    public func first(_ id: String) -> Chunk? {
        chunks.first { $0.id == id }
    }

    /// `COMM`'s sample rate, decoded from its 80-bit extended float.
    public var sampleRate: Double? {
        guard let comm = first("COMM"), comm.payload.count >= 18 else { return nil }

        let bytes = Data(comm.payload)
        let exponent = Int(Self.uint16(bytes, at: 8) & 0x7FFF)
        let mantissa = bytes.subdata(in: 10 ..< 18).reduce(UInt64(0)) { $0 << 8 | UInt64($1) }
        guard exponent != 0 || mantissa != 0 else { return 0 }

        return Double(mantissa) * pow(2, Double(exponent - 16383 - 63))
    }

    // MARK: - Markers and comments

    /// One `MARK` marker.
    public struct Marker: Equatable, Sendable {
        public let id: UInt16
        public let position: UInt32
        public let name: String

        public init(id: UInt16, position: UInt32, name: String) {
            self.id = id
            self.position = position
            self.name = name
        }
    }

    /// The `MARK` chunk's markers in stored order; empty when there is no chunk.
    public func markers() throws -> [Marker] {
        guard let mark = first("MARK") else { return [] }

        let payload = Data(mark.payload)
        guard payload.count >= 2 else { throw ReadError.malformed("MARK of \(payload.count) bytes") }

        var markers: [Marker] = []
        var offset = 2

        for _ in 0 ..< Self.uint16(payload, at: 0) {
            guard offset + 7 <= payload.count else { throw ReadError.malformed("MARK overruns at marker \(markers.count)") }

            let length = Int(payload[offset + 6])
            guard offset + 7 + length <= payload.count else { throw ReadError.malformed("MARK name overruns at marker \(markers.count)") }

            markers.append(Marker(
                id: Self.uint16(payload, at: offset),
                position: Self.uint32(payload, at: offset + 2),
                name: Self.text(payload.subdata(in: offset + 7 ..< offset + 7 + length))
            ))

            // A Pascal string padded to an even length, count byte included.
            offset += 6 + 1 + length + ((1 + length) & 1)
        }

        return markers
    }

    /// One `COMT` comment.
    public struct Comment: Equatable, Sendable {
        public let timeStamp: UInt32
        public let markerID: UInt16
        public let text: String

        public init(timeStamp: UInt32, markerID: UInt16, text: String) {
            self.timeStamp = timeStamp
            self.markerID = markerID
            self.text = text
        }
    }

    /// The `COMT` chunk's comments in stored order; empty when there is no chunk.
    public func comments() throws -> [Comment] {
        guard let comt = first("COMT") else { return [] }

        let payload = Data(comt.payload)
        guard payload.count >= 2 else { throw ReadError.malformed("COMT of \(payload.count) bytes") }

        var comments: [Comment] = []
        var offset = 2

        for _ in 0 ..< Self.uint16(payload, at: 0) {
            guard offset + 8 <= payload.count else { throw ReadError.malformed("COMT overruns at comment \(comments.count)") }

            let length = Int(Self.uint16(payload, at: offset + 6))
            guard offset + 8 + length <= payload.count else { throw ReadError.malformed("COMT text overruns at comment \(comments.count)") }

            comments.append(Comment(
                timeStamp: Self.uint32(payload, at: offset),
                markerID: Self.uint16(payload, at: offset + 4),
                text: Self.text(payload.subdata(in: offset + 8 ..< offset + 8 + length))
            ))

            offset += 8 + length + (length & 1)
        }

        return comments
    }

    // MARK: - Application and text chunks

    /// Each `APPL` chunk as its four-character signature and the bytes after it.
    public func applications() -> [(signature: String, data: Data)] {
        chunks.filter { $0.id == "APPL" && $0.payload.count >= 4 }.map {
            (RIFFChunks.fourCC($0.payload.prefix(4)), Data($0.payload.dropFirst(4)))
        }
    }

    /// A text chunk's (`NAME`, `AUTH`, `ANNO`, `(c) `) value, up to any NUL; nil when absent.
    public func text(_ id: String) -> String? {
        first(id).map { Self.text($0.payload) }
    }

    // MARK: - Helpers

    /// Throws at a chunk that overruns `data`.
    static func chunks(in data: Data) throws -> [Chunk] {
        var chunks: [Chunk] = []
        var offset = 0

        while offset + 8 <= data.count {
            let id = RIFFChunks.fourCC(data.dropFirst(offset).prefix(4))
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

    static func uint32(_ data: Data, at offset: Int) -> UInt32 {
        data.dropFirst(offset).prefix(4).reduce(0) { $0 << 8 | UInt32($1) }
    }

    static func uint16(_ data: Data, at offset: Int) -> UInt16 {
        data.dropFirst(offset).prefix(2).reduce(0) { $0 << 8 | UInt16($1) }
    }

    /// Up to the first NUL; UTF-8 where valid, else Mac OS Roman, AIFF's own encoding.
    static func text(_ bytes: Data) -> String {
        let end = bytes.firstIndex(of: 0) ?? bytes.endIndex
        let field = Data(bytes[bytes.startIndex ..< end])
        return String(data: field, encoding: .utf8) ?? String(data: field, encoding: .macOSRoman) ?? ""
    }
}

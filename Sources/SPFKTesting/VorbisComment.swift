// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-testing

import Foundation

/// A Vorbis comment as stored in FLAC's `VORBIS_COMMENT` block and Ogg's comment header: the
/// vendor string and every field in stored order, duplicates and key case kept.
public struct VorbisComment: Equatable, Sendable {
    public struct Field: Equatable, Sendable {
        public let key: String
        public let value: String

        public init(key: String, value: String) {
            self.key = key
            self.value = value
        }
    }

    public let vendor: String
    public let fields: [Field]

    /// Little-endian lengths throughout. A trailing Ogg framing bit is ignored.
    public init(_ payload: Data) throws {
        let bytes = Data(payload)
        var offset = 0

        func length() throws -> Int {
            guard offset + 4 <= bytes.count else { throw FLACBlocks.ReadError.malformed("comment ends at \(offset)") }
            defer { offset += 4 }
            return Int(RIFFChunks.uint32(bytes, at: offset))
        }

        func string() throws -> String {
            let count = try length()
            guard offset + count <= bytes.count else { throw FLACBlocks.ReadError.malformed("comment string of \(count) bytes at \(offset)") }
            defer { offset += count }
            return String(decoding: bytes.subdata(in: offset ..< offset + count), as: UTF8.self)
        }

        vendor = try string()

        let count = try length()
        fields = try (0 ..< count).map { _ in
            let field = try string()
            guard let equals = field.firstIndex(of: "=") else { throw FLACBlocks.ReadError.malformed("field without '=': \(field)") }
            return Field(key: String(field[..<equals]), value: String(field[field.index(after: equals)...]))
        }
    }

    /// The values of every field named `key`, in stored order. Names compare case-insensitively,
    /// as the specification makes them.
    public func values(_ key: String) -> [String] {
        fields.filter { $0.key.caseInsensitiveCompare(key) == .orderedSame }.map(\.value)
    }
}

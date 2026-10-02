// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-testing

import Foundation

/// Typed decoders for the frame bodies the metadata safety net compares. Each throws
/// ``ID3v2Frames/ReadError/malformed(_:)`` on a body too short for its layout.
extension ID3v2Frames {
    /// The text encoding byte that leads most frame bodies.
    public enum TextEncoding: UInt8, Sendable {
        case latin1 = 0
        /// Each string carries its own byte-order mark.
        case utf16 = 1
        case utf16BE = 2
        case utf8 = 3

        var terminatorLength: Int {
            self == .latin1 || self == .utf8 ? 1 : 2
        }
    }

    /// The values of a text frame (`T***` other than `TXXX`); a v2.4 list is NUL-separated.
    public static func textValues(_ body: Data) throws -> [String] {
        var reader = try BodyReader(body)
        let encoding = try reader.encoding()
        return reader.values(encoding)
    }

    /// `TXXX`.
    public struct UserText: Equatable, Sendable {
        public let description: String
        public let values: [String]

        public init(_ body: Data) throws {
            var reader = try BodyReader(body)
            let encoding = try reader.encoding()
            description = try reader.terminated(encoding)
            values = reader.values(encoding)
        }
    }

    /// `COMM` and `USLT`, which share a layout.
    public struct Comment: Equatable, Sendable {
        public let language: String
        public let description: String
        public let text: String

        public init(_ body: Data) throws {
            var reader = try BodyReader(body)
            let encoding = try reader.encoding()
            language = try BodyReader.latin1(reader.take(3))
            description = try reader.terminated(encoding)
            text = reader.values(encoding).first ?? ""
        }
    }

    /// `WXXX`.
    public struct UserURL: Equatable, Sendable {
        public let description: String
        public let url: String

        public init(_ body: Data) throws {
            var reader = try BodyReader(body)
            let encoding = try reader.encoding()
            description = try reader.terminated(encoding)
            url = reader.values(.latin1).first ?? ""
        }
    }

    /// `POPM`. `counter` is nil when the frame omits it.
    public struct Popularimeter: Equatable, Sendable {
        public let email: String
        public let rating: UInt8
        public let counter: UInt64?

        public init(_ body: Data) throws {
            var reader = try BodyReader(body)
            email = try reader.terminated(.latin1)
            rating = try reader.take(1)[0]
            let rest = reader.rest
            counter = rest.isEmpty ? nil : rest.reduce(0) { $0 << 8 | UInt64($1) }
        }
    }

    /// `PCNT`.
    public static func playCount(_ body: Data) throws -> UInt64 {
        guard (4 ... 8).contains(body.count) else { throw ReadError.malformed("PCNT of \(body.count) bytes") }
        return body.reduce(0) { $0 << 8 | UInt64($1) }
    }

    /// `PRIV` and `UFID`, which share a layout: a Latin-1 owner, then binary data.
    public struct OwnedData: Equatable, Sendable {
        public let owner: String
        public let data: Data

        public init(_ body: Data) throws {
            var reader = try BodyReader(body)
            owner = try reader.terminated(.latin1)
            data = reader.rest
        }
    }

    /// `GEOB`.
    public struct GeneralObject: Equatable, Sendable {
        public let mimeType: String
        public let fileName: String
        public let description: String
        public let object: Data

        public init(_ body: Data) throws {
            var reader = try BodyReader(body)
            let encoding = try reader.encoding()
            mimeType = try reader.terminated(.latin1)
            fileName = try reader.terminated(encoding)
            description = try reader.terminated(encoding)
            object = reader.rest
        }
    }

    /// `APIC`.
    public struct Picture: Equatable, Sendable {
        public let mimeType: String
        public let pictureType: UInt8
        public let description: String
        public let data: Data

        public init(_ body: Data) throws {
            var reader = try BodyReader(body)
            let encoding = try reader.encoding()
            mimeType = try reader.terminated(.latin1)
            pictureType = try reader.take(1)[0]
            description = try reader.terminated(encoding)
            data = reader.rest
        }
    }

    /// `CHAP`. Times in milliseconds; offsets are `0xFFFFFFFF` when unused.
    public struct Chapter: Equatable, Sendable {
        public let elementID: String
        public let startTime: UInt32
        public let endTime: UInt32
        public let startOffset: UInt32
        public let endOffset: UInt32
        public let subframes: [Frame]

        public init(_ body: Data, majorVersion: UInt8) throws {
            var reader = try BodyReader(body)
            elementID = try reader.terminated(.latin1)
            startTime = try reader.uint32()
            endTime = try reader.uint32()
            startOffset = try reader.uint32()
            endOffset = try reader.uint32()
            subframes = try ID3v2Frames.frames(inFrameData: reader.rest, majorVersion: majorVersion)
        }

        /// The first embedded `TIT2`'s first value.
        public var title: String? {
            subframes.first { $0.id == "TIT2" }.flatMap { try? ID3v2Frames.textValues($0.body).first }
        }
    }

    /// `CTOC`.
    public struct TableOfContents: Equatable, Sendable {
        public let elementID: String
        public let isTopLevel: Bool
        public let isOrdered: Bool
        public let children: [String]
        public let subframes: [Frame]

        public init(_ body: Data, majorVersion: UInt8) throws {
            var reader = try BodyReader(body)
            elementID = try reader.terminated(.latin1)
            let flags = try reader.take(1)[0]
            isTopLevel = flags & 0x02 != 0
            isOrdered = flags & 0x01 != 0
            let count = try reader.take(1)[0]
            children = try (0 ..< count).map { _ in try reader.terminated(.latin1) }
            subframes = try ID3v2Frames.frames(inFrameData: reader.rest, majorVersion: majorVersion)
        }
    }
}

// MARK: - Body reader

/// A cursor over a frame body.
struct BodyReader {
    private let bytes: [UInt8]
    private var offset = 0

    init(_ body: Data) throws {
        bytes = [UInt8](body)
    }

    var rest: Data {
        Data(bytes[offset...])
    }

    mutating func take(_ count: Int) throws -> [UInt8] {
        guard offset + count <= bytes.count else {
            throw ID3v2Frames.ReadError.malformed("body of \(bytes.count) bytes ends before \(offset + count)")
        }
        defer { offset += count }
        return Array(bytes[offset ..< offset + count])
    }

    mutating func uint32() throws -> UInt32 {
        try take(4).reduce(0) { $0 << 8 | UInt32($1) }
    }

    mutating func encoding() throws -> ID3v2Frames.TextEncoding {
        let byte = try take(1)[0]
        guard let encoding = ID3v2Frames.TextEncoding(rawValue: byte) else {
            throw ID3v2Frames.ReadError.malformed("text encoding \(byte)")
        }
        return encoding
    }

    /// A string up to its terminator, which is consumed.
    mutating func terminated(_ encoding: ID3v2Frames.TextEncoding) throws -> String {
        let width = encoding.terminatorLength
        var end = offset

        while end + width <= bytes.count, !bytes[end ..< end + width].allSatisfy({ $0 == 0 }) {
            end += width
        }

        guard end + width <= bytes.count else {
            throw ID3v2Frames.ReadError.malformed("unterminated string at \(offset)")
        }

        defer { offset = end + width }
        return Self.decode(Array(bytes[offset ..< end]), encoding)
    }

    /// The remaining bytes as terminator-separated values, empty values dropped.
    mutating func values(_ encoding: ID3v2Frames.TextEncoding) -> [String] {
        let width = encoding.terminatorLength
        var values: [String] = []
        var bom: [UInt8]?
        var start = offset
        var index = offset

        func flush(_ end: Int) {
            var piece = Array(bytes[start ..< end])
            if encoding == .utf16, piece.count >= 2 {
                if piece.starts(with: [0xFF, 0xFE]) || piece.starts(with: [0xFE, 0xFF]) {
                    bom = Array(piece.prefix(2))
                } else if let bom {
                    piece = bom + piece
                }
            }
            let value = Self.decode(piece, encoding)
            if !value.isEmpty { values.append(value) }
        }

        while index + width <= bytes.count {
            if bytes[index ..< index + width].allSatisfy({ $0 == 0 }) {
                flush(index)
                start = index + width
            }
            index += width
        }

        if start < bytes.count { flush(bytes.count) }
        offset = bytes.count
        return values
    }

    static func latin1(_ bytes: [UInt8]) -> String {
        String(bytes.map { Character(Unicode.Scalar($0)) })
    }

    static func decode(_ bytes: [UInt8], _ encoding: ID3v2Frames.TextEncoding) -> String {
        switch encoding {
        case .latin1:
            return latin1(bytes)

        case .utf8:
            return String(decoding: bytes, as: UTF8.self)

        case .utf16, .utf16BE:
            var body = bytes[...]
            var littleEndian = false

            if encoding == .utf16, body.starts(with: [0xFF, 0xFE]) {
                littleEndian = true
                body = body.dropFirst(2)
            } else if encoding == .utf16, body.starts(with: [0xFE, 0xFF]) {
                body = body.dropFirst(2)
            }

            let pairs = Array(body)
            let units = stride(from: 0, to: pairs.count - 1, by: 2).map { i in
                littleEndian
                    ? UInt16(pairs[i]) | UInt16(pairs[i + 1]) << 8
                    : UInt16(pairs[i]) << 8 | UInt16(pairs[i + 1])
            }
            return String(decoding: units, as: UTF16.self)
        }
    }
}

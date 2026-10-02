// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-testing

import Foundation

extension ID3v2Frames {
    /// A tag this reader declines rather than misreading.
    public enum ReadError: Error, Equatable {
        /// Only ID3v2.3 and ID3v2.4 are read.
        case unsupportedVersion(UInt8)
        case extendedHeader
        /// Set on the tag, or on a v2.4 frame.
        case unsynchronisation
        case malformed(String)
    }

    /// One frame: its four-character ID, the two flag bytes as stored, and its body.
    public struct Frame: Equatable, Sendable {
        public let id: String
        public let flags: Data
        public let body: Data

        public init(id: String, flags: Data = Data([0, 0]), body: Data) {
            self.id = id
            self.flags = flags
            self.body = body
        }
    }

    /// A leading ID3v2 tag: its major version and frames in tag order.
    public struct Tag: Equatable, Sendable {
        public let majorVersion: UInt8
        public let frames: [Frame]

        /// The frames with this ID, in tag order.
        public func frames(_ id: String) -> [Frame] {
            frames.filter { $0.id == id }
        }
    }

    /// The tag at the start of `data`, or nil when `data` does not start with one.
    public static func tag(in data: Data) throws -> Tag? {
        let bytes = [UInt8](data)
        guard bytes.count >= 10, bytes.starts(with: Array("ID3".utf8)) else { return nil }

        let version = bytes[3]
        guard version == 3 || version == 4 else { throw ReadError.unsupportedVersion(version) }

        let flags = bytes[5]
        if flags & 0x80 != 0 { throw ReadError.unsynchronisation }
        if flags & 0x40 != 0 { throw ReadError.extendedHeader }

        let tagEnd = try 10 + syncsafe(bytes, at: 6)
        guard tagEnd <= bytes.count else { throw ReadError.malformed("tag size \(tagEnd - 10) overruns the file") }

        return try Tag(majorVersion: version, frames: frames(in: bytes, range: 10 ..< tagEnd, majorVersion: version))
    }

    public static func tag(in url: URL) throws -> Tag? {
        try tag(in: Data(contentsOf: url))
    }

    /// Every frame of the tag at the start of `data`, in tag order; empty when there is no tag.
    public static func frames(in data: Data) throws -> [(id: String, body: Data)] {
        try tag(in: data)?.frames.map { ($0.id, $0.body) } ?? []
    }

    /// The leading tag's major version, or nil when the file has none.
    public static func majorVersion(in url: URL) throws -> UInt8? {
        let data = try Data(contentsOf: url)
        guard data.count >= 4, data.starts(with: Data("ID3".utf8)) else { return nil }
        return data[data.startIndex + 3]
    }

    /// The frames in `data`, which holds frames only: a `CHAP` or `CTOC` body's sub-frames.
    public static func frames(inFrameData data: Data, majorVersion: UInt8) throws -> [Frame] {
        try frames(in: [UInt8](data), range: 0 ..< data.count, majorVersion: majorVersion)
    }

    /// Stops at padding (a zero byte where a frame ID would start).
    static func frames(in bytes: [UInt8], range: Range<Int>, majorVersion: UInt8) throws -> [Frame] {
        var frames: [Frame] = []
        var offset = range.lowerBound

        while offset + 10 <= range.upperBound, bytes[offset] != 0 {
            let idBytes = bytes[offset ..< offset + 4]
            guard idBytes.allSatisfy({ (0x41 ... 0x5A).contains($0) || (0x30 ... 0x39).contains($0) }) else {
                throw ReadError.malformed("frame ID \(idBytes.map { String(format: "%02x", $0) }.joined()) at \(offset)")
            }

            let size = majorVersion >= 4 ? try syncsafe(bytes, at: offset + 4) : bigEndian(bytes, at: offset + 4, count: 4)
            let flags = Data(bytes[offset + 8 ..< offset + 10])
            if majorVersion >= 4, flags[flags.startIndex + 1] & 0x02 != 0 { throw ReadError.unsynchronisation }

            let body = offset + 10
            guard body + size <= range.upperBound else {
                throw ReadError.malformed("frame \(String(decoding: idBytes, as: UTF8.self)) of \(size) bytes overruns the tag")
            }

            frames.append(Frame(id: String(decoding: idBytes, as: UTF8.self), flags: flags, body: Data(bytes[body ..< body + size])))
            offset = body + size
        }

        return frames
    }

    static func syncsafe(_ bytes: [UInt8], at offset: Int) throws -> Int {
        let field = bytes[offset ..< offset + 4]
        guard field.allSatisfy({ $0 & 0x80 == 0 }) else { throw ReadError.malformed("size at \(offset) is not syncsafe") }
        return field.reduce(0) { $0 << 7 | Int($1) }
    }

    static func bigEndian(_ bytes: [UInt8], at offset: Int, count: Int) -> Int {
        bytes[offset ..< offset + count].reduce(0) { $0 << 8 | Int($1) }
    }
}

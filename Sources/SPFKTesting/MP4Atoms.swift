// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-testing

import Foundation

/// An MP4 or QuickTime file's atom tree, read without any metadata library: 32- and 64-bit sizes,
/// `meta` as a full box, `moov/udta/meta/ilst` items with their `data` atoms and freeform
/// `mean`/`name`, the `covr` list, Nero `chpl` chapters and `tref/chap` references.
public struct MP4Atoms: Equatable, Sendable {
    public enum ReadError: Error, Equatable {
        case malformed(String)
    }

    /// One atom. Types are Latin-1, so `0xA9` reads as `©`.
    public struct Box: Equatable, Sendable {
        public let type: String
        /// The offset of the atom's size field in the file.
        public let offset: Int
        /// The whole atom, header included.
        public let size: Int
        /// 8, or 16 for a 64-bit size.
        public let headerSize: Int
        /// Everything after the header; for a full-box `meta`, the version and flags included.
        public let payload: Data
        /// Parsed only for container atoms; empty for every other.
        public let children: [Box]

        public func child(_ type: String) -> Box? {
            children.first { $0.type == type }
        }

        public func children(_ type: String) -> [Box] {
            children.filter { $0.type == type }
        }

        /// The atom bytes as stored, header included.
        public var bytes: Data {
            MP4Atoms.header(type: type, size: size, headerSize: headerSize) + payload
        }
    }

    /// An `ilst` `data` atom.
    public struct DataAtom: Equatable, Sendable {
        /// The type indicator: 1 UTF-8, 13 JPEG, 14 PNG, 21 signed integer, 0 implicit.
        public let type: UInt32
        public let locale: UInt32
        public let value: Data

        public init(type: UInt32, locale: UInt32 = 0, value: Data) {
            self.type = type
            self.locale = locale
            self.value = value
        }

        /// The value as text: UTF-8 for type 1, a decimal for type 21, hex otherwise.
        public var text: String {
            switch type {
            case 1: return String(decoding: value, as: UTF8.self)
            case 21: return String(signedValue)
            default: return value.map { String(format: "%02x", $0) }.joined()
            }
        }

        /// A big-endian two's-complement integer of up to eight bytes.
        private var signedValue: Int64 {
            let unsigned = value.prefix(8).reduce(UInt64(0)) { $0 << 8 | UInt64($1) }
            let width = min(value.count, 8) * 8
            guard width > 0, width < 64, unsigned & (1 << (width - 1)) != 0 else { return Int64(bitPattern: unsigned) }
            return Int64(bitPattern: unsigned) - (Int64(1) << width)
        }
    }

    /// An `ilst` item. `key` is the atom type, or `----:<mean>:<name>` for a freeform atom.
    public struct Item: Equatable, Sendable {
        public let key: String
        public let values: [DataAtom]
    }

    /// One Nero `chpl` entry. Start is in 100-nanosecond units.
    public struct NeroChapter: Equatable, Sendable {
        public let start: UInt64
        public let title: String
    }

    /// The top-level atoms in file order.
    public let boxes: [Box]

    private static let containers: Set<String> = ["moov", "trak", "mdia", "minf", "stbl", "udta", "edts", "dinf", "tref", "ilst"]

    public init(_ data: Data) throws {
        boxes = try Self.children(Data(data), in: 0 ..< data.count, parent: nil)
    }

    public init(contentsOf url: URL) throws {
        try self.init(Data(contentsOf: url))
    }

    /// The first atom along `path` from the top level, e.g. `["moov", "udta", "chpl"]`.
    public func box(_ path: [String]) -> Box? {
        guard let first = path.first, var box = boxes.first(where: { $0.type == first }) else { return nil }

        for type in path.dropFirst() {
            guard let next = box.child(type) else { return nil }
            box = next
        }

        return box
    }

    /// Every top-level atom of `type`, in file order.
    public func boxes(_ type: String) -> [Box] {
        boxes.filter { $0.type == type }
    }

    // MARK: - ilst

    /// `moov/udta/meta/ilst`'s items in stored order; empty when there is no item list.
    public func items() throws -> [Item] {
        guard let ilst = box(["moov", "udta", "meta", "ilst"]) else { return [] }

        return try ilst.children.map { item in
            let values = try item.children("data").map { data in
                guard data.payload.count >= 8 else { throw ReadError.malformed("data atom of \(data.size) bytes at \(data.offset)") }
                return DataAtom(type: Self.uint32(data.payload, at: 0), locale: Self.uint32(data.payload, at: 4), value: Data(data.payload.dropFirst(8)))
            }

            guard item.type == "----" else { return Item(key: item.type, values: values) }

            func string(_ type: String) -> String {
                item.child(type).map { String(decoding: $0.payload.dropFirst(4), as: UTF8.self) } ?? ""
            }

            return Item(key: "----:\(string("mean")):\(string("name"))", values: values)
        }
    }

    /// Every item stored under `key`, in order.
    public func items(_ key: String) throws -> [Item] {
        try items().filter { $0.key == key }
    }

    /// The `covr` item's images, in stored order.
    public func covers() throws -> [DataAtom] {
        try items("covr").flatMap(\.values)
    }

    // MARK: - Chapters

    /// `moov/udta/chpl`'s entries; nil when there is no `chpl`.
    public func neroChapters() throws -> [NeroChapter]? {
        guard let chpl = box(["moov", "udta", "chpl"]) else { return nil }
        let payload = Data(chpl.payload)

        // Version, flags, and in version 1 four reserved bytes, then a one-byte count.
        var offset = payload.first == 1 ? 8 : 4
        guard offset < payload.count else { throw ReadError.malformed("chpl of \(payload.count) bytes") }

        let count = Int(payload[offset])
        offset += 1

        return try (0 ..< count).map { _ in
            guard offset + 9 <= payload.count else { throw ReadError.malformed("chpl entry at \(offset)") }
            let start = payload[offset ..< offset + 8].reduce(UInt64(0)) { $0 << 8 | UInt64($1) }
            let length = Int(payload[offset + 8])
            guard offset + 9 + length <= payload.count else { throw ReadError.malformed("chpl title at \(offset)") }
            defer { offset += 9 + length }
            return NeroChapter(start: start, title: String(decoding: payload[offset + 9 ..< offset + 9 + length], as: UTF8.self))
        }
    }

    /// The track IDs each track's `tref/chap` names, by track order; empty where a track has none.
    public func chapterReferences() -> [[UInt32]] {
        guard let moov = box(["moov"]) else { return [] }

        return moov.children("trak").map { trak in
            guard let chap = trak.child("tref")?.child("chap") else { return [] }
            return stride(from: 0, to: chap.payload.count - 3, by: 4).map { Self.uint32(chap.payload, at: $0) }
        }
    }

    // MARK: - Parsing

    private static func children(_ data: Data, in range: Range<Int>, parent: String?) throws -> [Box] {
        var boxes: [Box] = []
        var offset = range.lowerBound

        while offset + 8 <= range.upperBound {
            var size = Int(uint32(data, at: offset))
            var headerSize = 8

            if size == 1 {
                guard offset + 16 <= range.upperBound else { throw ReadError.malformed("64-bit size at \(offset) past the end") }
                size = Int(data[offset + 8 ..< offset + 16].reduce(UInt64(0)) { $0 << 8 | UInt64($1) })
                headerSize = 16
            } else if size == 0, parent == nil {
                size = range.upperBound - offset
            }

            guard size >= headerSize, offset + size <= range.upperBound else {
                throw ReadError.malformed("atom of \(size) bytes at \(offset) overruns \(range.upperBound)")
            }

            let type = String(data[offset + 4 ..< offset + 8].map { Character(Unicode.Scalar($0)) })
            let body = offset + headerSize ..< offset + size
            var children: [Box] = []

            if containers.contains(type) || parent == "ilst" {
                children = try Self.children(data, in: body, parent: type)
            } else if type == "meta" {
                // ISO `meta` is a full box; QuickTime's is a plain container whose first child is `hdlr`.
                let isQuickTime = body.count >= 8 && data[body.lowerBound + 4 ..< body.lowerBound + 8] == Data("hdlr".utf8)
                children = try Self.children(data, in: (isQuickTime ? body.lowerBound : body.lowerBound + 4) ..< body.upperBound, parent: type)
            }

            boxes.append(Box(type: type, offset: offset, size: size, headerSize: headerSize, payload: data.subdata(in: body), children: children))
            offset += size
        }

        // Fewer than eight bytes cannot be an atom: QuickTime ends `udta` with a zero terminator.
        return boxes
    }

    static func header(type: String, size: Int, headerSize: Int) -> Data {
        let typeBytes = Data(type.unicodeScalars.map { UInt8(truncatingIfNeeded: $0.value) })
        guard headerSize == 16 else { return be(UInt64(size), bytes: 4) + typeBytes }
        return be(1, bytes: 4) + typeBytes + be(UInt64(size), bytes: 8)
    }

    static func be(_ value: UInt64, bytes: Int) -> Data {
        Data((0 ..< bytes).reversed().map { UInt8(truncatingIfNeeded: value >> (UInt64($0) * 8)) })
    }

    static func uint32(_ data: Data, at offset: Int) -> UInt32 {
        data.dropFirst(offset).prefix(4).reduce(0) { $0 << 8 | UInt32($1) }
    }
}

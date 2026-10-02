// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-testing

import Foundation

/// RIFF (little-endian sizes) or IFF/AIFF (big-endian) top-level chunks, read and written
/// without any metadata library.
public enum IFFChunks {
    /// Appends a chunk at the end of the file and updates the container size.
    public static func append(id: String, payload: Data, to url: URL, bigEndian: Bool) throws {
        var data = try Data(contentsOf: url)
        data.append(Data(id.utf8))
        data.append(encode(UInt32(payload.count), bigEndian: bigEndian))
        data.append(payload)
        if payload.count.isMultiple(of: 2) == false { data.append(0) }
        data.replaceSubrange(4 ..< 8, with: encode(UInt32(data.count - 8), bigEndian: bigEndian))
        try data.write(to: url)
    }

    /// The first top-level chunk with this ID, without its header or pad byte.
    public static func payload(id: String, in url: URL, bigEndian: Bool) throws -> Data? {
        try chunks(in: url, bigEndian: bigEndian).first { $0.id == id }?.payload
    }

    /// The top-level chunk IDs, in file order.
    public static func ids(in url: URL, bigEndian: Bool) throws -> [String] {
        try chunks(in: url, bigEndian: bigEndian).map(\.id)
    }

    private static func chunks(in url: URL, bigEndian: Bool) throws -> [(id: String, payload: Data)] {
        let data = try Data(contentsOf: url)
        var chunks: [(id: String, payload: Data)] = []
        var offset = 12

        while offset + 8 <= data.count {
            let id = String(decoding: data[offset ..< offset + 4], as: UTF8.self)
            let size = Int(decode(data, at: offset + 4, bigEndian: bigEndian))
            let body = offset + 8
            guard body + size <= data.count else { break }

            chunks.append((id, Data(data[body ..< body + size])))
            offset = body + size + (size & 1)
        }

        return chunks
    }

    private static func encode(_ value: UInt32, bigEndian: Bool) -> Data {
        withUnsafeBytes(of: bigEndian ? value.bigEndian : value.littleEndian) { Data($0) }
    }

    private static func decode(_ data: Data, at offset: Int, bigEndian: Bool) -> UInt32 {
        let bytes = data[offset ..< offset + 4].map(UInt32.init)
        return bigEndian
            ? bytes[0] << 24 | bytes[1] << 16 | bytes[2] << 8 | bytes[3]
            : bytes[3] << 24 | bytes[2] << 16 | bytes[1] << 8 | bytes[0]
    }
}

/// The ID3v2 tag at the start of a file, read without any metadata library.
public enum ID3v2Frames {
    /// Every frame, in tag order, with its body. Throws where ``tag(in:)`` refuses the tag.
    public static func frames(in url: URL) throws -> [(id: String, body: Data)] {
        try frames(in: Data(contentsOf: url))
    }

    /// The packet in the `PRIV` frame owned by `XMP`.
    public static func xmpPacket(in url: URL) throws -> Data? {
        let owner = Data("XMP".utf8) + Data([0])

        return try frames(in: url)
            .first { $0.id == "PRIV" && $0.body.starts(with: owner) }
            .map { Data($0.body.dropFirst(owner.count)) }
    }

    /// Whether the file ends with an ID3v1 tag.
    public static func hasID3v1(in url: URL) throws -> Bool {
        let data = try Data(contentsOf: url)
        return data.count >= 128 && data.suffix(128).starts(with: Data("TAG".utf8))
    }
}

/// QuickTime atoms: 32-bit big-endian size, then the four-character type.
public enum QuickTimeBoxes {
    /// The types of `moov/udta`'s children.
    public static func userDataTypes(in url: URL) throws -> Set<String> {
        let data = try Data(contentsOf: url)

        guard let moov = children(of: data, in: 0 ..< data.count).first(where: { $0.type == "moov" }),
              let udta = children(of: data, in: moov.body).first(where: { $0.type == "udta" })
        else { return [] }

        return Set(children(of: data, in: udta.body).map(\.type))
    }

    private static func children(of data: Data, in range: Range<Int>) -> [(type: String, body: Range<Int>)] {
        var boxes: [(type: String, body: Range<Int>)] = []
        var offset = range.lowerBound

        while offset + 8 <= range.upperBound {
            let size = data[offset ..< offset + 4].reduce(0) { $0 << 8 | Int($1) }
            guard size >= 8, offset + size <= range.upperBound else { break }

            // Latin-1, so `0xA9` reads as `©`.
            let type = String(data[offset + 4 ..< offset + 8].map { Character(Unicode.Scalar($0)) })
            boxes.append((type, offset + 8 ..< offset + size))
            offset += size
        }

        return boxes
    }
}

// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-testing

import CryptoKit
import Foundation
import SPFKTesting
import Testing

/// The expected values were read off each fixture byte by byte, outside any metadata library.
@Suite(.tags(.file, .metadataSafetyNet))
struct ID3v2FramesTests {
    private let resources = TestBundleResources.shared

    private func tag(_ url: URL) throws -> ID3v2Frames.Tag {
        try #require(try ID3v2Frames.tag(in: url))
    }

    private func only(_ id: String, in tag: ID3v2Frames.Tag) throws -> ID3v2Frames.Frame {
        let frames = tag.frames(id)
        try #require(frames.count == 1, "\(id): \(frames.count) frames")
        return frames[0]
    }

    // MARK: - Fixtures

    @Test func utf8FramesChaptersAndTableOfContents() throws {
        let tag = try tag(resources.tabla_mp3)

        #expect(tag.majorVersion == 4)
        #expect(try ID3v2Frames.majorVersion(in: resources.tabla_mp3) == 4)
        #expect(try ID3v2Frames.hasID3v1(in: resources.tabla_mp3))
        #expect(try ID3v2Frames.textValues(only("TIT2", in: tag).body) == ["Stonehenge"])

        let txxx = try ID3v2Frames.UserText(only("TXXX", in: tag).body)
        #expect(txxx.description == "MUSICBRAINZ ALBUM RELEASE COUNTRY")
        #expect(txxx.values == ["UK"])

        let comment = try ID3v2Frames.Comment(only("COMM", in: tag).body)
        #expect(comment.language == "XXX")
        #expect(comment.description == "")
        #expect(comment.text.hasPrefix("And oh how they danced. The little children of Stonehenge."))

        let lyrics = try ID3v2Frames.Comment(only("USLT", in: tag).body)
        #expect(lyrics.language == "XXX")
        #expect(lyrics.description == "LYRICS")
        #expect(lyrics.text.hasPrefix("Stonehenge! Where the demons dwell."))

        let toc = try ID3v2Frames.TableOfContents(only("CTOC", in: tag).body, majorVersion: 4)
        #expect(toc.elementID == "toc")
        #expect(!toc.isTopLevel)
        #expect(!toc.isOrdered)
        #expect(toc.children == ["chapter0", "chapter1", "chapter2", "chapter3", "chapter4"])
        #expect(try toc.subframes.map { try ID3v2Frames.textValues($0.body) } == [["toplevel toc"]])

        let chapters = try tag.frames("CHAP").map { try ID3v2Frames.Chapter($0.body, majorVersion: 4) }
        #expect(chapters.map(\.elementID) == ["chapter0", "chapter1", "chapter2", "chapter3", "chapter4"])
        #expect(chapters.map(\.startTime) == [0, 1000, 2000, 3000, 4000])
        #expect(chapters.map(\.endTime) == [0, 1000, 2000, 3000, 4000])
        #expect(chapters.allSatisfy { $0.startOffset == .max && $0.endOffset == .max })
        #expect(chapters.map(\.title) == ["Marker 0", "Marker 1", "Marker 2", "Marker 3", "Marker 4"])
    }

    @Test func utf16TextMultipleValuesAndPicture() throws {
        let tag = try tag(resources.mp3_id3)

        #expect(tag.majorVersion == 4)
        #expect(try ID3v2Frames.textValues(only("TIT2", in: tag).body) == ["Stonehenge"])
        #expect(try ID3v2Frames.textValues(only("TRCK", in: tag).body) == ["9/13"])
        #expect(try ID3v2Frames.textValues(only("TMCL", in: tag).body) == ["Nigel Tufnel", "David St. Hubbins"])
        #expect(try ID3v2Frames.Comment(only("COMM", in: tag).body).language == "eng")

        let picture = try ID3v2Frames.Picture(only("APIC", in: tag).body)
        #expect(picture.mimeType == "image/jpeg")
        #expect(picture.pictureType == 3)
        #expect(picture.description == "Smell the glove")
        #expect(picture.data.count == 6253)
        #expect(SHA256.hash(data: picture.data).map { String(format: "%02x", $0) }.joined()
            == "2056b55b63991c35ea1e8d0710129f8f9583180bcfe3f975e756dcf6d227ce35")
    }

    @Test func version3LatinTextAndPrivateFrame() throws {
        let tag = try tag(resources.mp3_xmp)

        #expect(tag.majorVersion == 3)
        #expect(try ID3v2Frames.textValues(only("TPE1", in: tag).body) == ["Spinal Tap"])
        #expect(try ID3v2Frames.Comment(only("USLT", in: tag).body).language == "eng")

        let priv = try ID3v2Frames.OwnedData(only("PRIV", in: tag).body)
        #expect(priv.owner == "XMP")
        #expect(priv.data.count == 3331)
        #expect(priv.data.starts(with: Data("<?xpacket begin=".utf8)))
        #expect(try ID3v2Frames.xmpPacket(in: resources.mp3_xmp) == priv.data)
    }

    @Test func popularimeter() throws {
        let popm = try ID3v2Frames.Popularimeter(only("POPM", in: tag(resources.rated_80_mp3)).body)
        #expect(popm.email == "Windows Media Player 9 Series")
        #expect(popm.rating == 196)
        #expect(popm.counter == 0)
        #expect(try !ID3v2Frames.hasID3v1(in: resources.rated_80_mp3))
    }

    @Test func dataAndURLReadsAgree() throws {
        let url = resources.tabla_mp3
        let fromURL = try ID3v2Frames.frames(in: url)
        let fromData = try ID3v2Frames.frames(in: Data(contentsOf: url))

        #expect(fromURL.map(\.id) == fromData.map(\.id))
        #expect(fromURL.map(\.body) == fromData.map(\.body))
        #expect(try ID3v2Frames.frames(in: Data("not a tag".utf8)).isEmpty)
    }

    // MARK: - Hand-built bodies

    private static func be32(_ value: Int) -> [UInt8] {
        [24, 16, 8, 0].map { UInt8(truncatingIfNeeded: value >> $0) }
    }

    private static func header(version: UInt8, flags: UInt8, size: Int) -> [UInt8] {
        Array("ID3".utf8) + [version, 0, flags] + [21, 14, 7, 0].map { UInt8((size >> $0) & 0x7F) }
    }

    @Test func binaryFrames() throws {
        #expect(try ID3v2Frames.playCount(Data([0, 0, 1, 2])) == 258)
        #expect(throws: ID3v2Frames.ReadError.self) { try ID3v2Frames.playCount(Data([1, 2])) }

        let ufid = try ID3v2Frames.OwnedData(Data("http://example.com\0".utf8) + Data([0x53, 0x4E, 0x00, 0x01]))
        #expect(ufid.owner == "http://example.com")
        #expect(ufid.data == Data([0x53, 0x4E, 0x00, 0x01]))

        let geob = try ID3v2Frames.GeneralObject(Data([0]) + Data("application/octet-stream\0a.bin\0Object\0".utf8) + Data([9, 0, 8]))
        #expect([geob.mimeType, geob.fileName, geob.description] == ["application/octet-stream", "a.bin", "Object"])
        #expect(geob.object == Data([9, 0, 8]))

        let popm = try ID3v2Frames.Popularimeter(Data("a@b\0".utf8) + Data([64]))
        #expect(popm.email == "a@b")
        #expect(popm.rating == 64)
        #expect(popm.counter == nil)
    }

    @Test func textEncodings() throws {
        // Encoding 1, a BOM on the first value only: the second takes the first's byte order.
        let utf16 = Data([1, 0xFF, 0xFE, 0x41, 0, 0xE9, 0, 0, 0, 0x42, 0, 0, 0])
        #expect(try ID3v2Frames.textValues(utf16) == ["Aé", "B"])

        // Encoding 2, big-endian with no BOM.
        #expect(try ID3v2Frames.textValues(Data([2, 0, 0x41, 0x30, 0x42])) == ["A\u{3042}"])

        // Encoding 3, Latin-1 text bytes and an empty value dropped.
        #expect(try ID3v2Frames.textValues(Data([3]) + Data("Café\0\0x".utf8)) == ["Café", "x"])
        #expect(try ID3v2Frames.textValues(Data([0, 0x43, 0x61, 0x66, 0xE9, 0])) == ["Café"])

        let txxx = try ID3v2Frames.UserText(Data([1, 0xFE, 0xFF, 0, 0x44, 0, 0, 0xFE, 0xFF, 0, 0x76]))
        #expect(txxx.description == "D")
        #expect(txxx.values == ["v"])

        let wxxx = try ID3v2Frames.UserURL(Data([0]) + Data("Link\0https://example.com".utf8))
        #expect(wxxx.description == "Link")
        #expect(wxxx.url == "https://example.com")

        #expect(throws: ID3v2Frames.ReadError.self) { try ID3v2Frames.textValues(Data([7, 0x41])) }
        #expect(throws: ID3v2Frames.ReadError.self) { try ID3v2Frames.UserText(Data([0]) + Data("no terminator".utf8)) }
    }

    @Test func version3FrameSizesAreNotSyncsafe() throws {
        // A 200-byte body: 0xC8 is not a valid syncsafe byte, so a v2.4 read would refuse it.
        let body = [UInt8](repeating: 0x41, count: 199)
        let frame = Array("TIT2".utf8) + Self.be32(200) + [0, 0, 0] + body
        let tag = try #require(try ID3v2Frames.tag(in: Data(Self.header(version: 3, flags: 0, size: frame.count) + frame)))

        #expect(tag.majorVersion == 3)
        #expect(try ID3v2Frames.textValues(only("TIT2", in: tag).body) == [String(repeating: "A", count: 199)])

        #expect(throws: ID3v2Frames.ReadError.self) {
            try ID3v2Frames.tag(in: Data(Self.header(version: 4, flags: 0, size: frame.count) + frame))
        }
    }

    @Test func unsupportedLayoutsAreRefused() throws {
        let frame = Array("TIT2".utf8) + [0, 0, 0, 2, 0, 0, 0, 0x41]

        #expect(throws: ID3v2Frames.ReadError.unsynchronisation) {
            try ID3v2Frames.tag(in: Data(Self.header(version: 4, flags: 0x80, size: frame.count) + frame))
        }
        #expect(throws: ID3v2Frames.ReadError.extendedHeader) {
            try ID3v2Frames.tag(in: Data(Self.header(version: 3, flags: 0x40, size: frame.count) + frame))
        }
        #expect(throws: ID3v2Frames.ReadError.unsupportedVersion(2)) {
            try ID3v2Frames.tag(in: Data(Self.header(version: 2, flags: 0, size: frame.count) + frame))
        }

        let unsyncFrame = Array("TIT2".utf8) + [0, 0, 0, 2, 0, 0x02, 0, 0x41]
        #expect(throws: ID3v2Frames.ReadError.unsynchronisation) {
            try ID3v2Frames.tag(in: Data(Self.header(version: 4, flags: 0, size: unsyncFrame.count) + unsyncFrame))
        }

        let overrun = Array("TIT2".utf8) + [0, 0, 0, 9, 0, 0, 0, 0x41]
        #expect(throws: ID3v2Frames.ReadError.self) {
            try ID3v2Frames.tag(in: Data(Self.header(version: 4, flags: 0, size: overrun.count) + overrun))
        }
    }
}

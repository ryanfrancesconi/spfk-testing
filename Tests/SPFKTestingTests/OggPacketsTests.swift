// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-testing

import Foundation
import SPFKTesting
import Testing

/// The expected values were read off each fixture byte by byte, outside any metadata library.
@Suite(.tags(.file, .metadataSafetyNet))
struct OggPacketsTests {
    private let resources = TestBundleResources.shared

    @Test func vorbisHeadersAndComment() throws {
        let ogg = try OggPackets(contentsOf: resources.tabla_ogg)

        #expect(ogg.headerPacketCount == 3)
        #expect(ogg.pages.prefix(3).map(\.sequenceNumber) == [0, 1, 2])
        #expect(ogg.pages.prefix(3).map(\.granulePosition) == [0, 0, 12736])
        #expect(ogg.pages[1].lacingValues.count == 23)
        #expect(ogg.packets.prefix(3).map(\.lastPage) == [0, 1, 1])
        #expect(ogg.audioPages.first?.sequenceNumber == 2)

        let comment = try #require(try ogg.comment())
        #expect(comment.vendor == "Xiph.Org libVorbis I 20200704 (Reducing Environment)")
        #expect(comment.fields.count == 39)
        #expect(comment.values("title") == ["Stonehenge"])
        #expect(comment.values("CHAPTER002NAME") == ["Marker 1"])
    }

    @Test func opusHeadersAndComment() throws {
        let opus = try OggPackets(contentsOf: resources.sine_opus)

        #expect(opus.headerPacketCount == 2)
        #expect(opus.pages.map(\.sequenceNumber) == [0, 1, 2])
        #expect(opus.pages.last?.granulePosition == 12312)
        #expect(opus.audioPages.map(\.sequenceNumber) == [2])

        let comment = try #require(try opus.comment())
        #expect(comment.vendor == "Lavf63.1.100")
        #expect(comment.fields == [VorbisComment.Field(key: "encoder", value: "Lavc63.1.100 libopus")])
    }

    @Test(arguments: ["tabla.ogg", "sine.opus"])
    func pagesReencodeByteForByte(name: String) throws {
        let url = name == "tabla.ogg" ? resources.tabla_ogg : resources.sine_opus
        let data = try Data(contentsOf: url)

        #expect(try OggPackets(data).pages.map(\.encoded).reduce(Data(), +) == data)
    }

    @Test func refusesABadChecksum() throws {
        var data = try Data(contentsOf: resources.sine_opus)
        data[30] ^= 0xFF

        #expect(throws: OggPackets.ReadError.badCRC(page: 0)) { try OggPackets(data) }
        #expect(throws: OggPackets.ReadError.notOgg) { try OggPackets(Data(contentsOf: resources.tabla_wav)) }
    }
}

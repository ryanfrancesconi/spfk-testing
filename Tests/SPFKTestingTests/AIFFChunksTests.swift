// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-testing

import Foundation
import SPFKTesting
import Testing

/// The expected values were read off each fixture byte by byte, outside any metadata library.
@Suite(.tags(.file, .metadataSafetyNet))
struct AIFFChunksTests {
    private let resources = TestBundleResources.shared

    @Test func chunksSampleRateAndMarkers() throws {
        let aiff = try AIFFChunks(contentsOf: resources.tabla_aif)

        #expect(aiff.formType == "AIFF")
        #expect(aiff.chunks.map(\.id) == ["COMM", "FLLR", "SSND", "MARK", "ID3 "])
        #expect(aiff.sampleRate == 48000)
        #expect(aiff.first("SSND")?.payload.count == 1_265_408)
        #expect(aiff.first("ID3 ")?.payload.prefix(4) == Data("ID3".utf8) + Data([4]))

        let markers = try aiff.markers()
        #expect(markers.map(\.id) == [0, 1, 2, 3, 4])
        #expect(markers.map(\.position) == [0, 48000, 96000, 144_000, 192_000])
        #expect(markers.map(\.name) == ["Marker 0", "Marker 1", "Marker 2", "Marker 3", "Marker 4"])
    }

    @Test func aifcSampleRate() throws {
        let aifc = try AIFFChunks(contentsOf: resources.sine_aifc)

        #expect(aifc.formType == "AIFC")
        #expect(aifc.chunks.map(\.id) == ["FVER", "COMM", "FLLR", "SSND"])
        #expect(aifc.sampleRate == 44100)
    }

    /// A `COMT` with an odd-length comment, an `APPL`, a text chunk and an odd-length `MARK` name.
    @Test func commentsApplicationsAndText() throws {
        func be(_ value: Int, _ bytes: Int) -> Data {
            Data((0 ..< bytes).reversed().map { UInt8(truncatingIfNeeded: value >> (8 * $0)) })
        }

        func chunk(_ id: String, _ payload: Data) -> Data {
            Data(id.utf8) + be(payload.count, 4) + payload + (payload.count.isMultiple(of: 2) ? Data() : Data([0]))
        }

        let first: [Data] = [be(100, 4), be(1, 2), be(3, 2), Data("abc".utf8), Data([0])]
        let second: [Data] = [be(200, 4), be(0, 2), be(2, 2), Data("de".utf8)]
        let comt = ([be(2, 2)] + first + second).reduce(Data(), +)
        let mark = [be(1, 2), be(1, 2), be(4800, 4), Data([2]), Data("Hi".utf8), Data([0])].reduce(Data(), +)
        let chunks: [Data] = [
            chunk("COMT", comt), chunk("MARK", mark), chunk("APPL", Data("XMP ".utf8) + Data([1, 2, 3])), chunk("NAME", Data("A Name".utf8)),
        ]
        let body = Data("AIFF".utf8) + chunks.reduce(Data(), +)
        let aiff = try AIFFChunks(Data("FORM".utf8) + be(body.count, 4) + body)

        #expect(aiff.chunks.map(\.id) == ["COMT", "MARK", "APPL", "NAME"])
        #expect(try aiff.comments() == [
            AIFFChunks.Comment(timeStamp: 100, markerID: 1, text: "abc"),
            AIFFChunks.Comment(timeStamp: 200, markerID: 0, text: "de"),
        ])
        #expect(try aiff.markers() == [AIFFChunks.Marker(id: 1, position: 4800, name: "Hi")])
        #expect(aiff.applications().map(\.signature) == ["XMP "])
        #expect(aiff.applications().first?.data == Data([1, 2, 3]))
        #expect(aiff.text("NAME") == "A Name")
        #expect(aiff.text("AUTH") == nil)
    }

    @Test func refusesOtherFiles() throws {
        #expect(throws: AIFFChunks.ReadError.notRIFF) { try AIFFChunks(contentsOf: resources.tabla_wav) }
    }
}

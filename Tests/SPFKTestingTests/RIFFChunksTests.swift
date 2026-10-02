// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-testing

import Foundation
import SPFKTesting
import Testing

/// The expected values were read off each fixture byte by byte, outside any metadata library.
@Suite(.tags(.file, .metadataSafetyNet))
struct RIFFChunksTests {
    private let resources = TestBundleResources.shared

    @Test func topLevelChunksInFileOrder() throws {
        let riff = try RIFFChunks(contentsOf: resources.tabla_wav)

        #expect(riff.formType == "WAVE")
        #expect(riff.chunks.map(\.id) == ["fmt ", "data", "cue ", "LIST", "JUNK", "r64m", "smpl", "inst", "ID3 ", "LIST"])
        #expect(riff.chunks.compactMap(\.listType) == ["adtl", "INFO"])
        #expect(riff.sampleRate == 48000)
        #expect(riff.first("data")?.payload.count == 1_265_400)
        // An odd size: the pad byte after it is not part of the payload.
        #expect(riff.first("inst")?.payload == Data([0x00, 0x00, 0x00, 0x00, 0x7F, 0x01, 0x7F]))
        #expect(riff.first("JUNK")?.payload == Data(count: 28))
        #expect(riff.first("r64m")?.payload.count == 320)
        #expect(riff.first("ID3 ")?.payload.prefix(4) == Data("ID3".utf8) + Data([4]))
    }

    @Test func infoItems() throws {
        let items = try RIFFChunks(contentsOf: resources.tabla_wav).infoItems()

        #expect(items.map(\.id) == [
            "IART", "IBPM", "ICMT", "ICNT", "ICOP", "ICRD", "IEDT", "IGNR", "ILNG",
            "IMUS", "INAM", "IPLT", "IPRD", "IPRT", "IPUB", "ISRC", "ITCH", "IWRI",
        ])
        #expect(items.first { $0.id == "IART" }?.value == "Spinal Tap")
        #expect(items.first { $0.id == "INAM" }?.value == "Stonehenge")
        #expect(items.first { $0.id == "IPRT" }?.value == "9/13")
        #expect(items.first { $0.id == "ICMT" }?.value.hasPrefix("And oh how they danced. The little children of Stonehenge.") == true)
    }

    @Test func cuePointsAndLabels() throws {
        let riff = try RIFFChunks(contentsOf: resources.tabla_wav)
        let points = try riff.cuePoints()

        #expect(points.map(\.id) == [0, 1, 2, 3, 4])
        #expect(points.map(\.sampleOffset) == [0, 48000, 96000, 144_000, 192_000])
        #expect(points.map(\.position) == points.map(\.sampleOffset))
        #expect(points.allSatisfy { $0.chunkID == "data" && $0.chunkStart == 0 && $0.blockStart == 0 })

        #expect(try riff.associatedData().map(\.id) == ["labl", "labl", "labl", "labl", "labl"])
        #expect(try riff.labels() == [0: "Marker 0", 1: "Marker 1", 2: "Marker 2", 3: "Marker 3", 4: "Marker 4"])
    }

    @Test func broadcastExtension() throws {
        let riff = try RIFFChunks(contentsOf: resources.cowbell_bext_wav)
        #expect(riff.chunks.map(\.id) == ["fmt ", "bext", "data", "ID3 "])

        let bext = try #require(try riff.broadcastExtension())
        #expect(bext.description == "cowbell")
        #expect(bext.originator == "rf")
        #expect(bext.originatorReference == "ITRAIDA88396FG347125324098748726")
        #expect(bext.originationDate == "2026-02-02")
        #expect(bext.originationTime == "00:00:00")
        #expect(bext.timeReference == 0)
        #expect(bext.version == 2)
        #expect(bext.umid.map { String(format: "%02x", $0) }.joined() == "060a2b34010101010101021033000000000000000000008000000000000000000000000000000080000000000000000000000000202020202020202020202020")
        #expect(bext.loudness == [0, 100, 9900, 0, 0])
        #expect(bext.reserved == Data(count: 180))
        #expect(bext.codingHistory == Data("A=PCM,F=44100,W=24,M=stereo,T=libsndfile-1.2.2\r\nA=PCM,F=44100,W=24,M=stereo,T=libsndfile-1.2.2\r\n".utf8))
    }

    @Test func refusesLongFormFilesAndOverruns() throws {
        let rf64 = Data("RF64".utf8) + Data([0xFF, 0xFF, 0xFF, 0xFF]) + Data("WAVE".utf8)
        #expect(throws: RIFFChunks.ReadError.unsupportedForm("RF64")) { try RIFFChunks(rf64) }

        let overrun = Data("RIFF".utf8) + Data([20, 0, 0, 0]) + Data("WAVE".utf8) + Data("JUNK".utf8) + Data([0x10, 0, 0, 0, 0, 0])
        #expect(throws: RIFFChunks.ReadError.self) { try RIFFChunks(overrun) }

        #expect(throws: RIFFChunks.ReadError.notRIFF) { try RIFFChunks(Data("ID3".utf8) + Data(count: 20)) }
    }
}

// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-testing

import CryptoKit
import Foundation
import SPFKTesting
import Testing

/// The expected values were read off each fixture byte by byte, outside any metadata library.
@Suite(.tags(.file, .metadataSafetyNet))
struct FLACBlocksTests {
    private let resources = TestBundleResources.shared

    @Test func blocksInFileOrder() throws {
        let flac = try FLACBlocks(contentsOf: resources.tabla_flac)

        #expect(flac.prefix.isEmpty)
        #expect(flac.blocks.map(\.type) == [0, 3, 4, 2, 2, 2, 2, 2, 2, 2, 2])
        #expect(flac.blocks.map(\.payload.count) == [34, 18, 1428, 16, 28, 12, 40, 332, 72, 20, 418])
        #expect(flac.audio.prefix(2) == Data([0xFF, 0xF8]))
        #expect(flac.sampleRate == 48000)
        #expect(flac.totalSamples == 210_900)
        #expect(flac.blocks(.seekTable).first?.payload == Data(count: 16) + Data([0x10, 0x00]))
    }

    @Test func riffWrappedApplicationBlocks() throws {
        let flac = try FLACBlocks(contentsOf: resources.tabla_flac)
        let applications = flac.blocks(.application)

        #expect(applications.compactMap(\.applicationID) == Array(repeating: "riff", count: 8))

        let chunks = try applications.compactMap { try $0.riffChunk() }
        #expect(chunks.map(\.id) == ["RIFF", "fmt ", "data", "JUNK", "r64m", "smpl", "inst", "LIST"])
        // `RIFF` carries the form type; `data` carries only its size, since the samples are FLAC's.
        #expect(chunks.map(\.payload.count) == [4, 16, 0, 28, 320, 60, 7, 406])
        #expect(chunks.first?.payload == Data("WAVE".utf8))
        #expect(applications.compactMap(\.riffChunkSize) == [1_266_298, 16, 1_265_400, 28, 320, 60, 7, 406])
    }

    @Test func directApplicationBlocks() throws {
        let flac = try FLACBlocks(contentsOf: resources.flac_bext_ixml_external)

        #expect(flac.blocks.map(\.type) == [0, 4, 2, 2, 1])
        #expect(flac.blocks(.application).compactMap(\.applicationID) == ["iXML", "bext"])
        #expect(try flac.blocks(.application).compactMap { try $0.riffChunk() }.isEmpty)
        #expect(flac.blocks(.application).first?.payload.dropFirst(4).starts(with: Data("<?xml".utf8)) == true)
    }

    @Test func vorbisCommentKeepsOrderDuplicatesAndCase() throws {
        let comment = try #require(try FLACBlocks(contentsOf: resources.tabla_flac).vorbisComment())

        #expect(comment.vendor == "reference libFLAC 1.4.2 20221022")
        #expect(comment.fields.count == 40)
        #expect(comment.fields.first == VorbisComment.Field(key: "ALBUM", value: "This Is Spinal Tap"))
        #expect(comment.values("encoder") == ["TwistedWave", "TwistedWave"])
        #expect(comment.fields.filter { $0.key == "chapter001name" }.map(\.value) == ["Marker 0"])
        #expect(comment.fields.last == VorbisComment.Field(key: "ENCODER", value: "TwistedWave"))
    }

    @Test func pictureFromALegacyCommentField() throws {
        let comment = try #require(try FLACBlocks(contentsOf: resources.tabla_legacy_picture_flac).vorbisComment())
        let field = try #require(comment.values("METADATA_BLOCK_PICTURE").first)
        let picture = try FLACBlocks.Picture(#require(Data(base64Encoded: field)))

        #expect(picture.pictureType == 3)
        #expect(picture.mimeType == "image/jpeg")
        #expect(picture.description == "")
        #expect([picture.width, picture.height, picture.colorDepth, picture.colorCount] == [425, 425, 24, 0])
        #expect(picture.data.count == 42356)
        #expect(SHA256.hash(data: picture.data).map { String(format: "%02x", $0) }.joined() == "596619d02998590cdaa2f5c0b26c16daa70398c71039983c14e9e1eb10371379")
    }

    @Test func refusesOtherStreamsAndOverruns() throws {
        #expect(throws: FLACBlocks.ReadError.notFLAC) { try FLACBlocks(Data("OggS".utf8) + Data(count: 20)) }
        #expect(FLACBlocks.isFLAC(try Data(contentsOf: resources.tabla_mp3)) == false)

        // A last block declaring 16 bytes with 2 present.
        let overrun = Data("fLaC".utf8) + Data([0x80, 0x00, 0x00, 0x10, 0x00, 0x00])
        #expect(throws: FLACBlocks.ReadError.self) { try FLACBlocks(overrun) }
    }
}

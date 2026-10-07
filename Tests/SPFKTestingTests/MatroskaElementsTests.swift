// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-testing

import Foundation
import SPFKTesting
import Testing

/// The expected values were read off each fixture byte by byte, outside any metadata library.
@Suite(.tags(.file, .metadataSafetyNet))
struct MatroskaElementsTests {
    private let resources = TestBundleResources.shared
    private typealias ID = MatroskaElements.ID

    @Test func segmentLayoutAndSeekHead() throws {
        let mka = try MatroskaElements(contentsOf: resources.tabla_mka)

        #expect(mka.docType == "matroska")
        #expect(mka.title == "SPFK Tabla Matroska")
        #expect(mka.segmentDataOffset == 52)
        #expect(mka.segment.children.map(\.id) == [ID.seekHead, ID.void, ID.info, ID.tracks, ID.chapters, ID.tags, ID.cluster, ID.cues])
        #expect(mka.elements(ID.tags).first?.offset == 599)
        #expect(mka.seekEntries.map(\.id) == [ID.info, ID.tracks, ID.chapters, ID.tags, ID.cues])
        #expect(mka.seekEntries.map(\.position) == [161, 261, 343, 547, 154_242])
        #expect(mka.attachedFiles.isEmpty)
    }

    @Test func tagsWithTheirTargets() throws {
        let tags = try MatroskaElements(contentsOf: resources.tabla_mka).tags

        #expect(tags.count == 2)
        #expect(tags[0].targetTypeValue == nil)
        #expect(tags[0].trackUIDs.isEmpty)
        #expect(tags[0].simpleTags.prefix(3).map(\.name) == ["MAJOR_BRAND", "MINOR_VERSION", "COMPATIBLE_BRANDS"])
        #expect(tags[0].simpleTags.first?.string == "M4A ")
        #expect(tags[1].trackUIDs == [16_451_547_694_835_268_860])
        #expect(tags[1].simpleTags.map(\.name) == ["VENDOR_ID", "DURATION"])
    }

    @Test func webmDocType() throws {
        let webm = try MatroskaElements(contentsOf: resources.sample_webm)

        #expect(webm.docType == "webm")
        #expect(webm.title == "SPFK Sample WebM")
        #expect(webm.tags.filter { !$0.trackUIDs.isEmpty }.map(\.trackUIDs) == [[12_286_266_732_529_956_626], [18_036_882_007_848_602_005]])
    }

    @Test func refusesOtherFiles() throws {
        #expect(throws: MatroskaElements.ReadError.notEBML) { try MatroskaElements(contentsOf: resources.tabla_wav) }
    }
}

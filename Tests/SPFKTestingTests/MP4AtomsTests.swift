// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-testing

import Foundation
import SPFKTesting
import Testing

/// The expected values were read off each fixture byte by byte, outside any metadata library.
@Suite(.tags(.file, .metadataSafetyNet))
struct MP4AtomsTests {
    private let resources = TestBundleResources.shared

    @Test func treeWithMoovBeforeMdat() throws {
        let atoms = try MP4Atoms(contentsOf: resources.tabla_m4a)

        #expect(atoms.boxes.map(\.type) == ["ftyp", "moov", "mdat"])
        #expect(atoms.boxes.map(\.offset) == [0, 28, 5157])
        #expect(atoms.boxes.map(\.size) == [28, 5129, 150_901])
        #expect(atoms.box(["moov"])?.children("trak").count == 2)
        #expect(atoms.box(["moov", "udta", "meta"])?.children.map(\.type) == ["hdlr", "ilst", "free"])
        #expect(atoms.box(["moov", "udta", "meta", "free"])?.size == 982)
        #expect(atoms.chapterReferences() == [[2], []])
    }

    @Test func itemListWithFreeformAndTypedValues() throws {
        let atoms = try MP4Atoms(contentsOf: resources.tabla_m4a)
        let items = try atoms.items()

        #expect(items.count == 28)
        #expect(items.filter { $0.key.hasPrefix("----:com.apple.iTunes:") }.count == 14)
        #expect(items.first?.key == "----:com.apple.iTunes:CONDUCTOR")
        #expect(items.first?.values == [MP4Atoms.DataAtom(type: 1, locale: 0, value: Data("Derek Smalls".utf8))])
        #expect(items.contains { $0.key == "----:com.apple.iTunes:MusicBrainz Album Release Country" })
        #expect(try atoms.items("©nam").first?.values.first?.text == "Stonehenge")
        #expect(try atoms.items("tmpo").first?.values.first?.text == "666")
        #expect(try atoms.items("trkn").first?.values.first?.text == "00000009000d0000")
        #expect(try atoms.covers().isEmpty)
        #expect(try atoms.neroChapters() == nil)
    }

    @Test func treeWithMoovAfterMdat() throws {
        let atoms = try MP4Atoms(contentsOf: resources.sine_m4b)

        #expect(atoms.boxes.map(\.type) == ["ftyp", "free", "mdat", "moov"])
        #expect(atoms.boxes.map(\.offset) == [0, 28, 36, 1133])
        #expect(try atoms.items().map(\.key) == ["©too"])
        #expect(try atoms.items("©too").first?.values.first?.text == "Lavf63.1.100")
    }

    @Test func gaplessFreeformItem() throws {
        let item = try #require(try MP4Atoms(contentsOf: resources.ituns_mpb_m4a).items().first)

        #expect(item.key == "----:com.apple.iTunes:iTunSMPB")
        #expect(item.values.count == 1)
        #expect(item.values.first?.type == 1)
        #expect(item.values.first?.value.count == 116)
        #expect(item.values.first?.text.hasPrefix(" 00000000 00000840 00000000 000000000000") == true)
    }

    @Test func userDataOutsideMetaAndNeroChapters() throws {
        let atoms = try MP4Atoms(contentsOf: resources.tabla_cprt_m4a)
        let udta = try #require(atoms.box(["moov", "udta"]))

        #expect(udta.children.map(\.type) == ["cprt", "chpl"])
        #expect(udta.child("cprt")?.payload == Data([0, 0, 0, 0, 0x15, 0xC7]) + Data("ISO Copy".utf8) + Data([0]))
        #expect(try atoms.items().isEmpty)

        let chapters = try #require(try atoms.neroChapters())
        #expect(chapters.map(\.start) == [0, 10_000_000, 20_000_000, 30_000_000, 40_000_000])
        #expect(chapters.map(\.title) == ["", "", "", "", ""])
    }

    @Test func sixtyFourBitSizeAndBytes() throws {
        let box = Data([0, 0, 0, 1]) + Data("mdat".utf8) + Data([0, 0, 0, 0, 0, 0, 0, 0x18]) + Data(repeating: 7, count: 8)
        let atoms = try MP4Atoms(Data([0, 0, 0, 8]) + Data("free".utf8) + box)

        #expect(atoms.boxes.map(\.type) == ["free", "mdat"])
        #expect(atoms.boxes.last?.headerSize == 16)
        #expect(atoms.boxes.last?.size == 24)
        #expect(atoms.boxes.last?.payload == Data(repeating: 7, count: 8))
        #expect(atoms.boxes.last?.bytes == box)
    }

    @Test func refusesAnOverrun() {
        // A `moov` declaring 64 bytes with 12 present.
        let overrun = Data([0, 0, 0, 0x40]) + Data("moov".utf8) + Data(count: 4)
        #expect(throws: MP4Atoms.ReadError.self) { try MP4Atoms(overrun) }
    }
}

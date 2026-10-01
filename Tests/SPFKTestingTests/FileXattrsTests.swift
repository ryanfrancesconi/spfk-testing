// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-testing

import Foundation
import SPFKTesting
import Testing

@Suite(.tags(.file, .metadataSafetyNet))
struct FileXattrsTests {
    /// `_kMDItemUserTags` as macOS wrote it for the tag names `["Safety", "Red"]` through
    /// `NSURL.setResourceValue(_:forKey: .tagNamesKey)` in a command-line process. The color index
    /// after the newline depends on the process: a test host wrote `"Red\n6"` for the same call.
    static let systemWrittenUserTags = Data([
        0x62, 0x70, 0x6C, 0x69, 0x73, 0x74, 0x30, 0x30, 0xA2, 0x01, 0x02, 0x58, 0x53, 0x61, 0x66, 0x65,
        0x74, 0x79, 0x0A, 0x30, 0x55, 0x52, 0x65, 0x64, 0x0A, 0x30, 0x08, 0x0B, 0x14, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x1A,
    ])

    private func makeFile() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("FileXattrsTests-\(UUID().uuidString).bin")
        try Data([0x01, 0x02, 0x03]).write(to: url)
        return url
    }

    @Test func setValueReadsBackByteForByteAndIsListed() throws {
        let url = try makeFile()
        defer { try? FileManager.default.removeItem(at: url) }

        let bytes = Data([0x00, 0xFF, 0x10, 0x00, 0x7F])
        try FileXattrs.set("com.example.safetynet", value: bytes, on: url)
        try FileXattrs.set("com.example.empty", value: Data(), on: url)

        #expect(try FileXattrs.value("com.example.safetynet", of: url) == bytes)
        #expect(try FileXattrs.value("com.example.empty", of: url) == Data())
        #expect(try Set(FileXattrs.names(of: url)).isSuperset(of: ["com.example.safetynet", "com.example.empty"]))
        #expect(try FileXattrs.all(of: url)["com.example.safetynet"] == bytes)
    }

    @Test func anAbsentAttributeIsNil() throws {
        let url = try makeFile()
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(try FileXattrs.value("com.example.absent", of: url) == nil)
        #expect(try FileXattrs.userTags(of: url) == nil)
    }

    @Test func aMissingFileThrows() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("FileXattrsTests-missing-\(UUID().uuidString)")

        #expect(throws: POSIXError.self) { try FileXattrs.value("com.example.safetynet", of: url) }
        #expect(throws: POSIXError.self) { try FileXattrs.names(of: url) }
    }

    @Test func systemWrittenUserTagsDecodeInStoredOrder() throws {
        #expect(try FileXattrs.decodeUserTags(Self.systemWrittenUserTags) == ["Safety\n0", "Red\n0"])
    }

    @Test func userTagsThatAreNotAStringArrayThrow() throws {
        let data = try PropertyListSerialization.data(fromPropertyList: ["tag": 1], format: .binary, options: 0)
        #expect(throws: (any Error).self) { try FileXattrs.decodeUserTags(data) }
    }

    #if os(macOS)
        @Test func readsTagsTheSystemWrote() throws {
            let url = try makeFile()
            defer { try? FileManager.default.removeItem(at: url) }

            try (url as NSURL).setResourceValue(["Safety", "Red"], forKey: .tagNamesKey)

            let tags = try #require(try FileXattrs.userTags(of: url))

            #expect(tags.map { $0.split(separator: "\n").first.map(String.init) } == ["Safety", "Red"])
            #expect(tags.allSatisfy { $0.split(separator: "\n").last?.allSatisfy(\.isNumber) == true })
        }
    #endif
}

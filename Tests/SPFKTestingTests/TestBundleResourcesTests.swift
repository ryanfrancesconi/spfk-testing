import Foundation
import SPFKTesting
import Testing

@Suite("TestBundleResources")
struct TestBundleResourcesTests {
    let resources = TestBundleResources.shared

    // MARK: - Bundle paths

    @Test("resourcesDirectory is derived from bundleURL")
    func resourcesDirectory() {
        let dir = resources.resourcesDirectory.path
        #expect(dir.hasPrefix(resources.bundleURL.path))
    }

    // MARK: - Collections

    @Test("audioCases URLs have unique last path components")
    func audioCasesUnique() {
        let names = resources.audioCases.map(\.lastPathComponent)
        #expect(Set(names).count == names.count)
    }

    @Test("formats URLs have unique last path components")
    func formatsUnique() {
        let names = resources.formats.map(\.lastPathComponent)
        #expect(Set(names).count == names.count)
    }

    @Test("markerFormats is a subset of formats")
    func markerFormatsSubsetOfFormats() {
        let formatPaths = Set(resources.formats.map(\.lastPathComponent))
        for url in resources.markerFormats {
            #expect(
                formatPaths.contains(url.lastPathComponent),
                "\(url.lastPathComponent) is in markerFormats but not in formats"
            )
        }
    }

    @Test("all format resources resolve to expected file names")
    func allFormatsNames() {
        let expectedNames: Set = [
            "tabla.aac", "tabla.aif", "tabla.caf", "tabla.flac",
            "tabla.m4a", "tabla.mp3", "tabla.mp4", "tabla.ogg", "tabla.wav",
        ]
        let actualNames = Set(resources.formats.map(\.lastPathComponent))
        #expect(actualNames == expectedNames)
    }

    // MARK: - Resource naming

    @Test func everySurroundFixtureIsInTheBundle() {
        for url in resources.surroundFixtures + [resources.stereo_eac3_mka] {
            #expect(FileManager.default.fileExists(atPath: url.path), "\(url.lastPathComponent)")
        }
    }
}

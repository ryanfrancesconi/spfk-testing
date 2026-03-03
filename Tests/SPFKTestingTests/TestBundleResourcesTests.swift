import Foundation
import SPFKTesting
import Testing

@Suite("TestBundleResources")
struct TestBundleResourcesTests {
    let resources = TestBundleResources.shared

    // MARK: - Bundle paths

    @Test("bundleURL is non-empty path")
    func bundleURL() {
        #expect(!resources.bundleURL.path.isEmpty)
    }

    @Test("resourcesDirectory is derived from bundleURL")
    func resourcesDirectory() {
        let dir = resources.resourcesDirectory.path
        #expect(dir.hasPrefix(resources.bundleURL.path))
    }

    // MARK: - Collections

    @Test("audioCases contains 8 files")
    func audioCasesCount() {
        #expect(resources.audioCases.count == 8)
    }

    @Test("formats contains 9 files")
    func formatsCount() {
        #expect(resources.formats.count == 9)
    }

    @Test("markerFormats contains 6 files")
    func markerFormatsCount() {
        #expect(resources.markerFormats.count == 6)
    }

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

    @Test("all audioCases resources resolve to expected file names")
    func allAudioCasesNames() {
        let expectedNames: Set = [
            "and-oh-how-they-danced.mp3", "123456789_60BPM_48k.wav",
            "and-oh-how-they-danced.wav", "tabla.mp4", "tabla.wav",
            "tabla_6_channel.wav", "cowbell.wav", "pink_noise.wav",
        ]
        let actualNames = Set(resources.audioCases.map(\.lastPathComponent))
        #expect(actualNames == expectedNames)
    }

    @Test("all markerFormats resources resolve to expected file names")
    func allMarkerFormatsNames() {
        let expectedNames: Set = [
            "tabla.aif", "tabla.flac", "tabla.m4a",
            "tabla.mp3", "tabla.mp4", "tabla.wav",
        ]
        let actualNames = Set(resources.markerFormats.map(\.lastPathComponent))
        #expect(actualNames == expectedNames)
    }

    // MARK: - Individual audio resources

    @Test("mp3_no_metadata resolves to correct file name")
    func mp3NoMetadata() {
        #expect(resources.mp3_no_metadata.lastPathComponent == "no metadata.mp3")
    }

    @Test("mp3_xmp resolves to correct file name")
    func mp3Xmp() {
        #expect(resources.mp3_xmp.lastPathComponent == "xmp.mp3")
    }

    @Test("mp3_id3 resolves to correct file name")
    func mp3Id3() {
        #expect(resources.mp3_id3.lastPathComponent == "and-oh-how-they-danced.mp3")
    }

    @Test("wav_bext_v1 resolves to correct file name")
    func wavBextV1() {
        #expect(resources.wav_bext_v1.lastPathComponent == "123456789_60BPM_48k.wav")
    }

    @Test("counting_123456789_60BPM_48k is alias for wav_bext_v1")
    func countingAlias() {
        #expect(resources.counting_123456789_60BPM_48k == resources.wav_bext_v1)
    }

    @Test("wav_bext_v2 resolves to correct file name")
    func wavBextV2() {
        #expect(resources.wav_bext_v2.lastPathComponent == "and-oh-how-they-danced.wav")
    }

    @Test("wav_bext_v2b resolves to correct file name")
    func wavBextV2b() {
        #expect(resources.wav_bext_v2b.lastPathComponent == "and-oh-how-they-danced_2.wav")
    }

    @Test("toc_many_children resolves to correct file name")
    func tocManyChildren() {
        #expect(resources.toc_many_children.lastPathComponent == "toc_many_children.mp3")
    }

    @Test("cowbell_bext_wav resolves to correct file name")
    func cowbellBextWav() {
        #expect(resources.cowbell_bext_wav.lastPathComponent == "cowbell_bext.wav")
    }

    @Test("no_data_chunk resolves to correct file name")
    func noDataChunk() {
        #expect(resources.no_data_chunk.lastPathComponent == "no_data_chunk.wav")
    }

    @Test("ixml_chunk resolves to correct file name")
    func ixmlChunk() {
        #expect(resources.ixml_chunk.lastPathComponent == "usesEntireiXMLSpec.wav")
    }

    @Test("addAudio resolves to correct file name")
    func addAudio() {
        #expect(resources.addAudio.lastPathComponent == "boom.addAudio")
    }

    @Test("tabla_6_channel resolves to correct file name")
    func tabla6Channel() {
        #expect(resources.tabla_6_channel.lastPathComponent == "tabla_6_channel.wav")
    }

    // MARK: - Image resources

    @Test("sharksandwich resolves to correct file name")
    func sharksandwich() {
        #expect(resources.sharksandwich.lastPathComponent == "sharksandwich.jpg")
    }

    // MARK: - Resource naming

    @Test("resource URLs contain expected file extensions")
    func resourceExtensions() {
        #expect(resources.mp3_id3.pathExtension == "mp3")
        #expect(resources.wav_bext_v1.pathExtension == "wav")
        #expect(resources.tabla_aac.pathExtension == "aac")
        #expect(resources.tabla_flac.pathExtension == "flac")
        #expect(resources.tabla_ogg.pathExtension == "ogg")
        #expect(resources.tabla_aif.pathExtension == "aif")
        #expect(resources.tabla_caf.pathExtension == "caf")
        #expect(resources.tabla_m4a.pathExtension == "m4a")
        #expect(resources.tabla_mp4.pathExtension == "mp4")
        #expect(resources.sharksandwich.pathExtension == "jpg")
        #expect(resources.addAudio.pathExtension == "addAudio")
    }
}
